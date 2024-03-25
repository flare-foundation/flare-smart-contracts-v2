module.exports = {
  skipFiles: [
    'mock/',
    'ftso/merkle/',
    'ftso/interface/',
    'governance/interface/',
    'protocol/interface/',
    'protocol/merkle/',
    'userInterfaces/',


],
  istanbulReporter: ['html', 'json', 'cobertura', 'text-summary', 'lcov']
};