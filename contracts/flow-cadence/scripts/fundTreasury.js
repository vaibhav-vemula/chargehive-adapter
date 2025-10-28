import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL, authz, getAccountAddress } from "./config.js";

// Configure FCL
configureFCL();

const FUND_TREASURY_TRANSACTION = `
import FungibleToken from 0xFungibleToken
import CHToken from 0xCHToken
import CHAdapter from 0xCHAdapter

transaction(amount: UFix64) {
  let adminRef: &CHAdapter.Administrator
  let vaultRef: auth(FungibleToken.Withdraw) &CHToken.Vault

  prepare(signer: auth(BorrowValue, StorageCapabilities, SaveValue) &Account) {
    // Borrow admin reference
    self.adminRef = signer.storage.borrow<&CHAdapter.Administrator>(
      from: CHAdapter.AdminStoragePath
    ) ?? panic("Could not borrow admin reference")

    // Borrow CHT vault to withdraw from
    self.vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &CHToken.Vault>(
      from: CHToken.VaultStoragePath
    ) ?? panic("Could not borrow vault reference")
  }

  execute {
    // Withdraw tokens from signer's vault
    let vault <- self.vaultRef.withdraw(amount: amount)

    // Fund the treasury
    self.adminRef.fundTreasury(vault: <-vault)

    log("Treasury funded with ".concat(amount.toString()).concat(" CHT"))
  }
}
`;

async function fundTreasury(amount) {
  try {
    console.log("Funding CHAdapter treasury...");
    console.log("Amount:", amount, "CHT");

    const authorization = authz();

    const transactionId = await fcl.mutate({
      cadence: FUND_TREASURY_TRANSACTION,
      args: (arg, t) => [
        arg(amount, t.UFix64),
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

    console.log("\n✓ Treasury funded successfully!");
    console.log("Funded with:", amount, "CHT");

    return transaction;
  } catch (error) {
    console.error("Error funding treasury:", error);
    throw error;
  }
}

// Example usage
const args = process.argv.slice(2);

if (args.length < 1) {
  console.log("Usage: node fundTreasury.js <amount>");
  console.log("Example: node fundTreasury.js 1000.0");
  console.log("");
  console.log("This will transfer CHT tokens from your account to the CHAdapter treasury.");
  console.log("The treasury is used to distribute rewards to providers and users.");
  process.exit(1);
}

const amount = args[0];

fundTreasury(amount)
  .then(() => {
    console.log("\nTreasury is now ready to distribute rewards!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Failed to fund treasury:", error);
    process.exit(1);
  });
