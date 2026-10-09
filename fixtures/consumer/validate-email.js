const fs = require('fs');

const index = process.argv.indexOf('--file');
if (index === -1) {
  throw new Error('missing --file');
}
const file = process.argv[index + 1];
const html = fs.readFileSync(file, 'utf8');
if (!html.includes('<!doctype html>')) {
  throw new Error('fixture HTML missing doctype');
}
