// Reads its paths from the environment the Action sets for every template.
const render = require('./lib');

render(process.env.EMAIL_TEMPLATE_INPUT, process.env.EMAIL_TEMPLATE_OUTPUT, 'env');
