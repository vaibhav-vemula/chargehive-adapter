import serial 
import time
from datetime import datetime 
import json

COM_PORT = '/dev/rfcommO'
BAUD_RATE = 9600

COMMAND = b'\xF0'
CLEAR = b'\xF4'

write = 0
energy = 0

try:
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
    print(f"Connected to (COM_PORT) at (BAUD_RATE) baud.")
    
    time.sleep(2)
    
    data = {
        "KwhValues":[],
        "TotalKWH":0
    }
    
    time.sleep(1)
    while True:
        ser.write(COMMAND)
        response = ser.read(130)
        initial = response[4:6]
        current = int.from _bytes(initial, byteorder='big')
        
        if current > 0:
            write = 1
            value = response [106:110]
            energy = int.from_bytes(value, byteorder= 'big')
            timestamp = datetime.now().strftime ('%Y-%m-%d %H:%M:%S')
            
            new_entry = {
                "kwh": energy,
                "timestamp": timestamp
                }
            print(f"Energy: (energy) ... (timestamp)")
            data["kwhValues"].append (new_entry)
        else:
            if write == 1:
                data ["TotalKWH"] = energy
                write = 0
                ser.write(CLEAR)
                with open("log.json", "w") as json_file:
                    json.dump(data, json_file, indent=4)
                
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                print(f"Energy: (energy] ... (timestamp]")
                data ["kwhValues"] = []
            
        time.sleep(0.5)

except serial.SerialException as e:
    print(f"Serial error: {e}")

finally:
    if 'ser' in locals() and ser.is_open:
        ser.close()
        print ("Connection closed.")