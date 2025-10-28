# Energy Calculation Flow

## How Energy Values Flow Through the System

### 1. Energy Meter Reading (Wh)

The UM25C energy meter provides readings in **Watt-hours (Wh)**:

```python
# In flow_session_manager_http.py
value = response[106:110]
energy = int.from_bytes(value, byteorder='big')  # Returns: 5500 Wh
```

### 2. Python Publisher Calculates Consumption

```python
# Calculate energy consumed during session
if start_energy > 0 and current_energy >= start_energy:
    energy_wh = current_energy - start_energy
else:
    energy_wh = current_energy

# Example:
# start_energy = 100 Wh
# current_energy = 5600 Wh
# energy_wh = 5600 - 100 = 5500 Wh
```

### 3. Send Wh to API Server

```python
result = api_request('POST', '/api/session/end', data={
    'sessionId': flow_session_id,
    'energyUsed': energy_wh  # Sends: 5500 (in Wh)
})
```

### 4. API Server Converts Wh → kWh

```javascript
// In server.js
const energyWh = parseFloat(energyUsed);  // 5500 Wh
const energyKwh = energyWh / 1000.0;      // 5.5 kWh

console.log(`Energy: ${energyWh} Wh (${energyKwh.toFixed(3)} kWh)`);
// Output: Energy: 5500 Wh (5.500 kWh)
```

### 5. Flow Blockchain Receives kWh

```javascript
// In flowService.js
const result = await flowService.endSession(sessionId, energyKwh);
// Sends to blockchain: 5.5 kWh
```

### 6. Smart Contract Calculates Rewards

```cadence
// In CHAdapter.cdc
// energyUsed = 5.5 kWh (UFix64)

if energyUsed >= self.minimumKwh {
    // Provider gets: energyUsed × rewardRatePerKwh
    providerReward = energyUsed * self.rewardRatePerKwh
    // providerReward = 5.5 × 10.0 = 55.0 CHT

    // User gets: providerReward × userBonusPercentage / 100
    userReward = providerReward * self.userBonusPercentage / 100.0
    // userReward = 55.0 × 20 / 100 = 11.0 CHT
}

// USD cost (display only)
usdCost = energyUsed * self.pricePerKwhUsd
// usdCost = 5.5 × 0.15 = $0.825
```

## Complete Example

### Input from Energy Meter

```
Start Reading: 100 Wh
End Reading: 5600 Wh
```

### Step-by-Step Calculation

| Step | Location | Calculation | Value | Unit |
|------|----------|-------------|-------|------|
| 1 | Energy Meter | current_energy - start_energy | 5600 - 100 = **5500** | Wh |
| 2 | Python | Send to API | **5500** | Wh |
| 3 | API Server | Wh ÷ 1000 | 5500 ÷ 1000 = **5.5** | kWh |
| 4 | Flow Contract | energyUsed × rewardRate | 5.5 × 10 = **55.0** | CHT |
| 5 | Flow Contract | providerReward × 20% | 55.0 × 0.20 = **11.0** | CHT |
| 6 | Flow Contract | energyUsed × priceUSD | 5.5 × 0.15 = **$0.825** | USD |

### Final Output

```json
{
  "success": true,
  "transactionId": "abc123...",
  "rewards": {
    "provider": 55.0,     // CHT tokens
    "user": 11.0,         // CHT tokens
    "usdCost": 0.825      // USD (display only)
  }
}
```

## Why Send Wh to API?

### ✅ Advantages of Sending Wh

1. **Preserves Precision**: No rounding errors in Python
2. **Raw Data**: Original meter reading preserved
3. **Flexibility**: API can convert based on needs
4. **Debugging**: Easy to trace exact meter readings

### Data Flow Summary

```
Energy Meter → Python → API Server → Flow Blockchain
   (Wh)         (Wh)       (Wh→kWh)       (kWh)
   5500    →    5500   →     5.5      →    5.5
```

## Configuration

### Reward Rate (in CHAdapter contract)

```cadence
access(all) var rewardRatePerKwh: UFix64 = 10.0  // 10 CHT per kWh
access(all) var userBonusPercentage: UFix64 = 20.0  // 20% bonus
access(all) var pricePerKwhUsd: UFix64 = 0.15  // $0.15 per kWh
```

### To Change Rewards

You can update these values using the Admin functions in the contract.

## Examples with Different Energy Values

| Wh Input | kWh | Provider CHT | User CHT | USD Cost |
|----------|-----|--------------|----------|----------|
| 1000 | 1.0 | 10.0 | 2.0 | $0.15 |
| 2500 | 2.5 | 25.0 | 5.0 | $0.375 |
| 5500 | 5.5 | 55.0 | 11.0 | $0.825 |
| 10000 | 10.0 | 100.0 | 20.0 | $1.50 |
| 15000 | 15.0 | 150.0 | 30.0 | $2.25 |

## API Request/Response

### Request (from Python)

```bash
POST /api/session/end
Content-Type: application/json

{
  "sessionId": "RPI-SF-001-0x919d69a9d0efa39b-1738015815-3",
  "energyUsed": 5500  # Wh value
}
```

### Server Logs

```
🏁 Ending session: RPI-SF-001-0x919d69a9d0efa39b-1738015815-3
   Energy: 5500 Wh (5.500 kWh)
```

### Response (to Python)

```json
{
  "success": true,
  "transactionId": "abc123...",
  "status": 4,
  "rewards": {
    "provider": 55.0,
    "user": 11.0,
    "usdCost": 0.825
  }
}
```

## Summary

- **Python sends**: Raw Wh value from meter
- **API converts**: Wh → kWh (÷ 1000)
- **Flow receives**: kWh for reward calculation
- **Result**: Accurate rewards based on actual consumption

This approach ensures precision and makes it easy to debug if there are any discrepancies!
