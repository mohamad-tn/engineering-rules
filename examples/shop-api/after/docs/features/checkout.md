# Checkout

Charges the cart total through the payment provider.

- Currency, time zone, tax rate and the API key come from the environment (see `.env.example`).
- The charge call times out after `PAYMENT_TIMEOUT_MS` (default 5000) and is never retried.
