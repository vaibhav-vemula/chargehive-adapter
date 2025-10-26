/*
 * Transfer CHT Tokens
 *
 * This transaction transfers CHT tokens from the signer to a recipient
 */

import "FungibleToken"
import "CHToken"

transaction(to: Address, amount: UFix64) {

    let sentVault: @{FungibleToken.Vault}

    prepare(signer: auth(BorrowValue) &Account) {
        // Borrow a reference to the signer's CHToken Vault
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &CHToken.Vault>(
            from: CHToken.VaultStoragePath
        ) ?? panic("Could not borrow reference to the signer's CHToken Vault")

        // Withdraw tokens from the signer's vault
        self.sentVault <- vaultRef.withdraw(amount: amount)
    }

    execute {
        // Get the recipient's receiver capability
        let recipient = getAccount(to)
        let receiverRef = recipient.capabilities.borrow<&{FungibleToken.Receiver}>(CHToken.ReceiverPublicPath)
            ?? panic("Could not borrow receiver reference from recipient")

        // Deposit the tokens to the recipient
        receiverRef.deposit(from: <-self.sentVault)

        log("Transferred ".concat(amount.toString()).concat(" CHT tokens to ").concat(to.toString()))
    }
}
