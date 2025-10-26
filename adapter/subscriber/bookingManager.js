const fs = require("fs");
const path = require("path");

const BOOKINGS_FILE = path.join(__dirname, "bookings.json");

// Initialize bookings file if it doesn't exist
function initBookingsFile() {
  if (!fs.existsSync(BOOKINGS_FILE)) {
    const initialData = {
      bookings: [],
      nextBookingId: 0
    };
    fs.writeFileSync(BOOKINGS_FILE, JSON.stringify(initialData, null, 2));
  }
}

// Read bookings from file
function readBookings() {
  initBookingsFile();
  const data = fs.readFileSync(BOOKINGS_FILE, "utf8");
  return JSON.parse(data);
}

// Write bookings to file
function writeBookings(data) {
  fs.writeFileSync(BOOKINGS_FILE, JSON.stringify(data, null, 2));
}

// Create a new booking
function createBooking(adapterId, userAddress, startTime, endTime) {
  const data = readBookings();

  const booking = {
    bookingId: data.nextBookingId,
    adapterId: adapterId,
    userAddress: userAddress,
    startTime: startTime,           // When user plans to arrive
    endTime: endTime,               // When user plans to leave
    actualStartTime: null,          // When session actually started
    actualEndTime: null,            // When session actually ended
    status: "pending",              // pending, active, completed, cancelled
    sessionId: null,
    createdAt: Date.now()
  };

  data.bookings.push(booking);
  data.nextBookingId++;

  writeBookings(data);

  return booking;
}

// Get booking by ID
function getBooking(bookingId) {
  const data = readBookings();
  return data.bookings.find(b => b.bookingId === bookingId);
}

// Get all bookings for an adapter
function getAdapterBookings(adapterId) {
  const data = readBookings();
  return data.bookings.filter(b => b.adapterId === adapterId);
}

// Get pending booking for an adapter (most recent)
function getPendingBookingForAdapter(adapterId) {
  const bookings = getAdapterBookings(adapterId);
  const pendingBookings = bookings.filter(b => b.status === "pending");

  // Return most recent pending booking
  if (pendingBookings.length > 0) {
    return pendingBookings[pendingBookings.length - 1];
  }

  return null;
}

// Get active booking for an adapter
function getActiveBookingForAdapter(adapterId) {
  const bookings = getAdapterBookings(adapterId);
  return bookings.find(b => b.status === "active") || null;
}

// Get all bookings for a user
function getUserBookings(userAddress) {
  const data = readBookings();
  return data.bookings.filter(b => b.userAddress === userAddress);
}

// Update booking status
function updateBookingStatus(bookingId, status, sessionId = null) {
  const data = readBookings();
  const booking = data.bookings.find(b => b.bookingId === bookingId);

  if (!booking) {
    throw new Error(`Booking ${bookingId} not found`);
  }

  booking.status = status;
  if (sessionId) {
    booking.sessionId = sessionId;
  }

  writeBookings(data);

  return booking;
}

// Activate booking (when session starts)
function activateBooking(bookingId, sessionId) {
  const data = readBookings();
  const booking = data.bookings.find(b => b.bookingId === bookingId);

  if (!booking) {
    throw new Error(`Booking ${bookingId} not found`);
  }

  booking.status = "active";
  booking.sessionId = sessionId;
  booking.actualStartTime = Date.now();

  writeBookings(data);

  return booking;
}

// Complete booking (when session ends)
function completeBooking(bookingId) {
  const data = readBookings();
  const booking = data.bookings.find(b => b.bookingId === bookingId);

  if (!booking) {
    throw new Error(`Booking ${bookingId} not found`);
  }

  booking.status = "completed";
  booking.actualEndTime = Date.now();

  writeBookings(data);

  return booking;
}

// Cancel booking
function cancelBooking(bookingId, userAddress) {
  const booking = getBooking(bookingId);

  if (!booking) {
    throw new Error(`Booking ${bookingId} not found`);
  }

  if (booking.userAddress !== userAddress) {
    throw new Error("Only booking owner can cancel");
  }

  if (booking.status !== "pending") {
    throw new Error("Can only cancel pending bookings");
  }

  return updateBookingStatus(bookingId, "cancelled");
}

// Find booking by session ID
function findBookingBySession(sessionId) {
  const data = readBookings();
  return data.bookings.find(b => b.sessionId === sessionId) || null;
}

module.exports = {
  createBooking,
  getBooking,
  getAdapterBookings,
  getPendingBookingForAdapter,
  getActiveBookingForAdapter,
  getUserBookings,
  activateBooking,
  completeBooking,
  cancelBooking,
  findBookingBySession
};
