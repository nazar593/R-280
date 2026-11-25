import * as T from 'https://cdn.jsdelivr.net/npm/three@0.160.1/build/three.module.js';
// Cosmetic arcade crash feedback. No blast damage or physical weapon model.
export function createCrashEffect(scene){
 const canvas=document.createElement('canvas');canvas.width=canvas.height=64;
 const ctx=canvas.getContext('2d'),gradient=ctx.createRadialGradient(32,32,1,32,32,31);
 gradient.addColorStop(0,'rgba(255,255,255,1)');gradient.addColorStop(.30,'rgba(255,255,255,.65)');gradient.addColorStop(1,'rgba(255,255,255,0)');
 ctx.fillStyle=gradient;ctx.fillRect(0,0,64,64);
 const texture=new T.CanvasTexture(canvas);texture.colorSpace=T.SRGBColorSpace;
 const group=new T.Group();scene.add(group);group.visible=false;
 const flash=new T.Sprite(new T.SpriteMaterial({map:texture,color:0xffd5a0,transparent:true,depthWrite:false,blending:T.AdditiveBlending}));
 group.add(flash);
 const light=new T.PointLight(0xffb56a,0,7);group.add(light);
 const puffs=[];
 for(let i=0;i<24;i++){
  const smoke=i>=9;
  const sprite=new T.Sprite(new T.SpriteMaterial({map:texture,color:smoke?0x57514b:0xff9a36,transparent:true,depthWrite:false,blending:smoke?T.NormalBlending:T.AdditiveBlending}));
  group.add(sprite);puffs.push({sprite,smoke,velocity:new T.Vector3(),life:1,base:1});
 }
 let age=0,active=false;
 function start(pos){
  group.position.copy(pos);group.visible=true;age=0;active=true;flash.visible=true;flash.scale.setScalar(1.1);flash.material.opacity=1;light.intensity=12;
  for(const p of puffs){p.sprite.visible=true;p.sprite.position.set(0,0,0);p.velocity.set((Math.random()-.5)*1.9,.3+Math.random()*1.3,(Math.random()-.5)*1.9);p.life=p.smoke?1.4+Math.random()*1.5:.32+Math.random()*.35;p.base=.25+Math.random()*.5;p.sprite.scale.setScalar(p.base);p.sprite.material.opacity=p.smoke?.45:.9;}
 }
 function tick(dt){
  if(!active)return;
  age+=dt;flash.visible=age<.16;flash.scale.setScalar(1.1+age*5);flash.material.opacity=Math.max(0,1-age/.16);light.intensity=12*Math.max(0,1-age/.16);
  for(const p of puffs){const t=age/p.life;p.sprite.visible=t<1;if(t>=1)continue;p.sprite.position.addScaledVector(p.velocity,dt);p.sprite.scale.setScalar(p.base*(1+t*(p.smoke?3:1.6)));p.sprite.material.opacity=(p.smoke?.45:.9)*(1-t);}
  if(age>3){active=false;group.visible=false;light.intensity=0;}
 }
 function clear(){active=false;group.visible=false;light.intensity=0;}
 return {start,tick,clear};
}
