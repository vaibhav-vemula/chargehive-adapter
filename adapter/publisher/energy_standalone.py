import serial
import time
import json
from datetime import datetime
import uuid

# Serial configuration
COM_PORT = '/dev/rfcomm0'
BAUD_RATE = 9600

# Commands
COMMAND = b'\xF0'
CLEAR = b'\xF4'

# Global variables
session_active = False
session_id = None
energy_values = []
start_energy = 0
current_energy = 0

def start_session():
    """Start a new session with local session ID generation"""
    global session_active, session_id, start_energy, energy_values

    # Generate a unique session ID
    session_id = str(uuid.uuid4())
    session_active = True
    energy_values = []

    print(f"Session started with ID: {session_id}")

def end_session():
    """End the current session and save all data to file"""
    global session_active, session_id, energy_values, current_energy, start_energy

    if not session_active:
        return

    # Calculate total energy consumed during session
    if start_energy > 0 and current_energy >= start_energy:
        energy_consumed = current_energy - start_energy
    else:
        energy_consumed = current_energy
    
    print(f"Total energy consumed: {energy_consumed} Wh")
    print(f"Total readings: {len(energy_values)}")

    # Reset session state
    session_active = False
    session_id = None
    energy_values = []
    start_energy = 0
    current_energy = 0

try:
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
    print(f"Connected to {COM_PORT} at {BAUD_RATE} baud.")
    time.sleep(2)
    ser.write(CLEAR)

    consecutive_zeros = 0
    max_consecutive_zeros = 5  # Number of consecutive zero readings before ending session

    while True:
        ser.write(COMMAND)
        response = ser.read(130)

        if len(response) < 110:
            print("Incomplete response received")
            time.sleep(0.5)
            continue

        initial = response[4:6]
        current = int.from_bytes(initial, byteorder='big')
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        unix_timestamp = int(time.time())

        if current > 0:
            value = response[106:110]
            energy = int.from_bytes(value, byteorder='big')
            print(f"Energy: {energy} Wh ... {timestamp}")

            # Start a new session if not already active
            if not session_active:
                start_session()
                start_energy = energy

            # Record current energy
            current_energy = energy

            # Add to energy values with more detailed information
            energy_values.append({
                "energy": energy,
                "energyKWh": energy / 1000,
                "timestamp": unix_timestamp,
                "timestampISO": datetime.now().isoformat(),
                "current": current
            })

            consecutive_zeros = 0
        else:
            print(f"No current detected ... {timestamp}")
            ser.write(CLEAR)
            consecutive_zeros += 1

            # End session after several consecutive zero readings
            if session_active and consecutive_zeros >= max_consecutive_zeros:
                print(f"No current detected for {max_consecutive_zeros} consecutive readings. Ending session.")
                end_session()

        time.sleep(0.5)

except serial.SerialException as e:
    print(f"Serial error: {e}")
    # End session if active when an error occurs
    if session_active:
        end_session()

except KeyboardInterrupt:
    print("Program interrupted by user")
    # End session if active when user interrupts
    if session_active:
        end_session()

finally:
    if 'ser' in locals() and ser.is_open:
        ser.close()
        print("Connection closed.")
