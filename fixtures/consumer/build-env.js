// Reads its paths from the environment the Action sets for every file.
// Prefers FILE_* (v3) and falls back to EMAIL_TEMPLATE_* (v2).
const render = require('./lib');

const input = process.env.FILE_INPUT || process.env.EMAIL_TEMPLATE_INPUT;
const output = process.env.FILE_OUTPUT || process.env.EMAIL_TEMPLATE_OUTPUT;
render(input, output, 'env');
