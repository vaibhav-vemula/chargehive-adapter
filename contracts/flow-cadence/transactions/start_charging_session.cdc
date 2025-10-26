/*
 * Start Charging Session
 *
 * This transaction starts a new charging session
 * Called by: Raspberry Pi (via Backend) when user plugs in
 */

import "CHAdapter"

transaction(
    adapterId: String,
    userAddress: Address
) {

    prepare(signer: auth(BorrowValue) &Account) {
        // No preparation needed
    }

    execute {
        // Start the session
        let sessionId = CHAdapter.startSession(
            adapterId: adapterId,
            userAddress: userAddress
        )

        log("✅ Charging session started!")
        log("Session ID: ".concat(sessionId))
        log("Adapter: ".concat(adapterId))
        log("User: ".concat(userAddress.toString()))
    }
}
