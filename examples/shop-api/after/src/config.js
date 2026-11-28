// Business configuration is data: it comes from the environment, never from code.
const DEFAULT_PAYMENT_TIMEOUT_MS = 5000;
const MAX_PAYMENT_TIMEOUT_MS = 2_147_483_647;

function loadConfig(env = process.env) {
  const required = ["PAYMENT_API_KEY", "CURRENCY", "TIMEZONE", "TAX_RATE"];
  const missing = required.filter((name) => !env[name]);
  if (missing.length > 0) {
    throw new Error(`Missing configuration: ${missing.join(", ")}`);
  }

  const rawTaxRate = String(env.TAX_RATE).trim();
  const taxRate = Number(rawTaxRate);
  if (rawTaxRate === "" || !Number.isFinite(taxRate) || taxRate < 0) {
    throw new Error("Invalid configuration: TAX_RATE must be a finite, non-negative number");
  }

  const rawTimeout = String(env.PAYMENT_TIMEOUT_MS ?? "").trim();
  const timeoutMs = rawTimeout === "" ? DEFAULT_PAYMENT_TIMEOUT_MS : Number(rawTimeout);
  if (
    !Number.isSafeInteger(timeoutMs) ||
    timeoutMs <= 0 ||
    timeoutMs > MAX_PAYMENT_TIMEOUT_MS
  ) {
    throw new Error(
      `Invalid configuration: PAYMENT_TIMEOUT_MS must be a positive integer no greater than ${MAX_PAYMENT_TIMEOUT_MS}`,
    );
  }

  return {
    apiKey: env.PAYMENT_API_KEY,
    currency: env.CURRENCY,
    timezone: env.TIMEZONE,
    taxRate,
    timeoutMs,
  };
}

module.exports = { loadConfig };
