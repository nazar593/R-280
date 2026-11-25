import * as T from 'https://cdn.jsdelivr.net/npm/three@0.160.1/build/three.module.js';
import {createGraphics} from './graphics.js?v=4';
import {installControls} from './input.js?v=4';
const $=x=>document.querySelector(x);
const {renderer,camera,car,drone,wheels,resizeRender,visualsTick,renderVisuals}=createGraphics();
let mode='driver',chase=false,v=0,heading=0,look=0,pitch=0,dv=new T.Vector3(),keys={},fps=0;
// Abstract arcade flight parameters for the browser prototype, in scene units.
const flight={speed:9,yaw:0,turn:0,climb:0,bank:0,nose:0};
const damp=(a,b,k,dt)=>a+(b-a)*(1-Math.exp(-k*dt));
function resetFlight(){drone.position.set(0,9,0);flight.speed=9;flight.yaw=0;flight.turn=0;flight.climb=0;flight.bank=0;flight.nose=0;dv.set(0,0,-9);drone.rotation.set(0,0,0);}
function wrap(n,half){return ((n+half)%(2*half)+2*half)%(2*half)-half;}
function reset(){car.position.set(-1.65,0,0);heading=0;v=0;car.rotation.y=0;resetFlight();look=0;pitch=0;}reset();
function setMode(m){mode=m;look=0;pitch=0;chase=false;keys={};document.querySelector('[data-key="up"]').textContent=m==='drone'?'+':'▲';document.querySelector('[data-key="down"]').textContent=m==='drone'?'−':'▼';document.querySelector('[data-key="asc"]').textContent=m==='drone'?'Набор высоты':'Вверх';document.querySelector('[data-key="desc"]').textContent=m==='drone'?'Снижение':'Тормоз';document.querySelectorAll('[data-mode]').forEach(b=>b.classList.toggle('on',b.dataset.mode===m));$('#hud').style.display=m==='drone'?'block':'none';}
installControls({
 canvas:renderer.domElement,setMode,toggleCamera:()=>{chase=!chase;},reset,
 setKey:(k,value)=>{keys[k]=value;},clearKeys:()=>{keys={};},
 moveLook:(dx,dy)=>{look-=dx*.004;pitch=T.MathUtils.clamp(pitch-dy*.004,-.8,.8);},
 resize:()=>{resizeRender();camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();}
});
let uiFrame=0;
const clock=new T.Clock();const forward=new T.Vector3(),local=new T.Vector3(),target=new T.Vector3();function loop(){requestAnimationFrame(loop);let rawDt=clock.getDelta(),dt=Math.min(rawDt,.05);fps=.94*fps+.06/Math.max(rawDt,.001);let steer=(keys.left?1:0)-(keys.right?1:0);let throttle=(keys.up?1:0)-(keys.down?1:0);
if(mode!=='drone'){let desired=mode==='driver'?throttle*13:5; if(mode==='driver'&&keys.desc)desired=0;v+=(desired-v)*Math.min(1,dt*(keys.desc?6:1.5));if(mode==='driver')heading+=steer*v*.035*dt;else{let error=car.position.x+1.65;heading+=(Math.atan2(error,12)-heading)*dt*.8;}car.rotation.y=heading;forward.set(-Math.sin(heading),0,-Math.cos(heading));car.position.addScaledVector(forward,v*dt);if(Math.abs(car.position.z)>560)reset();if(Math.abs(car.position.x)>100)reset();for(const w of wheels)w.rotateX(v*dt/.43);drone.visible=false;car.visible=chase;
if(chase){local.set(0,3.3,7);local.applyAxisAngle(T.Object3D.DEFAULT_UP,heading+look);camera.position.copy(car.position).add(local);target.copy(car.position);target.y+=1;camera.lookAt(target);}else{local.set(mode==='driver'?-.37:mode==='passenger'?.37:0,mode==='observer'?2.15:1.77,mode==='observer'?1.3:-.6);local.applyAxisAngle(T.Object3D.DEFAULT_UP,heading);camera.position.copy(car.position).add(local);camera.rotation.set(pitch,heading+look,0,'YXZ');}}
else{
car.visible=true;drone.visible=chase;
// Always moving along the current course. No hover or reverse mode.
const climbInput=(keys.asc?1:0)-(keys.desc?1:0);
flight.speed=T.MathUtils.clamp(flight.speed+throttle*dt*5,5,16);
flight.turn=damp(flight.turn,steer,3.5,dt);
flight.yaw=wrap(flight.yaw+flight.turn*dt*1.05,Math.PI);
flight.climb=damp(flight.climb,climbInput*4,2.4,dt);
flight.bank=damp(flight.bank,-flight.turn*.38,3.5,dt);
flight.nose=damp(flight.nose,climbInput*.18,2.8,dt);
dv.set(-Math.sin(flight.yaw)*flight.speed,flight.climb,-Math.cos(flight.yaw)*flight.speed);
drone.position.addScaledVector(dv,dt);
drone.position.y=T.MathUtils.clamp(drone.position.y,3,60);
if((drone.position.y===3&&flight.climb<0)||(drone.position.y===60&&flight.climb>0))flight.climb=0;
// Wrap the test arena instead of clamping horizontal position to a wall.
drone.position.x=wrap(drone.position.x,110);
drone.position.z=wrap(drone.position.z,560);
drone.rotation.set(flight.nose,flight.yaw,flight.bank,'YXZ');
if(chase){
local.set(0,2,5).applyAxisAngle(T.Object3D.DEFAULT_UP,flight.yaw+look);
camera.position.copy(drone.position).add(local);camera.lookAt(drone.position);
}else{
camera.position.copy(drone.position);camera.rotation.set(pitch,flight.yaw+look,0,'YXZ');
}
$('#cross').style.top=(50+pitch*18)+'%';
}
$('#hud').style.display=mode==='drone'&&!chase?'block':'none';if(uiFrame++%8===0)$('#info').textContent='DEV 04 • '+(mode==='drone'?'Высота '+drone.position.y.toFixed(1)+' • Скорость '+flight.speed.toFixed(1)+' ед/с':mode==='driver'?'Ручное управление':'Автовождение — тест')+'\n'+(mode==='drone'?' + / −: скорость • ◀ / ▶: курс • ':Math.round(Math.abs(v)*3.6)+' км/ч • ')+Math.round(fps)+' FPS';visualsTick(dt,rawDt,steer,mode,chase,v,heading);renderVisuals();}loop();
