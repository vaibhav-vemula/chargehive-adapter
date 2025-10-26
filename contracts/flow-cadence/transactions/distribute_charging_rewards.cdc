/*
 * Distribute Charging Rewards
 *
 * This transaction distributes CHT token rewards to a user after a charging session
 */

import "CHAdapter"
import "FungibleToken"
import "CHToken"

transaction(adapterId: String, sessionId: String, userAddress: Address) {

    let adapterRef: &CHAdapter.Adapter
    let userReceiverCap: Capability<&{FungibleToken.Receiver}>

    prepare(signer: auth(BorrowValue) &Account) {
        // Borrow reference to AdapterManager
        let managerRef = signer.storage.borrow<&CHAdapter.AdapterManager>(from: CHAdapter.AdapterStoragePath)
            ?? panic("Could not borrow AdapterManager reference")

        // Get the adapter reference
        self.adapterRef = managerRef.getAdapter(adapterId: adapterId)
            ?? panic("Adapter not found")

        // Get user's receiver capability
        self.userReceiverCap = getAccount(userAddress)
            .capabilities.get<&{FungibleToken.Receiver}>(CHToken.ReceiverPublicPath)
    }

    execute {
        // Distribute rewards
        self.adapterRef.distributeRewards(
            sessionId: sessionId,
            userReceiverCap: self.userReceiverCap
        )

        log("Distributed rewards for session: ".concat(sessionId))
    }
}
