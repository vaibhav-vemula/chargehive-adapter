import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { configureFCL } from "./config.js";

// Configure FCL
configureFCL();

const GET_PENDING_BOOKING_SCRIPT = `
import CHAdapter from 0xCHAdapter

access(all) fun main(adapterId: String): CHAdapter.BookingInfo? {
  return CHAdapter.getPendingBookingForAdapter(adapterId: adapterId)
}
`;

async function getPendingBooking(adapterId) {
  try {
    const booking = await fcl.query({
      cadence: GET_PENDING_BOOKING_SCRIPT,
      args: (arg, t) => [
        arg(adapterId, t.String)
      ]
    });

    if (booking) {
      // Output in a machine-readable format
      console.log(JSON.stringify({
        success: true,
        booking: {
          bookingId: booking.bookingId,
          adapterId: booking.adapterId,
          userAddress: booking.userAddress,
          scheduledTime: booking.scheduledTime,
          status: booking.status,
          createdAt: booking.createdAt
        }
      }));
    } else {
      console.log(JSON.stringify({
        success: false,
        message: "No pending booking found"
      }));
    }

    return booking;
  } catch (error) {
    console.error(JSON.stringify({
      success: false,
      error: error.message
    }));
    throw error;
  }
}

// Example usage
const args = process.argv.slice(2);

if (args.length < 1) {
  console.log(JSON.stringify({
    success: false,
    error: "Usage: node getPendingBooking.js <adapterId>"
  }));
  process.exit(1);
}

const adapterId = args[0];

getPendingBooking(adapterId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    process.exit(1);
  });
