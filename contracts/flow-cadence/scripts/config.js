import * as fcl from "@onflow/fcl";
import pkg from "sha3";
const { SHA3 } = pkg;
import elliptic from "elliptic";
const { ec: EC } = elliptic;
import dotenv from "dotenv";

dotenv.config();

const ec = new EC("p256");

// Network configuration
const NETWORK = process.env.FLOW_NETWORK || "testnet";
const FLOW_ADDRESS = process.env.FLOW_ADDRESS;
const FLOW_PRIVATE_KEY = process.env.FLOW_PRIVATE_KEY;
const FLOW_KEY_INDEX = parseInt(process.env.FLOW_KEY_INDEX || "0");

// Configure FCL based on network
export function configureFCL() {
  const chtAddress = process.env.CHTTOKEN_ADDRESS || FLOW_ADDRESS;
  const chAdapterAddress = process.env.CHADAPTER_ADDRESS || FLOW_ADDRESS;

  // Ensure addresses have 0x prefix
  const formatAddress = (addr) => {
    if (!addr) return addr;
    return addr.startsWith('0x') ? addr : `0x${addr}`;
  };

  if (NETWORK === "testnet") {
    fcl.config({
      "accessNode.api": "https://rest-testnet.onflow.org",
      "flow.network": "testnet",
      "0xFungibleToken": "0x9a0766d93b6608b7",
      "0xFungibleTokenMetadataViews": "0x9a0766d93b6608b7",
      "0xMetadataViews": "0x631e88ae7f1d7c20",
      "0xViewResolver": "0x631e88ae7f1d7c20",
      "0xBurner": "0x9a0766d93b6608b7",
      "0xCHToken": formatAddress(chtAddress),
      "0xCHAdapter": formatAddress(chAdapterAddress),
    });
  } else if (NETWORK === "mainnet") {
    fcl.config({
      "accessNode.api": "https://rest-mainnet.onflow.org",
      "flow.network": "mainnet",
      "0xFungibleToken": "0xf233dcee88fe0abe",
      "0xFungibleTokenMetadataViews": "0xf233dcee88fe0abe",
      "0xMetadataViews": "0x1d7e57aa55817448",
      "0xViewResolver": "0x1d7e57aa55817448",
      "0xBurner": "0xf233dcee88fe0abe",
      "0xCHToken": formatAddress(chtAddress),
      "0xCHAdapter": formatAddress(chAdapterAddress),
    });
  } else {
    // Emulator
    fcl.config({
      "accessNode.api": "http://localhost:8888",
      "flow.network": "emulator",
      "0xFungibleToken": "0xee82856bf20e2aa6",
      "0xFungibleTokenMetadataViews": "0xee82856bf20e2aa6",
      "0xMetadataViews": "0x179b6b1cb6755e31",
      "0xViewResolver": "0xf8d6e0586b0a20c7",
      "0xBurner": "0xf8d6e0586b0a20c7",
      "0xCHToken": "0xf8d6e0586b0a20c7",
      "0xCHAdapter": "0xf8d6e0586b0a20c7",
    });
  }
}

// Sign message with private key
function signWithKey(privateKey, message) {
  const key = ec.keyFromPrivate(Buffer.from(privateKey, "hex"));
  const sha = new SHA3(256);
  sha.update(Buffer.from(message, "hex"));
  const digest = sha.digest();
  const signature = key.sign(digest);
  const n = 32;
  const r = signature.r.toArrayLike(Buffer, "be", n);
  const s = signature.s.toArrayLike(Buffer, "be", n);
  return Buffer.concat([r, s]).toString("hex");
}

// Authorization function for server-side signing
export const authz = (account) => {
  return async (account = {}) => {
    const user = account.addr || FLOW_ADDRESS;
    const key = FLOW_KEY_INDEX;
    const privateKey = FLOW_PRIVATE_KEY;

    if (!privateKey) {
      throw new Error("FLOW_PRIVATE_KEY not found in environment");
    }

    return {
      ...account,
      tempId: `${user}-${key}`,
      addr: fcl.sansPrefix(user),
      keyId: Number(key),
      signingFunction: async (signable) => {
        return {
          addr: fcl.withPrefix(user),
          keyId: Number(key),
          signature: signWithKey(privateKey, signable.message),
        };
      },
    };
  };
};

export const getAccountAddress = () => {
  return FLOW_ADDRESS;
};

export const getCHAdapterAddress = () => {
  return process.env.CHADAPTER_ADDRESS || FLOW_ADDRESS;
};

export const getCHTokenAddress = () => {
  return process.env.CHTTOKEN_ADDRESS || FLOW_ADDRESS;
};
