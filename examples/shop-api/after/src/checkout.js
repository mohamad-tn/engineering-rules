const { cartTotal } = require("./cart");

// Total in minor units, rounded once.
function orderTotal(items, taxRate) {
  return Math.round(cartTotal(items) * (1 + taxRate));
}

// The charge is NOT retried: it is not idempotent unless the provider
// accepts an idempotency key. The call has a timeout so it cannot hang.
async function checkout(items, config, fetchImpl = fetch) {
  const response = await fetchImpl("https://api.example.com/charge", {
    method: "POST",
    headers: { Authorization: `Bearer ${config.apiKey}` },
    body: JSON.stringify({
      total: orderTotal(items, config.taxRate),
      currency: config.currency,
      timezone: config.timezone,
    }),
    signal: AbortSignal.timeout(config.timeoutMs),
  });
  return response.json();
}

module.exports = { checkout, orderTotal };
