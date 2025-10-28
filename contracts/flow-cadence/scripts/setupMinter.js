import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL, authz } from "./config.js";

// Configure FCL
configureFCL();

const SETUP_MINTER_TRANSACTION = `
import CHToken from 0xCHToken

transaction(allowedAmount: UFix64) {
  prepare(signer: auth(BorrowValue, SaveValue) &Account) {
    // Check if minter already exists
    if signer.storage.borrow<&CHToken.Minter>(from: CHToken.MinterStoragePath) != nil {
      log("Minter already exists")
      return
    }

    // Borrow the Administrator resource
    let admin = signer.storage.borrow<&CHToken.Administrator>(
      from: CHToken.AdminStoragePath
    ) ?? panic("Could not borrow admin reference")

    // Create the Minter resource with allowed amount
    let minter <- admin.createNewMinter(allowedAmount: allowedAmount)

    // Save the Minter to storage
    signer.storage.save(<-minter, to: CHToken.MinterStoragePath)

    log("Minter created with allowed amount: ".concat(allowedAmount.toString()))
  }
}
`;

async function setupMinter(allowedAmount) {
  try {
    console.log("Setting up CHToken Minter...");
    console.log("Allowed Amount:", allowedAmount, "CHT");

    const authorization = authz();

    const transactionId = await fcl.mutate({
      cadence: SETUP_MINTER_TRANSACTION,
      args: (arg, t) => [
        arg(allowedAmount, t.UFix64),
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

    console.log("\n✓ Minter setup complete!");
    console.log("Minter can mint up to:", allowedAmount, "CHT");

    return transaction;
  } catch (error) {
    console.error("Error setting up minter:", error);
    throw error;
  }
}

// Example usage
const args = process.argv.slice(2);
const allowedAmount = args[0] || "1000000000.0"; // Default: 1 billion CHT

console.log("Creating minter with allowed amount:", allowedAmount, "CHT");

setupMinter(allowedAmount)
  .then(() => {
    console.log("\nMinter is ready to use!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Failed to setup minter:", error);
    process.exit(1);
  });
