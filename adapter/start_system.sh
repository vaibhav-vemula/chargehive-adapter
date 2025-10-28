#!/bin/bash

# ChargeHive Complete System Startup Script

echo "======================================"
echo "  ChargeHive Adapter System"
echo "======================================"
echo ""

# Set adapter ID
export ADAPTER_ID="${ADAPTER_ID:-RPI-SF-001}"
export API_BASE_URL="${API_BASE_URL:-http://localhost:3000}"

echo "Configuration:"
echo "  Adapter ID: $ADAPTER_ID"
echo "  API Server: $API_BASE_URL"
echo "  Serial Port: /dev/rfcomm0"
echo ""

# Check if dependencies are installed
echo "Checking dependencies..."

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js is not installed"
    exit 1
fi

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed"
    exit 1
fi

echo "✓ Node.js $(node --version)"
echo "✓ Python $(python3 --version)"
echo ""

# Install Node.js dependencies if needed
cd "$(dirname "$0")/subscriber"
if [ ! -d "node_modules" ]; then
    echo "Installing Node.js dependencies..."
    npm install
fi

# Install Python dependencies if needed
if ! python3 -c "import serial" 2>/dev/null; then
    echo "Installing Python dependencies..."
    pip3 install pyserial requests
fi

if ! python3 -c "import requests" 2>/dev/null; then
    pip3 install requests
fi

echo "✓ All dependencies installed"
echo ""

# Start API server in background
echo "Starting API server..."
cd "$(dirname "$0")/subscriber"
node server.js &
API_PID=$!

# Wait for API server to be ready
echo "Waiting for API server to start..."
sleep 3

# Check if API server is running
if ! curl -s http://localhost:3000/health > /dev/null; then
    echo "ERROR: API server failed to start"
    kill $API_PID 2>/dev/null
    exit 1
fi

echo "✓ API server running (PID: $API_PID)"
echo ""

# Start Python energy monitor
echo "Starting energy monitor..."
echo ""
cd "$(dirname "$0")/publisher"
python3 flow_session_manager_http.py

# Cleanup on exit
echo ""
echo "Shutting down..."
kill $API_PID 2>/dev/null
echo "✓ System stopped"
