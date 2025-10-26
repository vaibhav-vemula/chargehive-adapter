/*
 * Get User Sessions
 *
 * This script returns all session IDs for a specific user
 */

import "CHAdapter"

access(all) fun main(userAddress: Address): [String] {
    return CHAdapter.getUserSessions(userAddress: userAddress)
}
