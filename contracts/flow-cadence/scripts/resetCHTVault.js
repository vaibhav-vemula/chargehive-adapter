import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL, authz } from "./config.js";

// Configure FCL
configureFCL();

const RESET_VAULT_TRANSACTION = `
import FungibleToken from 0xFungibleToken
import CHToken from 0xCHToken
import Burner from 0xBurner

transaction {
  prepare(signer: auth(BorrowValue, SaveValue, StorageCapabilities, Capabilities, UnpublishCapability, LoadValue) &Account) {
    // Check if there's an existing vault
    if let oldVault <- signer.storage.load<@AnyResource>(from: CHToken.VaultStoragePath) {
      log("Found existing vault, destroying it")

      // Destroy the old vault (this burns any tokens in it)
      Burner.burn(<-oldVault)
    }

    // Unpublish old capabilities if they exist
    signer.capabilities.unpublish(CHToken.ReceiverPublicPath)
    signer.capabilities.unpublish(CHToken.VaultPublicPath)

    // Create a new CHToken Vault with the correct contract
    let vault <- CHToken.createEmptyVault(vaultType: Type<@CHToken.Vault>())
    signer.storage.save(<-vault, to: CHToken.VaultStoragePath)

    // Create new public capabilities
    let vaultCap = signer.capabilities.storage.issue<&CHToken.Vault>(
      CHToken.VaultStoragePath
    )
    signer.capabilities.publish(vaultCap, at: CHToken.ReceiverPublicPath)
    signer.capabilities.publish(vaultCap, at: CHToken.VaultPublicPath)

    log("CHToken Vault reset complete - account ready to receive CHT tokens")
  }
}
`;

async function resetCHTVault() {
  try {
    console.log("⚠️  WARNING: This will destroy any existing CHToken vault and its tokens!");
    console.log("This script will:");
    console.log("1. Remove the old CHToken vault (burning any tokens in it)");
    console.log("2. Create a new vault using your CHToken contract");
    console.log("");
    console.log("Proceeding in 3 seconds...");

    await new Promise(resolve => setTimeout(resolve, 3000));

    console.log("\nResetting CHToken vault...");

    const authorization = authz();

    const transactionId = await fcl.mutate({
      cadence: RESET_VAULT_TRANSACTION,
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

    console.log("\n✓ CHToken vault reset complete!");
    console.log("Account is now set up with the correct CHToken contract.");
    console.log("The account can now receive CHT rewards!");

    return transaction;
  } catch (error) {
    console.error("Error resetting vault:", error);
    throw error;
  }
}

console.log("=== CHToken Vault Reset Tool ===");
console.log("");

resetCHTVault()
  .then(() => {
    console.log("\nVault reset successful!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Failed to reset vault:", error);
    process.exit(1);
  });
