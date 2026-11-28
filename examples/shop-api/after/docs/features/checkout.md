# Checkout

Charges the cart total through the payment provider.

- Currency, time zone, tax rate and the API key come from the environment (see `.env.example`).
- `TAX_RATE` must be a finite, non-negative decimal fraction; for example, `0.08` means 8%.
- `PAYMENT_TIMEOUT_MS` is optional. An unset or blank value uses the 5000 ms default. When set, it must be a positive whole number no greater than 2147483647.
- The charge call times out after `PAYMENT_TIMEOUT_MS` (default 5000) and is never retried.
