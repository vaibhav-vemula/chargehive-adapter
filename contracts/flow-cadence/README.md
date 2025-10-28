# ChargeHive Flow Scripts

JavaScript scripts to interact with ChargeHive smart contracts on Flow blockchain.

## Prerequisites

- Node.js v18+ installed
- Flow CLI installed (optional, for deployment)
- Access to Flow Testnet or Emulator

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment

Create a `.env` file in this directory:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
# Network: emulator, testnet, or mainnet
FLOW_NETWORK=testnet

# Your Flow account address
FLOW_ADDRESS=0xYOUR_ADDRESS

# Your Flow account private key
FLOW_PRIVATE_KEY=YOUR_PRIVATE_KEY

# Key index (usually 0)
FLOW_KEY_INDEX=0

# Contract addresses (after deployment)
CHADAPTER_ADDRESS=0xYOUR_CHADAPTER_ADDRESS
CHTTOKEN_ADDRESS=0xYOUR_CHTTOKEN_ADDRESS
```

### 3. Update flow.json

Update `flow.json` with your deployed contract addresses.

## Available Scripts

### 1. Register Adapter

Register a new charging adapter on the platform.

```bash
npm run register-adapter <adapterId> <ownerAddress> <location> <details> <pricePerKwh>
```

**Example:**
```bash
npm run register-adapter RPI-SF-001 0x1234567890abcdef "123 Market St, SF" "Level 2, Type 2, 7kW" 0.25
```

**Parameters:**
- `adapterId`: Unique identifier for the adapter (e.g., "RPI-SF-001")
- `ownerAddress`: Flow address of the provider who owns this adapter
- `location`: Physical location of the charging station
- `details`: Description and specs (e.g., "Level 2 Charger, Type 2, 7kW")
- `pricePerKwh`: Price in USD per kWh (e.g., 0.25)

### 2. Create Booking

Create a booking for a user to reserve a charging slot.

```bash
npm run create-booking <adapterId> <userAddress> <scheduledTime>
```

**Example:**
```bash
# Get current timestamp + 1 hour
FUTURE_TIME=$(echo "$(date +%s) + 3600" | bc)
npm run create-booking RPI-SF-001 0xabcdef1234567890 ${FUTURE_TIME}.0
```

**Parameters:**
- `adapterId`: ID of the adapter to book
- `userAddress`: Flow address of the user making the booking
- `scheduledTime`: Unix timestamp (UFix64) when user plans to arrive (must be in future)

**Note:** Save the `bookingId` returned in the event for the next step!

### 3. Start Session

Start a charging session when user arrives and plugs in.

```bash
npm run start-session <bookingId>
```

**Example:**
```bash
npm run start-session 0
```

**Parameters:**
- `bookingId`: The booking ID obtained from creating a booking

**Note:** Save the `sessionId` from the output for ending the session!

### 4. End Session

End a charging session and distribute rewards to provider and user.

```bash
npm run end-session <sessionId> <energyUsed>
```

**Example:**
```bash
npm run end-session RPI-SF-001-0x123-1234567890-0 5.5
```

**Parameters:**
- `sessionId`: Session ID from the SessionStarted event
- `energyUsed`: Energy consumed in kWh (e.g., 5.5)

**Output shows:**
- Energy used
- Provider reward (100% of calculated reward)
- User reward (20% bonus of provider reward)
- USD cost (display only)

### 5. Get CHT Balance

Query CHT token balance for any address.

```bash
npm run get-balance <address>
```

**Example:**
```bash
npm run get-balance 0x1234567890abcdef
```

### 6. Get Adapter Info

Get detailed information about an adapter.

```bash
npm run get-adapter <adapterId>
```

**Example:**
```bash
npm run get-adapter RPI-SF-001
```

### 7. Get Booking Info

Get detailed information about a booking.

```bash
npm run get-booking <bookingId>
```

**Example:**
```bash
npm run get-booking 0
```

## Complete Workflow Example

Here's a complete end-to-end example:

```bash
# 1. Provider registers their charging adapter
npm run register-adapter RPI-SF-001 0x1234567890abcdef "123 Market St, SF" "Level 2, Type 2, 7kW" 0.25

# 2. Check adapter was registered
npm run get-adapter RPI-SF-001

# 3. User creates a booking (for 1 hour from now)
FUTURE_TIME=$(echo "$(date +%s) + 3600" | bc)
npm run create-booking RPI-SF-001 0xabcdef1234567890 ${FUTURE_TIME}.0
# Output: Booking ID: 0

# 4. Check booking details
npm run get-booking 0

# 5. User arrives and Raspberry Pi starts session
npm run start-session 0
# Output: Session ID: RPI-SF-001-0xabcdef1234567890-1735689600-0

# 6. User charges their vehicle (let's say 5.5 kWh)
# ... time passes while charging ...

# 7. User unplugs, Raspberry Pi ends session and distributes rewards
npm run end-session RPI-SF-001-0xabcdef1234567890-1735689600-0 5.5
# Output:
# Energy Used: 5.5 kWh
# Provider Reward: 55.0 CHT (5.5 kWh × 10 CHT/kWh)
# User Reward: 11.0 CHT (20% of provider reward)
# USD Cost: $0.825 (5.5 kWh × $0.15/kWh)

# 8. Check balances
npm run get-balance 0x1234567890abcdef  # Provider balance
npm run get-balance 0xabcdef1234567890  # User balance
```

## Reward Calculation

**Default Configuration:**
- Reward Rate: 10 CHT per kWh
- User Bonus: 20% of provider reward
- Minimum kWh: 0.0 (no minimum)
- Price Display: $0.15 per kWh (USD, display only)

**Example Calculation (5 kWh session):**
1. Provider Reward = 5 kWh × 10 CHT/kWh = **50 CHT**
2. User Reward = 50 CHT × 20% = **10 CHT**
3. USD Cost = 5 kWh × $0.15/kWh = **$0.75** (display only)

## Important Notes

### Booking Requirement
**All charging sessions MUST be initiated through a booking.** Users cannot start sessions without creating a booking first. This ensures:
- Better capacity planning for adapters
- Scheduled arrival times
- Tracked usage and accountability

### Network Selection
Set `FLOW_NETWORK` in `.env`:
- `emulator`: Local Flow emulator (for development)
- `testnet`: Flow Testnet
- `mainnet`: Flow Mainnet (production)

### Authentication
These scripts use server-side authentication. For production:
- Use proper key management (e.g., AWS KMS, HashiCorp Vault)
- Never commit private keys to version control
- Implement proper access controls

### Gas Limits
All transactions use a limit of 999. Adjust if needed for complex operations.

## Troubleshooting

### "Adapter not found"
- Ensure the adapter is registered first using `register-adapter`
- Check the adapter ID spelling

### "Booking not found"
- Ensure you're using the correct booking ID from the creation event
- Check booking status with `get-booking`

### "Session must be pending"
- This booking has already been used to start a session
- Each booking can only start one session

### "Scheduled time must be in the future"
- The scheduled time must be a future Unix timestamp
- Use `date +%s` to get current timestamp and add seconds

### "Could not borrow receiver"
- The user/provider account doesn't have CHT vault set up
- They need to run the setup account transaction first

## Contract Addresses

Update these after deploying your contracts:

**Testnet:**
- FungibleToken: `0x9a0766d93b6608b7`
- CHToken: `YOUR_DEPLOYED_ADDRESS`
- CHAdapter: `YOUR_DEPLOYED_ADDRESS`

**Mainnet:**
- FungibleToken: `0xf233dcee88fe0abe`
- CHToken: `YOUR_DEPLOYED_ADDRESS`
- CHAdapter: `YOUR_DEPLOYED_ADDRESS`

## Support

For issues or questions:
1. Check the contract source code in `contracts/`
2. Review Flow documentation: https://docs.onflow.org
3. Check FCL documentation: https://github.com/onflow/fcl-js
