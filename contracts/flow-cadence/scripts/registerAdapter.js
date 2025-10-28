import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL, authz } from "./config.js";

// Configure FCL
configureFCL();

const REGISTER_ADAPTER_TRANSACTION = `
import CHAdapter from 0xCHAdapter

transaction(
  adapterId: String,
  ownerAddress: Address,
  location: String,
  details: String,
  pricePerKwh: UFix64
) {
  prepare(signer: auth(BorrowValue) &Account) {
    // Signer can be admin or backend service account
  }

  execute {
    CHAdapter.registerAdapter(
      adapterId: adapterId,
      ownerAddress: ownerAddress,
      location: location,
      details: details,
      pricePerKwh: pricePerKwh
    )
    log("Adapter registered successfully")
  }
}
`;

async function registerAdapter(adapterId, ownerAddress, location, details, pricePerKwh) {
  try {
    console.log("Registering adapter...");
    console.log("Adapter ID:", adapterId);
    console.log("Owner Address:", ownerAddress);
    console.log("Location:", location);
    console.log("Details:", details);
    console.log("Price per kWh:", pricePerKwh);

    const authorization = authz();

    const transactionId = await fcl.mutate({
      cadence: REGISTER_ADAPTER_TRANSACTION,
      args: (arg, t) => [
        arg(adapterId, t.String),
        arg(ownerAddress, t.Address),
        arg(location, t.String),
        arg(details, t.String),
        arg(pricePerKwh, t.UFix64),
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
    console.log("Events:", transaction.events);

    return transaction;
  } catch (error) {
    console.error("Error registering adapter:", error);
    throw error;
  }
}

// Example usage
const args = process.argv.slice(2);

if (args.length < 5) {
  console.log("Usage: node registerAdapter.js <adapterId> <ownerAddress> <location> <details> <pricePerKwh>");
  console.log("Example: node registerAdapter.js RPI-SF-001 0x1234567890abcdef '123 Market St, SF' 'Level 2, Type 2, 7kW' 0.25");
  process.exit(1);
}

const [adapterId, ownerAddress, location, details, pricePerKwh] = args;

registerAdapter(adapterId, ownerAddress, location, details, pricePerKwh)
  .then(() => {
    console.log("Adapter registered successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Failed to register adapter:", error);
    process.exit(1);
  });
