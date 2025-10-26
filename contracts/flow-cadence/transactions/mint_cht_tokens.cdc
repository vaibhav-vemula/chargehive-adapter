/*
 * Mint CHT Tokens
 *
 * This transaction mints new CHT tokens and deposits them to a recipient
 * Only accounts with a Minter resource can execute this transaction
 */

import "FungibleToken"
import "CHToken"

transaction(recipient: Address, amount: UFix64) {

    let tokenMinter: &CHToken.Minter
    let tokenReceiver: &{FungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) {
        // Borrow the minter reference from the signer's storage
        self.tokenMinter = signer.storage.borrow<&CHToken.Minter>(from: CHToken.MinterStoragePath)
            ?? panic("Signer does not have a CHToken Minter resource")

        // Get the recipient's receiver capability
        self.tokenReceiver = getAccount(recipient)
            .capabilities.borrow<&{FungibleToken.Receiver}>(CHToken.ReceiverPublicPath)
            ?? panic("Could not borrow receiver reference from recipient")
    }

    execute {
        // Mint the tokens
        let mintedVault <- self.tokenMinter.mintTokens(amount: amount)

        // Deposit the minted tokens to the recipient
        self.tokenReceiver.deposit(from: <-mintedVault)

        log("Minted ".concat(amount.toString()).concat(" CHT tokens to ").concat(recipient.toString()))
    }
}
