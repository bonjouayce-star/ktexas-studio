import {can,allowedTabs,allProjects} from '../lib/permissions.js';
export {can,allowedTabs,allProjects};
let current='owner';
export const staffRole=()=>current;
export const setStaffRole=role=>{current=role};
export const has=capability=>can(current,capability);
