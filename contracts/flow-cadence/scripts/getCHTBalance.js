import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL } from "./config.js";

// Configure FCL
configureFCL();

const GET_BALANCE_SCRIPT = `
import FungibleToken from 0xFungibleToken
import CHToken from 0xCHToken

access(all) fun main(address: Address): UFix64 {
  let account = getAccount(address)

  let vaultRef = account.capabilities
    .borrow<&{FungibleToken.Balance}>(CHToken.VaultPublicPath)
    ?? panic("Could not borrow Balance reference to the Vault")

  return vaultRef.balance
}
`;

async function getCHTBalance(address) {
  try {
    console.log("Querying CHT balance for address:", address);

    const balance = await fcl.query({
      cadence: GET_BALANCE_SCRIPT,
      args: (arg, t) => [
        arg(address, t.Address)
      ]
    });

    console.log("\n=== CHT Balance ===");
    console.log("Address:", address);
    console.log("Balance:", balance, "CHT");

    return balance;
  } catch (error) {
    console.error("Error getting CHT balance:", error);
    throw error;
  }
}

// Example usage
const args = process.argv.slice(2);

if (args.length < 1) {
  console.log("Usage: node getCHTBalance.js <address>");
  console.log("Example: node getCHTBalance.js 0x1234567890abcdef");
  process.exit(1);
}

const address = args[0];

getCHTBalance(address)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error("Failed to get CHT balance:", error);
    process.exit(1);
  });
