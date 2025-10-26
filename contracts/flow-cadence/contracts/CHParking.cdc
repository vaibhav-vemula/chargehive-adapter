/*
 * ChargeHive Parking Contract
 *
 * Manages peer-to-peer parking space bookings and rewards.
 * Platform-managed contract where tokens are distributed automatically:
 * - Space owner earns 100% of calculated reward
 * - User (parker) earns 20% of owner's reward as bonus
 */

import "FungibleToken"
import "CHToken"

access(all) contract CHParking {

    /// Paths
    access(all) let TreasuryStoragePath: StoragePath
    access(all) let AdminStoragePath: StoragePath

    /// Configuration
    access(all) var rewardRatePerMinute: UFix64    // CHT per minute (default: 1.0)
    access(all) var userBonusPercentage: UFix64    // User bonus as % of owner reward (default: 20.0)

    /// Tracking
    access(all) var totalBookingCount: UInt64
    access(all) var totalSpaceCount: UInt64

    /// Storage
    access(contract) let parkingSpaces: {String: ParkingSpaceInfo}
    access(contract) let bookings: {UInt64: BookingInfo}
    access(contract) let userBookings: {Address: [UInt64]}         // User address -> booking IDs
    access(contract) let ownerSpaces: {Address: [String]}          // Owner address -> space IDs

    /// Events
    access(all) event ParkingSpaceListed(spaceId: String, ownerAddress: Address, location: String, pricePerHour: UFix64)
    access(all) event SpaceAvailabilityUpdated(spaceId: String, available: Bool)
    access(all) event BookingCreated(bookingId: UInt64, spaceId: String, userAddress: Address, ownerAddress: Address, startTime: UFix64, endTime: UFix64)
    access(all) event BookingEnded(
        bookingId: UInt64,
        spaceId: String,
        duration: UFix64,
        ownerReward: UFix64,
        userReward: UFix64,
        timestamp: UFix64
    )
    access(all) event RewardsDistributed(
        bookingId: UInt64,
        ownerAddress: Address,
        ownerAmount: UFix64,
        userAddress: Address,
        userAmount: UFix64
    )
    access(all) event ConfigUpdated(rewardRatePerMinute: UFix64, userBonus: UFix64)

    /// Parking Space Information
    access(all) struct ParkingSpaceInfo {
        access(all) let spaceId: String
        access(all) let ownerAddress: Address     // Space owner who earns tokens
        access(all) let location: String
        access(all) let details: String
        access(all) var pricePerHour: UFix64
        access(all) var isAvailable: Bool
        access(all) let createdAt: UFix64

        init(
            spaceId: String,
            ownerAddress: Address,
            location: String,
            details: String,
            pricePerHour: UFix64
        ) {
            self.spaceId = spaceId
            self.ownerAddress = ownerAddress
            self.location = location
            self.details = details
            self.pricePerHour = pricePerHour
            self.isAvailable = true
            self.createdAt = getCurrentBlock().timestamp
        }

        access(contract) fun setAvailability(available: Bool) {
            self.isAvailable = available
        }

        access(contract) fun updatePrice(newPrice: UFix64) {
            self.pricePerHour = newPrice
        }
    }

    /// Booking Information
    access(all) struct BookingInfo {
        access(all) let bookingId: UInt64
        access(all) let spaceId: String
        access(all) let ownerAddress: Address     // Space owner earning tokens
        access(all) let userAddress: Address      // User parking and earning bonus
        access(all) let startTime: UFix64
        access(all) var endTime: UFix64
        access(all) var duration: UFix64          // Duration in minutes
        access(all) var ownerReward: UFix64       // 100% of calculated reward
        access(all) var userReward: UFix64        // 20% of owner reward
        access(all) var isActive: Bool
        access(all) var rewardsDistributed: Bool

        access(contract) fun updateBooking(
            endTime: UFix64,
            duration: UFix64,
            ownerReward: UFix64,
            userReward: UFix64
        ) {
            self.endTime = endTime
            self.duration = duration
            self.ownerReward = ownerReward
            self.userReward = userReward
            self.isActive = false
            self.rewardsDistributed = true
        }

        init(
            bookingId: UInt64,
            spaceId: String,
            ownerAddress: Address,
            userAddress: Address,
            startTime: UFix64,
            endTime: UFix64
        ) {
            self.bookingId = bookingId
            self.spaceId = spaceId
            self.ownerAddress = ownerAddress
            self.userAddress = userAddress
            self.startTime = startTime
            self.endTime = endTime
            self.duration = 0.0
            self.ownerReward = 0.0
            self.userReward = 0.0
            self.isActive = true
            self.rewardsDistributed = false
        }
    }

    /// List a new parking space (called by Provider App via Backend)
    access(all) fun listParkingSpace(
        spaceId: String,
        ownerAddress: Address,
        location: String,
        details: String,
        pricePerHour: UFix64
    ) {
        pre {
            self.parkingSpaces[spaceId] == nil: "Space already exists"
            ownerAddress != nil: "Invalid owner address"
            pricePerHour > 0.0: "Price must be positive"
        }

        let spaceInfo = ParkingSpaceInfo(
            spaceId: spaceId,
            ownerAddress: ownerAddress,
            location: location,
            details: details,
            pricePerHour: pricePerHour
        )

        self.parkingSpaces[spaceId] = spaceInfo

        // Track owner's spaces
        if self.ownerSpaces[ownerAddress] == nil {
            self.ownerSpaces[ownerAddress] = []
        }
        self.ownerSpaces[ownerAddress]!.append(spaceId)

        self.totalSpaceCount = self.totalSpaceCount + 1

        emit ParkingSpaceListed(
            spaceId: spaceId,
            ownerAddress: ownerAddress,
            location: location,
            pricePerHour: pricePerHour
        )
    }

    /// Create a booking (called by User App via Backend)
    access(all) fun createBooking(
        spaceId: String,
        userAddress: Address,
        startTime: UFix64,
        endTime: UFix64
    ): UInt64 {
        pre {
            self.parkingSpaces[spaceId] != nil: "Parking space not found"
            self.parkingSpaces[spaceId]!.isAvailable: "Space not available"
            userAddress != nil: "Invalid user address"
            startTime < endTime: "End time must be after start time"
        }

        let space = self.parkingSpaces[spaceId]!
        let bookingId = self.totalBookingCount

        let booking = BookingInfo(
            bookingId: bookingId,
            spaceId: spaceId,
            ownerAddress: space.ownerAddress,
            userAddress: userAddress,
            startTime: startTime,
            endTime: endTime
        )

        self.bookings[bookingId] = booking

        // Track user's bookings
        if self.userBookings[userAddress] == nil {
            self.userBookings[userAddress] = []
        }
        self.userBookings[userAddress]!.append(bookingId)

        self.totalBookingCount = self.totalBookingCount + 1

        // Mark space as unavailable
        space.setAvailability(available: false)
        self.parkingSpaces[spaceId] = space

        emit BookingCreated(
            bookingId: bookingId,
            spaceId: spaceId,
            userAddress: userAddress,
            ownerAddress: space.ownerAddress,
            startTime: startTime,
            endTime: endTime
        )

        return bookingId
    }

    /// End booking and automatically distribute rewards to both owner and user
    /// (called via Backend when parking time ends or user leaves early)
    access(all) fun endBookingAndDistributeRewards(
        bookingId: UInt64
    ) {
        pre {
            self.bookings[bookingId] != nil: "Booking not found"
            self.bookings[bookingId]!.isActive: "Booking already ended"
        }

        let booking = self.bookings[bookingId]!
        let actualEndTime = getCurrentBlock().timestamp

        // Calculate duration in minutes
        let durationMinutes = (actualEndTime - booking.startTime) / 60.0

        // Calculate rewards
        var ownerReward: UFix64 = 0.0
        var userReward: UFix64 = 0.0

        if durationMinutes > 0.0 {
            // Owner gets: duration × rewardRatePerMinute
            ownerReward = durationMinutes * self.rewardRatePerMinute

            // User gets: ownerReward × userBonusPercentage / 100
            userReward = ownerReward * self.userBonusPercentage / 100.0
        }

        // Get treasury vault
        let treasuryVault = self.account.storage.borrow<auth(FungibleToken.Withdraw) &CHToken.Vault>(
            from: self.TreasuryStoragePath
        ) ?? panic("Could not borrow treasury vault")

        // Distribute to space owner
        if ownerReward > 0.0 {
            let ownerVault <- treasuryVault.withdraw(amount: ownerReward)
            let ownerReceiver = getAccount(booking.ownerAddress)
                .capabilities.borrow<&{FungibleToken.Receiver}>(CHToken.ReceiverPublicPath)
                ?? panic("Could not borrow owner receiver")
            ownerReceiver.deposit(from: <-ownerVault)
        }

        // Distribute to user (parker)
        if userReward > 0.0 {
            let userVault <- treasuryVault.withdraw(amount: userReward)
            let userReceiver = getAccount(booking.userAddress)
                .capabilities.borrow<&{FungibleToken.Receiver}>(CHToken.ReceiverPublicPath)
                ?? panic("Could not borrow user receiver")
            userReceiver.deposit(from: <-userVault)
        }

        // Update booking
        booking.updateBooking(
            endTime: actualEndTime,
            duration: durationMinutes,
            ownerReward: ownerReward,
            userReward: userReward
        )

        self.bookings[bookingId] = booking

        // Make space available again
        let space = self.parkingSpaces[booking.spaceId]!
        space.setAvailability(available: true)
        self.parkingSpaces[booking.spaceId] = space

        emit BookingEnded(
            bookingId: bookingId,
            spaceId: booking.spaceId,
            duration: durationMinutes,
            ownerReward: ownerReward,
            userReward: userReward,
            timestamp: actualEndTime
        )

        emit RewardsDistributed(
            bookingId: bookingId,
            ownerAddress: booking.ownerAddress,
            ownerAmount: ownerReward,
            userAddress: booking.userAddress,
            userAmount: userReward
        )
    }

    /// Update space availability (called by space owner)
    access(all) fun updateSpaceAvailability(spaceId: String, available: Bool, caller: Address) {
        pre {
            self.parkingSpaces[spaceId] != nil: "Parking space not found"
            self.parkingSpaces[spaceId]!.ownerAddress == caller: "Only owner can update availability"
        }

        let space = self.parkingSpaces[spaceId]!
        space.setAvailability(available: available)
        self.parkingSpaces[spaceId] = space

        emit SpaceAvailabilityUpdated(spaceId: spaceId, available: available)
    }

    /// Get parking space information
    access(all) fun getParkingSpace(spaceId: String): ParkingSpaceInfo? {
        return self.parkingSpaces[spaceId]
    }

    /// Get booking information
    access(all) fun getBooking(bookingId: UInt64): BookingInfo? {
        return self.bookings[bookingId]
    }

    /// Get all space IDs
    access(all) fun getAllSpaceIds(): [String] {
        return self.parkingSpaces.keys
    }

    /// Get spaces owned by an address
    access(all) fun getOwnerSpaces(ownerAddress: Address): [String] {
        return self.ownerSpaces[ownerAddress] ?? []
    }

    /// Get bookings for a user
    access(all) fun getUserBookings(userAddress: Address): [UInt64] {
        return self.userBookings[userAddress] ?? []
    }

    /// Get active bookings for a user
    access(all) fun getActiveUserBookings(userAddress: Address): [UInt64] {
        let allBookings = self.userBookings[userAddress] ?? []
        let activeBookings: [UInt64] = []

        for bookingId in allBookings {
            if let booking = self.bookings[bookingId] {
                if booking.isActive {
                    activeBookings.append(bookingId)
                }
            }
        }

        return activeBookings
    }

    /// Administrator Resource
    access(all) resource Administrator {

        /// Update reward configuration
        access(all) fun updateConfig(
            rewardRate: UFix64?,
            userBonus: UFix64?
        ) {
            if rewardRate != nil {
                CHParking.rewardRatePerMinute = rewardRate!
            }
            if userBonus != nil {
                CHParking.userBonusPercentage = userBonus!
            }

            emit ConfigUpdated(
                rewardRatePerMinute: CHParking.rewardRatePerMinute,
                userBonus: CHParking.userBonusPercentage
            )
        }

        /// Fund the treasury (transfer tokens to contract)
        access(all) fun fundTreasury(vault: @{FungibleToken.Vault}) {
            let treasuryVault = CHParking.account.storage.borrow<&CHToken.Vault>(
                from: CHParking.TreasuryStoragePath
            ) ?? panic("Could not borrow treasury vault")

            treasuryVault.deposit(from: <-vault)
        }

        /// Check treasury balance
        access(all) fun getTreasuryBalance(): UFix64 {
            let treasuryVault = CHParking.account.storage.borrow<&CHToken.Vault>(
                from: CHParking.TreasuryStoragePath
            ) ?? panic("Could not borrow treasury vault")

            return treasuryVault.balance
        }
    }

    init() {
        // Set paths
        self.TreasuryStoragePath = /storage/CHParkingTreasury
        self.AdminStoragePath = /storage/CHParkingAdmin

        // Initialize configuration
        self.rewardRatePerMinute = 1.0      // 1 CHT per minute
        self.userBonusPercentage = 20.0     // User gets 20% of owner reward

        // Initialize counters
        self.totalBookingCount = 0
        self.totalSpaceCount = 0

        // Initialize storage
        self.parkingSpaces = {}
        self.bookings = {}
        self.userBookings = {}
        self.ownerSpaces = {}

        // Create treasury vault
        let treasuryVault <- CHToken.createEmptyVault(vaultType: Type<@CHToken.Vault>())
        self.account.storage.save(<-treasuryVault, to: self.TreasuryStoragePath)

        // Create and save Administrator
        let admin <- create Administrator()
        self.account.storage.save(<-admin, to: self.AdminStoragePath)
    }
}
