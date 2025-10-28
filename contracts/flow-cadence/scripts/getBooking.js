import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL } from "./config.js";

// Configure FCL
configureFCL();

const GET_BOOKING_SCRIPT = `
import CHAdapter from 0xCHAdapter

access(all) fun main(bookingId: UInt64): CHAdapter.BookingInfo? {
  return CHAdapter.getBooking(bookingId: bookingId)
}
`;

async function getBooking(bookingId) {
  try {
    console.log("Querying booking info for ID:", bookingId);

    const booking = await fcl.query({
      cadence: GET_BOOKING_SCRIPT,
      args: (arg, t) => [
        arg(bookingId, t.UInt64)
      ]
    });

    if (booking) {
      console.log("\n=== Booking Information ===");
      console.log("Booking ID:", booking.bookingId);
      console.log("Adapter ID:", booking.adapterId);
      console.log("User Address:", booking.userAddress);
      console.log("Scheduled Time:", new Date(parseFloat(booking.scheduledTime) * 1000).toISOString());
      console.log("Status:", booking.status);
      console.log("Session ID:", booking.sessionId || "N/A");
      console.log("Created At:", new Date(parseFloat(booking.createdAt) * 1000).toISOString());
    } else {
      console.log("Booking not found!");
    }

    return booking;
  } catch (error) {
    console.error("Error getting booking info:", error);
    throw error;
  }
}

// Example usage
const args = process.argv.slice(2);

if (args.length < 1) {
  console.log("Usage: node getBooking.js <bookingId>");
  console.log("Example: node getBooking.js 0");
  process.exit(1);
}

const bookingId = args[0];

getBooking(bookingId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error("Failed to get booking info:", error);
    process.exit(1);
  });
