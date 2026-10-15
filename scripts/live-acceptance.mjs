import {loadEnv} from 'vite';
import {createClient} from '@supabase/supabase-js';
import {randomUUID,randomBytes} from 'node:crypto';
import assert from 'node:assert/strict';
const env={...loadEnv('production',process.cwd(),''),...process.env};
if(env.RESEND_API_KEY&&env.EMAIL_FROM)throw new Error('Use a staging environment for this check when live email delivery is configured.');
const admin=createClient(env.SUPABASE_URL,env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
const tag=randomUUID(),users=[],projects=[],paths=[],checks=[];let booking;
const ok=result=>{if(result.error)throw result.error;return result.data};
const check=(name)=>{checks.push(name);console.log('PASS · '+name)};
async function api(path,body,token){const r=await fetch(env.SITE_URL+path,{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:JSON.stringify(body),signal:AbortSignal.timeout(20000)});return {status:r.status,data:await r.json()}}
try{
 for(let i=0;i<2;i++){
  const email=`launch-check-${tag}-${i}@example.invalid`,password=randomBytes(32).toString('base64url');
  const user=ok(await admin.auth.admin.createUser({email,password,email_confirm:true})).user;users.push({id:user.id});
  const client=createClient(env.VITE_SUPABASE_URL,env.VITE_SUPABASE_PUBLISHABLE_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
  users[i].client=client;users[i].token=ok(await client.auth.signInWithPassword({email,password})).session.access_token;
  const project=ok(await admin.from('client_projects').insert({client_user_id:user.id,client_name:'Temporary launch check',client_email:email,title:'Temporary launch check '+tag,service:'Recording & music production'}).select().single());projects.push(project);
 }
 check('Two temporary client accounts sign in');
 for(let i=0;i<2;i++){
  const rows=ok(await users[i].client.from('client_projects').select('id').in('id',projects.map(p=>p.id)));assert.deepEqual(rows.map(p=>p.id),[projects[i].id]);
  const loaded=await api('/api/portal',{action:'load'},users[i].token);assert.equal(loaded.status,200);assert.deepEqual(loaded.data.projects.map(p=>p.id),[projects[i].id]);
 }
 check('Database and hosted portal isolate separate clients');
 const forbidden=await api('/api/portal',{action:'feedback',project_id:projects[1].id,body:'Temporary test'},users[0].token);assert.equal(forbidden.status,404);
 const feedback=await api('/api/portal',{action:'feedback',project_id:projects[0].id,body:'Temporary acceptance check'},users[0].token);assert.equal(feedback.status,201);
 check('Feedback allowed only on the client’s own project');
 const path=projects[0].id+'/launch-check-'+tag+'.txt';paths.push(path);
 ok(await admin.storage.from('studio-deliverables').upload(path,Buffer.from('Private acceptance test'),{contentType:'text/plain'}));
 const file=ok(await admin.from('client_files').insert({project_id:projects[0].id,name:'Acceptance check.txt',kind:'Document',storage_path:path}).select().single());
 const download=await api('/api/portal',{action:'file',project_id:projects[0].id,file_id:file.id},users[0].token);assert.equal(download.status,200);assert.equal(await (await fetch(download.data.url)).text(),'Private acceptance test');
 const denied=await api('/api/portal',{action:'file',project_id:projects[0].id,file_id:file.id},users[1].token);assert.equal(denied.status,404);
 const storageDenied=await users[1].client.storage.from('studio-deliverables').createSignedUrl(path,60);assert.ok(storageDenied.error);
 check('Private file delivery works and another client cannot download it');
 const staff=await api('/api/staff',{action:'identity'},users[0].token);assert.equal(staff.status,403);check('Client cannot access staff functions');
 const day=new Date(Date.now()+7*86400000);if(day.getUTCDay()===0)day.setUTCDate(day.getUTCDate()+1);const date=day.toISOString().slice(0,10);const availability=await api('/api/availability',{date,duration:2});assert.equal(availability.status,200);assert.ok(availability.data.slots.length);
 const email=`launch-booking-${tag}@example.invalid`;
 const requested=await api('/api/bookings',{name:'Temporary launch check '+tag,email,service:'Recording & music production',date,time:availability.data.slots[0],duration:2,consent:true});
 assert.equal(requested.status,201);booking=ok(await admin.from('bookings').select('*').eq('email',email).single());assert.equal(booking.status,'pending');check('Public booking saves as an unconfirmed enquiry');
 ok(await admin.from('bookings').update({status:'confirmed'}).eq('id',booking.id));const reservation=ok(await admin.from('studio_reservations').select('id').eq('booking_id',booking.id));assert.equal(reservation.length,1);check('Confirmation reserves the session interval');
 console.log('Live acceptance checks passed: '+checks.length);
}finally{
 if(paths.length)ok(await admin.storage.from('studio-deliverables').remove(paths));
 for(const p of projects)ok(await admin.from('client_projects').delete().eq('id',p.id));
 if(booking){ok(await admin.from('notification_outbox').delete().eq('booking_id',booking.id));ok(await admin.from('bookings').delete().eq('id',booking.id));}
 for(const u of users){if(u.client)ok(await u.client.auth.signOut({scope:'global'}));ok(await admin.auth.admin.deleteUser(u.id));}
 console.log('Temporary clients, projects, files, messages and booking removed.');
}
