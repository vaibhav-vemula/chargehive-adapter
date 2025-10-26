/*
 * Get CHT Token Balance
 *
 * This script returns the CHT token balance of an account
 */

import "FungibleToken"
import "CHToken"

access(all) fun main(address: Address): UFix64 {
    let account = getAccount(address)

    let vaultRef = account.capabilities
        .borrow<&{FungibleToken.Balance}>(CHToken.VaultPublicPath)
        ?? panic("Could not borrow Balance capability")

    return vaultRef.balance
}
