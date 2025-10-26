/*
 * Get Session Details
 *
 * This script returns details about a specific charging session
 */

import "CHAdapter"

access(all) fun main(sessionId: String): CHAdapter.SessionInfo? {
    return CHAdapter.getSession(sessionId: sessionId)
}
