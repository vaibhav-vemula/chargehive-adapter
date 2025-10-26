/*
 * Get All Adapter IDs
 *
 * This script returns all registered adapter IDs
 */

import "CHAdapter"

access(all) fun main(): [String] {
    return CHAdapter.getAllAdapterIds()
}
