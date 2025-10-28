import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL, authz } from "./config.js";

// Configure FCL
configureFCL();

const END_SESSION_TRANSACTION = `
import CHAdapter from 0xCHAdapter

transaction(sessionId: String, energyUsed: UFix64) {
  prepare(signer: auth(BorrowValue) &Account) {
    // Signer is typically the backend service or Raspberry Pi controller
  }

  execute {
    CHAdapter.endSessionAndDistributeRewards(
      sessionId: sessionId, 
      energyUsed: energyUsed
    )
    log("Session ended and rewards distributed")
  }
}
`;

async function endSession(sessionId, energyUsed) {
  try {
    console.log("Ending charging session...");
    console.log("Session ID:", sessionId);
    console.log("Energy Used (kWh):", energyUsed);

    const authorization = authz();

    const transactionId = await fcl.mutate({
      cadence: END_SESSION_TRANSACTION,
      args: (arg, t) => [
        arg(sessionId, t.String),
        arg(energyUsed, t.UFix64),
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

    // Find SessionEnded event
    const sessionEndedEvent = transaction.events.find(e => e.type.includes("SessionEnded"));
    if (sessionEndedEvent) {
      console.log("\n=== Session Summary ===");
      console.log("Session ID:", sessionEndedEvent.data.sessionId);
      console.log("Adapter ID:", sessionEndedEvent.data.adapterId);
      console.log("Energy Used:", sessionEndedEvent.data.energyUsed, "kWh");
      console.log("Provider Reward:", sessionEndedEvent.data.providerReward, "CHT");
      console.log("User Reward:", sessionEndedEvent.data.userReward, "CHT");
      console.log("USD Cost:", "$" + sessionEndedEvent.data.usdCost);
      console.log("Timestamp:", sessionEndedEvent.data.timestamp);
    }

    // Find RewardsDistributed event
    const rewardsEvent = transaction.events.find(e => e.type.includes("RewardsDistributed"));
    if (rewardsEvent) {
      console.log("\n=== Rewards Distributed ===");
      console.log("Provider Address:", rewardsEvent.data.providerAddress);
      console.log("Provider Amount:", rewardsEvent.data.providerAmount, "CHT");
      console.log("User Address:", rewardsEvent.data.userAddress);
      console.log("User Amount:", rewardsEvent.data.userAmount, "CHT");
    }

    return transaction;
  } catch (error) {
    console.error("Error ending session:", error);
    throw error;
  }
}

// Example usage
const args = process.argv.slice(2);

if (args.length < 2) {
  console.log("Usage: node endSession.js <sessionId> <energyUsed>");
  console.log("Example: node endSession.js RPI-SF-001-0x123-1234567890-0 5.5");
  console.log("         (Session ID from SessionStarted event, energy in kWh)");
  process.exit(1);
}

const [sessionId, energyUsedStr] = args;
const energyUsed = energyUsedStr;

endSession(sessionId, energyUsed)
  .then(() => {
    console.log("\n✓ Session ended and rewards distributed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Failed to end session:", error);
    process.exit(1);
  });
