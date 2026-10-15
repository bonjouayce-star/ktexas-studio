import {availableSlots} from './scheduling.js';
export function validateBooking(input,now=new Date()) {
  if(!input||typeof input!=='object'||Array.isArray(input))throw new Error('Invalid booking request.');
  const clean=(key,max,required=true)=>{const value=typeof input[key]==='string'?input[key].trim():'';if((required&&!value)||value.length>max)throw new Error(`Please check your ${key.replace('_',' ')}.`);return value};
  const name=clean('name',120),email=clean('email',254).toLowerCase(),phone=clean('phone',40,false),service=clean('service',180),notes=clean('notes',2000,false),date=clean('date',10),time=clean('time',5);
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))throw new Error('Please enter a valid email address.');
  const today=now.toLocaleDateString('en-CA',{timeZone:'Africa/Nairobi'});
  if(!/^\d{4}-\d{2}-\d{2}$/.test(date)||Number.isNaN(Date.parse(date))||new Date(date).toISOString().slice(0,10)!==date||date<today||date>new Date(now.getTime()+180*86400000).toLocaleDateString('en-CA',{timeZone:'Africa/Nairobi'}))throw new Error('Please choose a valid date within the next six months.');
  if(!['10:00','12:00','14:00','16:00','18:00','20:00'].includes(time))throw new Error('Please choose an available session time.');
  const duration=Number(input.duration);if(![2,3,4,6,8].includes(duration))throw new Error('Please choose a valid session length.');
  if(!availableSlots(date,duration,[],now).includes(time))throw new Error('Please choose a future session within studio opening hours.');
  if(!['on',true].includes(input.consent))throw new Error('Please consent to being contacted about your request.');
  return {name,email,phone,service,notes,date,time,duration,status:'pending'};
}
