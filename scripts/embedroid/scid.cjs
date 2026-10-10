const crypto = require('node:crypto');

// scrcpy parses scid with Java Integer.parseInt(hex, 16): a non-negative
// 31-bit integer. Keep eight hex digits so the ADB socket name agrees with
// the server's %08x formatting, including identifiers with leading zeroes.
function generateScid(randomBytes = crypto.randomBytes) {
  const bytes = randomBytes(4);
  bytes[0] &= 0x7f;
  return bytes.toString('hex');
}

module.exports = { generateScid };
