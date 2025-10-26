import serial
import time
from datetime import datetime

COM_PORT = '/dev/rfcommO'
BAUD_RATE = 9600

COMMAND = b'\xF0'
CLEAR = b'\xF4'

try:
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
    print(f"Connected to (COM_PORT) at (BAUD_RATE) baud.")
    time.sleep(2)
    ser.write(CLEAR)
    while True:
        ser.write(COMMAND)
        response = ser.read(130)
        initial = response [4:6]
        current = int.from_bytes(initial,byteorder='big')
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        if current > 0:
            value = response [106:110]
            energy = int. from_bytes(value, byteorder='big')
            print(f"Energy: (energy] .... (timestamp]")
        else:
            ser.write(CLEAR)
        
        time.sleep(0.5)

except serial.SerialException as e:
    print(f"Serial error: {e}")

finally:
    if 'ser' in locals() and ser.is_open:
        ser.close()
        print ("Connection closed.")