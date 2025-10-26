/*
 * Get Parking Space Details
 *
 * This script returns details about a specific parking space
 */

import "CHParking"

access(all) fun main(managerAddress: Address, spaceId: String): CHParking.ParkingSpace? {
    let account = getAccount(managerAddress)

    let managerRef = account.capabilities
        .borrow<&CHParking.ParkingManager>(CHParking.ParkingManagerPublicPath)

    if managerRef == nil {
        return nil
    }

    return managerRef!.getParkingSpace(spaceId: spaceId)
}
