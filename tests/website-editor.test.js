import test from 'node:test';
import assert from 'node:assert/strict';
import {allowedTabs,can} from '../lib/permissions.js';

test('website editor follows existing content permissions and keeps identity owner-only',()=>{
  for(const role of ['owner','manager'])assert.ok(allowedTabs(role).includes('Website editor'));
  for(const role of ['producer','engineer'])assert.ok(!allowedTabs(role).includes('Website editor'));
  assert.equal(can('owner','identity'),true);
  for(const role of ['manager','producer','engineer'])assert.equal(can(role,'identity'),false);
});
