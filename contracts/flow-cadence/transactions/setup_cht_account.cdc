/*
 * Setup CHToken Account
 *
 * This transaction sets up a user account to receive CHT tokens
 * by creating and storing a CHToken Vault in their account storage
 */

import "FungibleToken"
import "CHToken"

transaction {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {

        // Check if account already has a CHToken Vault
        if signer.storage.borrow<&CHToken.Vault>(from: CHToken.VaultStoragePath) != nil {
            return
        }

        // Create a new CHToken Vault and store it in account storage
        let vault <- CHToken.createEmptyVault(vaultType: Type<@CHToken.Vault>())
        signer.storage.save(<-vault, to: CHToken.VaultStoragePath)

        // Create a public capability to the Vault that exposes the Receiver interface
        let receiverCap = signer.capabilities.storage.issue<&CHToken.Vault>(
            CHToken.VaultStoragePath
        )
        signer.capabilities.publish(receiverCap, at: CHToken.ReceiverPublicPath)

        // Create a public capability to the Vault that exposes the Balance interface
        let vaultCap = signer.capabilities.storage.issue<&CHToken.Vault>(
            CHToken.VaultStoragePath
        )
        signer.capabilities.publish(vaultCap, at: CHToken.VaultPublicPath)
    }

    execute {
        log("CHToken account setup complete")
    }
}
