# ChargeHive Complete Setup & Integration Guide

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Flow Blockchain Setup](#flow-blockchain-setup)
5. [Raspberry Pi Backend Setup](#raspberry-pi-backend-setup)
6. [Complete Flow Walkthrough](#complete-flow-walkthrough)
7. [API Reference](#api-reference)
8. [Testing Guide](#testing-guide)
9. [Troubleshooting](#troubleshooting)

---

## Overview

ChargeHive is a P2P charging and parking platform with:
- **Bookings** - Users reserve charging time slots
- **Automatic Token Distribution** - Provider earns 100%, User earns 20% bonus
- **DePIN Integration** - Raspberry Pi tracks real energy usage
- **Flow Blockchain** - Secure, transparent token distribution

### Token Distribution Example

User charges 25.5 kWh:
- **Provider earns**: 255 CHT (25.5 × 10 CHT/kWh)
- **User earns**: 51 CHT (20% bonus)
- **Total distributed**: 306 CHT from platform treasury

---

## Architecture

```
┌─────────────┐
│  User App   │ Creates booking → Backend API (bookings.json)
└──────┬──────┘
       │
       ↓ Arrives & Plugs In
┌─────────────┐
│ Raspberry Pi│ → Detects current
└──────┬──────┘    Checks for booking (Backend API)
       │            Gets userAddress from booking
       ↓
┌─────────────────────────────────────┐
│      Flow Blockchain                │
│  - CHAdapter.startSession()         │
│  - Creates session with             │
│    providerAddress + userAddress    │
│  - Tracks energy usage              │
└──────┬──────────────────────────────┘
       │
       ↓ User Unplugs
┌─────────────┐
│ Raspberry Pi│ → Detects no current
└──────┬──────┘    Sends energy usage
       │
       ↓
┌─────────────────────────────────────┐
│      Flow Blockchain                │
│  - CHAdapter.endSessionAndDistribute│
│  - Calculates rewards               │
│  - Sends 255 CHT → Provider         │
│  - Sends 51 CHT → User              │
│  - Single atomic transaction        │
└─────────────────────────────────────┘
       │
       ↓
Backend marks booking as "completed"
```

### Storage Locations

| Data | Location | Why |
|------|----------|-----|
| **Bookings** | Backend API (`bookings.json`) | Free, fast, flexible |
| **Adapters** | Flow Blockchain | Immutable registry |
| **Sessions** | Flow Blockchain | Transparent records |
| **Tokens** | Flow Blockchain | Trustless distribution |

---

## Prerequisites

### System Requirements
- **Node.js** v14+ and npm
- **Python 3** (for energy tracker)
- **Flow CLI** (for blockchain deployment)
- **curl** (for testing APIs)

### Install Flow CLI

```bash
sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"
flow version
```

---

## Flow Blockchain Setup

### Step 1: Create Testnet Account

```bash
cd contracts/flow-cadence

# Create account (saves private key automatically)
flow accounts create --network=testnet

# Note: This creates chargehive.pkey file
# DO NOT commit this file to git!
```

### Step 2: Update flow.json

The account should be automatically added. Verify:

```json
{
  "accounts": {
    "chargehive": {
      "address": "0x7c1a6e4b7eb419c1",
      "key": {
        "type": "file",
        "location": "chargehive.pkey"
      }
    }
  },
  "deployments": {
    "testnet": {
      "chargehive": ["CHToken", "CHAdapter", "CHParking"]
    }
  }
}
```

### Step 3: Deploy Contracts

```bash
flow project deploy --network=testnet
```

**Expected Output:**
```
✅ CHToken deployed to 0x7c1a6e4b7eb419c1
✅ CHAdapter deployed to 0x7c1a6e4b7eb419c1
✅ CHParking deployed to 0x7c1a6e4b7eb419c1
```

### Step 4: Setup CHT Token Account

```bash
# Your account needs a CHT vault to receive tokens
flow transactions send ./transactions/setup_cht_account.cdc \
  --signer chargehive \
  --network testnet
```

### Step 5: Fund Treasury

```bash
# Fund CHAdapter treasury with 5M tokens
flow transactions send ./transactions/fund_adapter_treasury.cdc 5000000.0 \
  --signer chargehive \
  --network testnet

# Fund CHParking treasury with 5M tokens
flow transactions send ./transactions/fund_parking_treasury.cdc 5000000.0 \
  --signer chargehive \
  --network testnet
```

### Step 6: Register Charging Adapter

```bash
# Register your Raspberry Pi as a charging adapter
flow transactions send ./transactions/register_adapter.cdc \
  "adapter-rpi-001" \
  8e29b2a5f64a137f \
  "123 Main St, San Francisco" \
  "Tesla Charger - 150kW" \
  0.15 \
  --signer chargehive \
  --network testnet
```

**Parameters:**
- `adapter-rpi-001` - Unique adapter ID
- `8e29b2a5f64a137f` - Provider address (who earns tokens)
- `"123 Main St..."` - Location
- `"Tesla Charger..."` - Description
- `0.15` - Price per kWh in USD (display only)

### Step 7: Verify Deployment

```bash
# Check your account
flow accounts get 8e29b2a5f64a137f --network=testnet

# Check CHT balance
flow scripts execute ./scripts/get_cht_balance.cdc 8e29b2a5f64a137f --network=testnet

# Check adapter info
flow scripts execute ./scripts/get_adapter_info.cdc "adapter-rpi-001" --network=testnet
```

---

## Raspberry Pi Backend Setup

### Step 1: Install Dependencies

```bash
cd adapter
npm install
```

This installs:
- `@onflow/fcl` - Flow Client Library
- `@onflow/types` - Flow type definitions
- `elliptic` - Cryptography for signing
- `express` - Web server

### Step 2: Configure Backend

Edit `adapter/config.json`:

```json
{
  "comment": "ChargeHive Raspberry Pi Configuration",
  "network": "testnet",
  "accessNode": "access.devnet.nodes.onflow.org:9000",
  "platformPrivateKey": "YOUR_PRIVATE_KEY_HERE",
  "platformAddress": "0x7c1a6e4b7eb419c1",
  "adapterId": "adapter-rpi-001",
  "userAddress": "0x28cedbe601e68bfb",
  "CHAdapterContract": "0x7c1a6e4b7eb419c1",
  "CHTokenContract": "0x7c1a6e4b7eb419c1"
}
```

**Get your private key:**
```bash
cat ../contracts/flow-cadence/chargehive.pkey
```

Copy the hex string (without 0x) to `platformPrivateKey`.

**Configuration Fields:**
- `platformPrivateKey` - Signs transactions (from chargehive.pkey)
- `platformAddress` - Your Flow account address
- `adapterId` - Must match registered adapter ID
- `userAddress` - Fallback address (for testing without bookings)
- `CHAdapterContract` - Address where CHAdapter is deployed
- `CHTokenContract` - Address where CHToken is deployed

### Step 3: Start Backend Server

```bash
cd adapter
node index.js
```

**Expected Output:**
```
==============================================
ChargeHive Flow Adapter Server
==============================================
Server running on port 3000
Connected to Flow Testnet

Booking Endpoints:
  POST /booking/create               - Create a booking
  POST /booking/cancel               - Cancel a booking
  GET  /booking/:bookingId           - Get booking details
  GET  /booking/adapter/:adapterId   - Get all bookings for adapter
  GET  /booking/adapter/:adapterId/pending - Get pending booking
  GET  /booking/user/:userAddress    - Get user's bookings

Session Endpoints:
  GET  /startsession - Start a charging session
  POST /endsession   - End session and distribute rewards
==============================================
```

---

## Complete Flow Walkthrough

### Scenario: Alice Books a Charging Session

**Actors:**
- **Alice (User)** - 0x28cedbe601e68bfb
- **Bob (Provider)** - 0x7c1a6e4b7eb419c1
- **Raspberry Pi** - Bob's DePIN device at "adapter-rpi-001"

### 1. Alice Books Time Slot (User App)

```bash
# Alice's app creates a booking for 2 PM - 3 PM on Dec 26, 2024
curl -X POST http://localhost:3000/booking/create \
  -H "Content-Type: application/json" \
  -d '{
    "adapterId": "adapter-rpi-001",
    "userAddress": "0x28cedbe601e68bfb",
    "startTime": 1735225200,
    "endTime": 1735228800
  }'
```

**Response:**
```json
{
  "message": "Booking created successfully",
  "booking": {
    "bookingId": 0,
    "adapterId": "adapter-rpi-001",
    "userAddress": "0x28cedbe601e68bfb",
    "startTime": 1735225200,
    "endTime": 1735228800,
    "actualStartTime": null,
    "actualEndTime": null,
    "status": "pending",
    "sessionId": null,
    "createdAt": 1735220000
  }
}
```

**What Happened:**
- Booking stored in `adapter/subscriber/bookings.json`
- Status: `"pending"`
- No blockchain transaction yet (free!)

### 2. Alice Arrives and Plugs In

```bash
# Raspberry Pi detects current and calls backend
curl http://localhost:3000/startsession
```

**Backend Process:**
1. Checks for pending booking on `adapter-rpi-001`
2. Finds Alice's booking (bookingId: 0)
3. Gets Alice's address: `0x28cedbe601e68bfb`
4. Calls Flow blockchain: `CHAdapter.startSession(adapterId, userAddress)`

**Flow Blockchain:**
```cadence
CHAdapter.startSession(
  adapterId: "adapter-rpi-001",
  userAddress: 0x28cedbe601e68bfb
)
```

- Looks up adapter → finds owner: `0x7c1a6e4b7eb419c1` (Bob)
- Creates session with both addresses
- Returns sessionId: `"adapter-rpi-001-0x28cedbe601e68bfb-1735225210-0"`

**Backend Updates:**
- Booking status: `"pending"` → `"active"`
- Links sessionId to booking
- Records actualStartTime

**Response:**
```json
{
  "message": "Session Created and Started",
  "sessionId": "adapter-rpi-001-0x28cedbe601e68bfb-1735225210-0",
  "bookingId": 0,
  "userAddress": "0x28cedbe601e68bfb",
  "transactionId": "abc123...",
  "status": 4
}
```

### 3. Raspberry Pi Monitors Energy

The Raspberry Pi continuously tracks kWh using INA219 sensor:
- Monitors current flow
- Calculates energy: `Energy (kWh) = Power × Time`
- Example: 25.5 kWh consumed

### 4. Alice Unplugs

```bash
# Raspberry Pi detects no current and reports energy
curl -X POST http://localhost:3000/endsession \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "adapter-rpi-001-0x28cedbe601e68bfb-1735225210-0",
    "energy": 25.5
  }'
```

**Flow Blockchain Transaction:**
```cadence
CHAdapter.endSessionAndDistributeRewards(
  sessionId: "adapter-rpi-001-0x28cedbe601e68bfb-1735225210-0",
  energyUsed: 25.5
)
```

**Smart Contract Calculates:**
```
providerReward = 25.5 kWh × 10 CHT/kWh = 255 CHT
userReward = 255 CHT × 20% = 51 CHT
totalDistributed = 306 CHT
```

**Smart Contract Executes:**
1. Withdraws 306 CHT from treasury
2. Sends 255 CHT → 0x7c1a6e4b7eb419c1 (Bob)
3. Sends 51 CHT → 0x28cedbe601e68bfb (Alice)
4. Updates session as complete
5. Emits events

**Backend Updates:**
- Finds booking linked to session
- Booking status: `"active"` → `"completed"`
- Records actualEndTime

**Response:**
```json
{
  "message": "Session Ended and Rewards Distributed",
  "sessionId": "adapter-rpi-001-0x28cedbe601e68bfb-1735225210-0",
  "energyUsed": 25.5,
  "providerReward": "255.0",
  "userReward": "51.0",
  "providerAddress": "0x7c1a6e4b7eb419c1",
  "userAddress": "0x28cedbe601e68bfb",
  "bookingId": 0,
  "transactionId": "def456...",
  "status": 4
}
```

### 5. Verify Balances

```bash
# Check Bob's balance (should have +255 CHT)
flow scripts execute ./scripts/get_cht_balance.cdc 0x7c1a6e4b7eb419c1 --network=testnet

# Check Alice's balance (should have +51 CHT)
flow scripts execute ./scripts/get_cht_balance.cdc 0x28cedbe601e68bfb --network=testnet
```

### 6. Check Booking Status

```bash
# Get completed booking details
curl http://localhost:3000/booking/0
```

**Response:**
```json
{
  "booking": {
    "bookingId": 0,
    "adapterId": "adapter-rpi-001",
    "userAddress": "0x28cedbe601e68bfb",
    "startTime": 1735225200,
    "endTime": 1735228800,
    "actualStartTime": 1735225210,
    "actualEndTime": 1735228790,
    "status": "completed",
    "sessionId": "adapter-rpi-001-0x28cedbe601e68bfb-1735225210-0",
    "createdAt": 1735220000
  }
}
```

---

## API Reference

### Booking Endpoints

#### POST /booking/create
Creates a new booking.

**Request:**
```bash
curl -X POST http://localhost:3000/booking/create \
  -H "Content-Type: application/json" \
  -d '{
    "adapterId": "adapter-rpi-001",
    "userAddress": "0xUSER",
    "startTime": 1735225200,
    "endTime": 1735228800
  }'
```

**Response:**
```json
{
  "message": "Booking created successfully",
  "booking": { ... }
}
```

#### POST /booking/cancel
Cancels a pending booking.

**Request:**
```bash
curl -X POST http://localhost:3000/booking/cancel \
  -H "Content-Type: application/json" \
  -d '{
    "bookingId": 0,
    "userAddress": "0xUSER"
  }'
```

#### GET /booking/:bookingId
Get booking details.

```bash
curl http://localhost:3000/booking/0
```

#### GET /booking/adapter/:adapterId
Get all bookings for an adapter.

```bash
curl http://localhost:3000/booking/adapter/adapter-rpi-001
```

#### GET /booking/adapter/:adapterId/pending
Get pending booking for adapter (used by Raspberry Pi).

```bash
curl http://localhost:3000/booking/adapter/adapter-rpi-001/pending
```

**Response if booking exists:**
```json
{
  "booking": { ... }
}
```

**Response if no booking:**
```json
{
  "message": "No pending booking found"
}
```

#### GET /booking/user/:userAddress
Get all bookings for a user.

```bash
curl http://localhost:3000/booking/user/0x28cedbe601e68bfb
```

### Session Endpoints

#### GET /startsession
Starts a charging session.

**Auto-detects booking:**
```bash
curl http://localhost:3000/startsession
```

**With manual user address (no booking):**
```bash
curl http://localhost:3000/startsession?userAddress=0xUSER
```

**Response:**
```json
{
  "message": "Session Created and Started",
  "sessionId": "adapter-rpi-001-0xUSER-1234567890-0",
  "bookingId": 0,
  "userAddress": "0xUSER",
  "transactionId": "abc123...",
  "status": 4
}
```

#### POST /endsession
Ends session and distributes rewards.

**Request:**
```bash
curl -X POST http://localhost:3000/endsession \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "adapter-rpi-001-0xUSER-1234567890-0",
    "energy": 25.5
  }'
```

**Response:**
```json
{
  "message": "Session Ended and Rewards Distributed",
  "sessionId": "...",
  "energyUsed": 25.5,
  "providerReward": "255.0",
  "userReward": "51.0",
  "providerAddress": "0xPROVIDER",
  "userAddress": "0xUSER",
  "bookingId": 0,
  "transactionId": "def456...",
  "status": 4
}
```

---

## Testing Guide

### Test 1: Without Booking (Fallback Mode)

```bash
# 1. Start session with manual user address
curl "http://localhost:3000/startsession?userAddress=0x28cedbe601e68bfb"

# Save the sessionId from response

# 2. End session
curl -X POST http://localhost:3000/endsession \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "SESSION_ID_HERE",
    "energy": 10.0
  }'

# 3. Check balances
flow scripts execute ./scripts/get_cht_balance.cdc 0x7c1a6e4b7eb419c1 --network=testnet
flow scripts execute ./scripts/get_cht_balance.cdc 0x28cedbe601e68bfb --network=testnet
```

### Test 2: With Booking (Recommended)

```bash
# 1. Create booking
curl -X POST http://localhost:3000/booking/create \
  -H "Content-Type: application/json" \
  -d '{
    "adapterId": "adapter-rpi-001",
    "userAddress": "0x28cedbe601e68bfb",
    "startTime": 9999999999,
    "endTime": 9999999999
  }'

# 2. Start session (auto-detects booking)
curl http://localhost:3000/startsession

# Save the sessionId

# 3. End session
curl -X POST http://localhost:3000/endsession \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "SESSION_ID_HERE",
    "energy": 15.0
  }'

# 4. Check booking status
curl http://localhost:3000/booking/0

# 5. Check balances
flow scripts execute ./scripts/get_cht_balance.cdc 0x7c1a6e4b7eb419c1 --network=testnet
flow scripts execute ./scripts/get_cht_balance.cdc 0x28cedbe601e68bfb --network=testnet
```

### Test 3: Energy Tracker Simulation

```bash
# Run the Python energy tracker
cd publisher
python3 trackEnergy.py
```

This will:
1. Call `/startsession`
2. Track energy for 15 seconds (increments by 1 kWh/second)
3. Call `/endsession` with total energy
4. Distribute tokens automatically

---

## Troubleshooting

### Error: "Could not borrow treasury vault"

**Cause:** Treasury has no CHT tokens.

**Fix:**
```bash
flow transactions send ./transactions/fund_adapter_treasury.cdc 5000000.0 \
  --signer chargehive \
  --network testnet
```

### Error: "Could not borrow user receiver"

**Cause:** User account doesn't have CHT vault setup.

**Fix:**
```bash
flow transactions send ./transactions/setup_cht_account.cdc \
  --signer chargehive \
  --network testnet
```

### Error: "Adapter not found"

**Cause:** Adapter not registered in contract.

**Fix:**
```bash
flow transactions send ./transactions/register_adapter.cdc \
  "adapter-rpi-001" \
  0xPROVIDER_ADDRESS \
  "Location" \
  "Description" \
  0.15 \
  --signer chargehive \
  --network testnet
```

### Error: "Session not found"

**Cause:** Invalid session ID.

**Fix:** Check the sessionId from the `/startsession` response and use exactly that string.

### Error: "No pending booking found"

**Cause:** No booking exists or booking already used.

**Fix:** Create a new booking or use manual user address:
```bash
curl "http://localhost:3000/startsession?userAddress=0xUSER"
```

### Backend Not Starting

**Check Node.js:**
```bash
node --version  # Should be v14+
npm install
```

**Check Port:**
```bash
lsof -i :3000  # See if port is in use
```

### Flow CLI Issues

**Reinstall Flow CLI:**
```bash
sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"
```

**Check Network:**
```bash
flow config get networks
```

---

## Project Structure

```
chargehive/
├── contracts/flow-cadence/          # Flow blockchain contracts
│   ├── contracts/
│   │   ├── CHToken.cdc              # Token contract
│   │   ├── CHAdapter.cdc            # Charging adapter management
│   │   └── CHParking.cdc            # Parking management
│   ├── transactions/
│   │   ├── setup_cht_account.cdc    # Setup token vault
│   │   ├── register_adapter.cdc     # Register new adapter
│   │   ├── start_charging_session.cdc
│   │   ├── end_charging_session.cdc
│   │   ├── fund_adapter_treasury.cdc
│   │   └── create_booking.cdc       # Booking template
│   ├── scripts/
│   │   ├── get_cht_balance.cdc      # Check token balance
│   │   ├── get_adapter_info.cdc     # Get adapter details
│   │   ├── get_session_details.cdc  # Get session info
│   │   ├── get_booking_info.cdc     # Booking query helper
│   │   └── get_pending_booking.cdc  # Pending booking query
│   ├── flow.json                    # Flow configuration
│   ├── chargehive.pkey              # Private key (gitignored)
│   ├── README.md                    # Setup instructions
│   └── BOOKING-SCRIPTS.md           # Booking API reference
│
└── adapter/                         # Raspberry Pi backend
    ├── subscriber/
    │   ├── bookingManager.js        # Booking management
    │   ├── startSession-flow.js     # Start session handler
    │   ├── endSession-flow.js       # End session handler
    │   ├── bookings.json            # Booking storage (auto-generated)
    │   └── sessions-flow.json       # Session tracking
    ├── publisher/
    │   └── trackEnergy.py           # Energy tracker simulation
    ├── index.js                     # Express server
    ├── config.json                  # Backend configuration
    ├── package.json                 # Dependencies
    ├── README.md                    # Quick start
    ├── BOOKING-FLOW.md              # Booking flow details
    └── UPDATES-SUMMARY.md           # Changelog
```

---

## Key Concepts

### Booking States

- **pending** - User created booking, hasn't arrived
- **active** - User arrived, session in progress
- **completed** - Session ended, rewards distributed
- **cancelled** - User cancelled before arriving

### Token Economics

- **Reward Rate**: 10 CHT per kWh (configurable)
- **User Bonus**: 20% of provider reward (configurable)
- **Provider**: Gets 100% of calculated reward
- **User**: Gets 20% bonus on top

**Example:**
```
Energy: 50 kWh
Provider: 50 × 10 = 500 CHT
User: 500 × 20% = 100 CHT
Total: 600 CHT distributed
```

### Why Hybrid Architecture?

**Off-Chain Bookings:**
- ✅ Free to create/cancel
- ✅ Instant updates
- ✅ Flexible and private
- ✅ Easy to migrate to database

**On-Chain Sessions & Tokens:**
- ✅ Immutable records
- ✅ Transparent distribution
- ✅ Trustless execution
- ✅ Public verification

---

## Next Steps

### Development:
1. ✅ Deploy contracts to testnet
2. ✅ Setup backend with bookings
3. ✅ Test complete flow
4. 🔲 Build User App (Flutter/React Native)
5. 🔲 Build Provider App (Flutter/React Native)
6. 🔲 Integrate real hardware (INA219 sensor)
7. 🔲 Deploy to production Raspberry Pi

### Production:
1. 🔲 Audit smart contracts
2. 🔲 Migrate bookings to database (PostgreSQL/MongoDB)
3. 🔲 Setup monitoring & alerts
4. 🔲 Deploy to Flow Mainnet
5. 🔲 Scale to multiple adapters

---

## Resources

- **Flow Documentation**: https://developers.flow.com
- **Flow Testnet Faucet**: https://testnet-faucet.onflow.org
- **Flow Block Explorer**: https://testnet.flowscan.io
- **ChargeHive GitHub**: (your repo)

---

**Built with Flow Cadence - Resource-Oriented Smart Contracts**

For questions or issues, refer to the troubleshooting section or check individual README files in each directory.
