import {readFile,writeFile,rm} from 'node:fs/promises';
import {loadEnv} from 'vite';
import {defaultSettings} from '../src/data.js';
import {injectMeta,publicOrigin} from '../lib/site-meta.js';
const env={...loadEnv('production',process.cwd(),''),...process.env};let settings=defaultSettings;
if(env.VITE_SUPABASE_URL&&env.VITE_SUPABASE_PUBLISHABLE_KEY){const response=await fetch(`${env.VITE_SUPABASE_URL}/rest/v1/site_settings?id=eq.1&select=*`,{headers:{apikey:env.VITE_SUPABASE_PUBLISHABLE_KEY},signal:AbortSignal.timeout(10000)});if(!response.ok)throw new Error('Could not load public studio identity for search previews. Check the public Supabase connection.');const rows=await response.json();if(rows[0])settings={...settings,...rows[0]}}
await writeFile('dist/index.html',injectMeta(await readFile('dist/index.html','utf8'),settings,env.SITE_URL));const origin=publicOrigin(env.SITE_URL);await writeFile('dist/robots.txt',`User-agent: *\nAllow: /\nDisallow: /admin\nDisallow: /portal\nDisallow: /api/\n${origin?`Sitemap: ${origin}/sitemap.xml\n`:''}`);if(origin)await writeFile('dist/sitemap.xml',`<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>${origin.replace(/&/g,'&amp;')}/</loc></url></urlset>`);else await rm('dist/sitemap.xml',{force:true});
console.log('Studio search previews prepared'+(origin?' with the configured website address.':'; canonical address and sitemap await the real domain.'));
