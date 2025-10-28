# ChargeHive Adapter - Automated Flow Session Manager

Automatically manages Flow blockchain charging sessions with a Node.js API server and Python energy monitor.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Energy Meter (UM25C via Bluetooth Serial)     │
└────────────┬────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────┐
│  Publisher (Python)                             │
│  - flow_session_manager_http.py                 │
│  - Monitors current/energy via serial           │
│  - Detects connection/disconnection             │
│  - HTTP client to API server                    │
└────────────┬────────────────────────────────────┘
             │ HTTP/REST
             ▼
┌─────────────────────────────────────────────────┐
│  Subscriber (Node.js API Server)                │
│  - Express REST API                             │
│  - Flow blockchain integration                  │
│  - Session management                           │
│  - Reward distribution                          │
└────────────┬────────────────────────────────────┘
             │ Flow SDK
             ▼
┌─────────────────────────────────────────────────┐
│  Flow Blockchain (Testnet)                      │
│  - CHAdapter Contract                           │
│  - CHToken Contract                             │
│  - Bookings, Sessions, Rewards                  │
└─────────────────────────────────────────────────┘
```

## Features

- ✅ **Decoupled Architecture**: Python for hardware, Node.js for blockchain
- ✅ **HTTP/REST API**: Clean communication between components
- ✅ **Automatic Session Management**: Detects plug/unplug events
- ✅ **Pending Booking Detection**: Automatically finds bookings
- ✅ **Real-time Energy Tracking**: Monitors consumption continuously
- ✅ **Instant Rewards**: Distributed when charging ends
- ✅ **Local Data Backup**: JSON files for all sessions

## Quick Start

### One-Command Startup

```bash
cd /Users/vaibhav/Desktop/chargehive/adapter
./start_system.sh
```

# Flow Network Configuration
FLOW_NETWORK=testnet

# Your Flow account (contract deployer)
FLOW_ADDRESS=0x919d69a9d0efa39b
FLOW_PRIVATE_KEY=de16eb8282c42d9d5a7ab67bc8a4f012cccb42604d40137c137a2a44a42fc5ca
FLOW_KEY_INDEX=0

# Contract addresses
CHADAPTER_ADDRESS=0x919d69a9d0efa39b
CHTTOKEN_ADDRESS=0x919d69a9d0efa39b

# Server configuration
PORT=3000
ADAPTER_ID=RPI-SF-001


This will:
1. Install all dependencies
2. Start the Node.js API server
3. Start the Python energy monitor
4. Automatically manage sessions

## Manual Setup

### 1. Install Dependencies

**Node.js (API Server):**
```bash
cd /Users/vaibhav/Desktop/chargehive/adapter/subscriber
npm install
```

**Python (Energy Monitor):**
```bash
pip install pyserial requests
```

### 2. Configure Environment

Edit `subscriber/.env`:
```env
FLOW_NETWORK=testnet
FLOW_ADDRESS=0x919d69a9d0efa39b
FLOW_PRIVATE_KEY=your_private_key
CHADAPTER_ADDRESS=0x919d69a9d0efa39b
CHTTOKEN_ADDRESS=0x919d69a9d0efa39b
PORT=3000
ADAPTER_ID=RPI-SF-001
```

### 3. Start API Server

```bash
cd /Users/vaibhav/Desktop/chargehive/adapter/subscriber
npm start
```

Output:
```
============================================================
ChargeHive Adapter API Server
============================================================
Server: http://localhost:3000
Adapter ID: RPI-SF-001
Network: testnet
Flow Address: 0x919d69a9d0efa39b
============================================================

API Endpoints:
  GET  /health
  GET  /api/booking/pending?adapterId=RPI-SF-001
  POST /api/session/start
  POST /api/session/end
  GET  /api/adapter/:adapterId

Ready to accept requests...
============================================================
```

### 4. Start Energy Monitor

In a new terminal:
```bash
cd /Users/vaibhav/Desktop/chargehive/adapter/publisher
export ADAPTER_ID="RPI-SF-001"
export API_BASE_URL="http://localhost:3000"
python3 flow_session_manager_http.py
```

## API Reference

### GET /health
Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "adapter": "RPI-SF-001",
  "network": "testnet",
  "timestamp": "2025-01-27T19:30:00.000Z"
}
```

### GET /api/booking/pending
Get pending booking for an adapter.

**Query Parameters:**
- `adapterId` (optional): Adapter ID (defaults to env ADAPTER_ID)

**Response:**
```json
{
  "success": true,
  "booking": {
    "bookingId": 0,
    "adapterId": "RPI-SF-001",
    "userAddress": "0x919d69a9d0efa39b",
    "scheduledTime": "1738015800.0",
    "status": "pending",
    "sessionId": null,
    "createdAt": "1738015200.0"
  }
}
```

### POST /api/session/start
Start a charging session.

**Request Body:**
```json
{
  "bookingId": 0
}
```

**Response:**
```json
{
  "success": true,
  "sessionId": "RPI-SF-001-0x919d69a9d0efa39b-1738015815-3",
  "transactionId": "abc123...",
  "status": 4
}
```

### POST /api/session/end
End a session and distribute rewards.

**Request Body:**
```json
{
  "sessionId": "RPI-SF-001-0x919d69a9d0efa39b-1738015815-3",
  "energyUsed": 5.5
}
```

**Response:**
```json
{
  "success": true,
  "transactionId": "def456...",
  "status": 4,
  "rewards": {
    "provider": 55.0,
    "user": 11.0,
    "usdCost": 0.825
  }
}
```

### GET /api/adapter/:adapterId
Get adapter information.

**Response:**
```json
{
  "success": true,
  "adapter": {
    "adapterId": "RPI-SF-001",
    "ownerAddress": "0x919d69a9d0efa39b",
    "location": "123 Market St, SF",
    "details": "Level 2, 7kW",
    "pricePerKwh": 0.25,
    "authorized": true,
    "createdAt": "1738015000.0"
  }
}
```

## Complete Workflow

### Step 1: User Creates Booking

```bash
cd /Users/vaibhav/Desktop/chargehive/contracts/flow-cadence
FUTURE=$(echo "$(date +%s) + 3600" | bc)
npm run create-booking RPI-SF-001 0x919d69a9d0efa39b ${FUTURE}.0
```

### Step 2: Start System

```bash
cd /Users/vaibhav/Desktop/chargehive/adapter
./start_system.sh
```

### Step 3: User Plugs In (Automatic)

```
⚡ Energy: 150 Wh | Current: 3200 mA | 2025-01-27 19:30:15

🔌 CHARGING CONNECTED - Starting Flow session...
🔍 Checking for pending bookings...
✓ Found pending booking!
  Booking ID: 0
  User: 0x919d69a9d0efa39b
✓ Flow session started!
  Booking ID: 0
  Session ID: RPI-SF-001-0x919d69a9d0efa39b-1738015815-3
  Transaction: abc123...
```

### Step 4: User Unplugs (Automatic)

```
🔌 CHARGING DISCONNECTED - Ending Flow session...
  Energy consumed: 5500 Wh (5.500 kWh)
  Total readings: 660
✓ Flow session ended and rewards distributed!
  Transaction: def456...
  Provider Reward: 55.0 CHT
  User Reward: 11.0 CHT
  USD Cost: $0.825
  Session data saved: session_RPI-SF-001-0x919d69a9d0efa39b-1738015815-3_1738016730.json
```

## Environment Variables

### Subscriber (API Server)

| Variable | Description | Default |
|----------|-------------|---------|
| `FLOW_NETWORK` | Flow network | `testnet` |
| `FLOW_ADDRESS` | Your Flow address | Required |
| `FLOW_PRIVATE_KEY` | Your private key | Required |
| `FLOW_KEY_INDEX` | Key index | `0` |
| `CHADAPTER_ADDRESS` | CHAdapter contract address | Same as FLOW_ADDRESS |
| `CHTTOKEN_ADDRESS` | CHToken contract address | Same as FLOW_ADDRESS |
| `PORT` | API server port | `3000` |
| `ADAPTER_ID` | Default adapter ID | `RPI-SF-001` |

### Publisher (Energy Monitor)

| Variable | Description | Default |
|----------|-------------|---------|
| `ADAPTER_ID` | Adapter identifier | `RPI-SF-001` |
| `API_BASE_URL` | API server URL | `http://localhost:3000` |

## Testing API Server

Test endpoints with curl:

```bash
# Health check
curl http://localhost:3000/health

# Get pending booking
curl http://localhost:3000/api/booking/pending?adapterId=RPI-SF-001

# Start session
curl -X POST http://localhost:3000/api/session/start \
  -H "Content-Type: application/json" \
  -d '{"bookingId": 0}'

# End session
curl -X POST http://localhost:3000/api/session/end \
  -H "Content-Type: application/json" \
  -d '{"sessionId": "RPI-SF-001-0x919d69a9d0efa39b-1738015815-3", "energyUsed": 5.5}'

# Get adapter info
curl http://localhost:3000/api/adapter/RPI-SF-001
```

## Troubleshooting

### API Server Won't Start

```
✗ Cannot connect to API server at http://localhost:3000
```

**Solution:**
1. Check if port 3000 is already in use
2. Verify `.env` file exists in `subscriber/` directory
3. Run `npm install` in `subscriber/` directory

### No Pending Booking Found

```
○ No pending booking found
```

**Solution**: User needs to create a booking first:
```bash
cd contracts/flow-cadence
FUTURE=$(echo "$(date +%s) + 3600" | bc)
npm run create-booking RPI-SF-001 0x919d69a9d0efa39b ${FUTURE}.0
```

### Serial Port Error

```
✗ Serial error: [Errno 2] No such file or directory: '/dev/rfcomm0'
```

**Solution**: Update `COM_PORT` in `flow_session_manager_http.py` to your actual serial port.

## Benefits Over Subprocess Approach

- ✅ **Better Performance**: HTTP requests faster than spawning processes
- ✅ **Cleaner Separation**: Hardware logic in Python, blockchain in Node.js
- ✅ **Easier Testing**: Can test API independently
- ✅ **Better Error Handling**: HTTP status codes and JSON responses
- ✅ **Scalability**: API server can handle multiple adapters
- ✅ **Monitoring**: Can add logging, metrics, health checks
- ✅ **Reusability**: API can be used by other applications

## Project Structure

```
adapter/
├── README.md                           # This file
├── start_system.sh                     # Complete system startup
├── subscriber/                         # Node.js API Server
│   ├── package.json
│   ├── .env                           # Configuration
│   ├── server.js                      # Express server
│   └── flowService.js                 # Flow blockchain service
└── publisher/                          # Python Energy Monitor
    ├── flow_session_manager_http.py   # HTTP-based session manager
    └── sessions/                       # Session data (JSON files)
```
