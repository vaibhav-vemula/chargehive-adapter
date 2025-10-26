/*
 * Get Booking Information Script
 *
 * Query booking details from backend API
 * Note: Bookings are stored off-chain in the backend
 *
 * Usage:
 * curl http://localhost:3000/booking/:bookingId
 */

access(all) fun main(bookingId: UInt64): String {
    let message = "Booking ID: ".concat(bookingId.toString())
    let info = "To get booking details, call: GET /booking/".concat(bookingId.toString())

    log(message)
    log(info)
    log("Note: Bookings are stored in backend API at http://localhost:3000")

    return info
}
