import serial
import time
import json
import requests
from datetime import datetime
import threading

# Serial configuration
COM_PORT = '/dev/rfcommO'
BAUD_RATE = 9600

# Commands
COMMAND = b'\xF0'
CLEAR = b'\xF4'

# API endpoints
START_SESSION_URL = "http://localhost:3000/startsession"
END_SESSION_URL = "http://localhost:3000/endsession"

# Global variables
session_active = False
session_id = None
energy_values = []
start_energy = 0
current_energy = 0

def start_session():
    """Start a new session by calling the API endpoint"""
    global session_active, session_id
    
    try:
        response = requests.get(START_SESSION_URL)
        print(f"Start session response: {response.status_code}")
        
        # Try to parse session ID
        try:
            session_data = response.json()
            session_id = session_data.get('sessionId')
            print(f"Received session ID: {session_id}")
        except:
            print("Could not parse session ID from response")
        
        session_active = True
    except Exception as e:
        print(f"Error starting session: {e}")

def end_session():
    """End the current session and save data to file"""
    global session_active, session_id, energy_values, current_energy
    
    if not session_active:
        return
    
    # Create payload
    payload = {"energy": current_energy}
    if session_id:
        payload["sessionId"] = session_id
    
    # Generate filename with timestamp
    timestamp = int(time.time())
    filename = f"energy_data_{timestamp}.json"
    
    # Prepare data for JSON file
    data = {
        "TotalKWh": current_energy,
        "energyValues": energy_values
    }
    
    # Save to file
    with open(filename, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"Data saved to {filename}")
    
    # Create event to signal completion
    end_session_completed = threading.Event()
    
    def call_end_session():
        try:
            resp = requests.post(END_SESSION_URL, json=payload)
            print(f"End session response: {resp.status_code}")
        except Exception as e:
            print(f"Error in end session request: {e}")
        finally:
            end_session_completed.set()
    
    # Send end session request and wait for completion
    print("Sending end session request...")
    end_thread = threading.Thread(target=call_end_session)
    end_thread.start()
    
    # Wait for end session to complete with timeout
    if end_session_completed.wait(timeout=10):
        print("End session completed successfully")
    else:
        print("End session timed out after 10 seconds")
    
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
            print(f"Energy: {energy} ... {timestamp}")
            
            # Start a new session if not already active
            if not session_active:
                start_session()
                start_energy = energy
            
            # Record current energy
            current_energy = energy
            
            # Add to energy values
            energy_values.append({
                "energy": energy,
                "timestamp": unix_timestamp
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