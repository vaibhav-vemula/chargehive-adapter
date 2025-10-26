const fcl = require("@onflow/fcl");
const t = require("@onflow/types");
const config = require("../config.json");
const bookingManager = require("./bookingManager");

// Configure FCL
fcl.config()
  .put("accessNode.api", config.accessNode)
  .put("flow.network", config.network);

const endSession = async (req, res) => {
  try {
    const { energy, sessionId } = req.body;

    if (!sessionId || !energy) {
      return res.status(400).json({
        error: "Missing required parameters",
        details: "sessionId and energy are required"
      });
    }

    const signerAddress = config.adapterAddress;
    const privateKey = config.adapterPrivateKey;

    // Transaction code to end session and distribute rewards
    // This is the magic - single transaction does BOTH!
    const txCode = `
import CHAdapter from ${config.CHAdapterContract}

transaction(sessionId: String, energyUsed: UFix64) {

    prepare(signer: auth(BorrowValue) &Account) {
        // No preparation needed - contract manages everything
    }

    execute {
        // End session and automatically distribute rewards to both provider and user
        CHAdapter.endSessionAndDistributeRewards(
            sessionId: sessionId,
            energyUsed: energyUsed
        )

        log("✅ Session ended and rewards distributed!")
        log("Session ID: ".concat(sessionId))
        log("Energy Used: ".concat(energyUsed.toString()).concat(" kWh"))
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
        fcl.arg(sessionId, t.String),
        fcl.arg(energy.toFixed(1), t.UFix64)
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

    // Extract reward information from events
    let providerReward = null;
    let userReward = null;
    let providerAddress = null;
    let userAddress = null;

    for (const event of txResult.events) {
      console.log("Event:", event.type, event.data);

      if (event.type.includes("CHAdapter.SessionEnded")) {
        providerReward = event.data.providerReward;
        userReward = event.data.userReward;
      }

      if (event.type.includes("CHAdapter.RewardsDistributed")) {
        providerAddress = event.data.providerAddress;
        userAddress = event.data.userAddress;
      }
    }

    // Check if this session had a booking and complete it
    const booking = bookingManager.findBookingBySession(sessionId);
    if (booking && booking.status === "active") {
      bookingManager.completeBooking(booking.bookingId);
      console.log(`Booking ${booking.bookingId} completed`);
    }

    res.json({
      message: "Session Ended and Rewards Distributed",
      sessionId: sessionId,
      energyUsed: energy,
      providerReward: providerReward,
      userReward: userReward,
      providerAddress: providerAddress,
      userAddress: userAddress,
      bookingId: booking ? booking.bookingId : null,
      transactionId: response.transactionId,
      status: txResult.status
    });

  } catch (error) {
    console.error("Error ending session:", error);
    res.status(500).json({
      error: "Failed to end session",
      details: error.message
    });
  }
};

module.exports = { endSession };
