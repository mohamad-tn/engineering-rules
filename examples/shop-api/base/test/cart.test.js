const test = require("node:test");
const assert = require("node:assert");
const { cartTotal } = require("../src/cart");

test("cart total sums price times quantity", () => {
  assert.strictEqual(cartTotal([{ priceMinor: 250, quantity: 2 }, { priceMinor: 100, quantity: 1 }]), 600);
});
