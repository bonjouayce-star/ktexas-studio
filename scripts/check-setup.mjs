import {loadEnv} from 'vite';
import {createClient} from '@supabase/supabase-js';
const env={...loadEnv('production',process.cwd(),''),...process.env};
let missing=0,failed=0;
function report(label,ok,detail=''){console.log(`${ok?'READY':'NEEDS SETUP'} · ${label}${detail?' — '+detail:''}`);if(!ok)missing++}
const groups={Database:['VITE_SUPABASE_URL','VITE_SUPABASE_PUBLISHABLE_KEY','SUPABASE_URL','SUPABASE_SECRET_KEY'],Email:['RESEND_API_KEY','EMAIL_FROM'],Cards:['STRIPE_SECRET_KEY','STRIPE_WEBHOOK_SECRET'],Scheduler:['CRON_SECRET'], 'M-Pesa':['MPESA_CONSUMER_KEY','MPESA_CONSUMER_SECRET','MPESA_SHORTCODE','MPESA_PASSKEY']};
for(const [label,keys] of Object.entries(groups)){const absent=keys.filter(k=>!env[k]);report(label,!absent.length,absent.length?'missing '+absent.join(', '):'credentials present; provider acceptance still needs testing')}
let site;try{site=new URL(env.SITE_URL)}catch{}
report('Website address',!!site&&site.protocol==='https:'&&!site.username&&!site.password,'public HTTPS origin required for invitations and payment callbacks');
report('Matching database URLs',!!env.SUPABASE_URL&&env.SUPABASE_URL===env.VITE_SUPABASE_URL);
for(const key of Object.keys(env).filter(k=>k.startsWith('VITE_')&&/(SECRET|PRIVATE|SERVICE_ROLE|PASSKEY)/i.test(k))){console.log('ERROR · server secret uses public prefix: '+key);failed++}
if(env.SUPABASE_URL&&env.SUPABASE_SECRET_KEY){
 const db=createClient(env.SUPABASE_URL,env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(12000)})}});
 for(const table of ['site_settings','services','bookings','studio_reservations','client_projects','client_files','client_decisions','studio_staff','project_staff','project_documents','notification_outbox','mpesa_attempts']){
  try{const {error}=await db.from(table).select('*',{head:true,count:'exact'}).limit(1);report('Database table '+table,!error,error?'unreachable; check schema, API grants and server key':'reachable')}catch{report('Database table '+table,false,'connection failed')}
 }
 try{const {data,error}=await db.from('studio_admins').select('user_id').limit(1);report('Owner account',!error&&!!data?.length,'at least one studio owner is required')}catch{report('Owner account',false,'connection failed')}
}
console.log('\nNo messages sent, payments initiated, or database records changed.');
if(missing||failed){console.log(`Setup incomplete: ${missing} missing checks, ${failed} configuration errors.`);process.exitCode=1}else console.log('Configuration checks passed. Run live acceptance testing before launch.');
