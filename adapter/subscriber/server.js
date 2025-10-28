import express from 'express';
import dotenv from 'dotenv';
import * as flowService from './flowService.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const ADAPTER_ID = process.env.ADAPTER_ID || 'RPI-SF-001';

app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    adapter: ADAPTER_ID,
    network: process.env.FLOW_NETWORK,
    timestamp: new Date().toISOString()
  });
});

// Get pending booking
app.get('/api/booking/pending', async (req, res) => {
  try {
    const adapterId = req.query.adapterId || ADAPTER_ID;
    console.log(`📋 Getting pending booking for adapter: ${adapterId}`);

    const booking = await flowService.getPendingBooking(adapterId);

    if (booking) {
      res.json({
        success: true,
        booking: {
          bookingId: booking.bookingId,
          adapterId: booking.adapterId,
          userAddress: booking.userAddress,
          scheduledTime: booking.scheduledTime,
          status: booking.status,
          sessionId: booking.sessionId,
          createdAt: booking.createdAt
        }
      });
    } else {
      res.json({
        success: false,
        message: 'No pending booking found'
      });
    }
  } catch (error) {
    console.error('Error getting pending booking:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Start session
app.post('/api/session/start', async (req, res) => {
  try {
    const { bookingId } = req.body;

    if (bookingId === undefined || bookingId === null) {
      return res.status(400).json({
        success: false,
        error: 'bookingId is required'
      });
    }

    console.log(`🚀 Starting session for booking: ${bookingId}`);

    const result = await flowService.startSession(bookingId);

    res.json({
      success: true,
      sessionId: result.sessionId,
      transactionId: result.transactionId,
      status: result.status
    });
  } catch (error) {
    console.error('Error starting session:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// End session
app.post('/api/session/end', async (req, res) => {
  try {
    const { sessionId, energyUsed } = req.body;

    if (!sessionId) {
      return res.status(400).json({
        success: false,
        error: 'sessionId is required'
      });
    }

    if (energyUsed === undefined || energyUsed === null) {
      return res.status(400).json({
        success: false,
        error: 'energyUsed is required'
      });
    }

    // Convert Wh to kWh for blockchain (Flow expects kWh)
    const energyWh = parseFloat(energyUsed);
    const energyKwh = energyWh / 1000.0;

    console.log(`🏁 Ending session: ${sessionId}`);
    console.log(`   Energy: ${energyWh} Wh (${energyKwh.toFixed(3)} kWh)`);

    const result = await flowService.endSession(sessionId, energyKwh);

    res.json({
      success: true,
      transactionId: result.transactionId,
      status: result.status,
      rewards: {
        provider: result.sessionData?.providerReward || 0,
        user: result.sessionData?.userReward || 0,
        usdCost: result.sessionData?.usdCost || 0
      }
    });
  } catch (error) {
    console.error('Error ending session:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get adapter info
app.get('/api/adapter/:adapterId', async (req, res) => {
  try {
    const { adapterId } = req.params;
    console.log(`📡 Getting adapter info: ${adapterId}`);

    const adapter = await flowService.getAdapter(adapterId);

    if (adapter) {
      res.json({
        success: true,
        adapter: {
          adapterId: adapter.adapterId,
          ownerAddress: adapter.ownerAddress,
          location: adapter.location,
          details: adapter.details,
          pricePerKwh: adapter.pricePerKwh,
          authorized: adapter.authorized,
          createdAt: adapter.createdAt
        }
      });
    } else {
      res.status(404).json({
        success: false,
        message: 'Adapter not found'
      });
    }
  } catch (error) {
    console.error('Error getting adapter:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error'
  });
});

app.listen(PORT, () => {
  console.log('='.repeat(60));
  console.log('ChargeHive Adapter API Server');
  console.log('='.repeat(60));
  console.log(`Server: http://localhost:${PORT}`);
  console.log(`Adapter ID: ${ADAPTER_ID}`);
  console.log(`Network: ${process.env.FLOW_NETWORK}`);
  console.log(`Flow Address: ${process.env.FLOW_ADDRESS}`);
  console.log('='.repeat(60));
  console.log('');
  console.log('API Endpoints:');
  console.log(`  GET  /health`);
  console.log(`  GET  /api/booking/pending?adapterId=${ADAPTER_ID}`);
  console.log(`  POST /api/session/start`);
  console.log(`  POST /api/session/end`);
  console.log(`  GET  /api/adapter/:adapterId`);
  console.log('');
  console.log('Ready to accept requests...');
  console.log('='.repeat(60));
});
