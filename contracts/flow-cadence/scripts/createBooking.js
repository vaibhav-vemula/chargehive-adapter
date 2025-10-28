import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL, authz } from "./config.js";

// Configure FCL
configureFCL();

const CREATE_BOOKING_TRANSACTION = `
import CHAdapter from 0xCHAdapter

transaction(
  adapterId: String,
  userAddress: Address,
  scheduledTime: UFix64
) {
  prepare(signer: auth(BorrowValue) &Account) {
    // Signer can be backend service account
  }

  execute {
    let bookingId = CHAdapter.createBooking(
      adapterId: adapterId,
      userAddress: userAddress,
      scheduledTime: scheduledTime
    )
    log("Booking created with ID: ".concat(bookingId.toString()))
  }
}
`;

async function createBooking(adapterId, userAddress, scheduledTime) {
  try {
    console.log("Creating booking...");
    console.log("Adapter ID:", adapterId);
    console.log("User Address:", userAddress);
    console.log("Scheduled Time:", scheduledTime);

    const authorization = authz();

    const transactionId = await fcl.mutate({
      cadence: CREATE_BOOKING_TRANSACTION,
      args: (arg, t) => [
        arg(adapterId, t.String),
        arg(userAddress, t.Address),
        arg(scheduledTime, t.UFix64),
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

    // Find BookingCreated event
    const bookingEvent = transaction.events.find(e => e.type.includes("BookingCreated"));
    if (bookingEvent) {
      console.log("Booking ID:", bookingEvent.data.bookingId);
      console.log("Event data:", bookingEvent.data);
    }

    return transaction;
  } catch (error) {
    console.error("Error creating booking:", error);
    throw error;
  }
}

// Example usage
const args = process.argv.slice(2);

if (args.length < 3) {
  console.log("Usage: node createBooking.js <adapterId> <userAddress> <scheduledTime>");
  console.log("Example: node createBooking.js RPI-SF-001 0x1234567890abcdef 1735689600.0");
  console.log("Note: scheduledTime should be a future Unix timestamp (UFix64)");
  console.log("      Current time: " + Date.now() / 1000);
  process.exit(1);
}

const [adapterId, userAddress, scheduledTimeStr] = args;
const scheduledTime = scheduledTimeStr;

createBooking(adapterId, userAddress, scheduledTime)
  .then(() => {
    console.log("Booking created successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Failed to create booking:", error);
    process.exit(1);
  });
