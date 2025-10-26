/*
 * Get User Bookings
 *
 * This script returns all parking bookings for a user
 */

import "CHParking"

access(all) fun main(managerAddress: Address, userAddress: Address): [UInt64] {
    let account = getAccount(managerAddress)

    let managerRef = account.capabilities
        .borrow<&CHParking.ParkingManager>(CHParking.ParkingManagerPublicPath)

    if managerRef == nil {
        return []
    }

    return managerRef!.getUserBookings(userAddress: userAddress)
}
