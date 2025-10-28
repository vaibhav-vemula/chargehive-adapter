import serial
import time
import json
import requests
import os
from datetime import datetime
from pathlib import Path

# Serial configuration
COM_PORT = '/dev/rfcomm0'
BAUD_RATE = 9600

# API Server configuration
API_BASE_URL = os.getenv('API_BASE_URL', 'http://localhost:3000')
ADAPTER_ID = os.getenv('ADAPTER_ID', 'RPI-SF-001')

# Commands
COMMAND = b'\xF0'
CLEAR = b'\xF4'

# Global session state
session_active = False
flow_session_id = None
flow_booking_id = None
start_energy = 0
current_energy = 0
energy_readings = []

def api_request(method, endpoint, data=None, params=None):
    """Make HTTP request to API server"""
    url = f"{API_BASE_URL}{endpoint}"
    try:
        if method == 'GET':
            response = requests.get(url, params=params, timeout=10)
        elif method == 'POST':
            response = requests.post(url, json=data, timeout=30)
        else:
            raise ValueError(f"Unsupported method: {method}")

        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"✗ API request failed: {e}")
        return None

def get_pending_booking():
    """Get the latest pending booking for this adapter"""
    try:
        print("🔍 Checking for pending bookings...")
        result = api_request('GET', '/api/booking/pending', params={'adapterId': ADAPTER_ID})

        if result and result.get('success'):
            booking = result.get('booking')
            if booking:
                booking_id = booking['bookingId']
                user_address = booking['userAddress']
                print(f"✓ Found pending booking!")
                print(f"  Booking ID: {booking_id}")
                print(f"  User: {user_address}")
                return booking_id

        print("○ No pending booking found")
        return None
    except Exception as e:
        print(f"✗ Error getting pending booking: {e}")
        return None

def start_flow_session(booking_id=None):
    """Start a Flow blockchain session"""
    global session_active, flow_session_id, flow_booking_id, start_energy, energy_readings

    if session_active:
        print("⚠ Session already active")
        return False

    print("\n🔌 CHARGING CONNECTED - Starting Flow session...")

    # If no booking ID provided, try to get the latest pending booking
    if booking_id is None:
        booking_id = get_pending_booking()

    if booking_id is None:
        print("⚠ No pending booking found. Session cannot start.")
        print("   User must create a booking first!")
        return False

    # Start session on Flow blockchain
    result = api_request('POST', '/api/session/start', data={'bookingId': booking_id})

    if result and result.get('success'):
        flow_session_id = result.get('sessionId')

        if flow_session_id:
            session_active = True
            flow_booking_id = booking_id
            energy_readings = []

            print(f"✓ Flow session started!")
            print(f"  Booking ID: {booking_id}")
            print(f"  Session ID: {flow_session_id}")
            print(f"  Transaction: {result.get('transactionId')}")
            return True
        else:
            print("✗ Failed to extract session ID from response")
            return False
    else:
        print("✗ Failed to start Flow session")
        if result:
            print(f"   Error: {result.get('error', 'Unknown error')}")
        return False

def end_flow_session():
    """End the Flow session and distribute rewards"""
    global session_active, flow_session_id, flow_booking_id, current_energy, start_energy, energy_readings

    if not session_active or not flow_session_id:
        print("⚠ No active session to end")
        return False

    print("\n🔌 CHARGING DISCONNECTED - Ending Flow session...")

    # Calculate energy consumed in Wh
    if start_energy > 0 and current_energy >= start_energy:
        energy_wh = current_energy - start_energy
    else:
        energy_wh = current_energy

    energy_kwh = energy_wh / 1000.0  # For display only

    print(f"  Energy consumed: {energy_wh} Wh ({energy_kwh:.3f} kWh)")
    print(f"  Total readings: {len(energy_readings)}")

    # Save session data locally
    save_session_data(energy_kwh, energy_wh)

    # End session on Flow blockchain - Send Wh value
    if energy_wh > 0:
        result = api_request('POST', '/api/session/end', data={
            'sessionId': flow_session_id,
            'energyUsed': energy_wh  # Send Wh value directly
        })

        if result and result.get('success'):
            print("✓ Flow session ended and rewards distributed!")
            print(f"  Transaction: {result.get('transactionId')}")

            rewards = result.get('rewards', {})
            print(f"  Provider Reward: {rewards.get('provider', 0)} CHT")
            print(f"  User Reward: {rewards.get('user', 0)} CHT")
            print(f"  USD Cost: ${rewards.get('usdCost', 0)}")
        else:
            print("✗ Failed to end Flow session")
            if result:
                print(f"   Error: {result.get('error', 'Unknown error')}")
            print("  Session data saved locally - you can manually end it later")
    else:
        print("⚠ No energy consumed - session ended without rewards")

    # Reset session state
    session_active = False
    flow_session_id = None
    flow_booking_id = None
    energy_readings = []
    start_energy = 0
    current_energy = 0

    return True

def save_session_data(energy_kwh, energy_wh):
    """Save session data to local file"""
    session_data = {
        "session_id": flow_session_id,
        "booking_id": flow_booking_id,
        "adapter_id": ADAPTER_ID,
        "start_time": energy_readings[0]['timestampISO'] if energy_readings else None,
        "end_time": datetime.now().isoformat(),
        "energy_wh": energy_wh,
        "energy_kwh": energy_kwh,
        "total_readings": len(energy_readings),
        "readings": energy_readings
    }

    # Save to JSON file
    filename = f"session_{flow_session_id.replace('/', '_')}_{int(time.time())}.json"
    filepath = Path(__file__).parent / 'sessions' / filename
    filepath.parent.mkdir(exist_ok=True)

    with open(filepath, 'w') as f:
        json.dump(session_data, f, indent=2)

    print(f"  Session data saved: {filename}")

def check_api_server():
    """Check if API server is running"""
    try:
        result = api_request('GET', '/health')
        if result and result.get('status') == 'ok':
            print(f"✓ API Server connected")
            print(f"  URL: {API_BASE_URL}")
            print(f"  Network: {result.get('network')}")
            return True
        else:
            print(f"✗ API Server not responding properly")
            return False
    except Exception as e:
        print(f"✗ Cannot connect to API server at {API_BASE_URL}")
        print(f"  Error: {e}")
        print("\n  Please start the API server:")
        print(f"  cd adapter/subscriber && npm start")
        return False

def main():
    """Main energy monitoring loop"""
    global session_active, start_energy, current_energy, energy_readings

    print("=" * 60)
    print("ChargeHive Flow Session Manager (HTTP)")
    print("=" * 60)
    print(f"Adapter ID: {ADAPTER_ID}")
    print(f"API Server: {API_BASE_URL}")
    print(f"Serial Port: {COM_PORT}")
    print("=" * 60)
    print()

    # Check API server connection
    if not check_api_server():
        print("\nExiting... Please start the API server first.")
        return

    print("\nWaiting for charging connection...\n")

    try:
        ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
        print(f"✓ Connected to {COM_PORT}")
        time.sleep(2)
        ser.write(CLEAR)

        consecutive_zeros = 0
        max_consecutive_zeros = 5

        while True:
            ser.write(COMMAND)
            response = ser.read(130)

            if len(response) < 110:
                print("⚠ Incomplete response")
                time.sleep(0.5)
                continue

            # Parse current
            initial = response[4:6]
            current = int.from_bytes(initial, byteorder='big')
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            unix_timestamp = int(time.time())

            if current > 0:
                # Parse energy
                value = response[106:110]
                energy = int.from_bytes(value, byteorder='big')

                print(f"⚡ Energy: {energy} Wh | Current: {current} mA | {timestamp}")

                # Start Flow session if not active
                if not session_active:
                    booking_id = get_pending_booking()
                    if booking_id is not None:
                        if start_flow_session(booking_id):
                            start_energy = energy

                if session_active:
                    # Record current energy
                    current_energy = energy

                    # Add reading
                    energy_readings.append({
                        "energy": energy,
                        "energyKWh": energy / 1000,
                        "current": current,
                        "timestamp": unix_timestamp,
                        "timestampISO": datetime.now().isoformat()
                    })

                consecutive_zeros = 0

            else:
                print(f"○ No current | {timestamp}")
                ser.write(CLEAR)
                consecutive_zeros += 1

                # End session after consecutive zero readings
                if session_active and consecutive_zeros >= max_consecutive_zeros:
                    print(f"\n⚠ No current for {max_consecutive_zeros} readings")
                    end_flow_session()

            time.sleep(0.5)

    except serial.SerialException as e:
        print(f"\n✗ Serial error: {e}")
        if session_active:
            end_flow_session()

    except KeyboardInterrupt:
        print("\n\n⚠ Interrupted by user")
        if session_active:
            end_flow_session()

    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print("\n✓ Serial connection closed")

if __name__ == "__main__":
    main()
