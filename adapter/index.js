const express = require("express");
const { startSession } = require("./subscriber/startSession-flow");
const { endSession } = require("./subscriber/endSession-flow");
const bookingManager = require("./subscriber/bookingManager");

const app = express();
const PORT = 3000;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get("/", (req, res) => {
  res.status(200);
  res.send("ChargeHive Flow Adapter - Server Running");
});

// Booking endpoints
app.post("/booking/create", (req, res) => {
  try {
    const { adapterId, userAddress, startTime, endTime } = req.body;

    if (!adapterId || !userAddress || !startTime || !endTime) {
      return res.status(400).json({
        error: "Missing required fields",
        required: ["adapterId", "userAddress", "startTime", "endTime"]
      });
    }

    const booking = bookingManager.createBooking(adapterId, userAddress, startTime, endTime);

    res.json({
      message: "Booking created successfully",
      booking: booking
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/booking/cancel", (req, res) => {
  try {
    const { bookingId, userAddress } = req.body;

    const booking = bookingManager.cancelBooking(bookingId, userAddress);

    res.json({
      message: "Booking cancelled successfully",
      booking: booking
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.get("/booking/:bookingId", (req, res) => {
  try {
    const bookingId = parseInt(req.params.bookingId);
    const booking = bookingManager.getBooking(bookingId);

    if (!booking) {
      return res.status(404).json({ error: "Booking not found" });
    }

    res.json({ booking: booking });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/booking/adapter/:adapterId", (req, res) => {
  try {
    const adapterId = req.params.adapterId;
    const bookings = bookingManager.getAdapterBookings(adapterId);

    res.json({ bookings: bookings });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/booking/adapter/:adapterId/pending", (req, res) => {
  try {
    const adapterId = req.params.adapterId;
    const booking = bookingManager.getPendingBookingForAdapter(adapterId);

    if (!booking) {
      return res.status(404).json({ message: "No pending booking found" });
    }

    res.json({ booking: booking });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/booking/user/:userAddress", (req, res) => {
  try {
    const userAddress = req.params.userAddress;
    const bookings = bookingManager.getUserBookings(userAddress);

    res.json({ bookings: bookings });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Flow blockchain endpoints
app.get("/startsession", startSession);
app.post("/endsession", endSession);

app.listen(PORT, (error) => {
  if (!error) {
    console.log("==============================================");
    console.log("ChargeHive Flow Adapter Server");
    console.log("==============================================");
    console.log(`Server running on port ${PORT}`);
    console.log("Connected to Flow Testnet");
    console.log("");
    console.log("Booking Endpoints:");
    console.log("  POST /booking/create               - Create a booking");
    console.log("  POST /booking/cancel               - Cancel a booking");
    console.log("  GET  /booking/:bookingId           - Get booking details");
    console.log("  GET  /booking/adapter/:adapterId   - Get all bookings for adapter");
    console.log("  GET  /booking/adapter/:adapterId/pending - Get pending booking");
    console.log("  GET  /booking/user/:userAddress    - Get user's bookings");
    console.log("");
    console.log("Session Endpoints:");
    console.log("  GET  /startsession - Start a charging session");
    console.log("  POST /endsession   - End session and distribute rewards");
    console.log("==============================================");
  } else {
    console.log("Error occurred, server can't start", error);
  }
});
