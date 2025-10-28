import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL, authz } from "./config.js";

// Configure FCL
configureFCL();

const START_SESSION_TRANSACTION = `
import CHAdapter from 0xCHAdapter

transaction(bookingId: UInt64) {
  prepare(signer: auth(BorrowValue) &Account) {
    // Signer is typically the backend service or Raspberry Pi controller
  }

  execute {
    let sessionId = CHAdapter.startSessionWithBooking(bookingId: bookingId)
    log("Session started with ID: ".concat(sessionId))
  }
}
`;

async function startSession(bookingId) {
  try {
    console.log("Starting charging session...");
    console.log("Booking ID:", bookingId);

    const authorization = authz();

    const transactionId = await fcl.mutate({
      cadence: START_SESSION_TRANSACTION,
      args: (arg, t) => [
        arg(bookingId, t.UInt64),
      ],
      proposer: authorization,
      payer: authorization,
      authorizations: [authorization],
      limit: 999,
    });

    console.log("Transaction ID:", transactionId);
    console.log("Waiting for transaction to be sealed...");

    const transaction = await fcl.tx(transactionId).onceSealed();
    console.log("Transaction sealed!");
    console.log("Status:", transaction.status);

    // Find SessionStarted event
    const sessionEvent = transaction.events.find(e => e.type.includes("SessionStarted"));
    if (sessionEvent) {
      console.log("\nSession Details:");
      console.log("Session ID:", sessionEvent.data.sessionId);
      console.log("Adapter ID:", sessionEvent.data.adapterId);
      console.log("User Address:", sessionEvent.data.userAddress);
      console.log("Owner Address:", sessionEvent.data.ownerAddress);
      console.log("Timestamp:", sessionEvent.data.timestamp);
    }

    return transaction;
  } catch (error) {
    console.error("Error starting session:", error);
    throw error;
  }
}

// Example usage
const args = process.argv.slice(2);

if (args.length < 1) {
  console.log("Usage: node startSession.js <bookingId>");
  console.log("Example: node startSession.js 0");
  process.exit(1);
}

const bookingId = args[0];

startSession(bookingId)
  .then(() => {
    console.log("\nCharging session started successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Failed to start session:", error);
    process.exit(1);
  });
