/*
 * Get Adapter Bookings Script
 *
 * Query all bookings for an adapter from backend API
 * Note: Bookings are stored off-chain in the backend
 *
 * Usage:
 * curl http://localhost:3000/booking/adapter/:adapterId
 */

access(all) fun main(adapterId: String): String {
    let message = "Adapter ID: ".concat(adapterId)
    let info = "To get bookings, call: GET /booking/adapter/".concat(adapterId)

    log(message)
    log(info)
    log("Note: Bookings are stored in backend API at http://localhost:3000")

    return info
}
