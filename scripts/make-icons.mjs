// Generates PNG app icons without any dependencies (node's zlib + a tiny PNG
// writer). Run: node scripts/make-icons.mjs
import { deflateSync } from 'node:zlib';
import { writeFileSync, mkdirSync } from 'node:fs';

function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function png(width, height, rgba) {
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (width * 4 + 1)] = 0; // filter: none
    rgba.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// Same picture as icons/icon.svg, rasterised by hand: dark rounded square with
// gradient bars (a little spectrogram).
function draw(size) {
  const px = Buffer.alloc(size * size * 4);
  const s = size / 512;
  const bars = [[96, 256, 40, 120], [156, 176, 40, 200], [216, 96, 40, 280], [276, 136, 40, 240], [336, 216, 40, 160], [396, 296, 20, 80]];
  const radius = 112 * s;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const i = (y * size + x) * 4;
      // rounded-rect mask
      const dx = Math.max(radius - x, x - (size - 1 - radius), 0);
      const dy = Math.max(radius - y, y - (size - 1 - radius), 0);
      const inside = dx * dx + dy * dy <= radius * radius;
      if (!inside) { px[i + 3] = 0; continue; }
      let r = 11, g = 11, b = 16;
      for (const [bx, by, bw, bh] of bars) {
        if (x >= bx * s && x < (bx + bw) * s && y >= by * s && y < (by + bh) * s) {
          const t = (x + y) / (2 * size); // diagonal gradient
          r = Math.round(255 + (122 - 255) * t);
          g = Math.round(122 + (31 - 122) * t);
          b = Math.round(26 + (162 - 26) * t);
        }
      }
      if (y >= 400 * s && y < 416 * s && x >= 96 * s && x < 416 * s) { r = 150; g = 150; b = 158; }
      px[i] = r; px[i + 1] = g; px[i + 2] = b; px[i + 3] = 255;
    }
  }
  return png(size, size, px);
}

mkdirSync('icons', { recursive: true });
for (const size of [180, 192, 512]) {
  writeFileSync(`icons/icon-${size}.png`, draw(size));
  console.log(`wrote icons/icon-${size}.png`);
}
