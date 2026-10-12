// Usage: node build-equals.js --src=<input> --dest=<output>
const render = require('./lib');

function value(name) {
  const hit = process.argv.find((a) => a.startsWith(name + '='));
  return hit ? hit.slice(name.length + 1) : undefined;
}

render(value('--src'), value('--dest'), 'equals');
