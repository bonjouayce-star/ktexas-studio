import {escapeHTML as esc,safeURL} from './main.js';
import {wireMediaFields} from './media-library.js';
import './website-editor.css';

// Uses the existing settings row and content editors; no public layout or schema changes.
export function renderWebsiteEditor(body,{settings,projects,services,demo,identity,navigate,save}) {
  const cards=[['Projects','Gallery & recent work','Add a project, choose its cover and arrange captioned gallery photos.',`${projects.filter(p=>p.published!==false).length} published projects`],['Media library','Photos, video & audio','Upload approved files once and reuse them across the website.','Your shared media shelf'],['Services','Services & new offers','Add or update the services visitors can discover and book.',`${services.filter(s=>s.active).length} active services`],['Studio experience','Packages, reel & studio','Change package prices, showreel, audio examples, team and studio tour.','Open the experience editor'],['Testimonials','Client stories','Manage quotes and publish them after recording client permission.','Build trust with real stories']];
  body.innerHTML=`<section class="panel website-intro"><div><div class="eyebrow">MAKE IT YOURS</div><h2>Your website, in your hands.</h2><p>Edit the words and images. Keep the design you love.</p></div><a class="button lime" href="/" target="_blank" rel="noopener">View website ↗</a></section><div class="website-cards">${cards.map(([tab,title,description,count])=>`<button class="panel website-card" data-open-editor="${tab}"><span class="eyebrow">${esc(count)}</span><h3>${title} ↗</h3><p>${description}</p></button>`).join('')}</div>${identity?`<form id="website-form"><div class="website-edit-layout"><div><section class="panel"><h2>Welcome & hero</h2><p class="quiet">A first impression that sounds like you. Line breaks in the headline are preserved.</p><label>Welcome headline<textarea name="hero_line" rows="3" maxlength="150" required>${esc(settings.hero_line||'')}</textarea></label><label>Welcome message<textarea name="hero_description" rows="4" maxlength="600" required>${esc(settings.hero_description||'')}</textarea></label><label>Welcome photo<input name="hero_image" value="${esc(settings.hero_image||'')}" maxlength="300"></label><label>Describe the photo<input name="hero_image_alt" value="${esc(settings.hero_image_alt||'')}" maxlength="300"></label><label class="check-label"><input type="checkbox" name="hero_is_reference" ${settings.hero_is_reference!==false?'checked':''}>This is a reference photo</label></section><section class="panel"><h2>Contact & social links</h2><div class="field-grid">${[['phone','Phone / WhatsApp','tel'],['email','Email address','email'],['location','Studio location','text'],['instagram','Instagram','url'],['youtube','YouTube','url'],['tiktok','TikTok','url'],['facebook','Facebook','url']].map(([key,title,type])=>`<label>${title}<input type="${type}" name="${key}" maxlength="300" value="${esc(settings[key]||'')}"></label>`).join('')}</div><label class="check-label"><input type="checkbox" name="booking_open" ${settings.booking_open?'checked':''}>Accept new booking requests</label></section></div><aside><section class="panel website-preview-panel"><div class="eyebrow">LIVE DRAFT PREVIEW</div><p class="quiet">A simplified preview of your welcome section.</p><div class="website-preview"><img id="website-preview-image" alt=""><div><h2 id="website-preview-title"></h2><p id="website-preview-description"></p><span class="button lime">Let’s create together ↗</span></div></div><p class="quiet">Your edits go live only when you publish. The public page keeps its existing design.</p></section></aside></div><section class="panel website-publish"><p role="status" id="website-save-status">No unpublished changes.</p><div><button type="reset" class="subtle-button">Discard edits</button><button type="submit" class="button lime">${demo?'Save demo changes':'Publish website changes'} ↗</button></div></section></form>`:'<section class="panel"><h2>Need to change the welcome message or phone number?</h2><p>The studio owner can edit contact details and the homepage here. Use the editors above for your content updates.</p></section>'}`;
  body.querySelectorAll('[data-open-editor]').forEach(button=>button.onclick=()=>navigate(button.dataset.openEditor));
  if(!identity)return;
  const form=body.querySelector('#website-form'),status=body.querySelector('#website-save-status');
  let baseline;
  const snapshot=()=>JSON.stringify([...new FormData(form)].filter(([key])=>!['files','permission'].includes(key)));
  const update=()=>{
    body.querySelector('#website-preview-title').textContent=form.elements.hero_line.value;
    body.querySelector('#website-preview-description').textContent=form.elements.hero_description.value;
    const image=body.querySelector('#website-preview-image');
    image.src=safeURL(form.elements.hero_image.value)||'/images/studio.jpg';
    image.alt=form.elements.hero_image_alt.value;
    status.textContent=snapshot()===baseline?'No unpublished changes.':'Unpublished changes — review your preview, then publish.';
  };
  wireMediaFields(form,demo,[['hero_image','image']]);
  baseline=snapshot();update();form.addEventListener('input',update);form.addEventListener('change',update);
  form.addEventListener('reset',()=>setTimeout(update,0));
  form.onsubmit=async event=>{
    event.preventDefault();const data={};
    for(const key of ['hero_line','hero_description','hero_image','hero_image_alt','phone','email','location','instagram','youtube','tiktok','facebook'])data[key]=form.elements[key].value.trim();
    for(const key of ['hero_image','instagram','youtube','tiktok','facebook'])if(data[key]&&!safeURL(data[key])){status.textContent='Please enter a valid photo or social link.';form.elements[key].focus();return;}
    data.hero_is_reference=form.elements.hero_is_reference.checked;data.booking_open=form.elements.booking_open.checked;
    const controls=[...form.querySelectorAll('button,input,textarea,select')],disabled=controls.map(c=>c.disabled);controls.forEach(c=>c.disabled=true);status.textContent='Saving your website changes…';
    try{await save(data);for(const key of Object.keys(data)){const input=form.elements[key];if(input.type==='checkbox')input.defaultChecked=input.checked;else input.defaultValue=input.value;}controls.forEach((c,i)=>c.disabled=disabled[i]);baseline=snapshot();status.textContent=demo?'Demo saved in this browser session. The public website is unchanged.':'Published. Open the website to see your changes.';}
    catch(error){status.textContent=`Could not publish: ${error.message}. Your edits are still here.`;}
    finally{controls.forEach((c,i)=>c.disabled=disabled[i]);}
  };
}
