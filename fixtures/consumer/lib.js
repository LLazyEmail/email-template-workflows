const fs = require('fs');
const path = require('path');

// Shared by the build-* fixture scripts that take their arguments in a style
// other than --input/--output.
module.exports = function render(input, output, title) {
  if (!input || !output) {
    throw new Error('missing input or output');
  }
  if (!fs.existsSync(input)) {
    throw new Error('source not found: ' + input);
  }
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(
    output,
    '<!doctype html><title>' + title + '</title><p>' + fs.readFileSync(input, 'utf8') + '</p>\n'
  );
};
