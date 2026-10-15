export function contactLinks(phone){
  const value=String(phone||'').trim();
  if(!/^[+\d\s()-]+$/.test(value))return null;
  let digits=value.replace(/\D/g,'');
  if(/^0[17]\d{8}$/.test(digits))digits='254'+digits.slice(1);
  if(!/^[1-9]\d{7,14}$/.test(digits))return null;
  return {call:`tel:+${digits}`,whatsapp:`https://wa.me/${digits}`};
}

export function packageSelection(pack,options){
  if(options.includes(pack.service))return {service:pack.service};
  const renamed={'Recording & music production':'Audio recording & music production','Film & video production':'Videography & event coverage'};
  if(options.includes(renamed[pack.service]))return {service:renamed[pack.service]};
  const fallback='Something else — let’s talk';
  return {service:options.includes(fallback)?fallback:''};
}
