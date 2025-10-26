import time
import json
import requests
import threading

def generate_incremental_energy_values(duration_seconds=10, start_value=0, filename="energy_data.json"):
    # Call start session sequentially
    print("Starting session...")
    session_id = None
    try:
        start_response = requests.get("http://localhost:3000/startsession")
        print(f"Start session response status: {start_response.status_code}")
        
        # Try to parse session ID from response
        try:
            session_data = start_response.json()
            session_id = session_data.get('sessionId')
            print(f"Received session ID: {session_id}")
        except:
            print("Could not parse session ID from response")
    except Exception as e:
        print(f"Error in start session request: {e}")
    
    # Generate energy values
    energy = start_value
    energy_values = []
    
    for _ in range(duration_seconds):
        unix_timestamp = int(time.time())
        energy_values.append({
            "energy": energy,
            "timestamp": unix_timestamp
        })
        
        print(f"energy = {energy} kWh, timestamp: {unix_timestamp}")
        
        energy += 1
        time.sleep(1)
        
    data = {
        "TotalKWh": energy,  # Use the final energy value instead of length
        "energyValues": energy_values
    }
    
    with open(filename, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"\nData saved to {filename}")
    
    # Use an Event to signal when the end session is complete
    end_session_completed = threading.Event()
    
    def call_end_session():
        try:
            # Create payload with energy and session ID if available
            payload = {"energy": energy}
            if session_id:
                payload["sessionId"] = session_id
                
            resp = requests.post(
                "http://localhost:3000/endsession", 
                json=payload
            )
            print(f"End session response: {resp.status_code}")
        except Exception as e:
            print(f"Error in end session request: {e}")
        finally:
            # Signal that end session is complete
            end_session_completed.set()
    
    print("Sending end session request...")
    end_thread = threading.Thread(target=call_end_session)
    end_thread.start()
    
    # Wait for end session to complete with timeout
    if end_session_completed.wait(timeout=10):
        print("End session completed successfully")
    else:
        print("End session timed out after 10 seconds")

if __name__ == "__main__":
    print("Generating energy values incrementing by 1 kWh every second...")
    generate_incremental_energy_values(15, 0)
    print("Done!")