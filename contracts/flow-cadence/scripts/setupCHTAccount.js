import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL, authz } from "./config.js";

// Configure FCL
configureFCL();

const SETUP_ACCOUNT_TRANSACTION = `
import FungibleToken from 0xFungibleToken
import CHToken from 0xCHToken

transaction {
  prepare(signer: auth(BorrowValue, SaveValue, StorageCapabilities, Capabilities) &Account) {
    // Check if vault already exists
    if signer.storage.borrow<&CHToken.Vault>(from: CHToken.VaultStoragePath) != nil {
      log("CHToken Vault already exists")
      return
    }

    // Create a new CHToken Vault and put it in storage
    let vault <- CHToken.createEmptyVault(vaultType: Type<@CHToken.Vault>())
    signer.storage.save(<-vault, to: CHToken.VaultStoragePath)

    // Create public capabilities for the vault
    let vaultCap = signer.capabilities.storage.issue<&CHToken.Vault>(
      CHToken.VaultStoragePath
    )
    signer.capabilities.publish(vaultCap, at: CHToken.ReceiverPublicPath)
    signer.capabilities.publish(vaultCap, at: CHToken.VaultPublicPath)

    log("CHToken Vault setup complete")
  }
}
`;

async function setupCHTAccount(address) {
  try {
    console.log("Setting up CHToken vault for address:", address);

    const authorization = authz();

    const transactionId = await fcl.mutate({
      cadence: SETUP_ACCOUNT_TRANSACTION,
      args: (arg, t) => [],
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

    console.log("\n✓ CHToken vault setup complete!");
    console.log("Account can now receive CHT tokens from:", address);

    return transaction;
  } catch (error) {
    console.error("Error setting up account:", error);
    throw error;
  }
}

// Example usage
const args = process.argv.slice(2);

if (args.length < 1) {
  console.log("Usage: node setupCHTAccount.js <address>");
  console.log("Example: node setupCHTAccount.js 0x919d69a9d0efa39b");
  console.log("");
  console.log("This sets up a CHToken vault for the specified address.");
  console.log("Required before an account can receive CHT tokens.");
  process.exit(1);
}

const address = args[0];

setupCHTAccount(address)
  .then(() => {
    console.log("\nAccount is ready to receive CHT tokens!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Failed to setup account:", error);
    process.exit(1);
  });
