/*
 * Get Pending Booking Script
 *
 * Query pending booking for an adapter from backend API
 * Note: Bookings are stored off-chain in the backend
 *
 * Usage:
 * curl http://localhost:3000/booking/adapter/:adapterId/pending
 */

access(all) fun main(adapterId: String): String {
    let message = "Checking for pending booking on adapter: ".concat(adapterId)
    let info = "To get pending booking, call: GET /booking/adapter/".concat(adapterId).concat("/pending")

    log(message)
    log(info)
    log("Note: Bookings are stored in backend API at http://localhost:3000")

    return info
}
