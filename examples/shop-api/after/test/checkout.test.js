const test = require("node:test");
const assert = require("node:assert");
const { orderTotal } = require("../src/checkout");
const { loadConfig } = require("../src/config");

const validEnv = {
  PAYMENT_API_KEY: "test-key",
  CURRENCY: "USD",
  TIMEZONE: "UTC",
  TAX_RATE: "0.2",
};

test("order total applies the configured tax rate once", () => {
  assert.strictEqual(orderTotal([{ priceMinor: 1000, quantity: 1 }], 0.2), 1200);
});

test("missing configuration is an error, not a silent default", () => {
  assert.throws(() => loadConfig({}), /Missing configuration/);
  assert.throws(
    () => loadConfig({ ...validEnv, TAX_RATE: "" }),
    /Missing configuration: TAX_RATE/,
  );
});

test("valid tax rates include zero and are parsed as numbers", () => {
  assert.strictEqual(loadConfig({ ...validEnv, TAX_RATE: "0" }).taxRate, 0);
  assert.strictEqual(loadConfig(validEnv).taxRate, 0.2);
});

test("invalid tax rates are rejected with the setting name", () => {
  for (const value of [" ", "not-a-number", "NaN", "Infinity", "-0.01"]) {
    assert.throws(
      () => loadConfig({ ...validEnv, TAX_RATE: value }),
      /TAX_RATE must be a finite, non-negative number/,
    );
  }
});

test("missing or blank payment timeout uses the documented default", () => {
  assert.strictEqual(loadConfig(validEnv).timeoutMs, 5000);
  assert.strictEqual(loadConfig({ ...validEnv, PAYMENT_TIMEOUT_MS: "" }).timeoutMs, 5000);
  assert.strictEqual(loadConfig({ ...validEnv, PAYMENT_TIMEOUT_MS: "  " }).timeoutMs, 5000);
});

test("valid payment timeouts are positive integers within the supported range", () => {
  assert.strictEqual(loadConfig({ ...validEnv, PAYMENT_TIMEOUT_MS: "2500" }).timeoutMs, 2500);
  assert.strictEqual(
    loadConfig({ ...validEnv, PAYMENT_TIMEOUT_MS: "2147483647" }).timeoutMs,
    2147483647,
  );
});

test("invalid payment timeouts are rejected with the setting name", () => {
  for (const value of ["not-a-number", "Infinity", "0", "-1", "1.5", "2147483648"]) {
    assert.throws(
      () => loadConfig({ ...validEnv, PAYMENT_TIMEOUT_MS: value }),
      /PAYMENT_TIMEOUT_MS must be a positive integer/,
    );
  }
});
