const test = require("node:test");
const assert = require("node:assert");
const { orderTotal } = require("../src/checkout");
const { loadConfig } = require("../src/config");

test("order total applies the configured tax rate once", () => {
  assert.strictEqual(orderTotal([{ priceMinor: 1000, quantity: 1 }], 0.2), 1200);
});

test("missing configuration is an error, not a silent default", () => {
  assert.throws(() => loadConfig({}), /Missing configuration/);
});
