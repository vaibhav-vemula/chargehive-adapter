/*
 * End Charging Session and Distribute Rewards
 *
 * This transaction ends a charging session and automatically distributes
 * tokens to both the provider and the user in a SINGLE transaction
 *
 * Called by: Raspberry Pi (via Backend) when user unplugs
 */

import "CHAdapter"

transaction(
    sessionId: String,
    energyUsed: UFix64
) {

    prepare(signer: auth(BorrowValue) &Account) {
        // No preparation needed - contract handles everything
    }

    execute {
        // End session and distribute rewards automatically
        CHAdapter.endSessionAndDistributeRewards(
            sessionId: sessionId,
            energyUsed: energyUsed
        )

        log("✅ Session ended and rewards distributed!")
        log("Session ID: ".concat(sessionId))
        log("Energy used: ".concat(energyUsed.toString()).concat(" kWh"))

        // Get session details to show rewards
        if let session = CHAdapter.getSession(sessionId: sessionId) {
            log("Provider earned: ".concat(session.providerReward.toString()).concat(" CHT"))
            log("User earned: ".concat(session.userReward.toString()).concat(" CHT"))
            log("USD cost: $".concat(session.usdCost.toString()))
        }
    }
}
