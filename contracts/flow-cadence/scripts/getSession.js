import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL } from "./config.js";

// Configure FCL
configureFCL();

const GET_SESSION_SCRIPT = `
import CHAdapter from 0xCHAdapter

access(all) fun main(sessionId: String): CHAdapter.SessionInfo? {
  return CHAdapter.getSession(sessionId: sessionId)
}
`;

async function getSession(sessionId) {
  try {
    console.log("Querying session info for:", sessionId);

    const session = await fcl.query({
      cadence: GET_SESSION_SCRIPT,
      args: (arg, t) => [
        arg(sessionId, t.String)
      ]
    });

    if (session) {
      console.log("\n=== Session Information ===");
      console.log("Session ID:", session.sessionId);
      console.log("Adapter ID:", session.adapterId);
      console.log("Owner Address:", session.ownerAddress);
      console.log("User Address:", session.userAddress);
      console.log("Start Time:", new Date(parseFloat(session.startTime) * 1000).toISOString());
      console.log("Active:", session.active);
      console.log("Energy Used:", session.energyUsed, "kWh");
      console.log("Provider Reward:", session.providerReward, "CHT");
      console.log("User Reward:", session.userReward, "CHT");
      console.log("USD Cost:", "$" + session.usdCost);
      console.log("Rewards Distributed:", session.rewardsDistributed);

      if (!session.active) {
        console.log("End Time:", new Date(parseFloat(session.endTime) * 1000).toISOString());
      }
    } else {
      console.log("\n❌ Session not found!");
      console.log("This session ID doesn't exist. Possible reasons:");
      console.log("1. The session was never started");
      console.log("2. The session ID is incorrect");
      console.log("3. Check the SessionStarted event for the correct session ID");
    }

    return session;
  } catch (error) {
    console.error("Error getting session info:", error);
    throw error;
  }
}

// Example usage
const args = process.argv.slice(2);

if (args.length < 1) {
  console.log("Usage: node getSession.js <sessionId>");
  console.log("Example: node getSession.js RPI-SF-001-0x919d69a9d0efa39b-1234567890-0");
  process.exit(1);
}

const sessionId = args[0];

getSession(sessionId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error("Failed to get session info:", error);
    process.exit(1);
  });
