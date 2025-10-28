import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL, authz } from "./config.js";

// Configure FCL
configureFCL();

const MINT_TOKENS_TRANSACTION = `
import FungibleToken from 0xFungibleToken
import CHToken from 0xCHToken

transaction(amount: UFix64, recipient: Address) {
  let minterRef: &CHToken.Minter
  let recipientRef: &{FungibleToken.Receiver}

  prepare(signer: auth(BorrowValue) &Account) {
    // Borrow minter reference
    self.minterRef = signer.storage.borrow<&CHToken.Minter>(
      from: CHToken.MinterStoragePath
    ) ?? panic("Could not borrow minter reference")

    // Get recipient's receiver capability
    self.recipientRef = getAccount(recipient)
      .capabilities.borrow<&{FungibleToken.Receiver}>(CHToken.ReceiverPublicPath)
      ?? panic("Could not borrow receiver reference")
  }

  execute {
    // Mint tokens
    let vault <- self.minterRef.mintTokens(amount: amount)

    // Deposit to recipient
    self.recipientRef.deposit(from: <-vault)

    log("Minted ".concat(amount.toString()).concat(" CHT to ").concat(recipient.toString()))
  }
}
`;

async function mintTokens(amount, recipient) {
  try {
    console.log("Minting CHT tokens...");
    console.log("Amount:", amount, "CHT");
    console.log("Recipient:", recipient);

    const authorization = authz();

    const transactionId = await fcl.mutate({
      cadence: MINT_TOKENS_TRANSACTION,
      args: (arg, t) => [
        arg(amount, t.UFix64),
        arg(recipient, t.Address),
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

    // Find TokensMinted event
    const mintEvent = transaction.events.find(e => e.type.includes("TokensMinted"));
    if (mintEvent) {
      console.log("\n✓ Tokens minted successfully!");
      console.log("Amount:", mintEvent.data.amount, "CHT");
    }

    return transaction;
  } catch (error) {
    console.error("Error minting tokens:", error);
    throw error;
  }
}

// Example usage
const args = process.argv.slice(2);

if (args.length < 2) {
  console.log("Usage: node mintTokens.js <amount> <recipient>");
  console.log("Example: node mintTokens.js 10000.0 0x919d69a9d0efa39b");
  console.log("");
  console.log("This will mint new CHT tokens to the specified recipient address.");
  process.exit(1);
}

const [amountStr, recipient] = args;
const amount = amountStr;

mintTokens(amount, recipient)
  .then(() => {
    console.log("\nTokens minted successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Failed to mint tokens:", error);
    process.exit(1);
  });
