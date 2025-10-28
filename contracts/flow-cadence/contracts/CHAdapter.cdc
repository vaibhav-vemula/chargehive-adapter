/*
 * ChargeHive Adapter Contract
 *
 * Manages charging adapters (Raspberry Pi DePIN devices) and their sessions.
 * Platform-managed contract where tokens are distributed automatically:
 * - Provider earns 100% of calculated reward
 * - User earns 20% of provider's reward as bonus
 *
 * BOOKING REQUIREMENT: All charging sessions must be initiated through a booking.
 * Users must create a booking before arriving at the charging station.
 */

import "FungibleToken"
import "CHToken"

access(all) contract CHAdapter {

    /// Paths
    access(all) let TreasuryStoragePath: StoragePath
    access(all) let AdminStoragePath: StoragePath

    /// Configuration
    access(all) var rewardRatePerKwh: UFix64       // CHT per kWh (default: 10.0)
    access(all) var minimumKwh: UFix64             // Minimum kWh to earn (default: 0.0)
    access(all) var pricePerKwhUsd: UFix64         // USD per kWh for display (default: 0.15)
    access(all) var userBonusPercentage: UFix64    // User bonus as % of provider reward (default: 20.0)

    /// Session tracking
    access(all) var totalSessionCount: UInt64
    access(all) var totalAdapterCount: UInt64
    access(all) var totalBookingCount: UInt64

    /// Storage
    access(contract) let adapters: {String: AdapterInfo}
    access(contract) let sessions: {String: SessionInfo}
    access(contract) let bookings: {UInt64: BookingInfo}        // Booking ID -> Booking info
    access(contract) let adapterBookings: {String: [UInt64]}    // Adapter ID -> booking IDs
    access(contract) let userSessions: {Address: [String]}      // User address -> session IDs
    access(contract) let providerAdapters: {Address: [String]}  // Provider address -> adapter IDs

    /// Events
    access(all) event AdapterRegistered(adapterId: String, ownerAddress: Address, location: String, pricePerKwh: UFix64)
    access(all) event AdapterAuthorized(adapterId: String, authorized: Bool)
    access(all) event BookingCreated(bookingId: UInt64, adapterId: String, userAddress: Address, scheduledTime: UFix64)
    access(all) event BookingCancelled(bookingId: UInt64, adapterId: String)
    access(all) event SessionStarted(adapterId: String, sessionId: String, userAddress: Address, ownerAddress: Address, timestamp: UFix64)
    access(all) event SessionEnded(
        adapterId: String,
        sessionId: String,
        energyUsed: UFix64,
        providerReward: UFix64,
        userReward: UFix64,
        usdCost: UFix64,
        timestamp: UFix64
    )
    access(all) event RewardsDistributed(
        sessionId: String,
        providerAddress: Address,
        providerAmount: UFix64,
        userAddress: Address,
        userAmount: UFix64
    )
    access(all) event ConfigUpdated(rewardRate: UFix64, minimumKwh: UFix64, pricePerKwh: UFix64, userBonus: UFix64)

    /// Adapter Information
    access(all) struct AdapterInfo {
        access(all) let adapterId: String
        access(all) let ownerAddress: Address      // Provider who owns this adapter
        access(all) let location: String
        access(all) let details: String
        access(all) var pricePerKwh: UFix64
        access(all) var authorized: Bool
        access(all) let createdAt: UFix64

        access(contract) fun setAuthorization(authorized: Bool) {
            self.authorized = authorized
        }

        init(
            adapterId: String,
            ownerAddress: Address,
            location: String,
            details: String,
            pricePerKwh: UFix64
        ) {
            self.adapterId = adapterId
            self.ownerAddress = ownerAddress
            self.location = location
            self.details = details
            self.pricePerKwh = pricePerKwh
            self.authorized = true
            self.createdAt = getCurrentBlock().timestamp
        }
    }

    /// Booking Information
    access(all) struct BookingInfo {
        access(all) let bookingId: UInt64
        access(all) let adapterId: String
        access(all) let userAddress: Address
        access(all) let scheduledTime: UFix64         // When user plans to arrive
        access(all) var status: String                // "pending", "active", "completed", "cancelled"
        access(all) var sessionId: String?            // Set when session starts
        access(all) let createdAt: UFix64

        access(contract) fun activate(sessionId: String) {
            self.sessionId = sessionId
            self.status = "active"
        }

        access(contract) fun complete() {
            self.status = "completed"
        }

        access(contract) fun cancel() {
            self.status = "cancelled"
        }

        init(
            bookingId: UInt64,
            adapterId: String,
            userAddress: Address,
            scheduledTime: UFix64
        ) {
            self.bookingId = bookingId
            self.adapterId = adapterId
            self.userAddress = userAddress
            self.scheduledTime = scheduledTime
            self.status = "pending"
            self.sessionId = nil
            self.createdAt = getCurrentBlock().timestamp
        }
    }

    /// Session Information
    access(all) struct SessionInfo {
        access(all) let sessionId: String
        access(all) let adapterId: String
        access(all) let ownerAddress: Address      // Provider earning tokens
        access(all) let userAddress: Address       // User earning bonus
        access(all) let startTime: UFix64
        access(all) var endTime: UFix64
        access(all) var energyUsed: UFix64
        access(all) var providerReward: UFix64     // 100% of calculated reward
        access(all) var userReward: UFix64         // 20% of provider reward
        access(all) var usdCost: UFix64            // Display only
        access(all) var active: Bool
        access(all) var rewardsDistributed: Bool

        access(contract) fun updateSession(
            endTime: UFix64,
            energyUsed: UFix64,
            providerReward: UFix64,
            userReward: UFix64,
            usdCost: UFix64
        ) {
            self.endTime = endTime
            self.energyUsed = energyUsed
            self.providerReward = providerReward
            self.userReward = userReward
            self.usdCost = usdCost
            self.active = false
            self.rewardsDistributed = true
        }

        init(
            sessionId: String,
            adapterId: String,
            ownerAddress: Address,
            userAddress: Address
        ) {
            self.sessionId = sessionId
            self.adapterId = adapterId
            self.ownerAddress = ownerAddress
            self.userAddress = userAddress
            self.startTime = getCurrentBlock().timestamp
            self.endTime = 0.0
            self.energyUsed = 0.0
            self.providerReward = 0.0
            self.userReward = 0.0
            self.usdCost = 0.0
            self.active = true
            self.rewardsDistributed = false
        }
    }

    /// Register a new adapter (called by Provider App via Backend)
    access(all) fun registerAdapter(
        adapterId: String,
        ownerAddress: Address,
        location: String,
        details: String,
        pricePerKwh: UFix64
    ) {
        pre {
            self.adapters[adapterId] == nil: "Adapter already exists"
            ownerAddress != nil: "Invalid owner address"
            pricePerKwh > 0.0: "Price must be positive"
        }

        let adapterInfo = AdapterInfo(
            adapterId: adapterId,
            ownerAddress: ownerAddress,
            location: location,
            details: details,
            pricePerKwh: pricePerKwh
        )

        self.adapters[adapterId] = adapterInfo

        // Track provider's adapters
        if self.providerAdapters[ownerAddress] == nil {
            self.providerAdapters[ownerAddress] = []
        }
        self.providerAdapters[ownerAddress]!.append(adapterId)

        self.totalAdapterCount = self.totalAdapterCount + 1

        emit AdapterRegistered(
            adapterId: adapterId,
            ownerAddress: ownerAddress,
            location: location,
            pricePerKwh: pricePerKwh
        )
    }

    /// Create a booking (called by User App before arriving)
    access(all) fun createBooking(
        adapterId: String,
        userAddress: Address,
        scheduledTime: UFix64
    ): UInt64 {
        pre {
            self.adapters[adapterId] != nil: "Adapter not found"
            self.adapters[adapterId]!.authorized: "Adapter not authorized"
            userAddress != nil: "Invalid user address"
            scheduledTime > getCurrentBlock().timestamp: "Scheduled time must be in the future"
        }

        let bookingId = self.totalBookingCount

        let booking = BookingInfo(
            bookingId: bookingId,
            adapterId: adapterId,
            userAddress: userAddress,
            scheduledTime: scheduledTime
        )

        self.bookings[bookingId] = booking

        // Track bookings for this adapter
        if self.adapterBookings[adapterId] == nil {
            self.adapterBookings[adapterId] = []
        }
        self.adapterBookings[adapterId]!.append(bookingId)

        self.totalBookingCount = self.totalBookingCount + 1

        emit BookingCreated(
            bookingId: bookingId,
            adapterId: adapterId,
            userAddress: userAddress,
            scheduledTime: scheduledTime
        )

        return bookingId
    }

    /// Cancel a booking (called by User App)
    access(all) fun cancelBooking(bookingId: UInt64, caller: Address) {
        pre {
            self.bookings[bookingId] != nil: "Booking not found"
            self.bookings[bookingId]!.userAddress == caller: "Only booking owner can cancel"
            self.bookings[bookingId]!.status == "pending": "Can only cancel pending bookings"
        }

        let booking = self.bookings[bookingId]!
        booking.cancel()
        self.bookings[bookingId] = booking

        emit BookingCancelled(
            bookingId: bookingId,
            adapterId: booking.adapterId
        )
    }

    /// Start a charging session (called by Raspberry Pi when user plugs in)
    /// REQUIRES a valid booking - users must create a booking before charging
    access(all) fun startSessionWithBooking(
        bookingId: UInt64
    ): String {
        pre {
            self.bookings[bookingId] != nil: "Booking not found"
            self.bookings[bookingId]!.status == "pending": "Booking must be pending"
        }

        let booking = self.bookings[bookingId]!
        let adapterId = booking.adapterId
        let userAddress = booking.userAddress

        let adapter = self.adapters[adapterId]!
        let sessionId = self.generateSessionId(adapterId: adapterId, userAddress: userAddress)

        let session = SessionInfo(
            sessionId: sessionId,
            adapterId: adapterId,
            ownerAddress: adapter.ownerAddress,
            userAddress: userAddress
        )

        self.sessions[sessionId] = session

        // Update booking to active
        booking.activate(sessionId: sessionId)
        self.bookings[bookingId] = booking

        // Track user's sessions
        if self.userSessions[userAddress] == nil {
            self.userSessions[userAddress] = []
        }
        self.userSessions[userAddress]!.append(sessionId)

        self.totalSessionCount = self.totalSessionCount + 1

        emit SessionStarted(
            adapterId: adapterId,
            sessionId: sessionId,
            userAddress: userAddress,
            ownerAddress: adapter.ownerAddress,
            timestamp: getCurrentBlock().timestamp
        )

        return sessionId
    }


    /// End session and automatically distribute rewards to both provider and user
    /// (called by Raspberry Pi via Backend when user unplugs)
    access(all) fun endSessionAndDistributeRewards(
        sessionId: String,
        energyUsed: UFix64
    ) {
        pre {
            self.sessions[sessionId] != nil: "Session not found"
            self.sessions[sessionId]!.active: "Session already ended"
            energyUsed > 0.0: "Energy used must be positive"
        }

        let session = self.sessions[sessionId]!

        // Calculate rewards
        var providerReward: UFix64 = 0.0
        var userReward: UFix64 = 0.0

        if energyUsed >= self.minimumKwh {
            // Provider gets: energyUsed × rewardRatePerKwh
            providerReward = energyUsed * self.rewardRatePerKwh

            // User gets: providerReward × userBonusPercentage / 100
            userReward = providerReward * self.userBonusPercentage / 100.0
        }

        // Calculate USD cost (display only)
        let usdCost = energyUsed * self.pricePerKwhUsd

        // Get treasury vault
        let treasuryVault = self.account.storage.borrow<auth(FungibleToken.Withdraw) &CHToken.Vault>(
            from: self.TreasuryStoragePath
        ) ?? panic("Could not borrow treasury vault")

        // Distribute to provider
        if providerReward > 0.0 {
            let providerVault <- treasuryVault.withdraw(amount: providerReward)
            let providerReceiver = getAccount(session.ownerAddress)
                .capabilities.borrow<&{FungibleToken.Receiver}>(CHToken.ReceiverPublicPath)
                ?? panic("Could not borrow provider receiver")
            providerReceiver.deposit(from: <-providerVault)
        }

        // Distribute to user
        if userReward > 0.0 {
            let userVault <- treasuryVault.withdraw(amount: userReward)
            let userReceiver = getAccount(session.userAddress)
                .capabilities.borrow<&{FungibleToken.Receiver}>(CHToken.ReceiverPublicPath)
                ?? panic("Could not borrow user receiver")
            userReceiver.deposit(from: <-userVault)
        }

        // Update session
        session.updateSession(
            endTime: getCurrentBlock().timestamp,
            energyUsed: energyUsed,
            providerReward: providerReward,
            userReward: userReward,
            usdCost: usdCost
        )

        self.sessions[sessionId] = session

        // Mark booking as completed if this session came from a booking
        for bookingId in self.bookings.keys {
            let booking = self.bookings[bookingId]!
            if booking.sessionId == sessionId && booking.status == "active" {
                booking.complete()
                self.bookings[bookingId] = booking
                break
            }
        }

        emit SessionEnded(
            adapterId: session.adapterId,
            sessionId: sessionId,
            energyUsed: energyUsed,
            providerReward: providerReward,
            userReward: userReward,
            usdCost: usdCost,
            timestamp: getCurrentBlock().timestamp
        )

        emit RewardsDistributed(
            sessionId: sessionId,
            providerAddress: session.ownerAddress,
            providerAmount: providerReward,
            userAddress: session.userAddress,
            userAmount: userReward
        )
    }

    /// Generate unique session ID
    access(self) fun generateSessionId(adapterId: String, userAddress: Address): String {
        let timestamp = getCurrentBlock().timestamp.toString()
        let counter = self.totalSessionCount.toString()
        let userAddr = userAddress.toString()
        return adapterId.concat("-").concat(userAddr).concat("-").concat(timestamp).concat("-").concat(counter)
    }

    /// Get adapter information
    access(all) fun getAdapter(adapterId: String): AdapterInfo? {
        return self.adapters[adapterId]
    }

    /// Get session information
    access(all) fun getSession(sessionId: String): SessionInfo? {
        return self.sessions[sessionId]
    }

    /// Get all adapter IDs
    access(all) fun getAllAdapterIds(): [String] {
        return self.adapters.keys
    }

    /// Get adapters owned by a provider
    access(all) fun getProviderAdapters(ownerAddress: Address): [String] {
        return self.providerAdapters[ownerAddress] ?? []
    }

    /// Get sessions for a user
    access(all) fun getUserSessions(userAddress: Address): [String] {
        return self.userSessions[userAddress] ?? []
    }

    /// Get booking information
    access(all) fun getBooking(bookingId: UInt64): BookingInfo? {
        return self.bookings[bookingId]
    }

    /// Get all bookings for an adapter
    access(all) fun getAdapterBookings(adapterId: String): [UInt64] {
        return self.adapterBookings[adapterId] ?? []
    }

    /// Get pending booking for an adapter (most recent pending booking)
    access(all) fun getPendingBookingForAdapter(adapterId: String): BookingInfo? {
        let bookingIds = self.adapterBookings[adapterId] ?? []

        // Find most recent pending booking
        var i = bookingIds.length
        while i > 0 {
            i = i - 1
            let bookingId = bookingIds[i]
            let booking = self.bookings[bookingId]!
            if booking.status == "pending" {
                return booking
            }
        }

        return nil
    }

    /// Get active booking for an adapter
    access(all) fun getActiveBookingForAdapter(adapterId: String): BookingInfo? {
        let bookingIds = self.adapterBookings[adapterId] ?? []

        // Find active booking
        for bookingId in bookingIds {
            let booking = self.bookings[bookingId]!
            if booking.status == "active" {
                return booking
            }
        }

        return nil
    }

    /// Administrator Resource
    access(all) resource Administrator {

        /// Update reward configuration
        access(all) fun updateConfig(
            rewardRate: UFix64?,
            minimumKwh: UFix64?,
            pricePerKwh: UFix64?,
            userBonus: UFix64?
        ) {
            if rewardRate != nil {
                CHAdapter.rewardRatePerKwh = rewardRate!
            }
            if minimumKwh != nil {
                CHAdapter.minimumKwh = minimumKwh!
            }
            if pricePerKwh != nil {
                CHAdapter.pricePerKwhUsd = pricePerKwh!
            }
            if userBonus != nil {
                CHAdapter.userBonusPercentage = userBonus!
            }

            emit ConfigUpdated(
                rewardRate: CHAdapter.rewardRatePerKwh,
                minimumKwh: CHAdapter.minimumKwh,
                pricePerKwh: CHAdapter.pricePerKwhUsd,
                userBonus: CHAdapter.userBonusPercentage
            )
        }

        /// Authorize/deauthorize an adapter
        access(all) fun setAdapterAuthorization(adapterId: String, authorized: Bool) {
            pre {
                CHAdapter.adapters[adapterId] != nil: "Adapter not found"
            }

            let adapter = CHAdapter.adapters[adapterId]!
            adapter.setAuthorization(authorized: authorized)
            CHAdapter.adapters[adapterId] = adapter

            emit AdapterAuthorized(adapterId: adapterId, authorized: authorized)
        }

        /// Fund the treasury (transfer tokens to contract)
        access(all) fun fundTreasury(vault: @{FungibleToken.Vault}) {
            let treasuryVault = CHAdapter.account.storage.borrow<&CHToken.Vault>(
                from: CHAdapter.TreasuryStoragePath
            ) ?? panic("Could not borrow treasury vault")

            treasuryVault.deposit(from: <-vault)
        }

        /// Check treasury balance
        access(all) fun getTreasuryBalance(): UFix64 {
            let treasuryVault = CHAdapter.account.storage.borrow<&CHToken.Vault>(
                from: CHAdapter.TreasuryStoragePath
            ) ?? panic("Could not borrow treasury vault")

            return treasuryVault.balance
        }
    }

    init() {
        // Set paths
        self.TreasuryStoragePath = /storage/CHAdapterTreasury
        self.AdminStoragePath = /storage/CHAdapterAdmin

        // Initialize configuration
        self.rewardRatePerKwh = 10.0      // 10 CHT per kWh
        self.minimumKwh = 0.0             // No minimum
        self.pricePerKwhUsd = 0.15        // $0.15 per kWh (display only)
        self.userBonusPercentage = 20.0   // User gets 20% of provider reward

        // Initialize counters
        self.totalSessionCount = 0
        self.totalAdapterCount = 0
        self.totalBookingCount = 0

        // Initialize storage
        self.adapters = {}
        self.sessions = {}
        self.bookings = {}
        self.adapterBookings = {}
        self.userSessions = {}
        self.providerAdapters = {}

        // Create treasury vault
        let treasuryVault <- CHToken.createEmptyVault(vaultType: Type<@CHToken.Vault>())
        self.account.storage.save(<-treasuryVault, to: self.TreasuryStoragePath)

        // Create and save Administrator
        let admin <- create Administrator()
        self.account.storage.save(<-admin, to: self.AdminStoragePath)
    }
}
