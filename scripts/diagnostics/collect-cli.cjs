'use strict';
// Explicit CLI entrypoint: do not rely on require.main in a host's Node runtime.
const fs = require('node:fs');
const { collect } = require('./collect.cjs');

try {
  if (!process.argv[2]) throw new Error('Repository root argument is required.');
  const result = collect(process.argv[2]);
  if (!fs.statSync(result.file).isFile()) {
    throw new Error('Collector did not create diagnostics/current.json.');
  }
  console.log('DIAGNOSTICS_COLLECTED ' + (result.changed ? 'updated' : 'unchanged'));
} catch (error) {
  console.error('DIAGNOSTICS_FAILED ' + (error.code || error.name || 'Error') +
    ': ' + (error.message || 'Unknown failure'));
  process.exitCode = 1;
}
