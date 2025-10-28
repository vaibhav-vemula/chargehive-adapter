import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL } from "./config.js";

// Configure FCL
configureFCL();

const GET_ADAPTER_SCRIPT = `
import CHAdapter from 0xCHAdapter

access(all) fun main(adapterId: String): CHAdapter.AdapterInfo? {
  return CHAdapter.getAdapter(adapterId: adapterId)
}
`;

async function getAdapter(adapterId) {
  try {
    console.log("Querying adapter info for:", adapterId);

    const adapter = await fcl.query({
      cadence: GET_ADAPTER_SCRIPT,
      args: (arg, t) => [
        arg(adapterId, t.String)
      ]
    });

    if (adapter) {
      console.log("\n=== Adapter Information ===");
      console.log("Adapter ID:", adapter.adapterId);
      console.log("Owner Address:", adapter.ownerAddress);
      console.log("Location:", adapter.location);
      console.log("Details:", adapter.details);
      console.log("Price per kWh:", "$" + adapter.pricePerKwh);
      console.log("Authorized:", adapter.authorized);
      console.log("Created At:", new Date(parseFloat(adapter.createdAt) * 1000).toISOString());
    } else {
      console.log("Adapter not found!");
    }

    return adapter;
  } catch (error) {
    console.error("Error getting adapter info:", error);
    throw error;
  }
}

// Example usage
const args = process.argv.slice(2);

if (args.length < 1) {
  console.log("Usage: node getAdapter.js <adapterId>");
  console.log("Example: node getAdapter.js RPI-SF-001");
  process.exit(1);
}

const adapterId = args[0];

getAdapter(adapterId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error("Failed to get adapter info:", error);
    process.exit(1);
  });
