/*
 * Register Charging Adapter
 *
 * This transaction registers a new charging adapter in the CHAdapter contract
 * Called by: Provider App (via Backend)
 */

import "CHAdapter"

transaction(
    adapterId: String,
    ownerAddress: Address,
    location: String,
    details: String,
    pricePerKwh: UFix64
) {

    prepare(signer: auth(BorrowValue) &Account) {
        // No preparation needed - contract manages storage
    }

    execute {
        // Register the adapter
        CHAdapter.registerAdapter(
            adapterId: adapterId,
            ownerAddress: ownerAddress,
            location: location,
            details: details,
            pricePerKwh: pricePerKwh
        )

        log("✅ Adapter registered successfully!")
        log("Adapter ID: ".concat(adapterId))
        log("Owner: ".concat(ownerAddress.toString()))
        log("Location: ".concat(location))
    }
}
