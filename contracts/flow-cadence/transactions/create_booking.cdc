/*
 * Create Booking Transaction
 *
 * User creates a booking for a charging adapter
 * This is stored off-chain in the backend but can be logged on-chain if needed
 */

transaction(
    adapterId: String,
    userAddress: Address,
    startTime: UFix64,
    endTime: UFix64
) {

    prepare(signer: auth(BorrowValue) &Account) {
        // Log the booking details
        log("Creating booking for adapter: ".concat(adapterId))
        log("User: ".concat(userAddress.toString()))
        log("Start Time: ".concat(startTime.toString()))
        log("End Time: ".concat(endTime.toString()))
    }

    execute {
        // In the current implementation, bookings are stored in backend
        // This transaction can be used to emit an event or store on-chain if needed
        log("✅ Booking request logged")
        log("Note: Actual booking stored in backend API")
    }
}
