/*
 * Get User Bookings Script
 *
 * Query all bookings for a user from backend API
 * Note: Bookings are stored off-chain in the backend
 *
 * Usage:
 * curl http://localhost:3000/booking/user/:userAddress
 */

access(all) fun main(userAddress: Address): String {
    let message = "User Address: ".concat(userAddress.toString())
    let info = "To get user bookings, call: GET /booking/user/".concat(userAddress.toString())

    log(message)
    log(info)
    log("Note: Bookings are stored in backend API at http://localhost:3000")

    return info
}
