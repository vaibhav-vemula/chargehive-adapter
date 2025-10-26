const fcl = require("@onflow/fcl");
const t = require("@onflow/types");
const fs = require("fs");
const path = require("path");
const config = require("../config.json");
const bookingManager = require("./bookingManager");

// Configure FCL
fcl.config()
  .put("accessNode.api", config.accessNode)
  .put("flow.network", config.network);

const startSession = async (req, res) => {
  try {
    const adapterId = config.adapterId;

    // Check for pending booking first
    const pendingBooking = bookingManager.getPendingBookingForAdapter(adapterId);

    let userAddress;
    let bookingId = null;

    if (pendingBooking) {
      // Use booking's user address
      userAddress = pendingBooking.userAddress;
      bookingId = pendingBooking.bookingId;
      console.log(`Found pending booking ${bookingId} for user ${userAddress}`);
    } else {
      // Fallback: use configured user address or from query params
      userAddress = req.query.userAddress || config.userAddress;
      console.log(`No booking found, using user address: ${userAddress}`);
    }

    const signerAddress = config.platformAddress || config.adapterAddress;
    const privateKey = config.platformPrivateKey || config.adapterPrivateKey;

    // Transaction code to start a charging session
    const txCode = `
import CHAdapter from ${config.CHAdapterContract}

transaction(adapterId: String, userAddress: Address) {

    prepare(signer: auth(BorrowValue) &Account) {
        // No preparation needed - contract manages storage
    }

    execute {
        // Start the charging session
        let sessionId = CHAdapter.startSession(
            adapterId: adapterId,
            userAddress: userAddress
        )

        log("✅ Charging session started!")
        log("Session ID: ".concat(sessionId))
        log("Adapter ID: ".concat(adapterId))
        log("User: ".concat(userAddress.toString()))
    }
}
`;

    // Create authorization function
    const authorization = (account) => {
      return {
        ...account,
        tempId: `${signerAddress}-${Math.random()}`,
        addr: fcl.sansPrefix(signerAddress),
        keyId: 0,
        signingFunction: async (signable) => {
          const ec = require("elliptic").ec;
          const curve = new ec("p256");
          const key = curve.keyFromPrivate(Buffer.from(privateKey, "hex"));
          const sig = key.sign(Buffer.from(signable.message, "hex"));
          const n = 32;
          const r = sig.r.toArrayLike(Buffer, "be", n);
          const s = sig.s.toArrayLike(Buffer, "be", n);
          return {
            addr: fcl.sansPrefix(signerAddress),
            keyId: 0,
            signature: Buffer.concat([r, s]).toString("hex")
          };
        }
      };
    };

    // Send transaction
    const response = await fcl.send([
      fcl.transaction(txCode),
      fcl.args([
        fcl.arg(adapterId, t.String),
        fcl.arg(userAddress, t.Address)
      ]),
      fcl.proposer(authorization),
      fcl.authorizations([authorization]),
      fcl.payer(authorization),
      fcl.limit(9999)
    ]);

    console.log("Transaction sent:", response.transactionId);

    // Wait for transaction to be sealed
    const txResult = await fcl.tx(response).onceSealed();
    console.log("Transaction sealed:", txResult.status);

    // Extract session ID from events
    let sessionId = null;
    for (const event of txResult.events) {
      if (event.type.includes("CHAdapter.SessionStarted")) {
        sessionId = event.data.sessionId;
        console.log("Generated Session ID:", sessionId);
        break;
      }
    }

    // Save session ID to file
    const filePath = path.join(__dirname, "sessions-flow.json");
    updateSessionsFile(filePath, sessionId);

    // If this session came from a booking, activate it
    if (bookingId !== null) {
      bookingManager.activateBooking(bookingId, sessionId);
      console.log(`Booking ${bookingId} activated with session ${sessionId}`);
    }

    res.json({
      message: "Session Created and Started",
      sessionId: sessionId,
      bookingId: bookingId,
      userAddress: userAddress,
      transactionId: response.transactionId,
      status: txResult.status
    });

  } catch (error) {
    console.error("Error starting session:", error);
    res.status(500).json({
      error: "Failed to start session",
      details: error.message
    });
  }
};

const updateSessionsFile = (filePath, sessionid) => {
  if (!fs.existsSync(filePath)) {
    fs.writeFileSync(
      filePath,
      JSON.stringify({ sessions: [] }, null, 2),
      "utf8"
    );
  }

  fs.readFile(filePath, "utf8", (err, data) => {
    if (err) {
      console.error("Error reading file:", err);
      return;
    }

    let jsonData;
    try {
      jsonData = JSON.parse(data);
    } catch (parseError) {
      console.error("Error parsing JSON:", parseError);
      return;
    }

    if (!Array.isArray(jsonData.sessions)) {
      jsonData.sessions = [];
    }

    jsonData.sessions.push(sessionid);

    fs.writeFile(
      filePath,
      JSON.stringify(jsonData, null, 2),
      "utf8",
      (writeErr) => {
        if (writeErr) {
          console.error("Error writing file:", writeErr);
        } else {
          console.log("Session ID saved to file");
        }
      }
    );
  });
};

module.exports = { startSession };
