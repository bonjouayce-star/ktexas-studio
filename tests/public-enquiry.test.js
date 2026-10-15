import test from 'node:test';
import assert from 'node:assert/strict';
import {contactLinks,packageSelection} from '../lib/public-enquiry.js';

test('public phone actions normalize Kenyan numbers and reject unusable contact values',()=>{
  const expected={call:'tel:+254790693962',whatsapp:'https://wa.me/254790693962'};
  for(const phone of ['0790693962','+254 790 693 962','254790693962'])assert.deepEqual(contactLinks(phone),expected);
  for(const phone of ['',null,'javascript:alert(1)','123','0790693962?text=bad'])assert.equal(contactLinks(phone),null);
});

test('packages select the advertised service after renaming and safely fall back if removed',()=>{
  const fallback='Something else — let’s talk';
  assert.equal(packageSelection({service:'Recording & music production'},['Audio recording & music production',fallback]).service,'Audio recording & music production');
  assert.equal(packageSelection({service:'Film & video production'},['Videography & event coverage',fallback]).service,'Videography & event coverage');
  assert.equal(packageSelection({service:'Photography'},['Photography',fallback]).service,'Photography');
  assert.equal(packageSelection({service:'Old service'},['Photography',fallback]).service,fallback);
});
