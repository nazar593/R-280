// Browser input only; movement stays in main.js.
export function installControls({canvas,setMode,toggleCamera,reset,setKey,clearKeys,moveLook,resize}){
 document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>setMode(b.dataset.mode));
 document.querySelector('#cam').onclick=toggleCamera;
 document.querySelector('#reset').onclick=reset;
 document.querySelectorAll('[data-key]').forEach(b=>{
   const k=b.dataset.key;
   b.onpointerdown=e=>{e.preventDefault();b.setPointerCapture(e.pointerId);setKey(k,true);};
   b.onpointerup=b.onpointercancel=b.onlostpointercapture=()=>setKey(k,false);
 });
 const km={w:'up',a:'left',s:'down',d:'right',ArrowUp:'up',ArrowDown:'down',ArrowLeft:'left',ArrowRight:'right',e:'asc',q:'desc',' ':'desc'};
 addEventListener('keydown',e=>{if(km[e.key]){setKey(km[e.key],true);e.preventDefault();}});
 addEventListener('keyup',e=>{if(km[e.key])setKey(km[e.key],false);});
 addEventListener('blur',clearKeys);document.addEventListener('visibilitychange',clearKeys);
 let drag=null;
 canvas.onpointerdown=e=>{drag=[e.clientX,e.clientY];canvas.setPointerCapture(e.pointerId);};
 canvas.onpointermove=e=>{if(!drag)return;moveLook(e.clientX-drag[0],e.clientY-drag[1]);drag[0]=e.clientX;drag[1]=e.clientY;};
 canvas.onpointerup=canvas.onpointercancel=canvas.onlostpointercapture=()=>drag=null;
 addEventListener('resize',resize);
}
