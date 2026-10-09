const fs = require('fs');
const path = require('path');

function arg(name) {
  const index = process.argv.indexOf(name);
  if (index === -1 || !process.argv[index + 1]) {
    throw new Error('missing ' + name);
  }
  return process.argv[index + 1];
}

const input = arg('--input');
const output = arg('--output');
const titleIndex = process.argv.indexOf('--title');
const title = titleIndex === -1 ? 'Fixture' : process.argv[titleIndex + 1];

if (!fs.existsSync(input)) {
  throw new Error('source not found: ' + input);
}

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(
  output,
  '<!doctype html><title>' + title + '</title><p>' + fs.readFileSync(input, 'utf8') + '</p>\n'
);
