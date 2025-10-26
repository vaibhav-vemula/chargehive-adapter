/*
 * Fund CHParking Treasury
 *
 * This transaction transfers CHT tokens from the signer's account
 * to the CHParking contract treasury for reward distribution
 *
 * Called by: Platform admin to fund the treasury
 */

import "FungibleToken"
import "CHToken"
import "CHParking"

transaction(amount: UFix64) {

    let adminRef: &CHParking.Administrator
    let vaultRef: auth(FungibleToken.Withdraw) &CHToken.Vault

    prepare(signer: auth(BorrowValue) &Account) {
        // Borrow admin resource
        self.adminRef = signer.storage.borrow<&CHParking.Administrator>(
            from: CHParking.AdminStoragePath
        ) ?? panic("Could not borrow CHParking Administrator")

        // Borrow vault to withdraw tokens
        self.vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &CHToken.Vault>(
            from: CHToken.VaultStoragePath
        ) ?? panic("Could not borrow CHToken Vault")
    }

    execute {
        // Withdraw tokens from signer's vault
        let tokens <- self.vaultRef.withdraw(amount: amount)

        // Fund the treasury
        self.adminRef.fundTreasury(vault: <-tokens)

        log("✅ CHParking treasury funded with ".concat(amount.toString()).concat(" CHT"))

        // Show treasury balance
        let balance = self.adminRef.getTreasuryBalance()
        log("Treasury balance: ".concat(balance.toString()).concat(" CHT"))
    }
}
