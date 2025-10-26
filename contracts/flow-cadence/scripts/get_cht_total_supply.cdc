/*
 * Get CHT Total Supply
 *
 * This script returns the total supply of CHT tokens
 */

import "CHToken"

access(all) fun main(): UFix64 {
    return CHToken.totalSupply
}
