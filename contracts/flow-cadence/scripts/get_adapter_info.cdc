/*
 * Get Adapter Information
 *
 * This script returns information about a specific adapter
 */

import "CHAdapter"

access(all) fun main(adapterId: String): CHAdapter.AdapterInfo? {
    return CHAdapter.getAdapter(adapterId: adapterId)
}
