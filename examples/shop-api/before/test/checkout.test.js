const test = require("node:test");
const assert = require("node:assert");
const { TAX_RATE } = require("../src/checkout");

test("tax rate is 20 percent", () => {
  assert.strictEqual(TAX_RATE, 0.2);
});
