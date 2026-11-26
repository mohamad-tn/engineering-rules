const { cartTotal } = require("./cart");

// Hard-coded business configuration, and a network call with no timeout.
const CURRENCY = "USD";
const TIMEZONE = "Europe/Berlin";
const TAX_RATE = 0.19;

async function checkout(items) {
  const subtotal = cartTotal(items);
  const total = Math.round(subtotal * (1 + TAX_RATE));
  const response = await fetch("https://api.example.com/charge", {
    method: "POST",
    headers: { Authorization: "Bearer example-token" },
    body: JSON.stringify({ total, currency: CURRENCY, timezone: TIMEZONE }),
  });
  return response.json();
}

module.exports = { checkout, TAX_RATE };
