// Usage: node build-positional.js <input> <output>
const render = require('./lib');

const [input, output] = process.argv.slice(2);
render(input, output, 'positional');
