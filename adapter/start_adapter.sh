#!/bin/bash

# ChargeHive Adapter Startup Script

echo "======================================"
echo "  ChargeHive Adapter Manager"
echo "======================================"
echo ""

# Set adapter ID (change this for your adapter)
export ADAPTER_ID="${ADAPTER_ID:-RPI-SF-001}"

echo "Configuration:"
echo "  Adapter ID: $ADAPTER_ID"
echo "  Serial Port: /dev/rfcomm0"
echo ""

# Check if Flow scripts are available
FLOW_DIR="$(dirname "$0")/../contracts/flow-cadence"
if [ ! -d "$FLOW_DIR" ]; then
    echo "ERROR: Flow scripts directory not found at $FLOW_DIR"
    exit 1
fi

echo "  Flow Scripts: $FLOW_DIR"
echo ""

# Check if Python dependencies are installed
if ! python3 -c "import serial" 2>/dev/null; then
    echo "WARNING: pyserial not installed"
    echo "Installing pyserial..."
    pip3 install pyserial
fi

# Start the session manager
echo "Starting session manager..."
echo ""
cd "$(dirname "$0")/publisher"
python3 flow_session_manager.py
