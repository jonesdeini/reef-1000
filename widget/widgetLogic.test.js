'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const widgetLogic = require('./widgetLogic');

// Harness smoke test — proves `node --test` is wired up and the module loads. Replace/expand
// once widgetLogic.js has real functions (isStale, formatReading, etc.) to exercise.
describe('widgetLogic', () => {
  it('loads as a module', () => {
    assert.equal(typeof widgetLogic, 'object');
  });
});
