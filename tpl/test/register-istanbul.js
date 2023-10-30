/**
 * This file is useful for mocha tests.
 * To use, run mocha --require coffee-coverage/register-istanbul
 */
var coffeeCoverage = require('iced-coffee-coverage');
var coverageVar = coffeeCoverage.findIstanbulVariable();
var writeOnExit = coverageVar == null ? true : null;

coffeeCoverage.register({
    instrumentor: 'istanbul',
    basePath: process.cwd(),
    exclude: ['/test', '/node_modules', '/.git', '**/*.com.coffee', '/code_bubble', '/htdocs', '/gen', '/src/endpoint', '/src/util/endpoint_channel.coffee'],
    coverageVar: coverageVar,
    writeOnExit: writeOnExit ? ((_ref = process.env.COFFEECOV_OUT) != null ? _ref : 'coverage/coverage-coffee.json') : null,
    initAll: (_ref = process.env.COFFEECOV_INIT_ALL) != null ? (_ref === 'true') : true
});