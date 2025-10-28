# ChargeHive - Quick Start Commands

## Setup (One-time)

```bash
# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your Flow account details
```

## Initial Setup - Fund the Treasury

Before you can distribute rewards, you must fund the CHAdapter treasury:

```bash
# 1. Setup the minter (one-time, after deployment)
npm run setup-minter

# 2. Mint CHT tokens to your account
npm run mint-tokens 10000.0 0x919d69a9d0efa39b

# 3. Fund the CHAdapter treasury (needed for reward distribution)
npm run fund-treasury 5000.0

# 4. Check your balance
npm run get-balance 0x919d69a9d0efa39b
```

## Core Commands

### 1. Register Adapter
```bash
npm run register-adapter <adapterId> <ownerAddress> <location> <details> <pricePerKwh>

# Example
npm run register-adapter RPI-SF-001 0x919d69a9d0efa39b "123 Market St, SF" "Level 2, 7kW" 0.25
```

### 2. Create Booking
```bash
npm run create-booking <adapterId> <userAddress> <scheduledTime>

# Example (1 hour from now)
FUTURE=$(echo "$(date +%s) + 3600" | bc)
npm run create-booking RPI-SF-001 0x28cedbe601e68bfb ${FUTURE}.0
```
**Save the booking ID from output!**

### 3. Start Session
```bash
npm run start-session <bookingId>

# Example
npm run start-session 0
```
**Save the session ID from output!**

### 4. End Session
```bash
npm run end-session <sessionId> <energyUsed>

# Example (5.5 kWh used)
npm run end-session RPI-SF-001-0x919d69a9d0efa39b-1761522382.00000000-2 5.5
```

### 5. View CHT Balance
```bash
npm run get-balance <address>

# Example
npm run get-balance 0x919d69a9d0efa39b
```

## Query Commands

```bash
# Get adapter details
npm run get-adapter RPI-SF-001

# Get booking details
npm run get-booking 0
```

## Complete Flow Example

```bash
# 0. Initial setup - Fund treasury (one-time)
npm run setup-minter
npm run mint-tokens 10000.0 0x919d69a9d0efa39b
npm run fund-treasury 5000.0

# 1. Register adapter
npm run register-adapter RPI-001 0x919d69a9d0efa39b "Location" "Details" 0.25

# 2. Create booking
FUTURE=$(echo "$(date +%s) + 3600" | bc)
npm run create-booking RPI-001 0x919d69a9d0efa39b ${FUTURE}.0
# Returns: Booking ID: 0

# 3. Start session
npm run start-session 0
# Returns: Session ID: RPI-001-0x919d69a9d0efa39b-1234567890-0

# 4. End session (after charging)
npm run end-session RPI-001-0x919d69a9d0efa39b-1234567890-0 5.0
# Provider gets: 50 CHT (5 kWh × 10)
# User gets: 10 CHT (20% bonus)

# 5. Check balances
npm run get-balance 0x919d69a9d0efa39b
```

## Reward Calculation

- **Provider Reward** = energyUsed × 10 CHT/kWh
- **User Bonus** = providerReward × 20%

Example: 5 kWh session
- Provider: 5 × 10 = **50 CHT**
- User: 50 × 0.20 = **10 CHT**
- **Total needed from treasury: 60 CHT**

## Treasury Management

The CHAdapter treasury holds CHT tokens for reward distribution:

```bash
# Mint tokens to your account
npm run mint-tokens <amount> <recipient>

# Transfer tokens to treasury
npm run fund-treasury <amount>

# Check your balance
npm run get-balance <address>
```

**Important:** Ensure treasury has enough CHT before ending sessions!

## Notes

- Bookings are **required** - cannot start sessions without them
- Scheduled time must be in the future
- Each booking can only start one session
- Rewards are distributed automatically when session ends
- Treasury must have sufficient CHT tokens for reward distribution
