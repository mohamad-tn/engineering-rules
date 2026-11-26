// Business configuration is data: it comes from the environment, never from code.
function loadConfig(env = process.env) {
  const required = ["PAYMENT_API_KEY", "CURRENCY", "TIMEZONE", "TAX_RATE"];
  const missing = required.filter((name) => !env[name]);
  if (missing.length > 0) {
    throw new Error(`Missing configuration: ${missing.join(", ")}`);
  }
  return {
    apiKey: env.PAYMENT_API_KEY,
    currency: env.CURRENCY,
    timezone: env.TIMEZONE,
    taxRate: Number(env.TAX_RATE),
    timeoutMs: Number(env.PAYMENT_TIMEOUT_MS || 5000),
  };
}

module.exports = { loadConfig };
