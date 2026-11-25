import * as T from 'https://cdn.jsdelivr.net/npm/three@0.160.1/build/three.module.js';

export function createGraphics(){
const $=x=>document.querySelector(x);let renderer;
try{renderer=new T.WebGLRenderer({antialias:true,powerPreference:'high-performance'});}catch(e){$('#notice').textContent='WebGL недоступен на этом устройстве.';throw e;}

/* ---------- 1. Lighting, sky and environmental materials ---------- */
renderer.outputColorSpace=T.SRGBColorSpace;
renderer.toneMapping=T.ACESFilmicToneMapping;
renderer.toneMappingExposure=1.08;
renderer.shadowMap.type=T.PCFSoftShadowMap;
renderer.shadowMap.autoUpdate=false;
renderer.setPixelRatio(Math.min(devicePixelRatio,1.1));
renderer.setSize(innerWidth,innerHeight);
document.body.prepend(renderer.domElement);
const scene=new T.Scene();
scene.background=new T.Color(0xa1b5c5);
scene.fog=new T.FogExp2(0xa1b5c5,.006);
const camera=new T.PerspectiveCamera(65,innerWidth/innerHeight,.08,650);
const hemi=new T.HemisphereLight(0xe5edff,0x555b43,1.8);scene.add(hemi);
const sun=new T.DirectionalLight(0xfff2d9,3.1);scene.add(sun,sun.target);
sun.castShadow=true;
const sc=sun.shadow.camera;sc.left=-48;sc.right=48;sc.top=48;sc.bottom=-48;sc.near=1;sc.far=180;
sun.shadow.mapSize.set(1024,1024);sun.shadow.bias=-.00015;sun.shadow.normalBias=.035;sun.shadow.radius=2;
let seed=41;
function rand(){seed=(1664525*seed+1013904223)>>>0;return seed/4294967296}
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
const smooth=(a,b,x)=>{let t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t)};
const times=[
 {name:'День',top:0x477eb4,horizon:0xc7d7d8,cloud:0xf4f1e9,fog:0xb1c4c9,sun:0xfff2d9,dir:[-.48,.78,-.39],light:3.1,ambient:1.55,exposure:1.05},
 {name:'Закат',top:0x354e82,horizon:0xf2a773,cloud:0xe4b0a0,fog:0xb9988e,sun:0xffb575,dir:[-.81,.22,-.55],light:2.3,ambient:.95,exposure:1.08},
 {name:'Ночь',top:0x070f25,horizon:0x28394d,cloud:0x344052,fog:0x243044,sun:0xb8d2ff,dir:[.3,.68,-.6],light:.16,ambient:.43,exposure:1.2}
];
let timeIndex=0,elapsed=0,quality=1,autoQuality=true,frame=0;
const skyUniform={topColor:{value:new T.Color()},horizonColor:{value:new T.Color()},cloudColor:{value:new T.Color()},sunDirection:{value:new T.Vector3()},sunColor:{value:new T.Color()},time:{value:0},night:{value:0}};
const skyMat=new T.ShaderMaterial({uniforms:skyUniform,side:T.BackSide,depthWrite:false,fog:false,
vertexShader:`varying vec3 dir;void main(){dir=position;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}`,
fragmentShader:`varying vec3 dir;uniform vec3 topColor,horizonColor,cloudColor,sunDirection,sunColor;uniform float time,night;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void main(){vec3 d=normalize(dir);float h=max(d.y,0.);vec3 c=mix(horizonColor,topColor,pow(h,.55));
vec2 uv=d.xz/(max(d.y,0.)+.23)*2.5+vec2(time*.009,0.);
float n=noise(uv)*.58+noise(uv*2.1)*.27+noise(uv*4.4)*.15;
float cl=smoothstep(.49,.72,n)*smoothstep(.01,.22,h);c=mix(c,cloudColor,cl*.72);
float sd=max(dot(d,sunDirection),0.);c+=sunColor*(pow(sd,26.)*.22+smoothstep(.9992,.9998,sd)*2.5)*(1.-night*.75);
gl_FragColor=vec4(c,1.);
#include <tonemapping_fragment>
#include <colorspace_fragment>
}`});
const sky=new T.Mesh(new T.SphereGeometry(130,32,16),skyMat);sky.frustumCulled=false;sky.renderOrder=-100;scene.add(sky);
const pmrem=new T.PMREMGenerator(renderer);let envTarget=null;
const sunOffset=new T.Vector3();
function updateEnvironment(p){
 const c=document.createElement('canvas');c.width=256;c.height=128;const g=c.getContext('2d');
 const col=n=>'#'+n.toString(16).padStart(6,'0');
 const gradient=g.createLinearGradient(0,0,0,128);gradient.addColorStop(0,col(p.top));gradient.addColorStop(.50,col(p.horizon));gradient.addColorStop(.57,'#626b54');gradient.addColorStop(1,'#252d23');g.fillStyle=gradient;g.fillRect(0,0,256,128);
 const x=128+Math.atan2(p.dir[2],p.dir[0])*128/Math.PI,y=64-Math.asin(p.dir[1])*128/Math.PI;
 const glow=g.createRadialGradient(x,y,1,x,y,23);glow.addColorStop(0,col(p.sun));glow.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=glow;g.fillRect(0,0,256,128);
 const t=new T.CanvasTexture(c);t.colorSpace=T.SRGBColorSpace;t.mapping=T.EquirectangularReflectionMapping;
 const next=pmrem.fromEquirectangular(t);t.dispose();const old=envTarget;envTarget=next;scene.environment=next.texture;if(old)old.dispose();
}
function applyTime(){
 const p=times[timeIndex];skyUniform.topColor.value.setHex(p.top);skyUniform.horizonColor.value.setHex(p.horizon);skyUniform.cloudColor.value.setHex(p.cloud);
 skyUniform.sunDirection.value.set(...p.dir).normalize();skyUniform.sunColor.value.setHex(p.sun);skyUniform.night.value=timeIndex===2?1:0;
 sunOffset.copy(skyUniform.sunDirection.value).multiplyScalar(95);sun.color.setHex(p.sun);sun.intensity=p.light;hemi.intensity=p.ambient;hemi.color.setHex(timeIndex===2?0xa9bce0:0xe5edff);
 scene.fog.color.setHex(p.fog);renderer.toneMappingExposure=p.exposure;updateEnvironment(p);$('#daytime').textContent=p.name;
 renderer.shadowMap.needsUpdate=true;
}
/* ---------- 2. Procedural textures and terrain ---------- */
function canvasTex(kind,size=256){
 const c=document.createElement('canvas');c.width=c.height=size;const g=c.getContext('2d');
 const palette={grass:[91,105,55],soil:[117,99,73],rock:[109,108,102],asphalt:[67,69,70],rubber:[35,36,34],rust:[122,83,54],camo:[88,102,66],mud:[104,90,64],wood:[96,77,55],roof:[105,75,64],bump:[128,128,128]};
 const p=palette[kind]||palette.soil,img=g.createImageData(size,size);
 for(let y=0;y<size;y++)for(let x=0;x<size;x++){const i=(x+y*size)*4,n=(rand()-.5)*(kind==='asphalt'?44:34)+Math.sin(x*.09)*Math.cos(y*.11)*8;for(let k=0;k<3;k++)img.data[i+k]=clamp(p[k]+n,0,255);img.data[i+3]=255;}
 g.putImageData(img,0,0);
 if(kind==='asphalt'){g.strokeStyle='rgba(15,17,18,.39)';for(let j=0;j<18;j++){let x=rand()*size,y=rand()*size;g.beginPath();g.moveTo(x,y);for(let k=0;k<6;k++){x+=(rand()-.45)*13;y+=(rand()-.45)*14;g.lineTo(x,y);}g.lineWidth=.4+rand();g.stroke();}
 for(let j=0;j<25;j++){g.fillStyle='rgba(155,145,130,.04)';g.fillRect(rand()*size,rand()*size,8+rand()*26,3+rand()*9);}}
 if(kind==='camo'){for(let j=0;j<95;j++){g.fillStyle=['#3f4832','#6b714b','#929373','#4e503e','#75745a'][j%5];g.beginPath();let x=rand()*size,y=rand()*size;g.ellipse(x,y,5+rand()*25,4+rand()*11,rand()*6.28,0,6.28);g.fill();}}
 if(kind==='wood'||kind==='roof'||kind==='rubber'){g.strokeStyle='rgba(20,15,10,.3)';g.lineWidth=2;for(let j=0;j<size;j+=12){g.beginPath();g.moveTo(j,0);g.lineTo(j+(kind==='wood'?3:0),size);g.stroke();}}
 if(kind==='mud'||kind==='rust'){for(let j=0;j<90;j++){g.fillStyle='rgba(56,42,29,.09)';g.beginPath();g.arc(rand()*size,rand()*size,1+rand()*9,0,6.28);g.fill();}}
 const t=new T.CanvasTexture(c);t.wrapS=t.wrapT=T.RepeatWrapping;t.colorSpace=kind==='bump'?T.NoColorSpace:T.SRGBColorSpace;t.anisotropy=Math.min(4,renderer.capabilities.getMaxAnisotropy());return t;
}
const tex={};for(const k of ['grass','soil','rock','asphalt','rubber','rust','camo','mud','wood','roof','bump'])tex[k]=canvasTex(k);
function repeat(t,x,y){const a=t.clone();a.repeat.set(x,y);a.needsUpdate=true;return a;}
const mat=(c,options={})=>new T.MeshStandardMaterial({color:c,roughness:.87,...options});
const body=mat(0xb6b9a4,{map:tex.camo,roughness:.64,metalness:.25,bumpMap:tex.bump,bumpScale:.018});
const black=mat(0x202329,{roughness:.74}),silver=mat(0x8f9698,{roughness:.37,metalness:.75});
const glass=new T.MeshPhysicalMaterial({color:0x536a78,roughness:.17,metalness:.42,clearcoat:1,clearcoatRoughness:.15});
const trunkMat=mat(0x7d735c,{map:tex.wood,roughness:1}),leaf=mat(0x607a41,{roughness:1});
const tireMat=mat(0x666666,{map:tex.rubber,bumpMap:tex.bump,bumpScale:.035,roughness:1});
const asphalt=mat(0xffffff,{map:repeat(tex.asphalt,2,160),bumpMap:repeat(tex.bump,2,160),bumpScale:.025});
const shoulder=mat(0xffffff,{map:repeat(tex.mud,1,130),roughness:1});
const stripe=mat(0xd7d4b9,{roughness:.95});
function mesh(parent,geo,m,x=0,y=0,z=0){const o=new T.Mesh(geo,m);o.position.set(x,y,z);parent.add(o);return o;}
function box(parent,w,h,d,x,y,z,m){return mesh(parent,new T.BoxGeometry(w,h,d),m,x,y,z);}
function terrainHeight(x,z){
 const edge=smooth(7,25,Math.abs(x));const n=Math.sin(x*.037+Math.cos(z*.019)*.8)*.48+Math.cos(z*.041+x*.018)*.3+Math.sin(x*.12+z*.07)*.12;
 return edge*(n*.65+smooth(65,160,Math.abs(x))*(2+2.4*Math.sin(z*.013+x*.021)));
}
const terrainGeo=new T.PlaneGeometry(500,1200,125,300);terrainGeo.rotateX(-Math.PI/2);
const pos=terrainGeo.attributes.position;for(let i=0;i<pos.count;i++)pos.setY(i,terrainHeight(pos.getX(i),pos.getZ(i))-.075);
terrainGeo.computeVertexNormals();
const terrainMat=mat(0xffffff,{roughness:1});
terrainMat.onBeforeCompile=sh=>{
 sh.uniforms.gTex={value:tex.grass};sh.uniforms.sTex={value:tex.soil};sh.uniforms.rTex={value:tex.rock};
 sh.vertexShader='varying vec3 worldTerrain; varying vec3 normalTerrain;\n'+sh.vertexShader;
 sh.vertexShader=sh.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\nworldTerrain=position;normalTerrain=normal;');
 sh.fragmentShader='uniform sampler2D gTex,sTex,rTex; varying vec3 worldTerrain,normalTerrain;\n'+sh.fragmentShader;
 sh.fragmentShader=sh.fragmentShader.replace('#include <map_fragment>',`vec2 tuv=worldTerrain.xz*.32;
 float field=sin(worldTerrain.z*.075)*sin(worldTerrain.x*.061);
 float slope=1.-abs(normalize(normalTerrain).y);
 float soil=smoothstep(.12,.65,field)*.65+(.18+.18*sin(worldTerrain.z*.018))*smoothstep(12.,23.,abs(worldTerrain.x));
 float rock=smoothstep(.10,.32,slope)+smoothstep(1.3,4.5,worldTerrain.y)*.35;
 vec3 tc=mix(texture2D(gTex,tuv).rgb,texture2D(sTex,tuv*.9).rgb,clamp(soil,0.,1.));
 tc=mix(tc,texture2D(rTex,tuv*.6).rgb,clamp(rock,0.,1.));
 float rows=pow(.5+.5*sin(worldTerrain.x*4.2),8.);
 diffuseColor.rgb*=tc*(1.-rows*soil*.13);`);
};
const terrain=mesh(scene,terrainGeo,terrainMat);terrain.receiveShadow=true;
const road=box(scene,8,.07,1200,0,-.005,0,asphalt);road.receiveShadow=true;
for(const x of [-4.75,4.75]){const o=box(scene,1.5,.026,1200,x,-.016,0,shoulder);o.receiveShadow=true;}
const dummy=new T.Object3D(),tint=new T.Color();
function instance(geo,mat,items,parent=scene,shadow=false){
 const o=new T.InstancedMesh(geo,mat,items.length);for(let i=0;i<items.length;i++){const q=items[i];dummy.position.set(q[0],q[1],q[2]);dummy.rotation.set(q[6]||0,q[7]||0,q[8]||0);dummy.scale.set(q[3]??1,q[4]??1,q[5]??1);dummy.updateMatrix();o.setMatrixAt(i,dummy.matrix);if(q[9]!==undefined){tint.setHex(q[9]);o.setColorAt(i,tint);}}
 o.instanceMatrix.needsUpdate=true;if(o.instanceColor)o.instanceColor.needsUpdate=true;o.castShadow=shadow;o.receiveShadow=true;o.computeBoundingSphere();parent.add(o);return o;
}
const marks=[];for(let z=-590;z<600;z+=11)marks.push([0,.037,z,1,1,1,0,0,0,rand()>.23?0xe3e2d0:0xb6b5a2]);instance(new T.BoxGeometry(.11,.006,4),stripe,marks);
for(const x of [-3.7,3.7])box(scene,.10,.006,1200,x,.038,0,stripe);
const wear=mat(0x33352f,{transparent:true,opacity:.14,depthWrite:false});for(const x of [-2.6,-.8,.8,2.6])box(scene,.19,.002,1200,x,.034,0,wear);
/* ---------- 3. Roadside geometry, vegetation and LOD ---------- */
const windTime={value:0};
const bladeMat=mat(0xffffff,{side:T.DoubleSide,roughness:1});
bladeMat.onBeforeCompile=sh=>{sh.uniforms.windTime=windTime;sh.vertexShader='uniform float windTime;\n'+sh.vertexShader;
sh.vertexShader=sh.vertexShader.replace('#include <begin_vertex>',`#include <begin_vertex>
float phase=0.;
#ifdef USE_INSTANCING
 phase=instanceMatrix[3].x*.17+instanceMatrix[3].z*.12;
#endif
 transformed.x+=sin(windTime*1.7+phase)*position.y*position.y*.24;`);};
const bladeGeo=new T.BufferGeometry();bladeGeo.setAttribute('position',new T.Float32BufferAttribute([-.075,0,0,.075,0,0,.035,.35,0,-.075,0,0,.035,.35,0,-.012,.65,0,0,0,-.07,0,0,.07,0,.65,0],3));bladeGeo.computeVertexNormals();
leaf.onBeforeCompile=sh=>{sh.uniforms.windTime=windTime;sh.vertexShader='uniform float windTime;\n'+sh.vertexShader;sh.vertexShader=sh.vertexShader.replace('#include <begin_vertex>',`#include <begin_vertex>
 #ifdef USE_INSTANCING
 float branchPhase=instanceMatrix[3].x*.25+instanceMatrix[3].z*.13;
 transformed.x+=sin(windTime*.9+branchPhase)*.035*(position.y+1.);
 #endif
 `);};
const trunkGeo=new T.CylinderGeometry(.12,.25,3.4,7,2);const crownGeo=new T.IcosahedronGeometry(1,1),farCrownGeo=new T.IcosahedronGeometry(1,0);
const vegetation=[];
for(let c=0;c<12;c++){
 const cz=-550+c*100,trs=[],near=[],far=[],blades=[],bushes=[];
 for(let j=0;j<18;j++){const x=(j%2?1:-1)*(12+rand()*48),z=cz+(rand()-.5)*95,h=.8+rand()*.9,y=terrainHeight(x,z);
 trs.push([x,y+1.7*h,z,h,h,h,0,rand()*6,0,0xc8bba4]);
 const color=[0x84945d,0x748c51,0x94a36c,0x627b4a][j%4];
 for(let k=0;k<4;k++)near.push([x+(rand()-.5)*1.8*h,y+(2.9+k*.61)*h,z+(rand()-.5)*1.8*h,(1.4+rand()*.5)*h,(1.35+rand()*.4)*h,(1.4+rand()*.4)*h,0,rand()*6,0,color]);
 far.push([x,y+4*h,z,2.2*h,2.6*h,2.2*h,0,rand()*6,0,color]);
 }
 for(let j=0;j<360;j++){const x=(j%2?1:-1)*(5.6+rand()*9),z=cz+(rand()-.5)*98,h=.4+rand()*.85;blades.push([x,terrainHeight(x,z)-.04,z,h,h,h,0,rand()*6,0,[0x718c42,0x89984a,0x526b37,0x9c9c56][j%4]]);}
 for(let j=0;j<12;j++){let x=(j%2?1:-1)*(8+rand()*17),z=cz+(rand()-.5)*95;bushes.push([x,terrainHeight(x,z)+.3,z,.5+rand()*.7,.42+rand()*.38,.5+rand()*.7,0,rand()*6,0,0x83945d]);}
 const group=new T.Group();scene.add(group);
 const t=instance(trunkGeo,trunkMat,trs,group,true),n=instance(crownGeo,leaf,near,group,true),f=instance(farCrownGeo,leaf,far,group,false),g=instance(bladeGeo,bladeMat,blades,group),bu=instance(crownGeo,leaf,bushes,group,true);
 vegetation.push({z:cz,group,near:n,far:f,grass:g,bush:bu,trunks:t});
}
const stoneMat=mat(0xaaa49a,{map:tex.rock});let stones=[];
for(let j=0;j<90;j++){let x=(j%2?1:-1)*(7+rand()*25),z=rand()*1100-550,k=.16+rand()*.55;stones.push([x,terrainHeight(x,z)+k*.2,z,k,k*.57,k*.8,0,rand()*6,0,0xaaa99e]);}
instance(farCrownGeo,stoneMat,stones);
const wallMat=mat(0xc1b8a3,{map:tex.soil}),roofMat=mat(0xb9a79b,{map:tex.roof,metalness:.15}),trim=mat(0x64685c);
function gable(w,h,d){const sh=new T.Shape();sh.moveTo(-w/2,0);sh.lineTo(0,h);sh.lineTo(w/2,0);sh.closePath();const g=new T.ExtrudeGeometry(sh,{depth:d,bevelEnabled:false});g.translate(0,0,-d/2);return g;}
for(let j=0;j<8;j++){let x=24+(j%2)*13,z=-95+j*16,y=terrainHeight(x,z);const house=new T.Group();house.position.set(x,y,z);scene.add(house);
 const shell=box(house,8,3.2,6,0,1.6,0,wallMat);shell.castShadow=shell.receiveShadow=true;const roof=mesh(house,gable(8.6,1.75,6.7),roofMat,0,3.15,0);roof.castShadow=true;
 for(const dx of [-2,2]){box(house,1.25,1.15,.055,dx,1.8,-3.03,trim);box(house,1.04,.94,.07,dx,1.8,-3.07,glass);}
 box(house,1,1.9,.09,0,.95,-3.04,trunkMat);
}
const poles=[],crossbars=[],fencePosts=[],fenceRails=[];
for(let z=-570;z<=570;z+=38){let x=-9,y=terrainHeight(x,z);poles.push([x,y+3.6,z,1,1,1]);crossbars.push([x,y+6.65,z,1,1,1]);}
instance(new T.CylinderGeometry(.085,.15,7.2,7),trunkMat,poles,scene,true);instance(new T.BoxGeometry(1.8,.12,.12),silver,crossbars);
const wireV=[];for(let j=0;j<poles.length-1;j++)for(const off of [-.7,.7])for(let k=0;k<6;k++){const a=k/6,b=(k+1)/6,p=poles[j],q=poles[j+1];for(const t of [a,b])wireV.push(p[0]+off,p[1]+3.05+(q[1]-p[1])*t-Math.sin(t*Math.PI)*.6,p[2]+(q[2]-p[2])*t);}
const wireG=new T.BufferGeometry();wireG.setAttribute('position',new T.Float32BufferAttribute(wireV,3));scene.add(new T.LineSegments(wireG,new T.LineBasicMaterial({color:0x424641})));
for(let z=-110;z<45;z+=2.5){const x=15,y=terrainHeight(x,z);fencePosts.push([x,y+.62,z]);for(const h of [.45,.95])fenceRails.push([x,y+h,z+1.25]);}
instance(new T.BoxGeometry(.13,1.25,.13),trunkMat,fencePosts);instance(new T.BoxGeometry(.09,.10,2.5),trunkMat,fenceRails);
/* ---------- 4. Vehicle surfaces and camera interior ---------- */
function rounded(w,h,d,r){r=Math.min(r,w*.2,h*.2,d*.4);const x=-w/2,y=-h/2,sh=new T.Shape();sh.moveTo(x+r,y);sh.lineTo(x+w-r,y);sh.quadraticCurveTo(x+w,y,x+w,y+r);sh.lineTo(x+w,y+h-r);sh.quadraticCurveTo(x+w,y+h,x+w-r,y+h);sh.lineTo(x+r,y+h);sh.quadraticCurveTo(x,y+h,x,y+h-r);sh.lineTo(x,y+r);sh.quadraticCurveTo(x,y,x+r,y);const g=new T.ExtrudeGeometry(sh,{depth:d-2*r,bevelEnabled:true,bevelSize:r*.45,bevelThickness:r,bevelSegments:2,steps:1,curveSegments:4});g.translate(0,0,-(d-2*r)/2);return g;}
function roundedPart(parent,w,h,d,x,y,z,m,r=.08){let o=mesh(parent,rounded(w,h,d,r),m,x,y,z);o.castShadow=true;o.receiveShadow=true;return o;}
const car=new T.Group();scene.add(car);
roundedPart(car,1.87,.47,4.45,0,.80,0,body,.11);
roundedPart(car,1.83,.42,1.35,0,1.08,-1.58,body);
roundedPart(car,1.76,.64,1.76,0,1.34,-.35,body,.12);
roundedPart(car,1.68,.51,1.60,0,1.68,-.35,glass,.12);
roundedPart(car,1.78,.14,1.68,0,1.97,-.35,body,.07);
const frameMat=mat(0x242b2b),mudMat=mat(0x8e806b,{map:tex.mud,roughness:1});
for(const x of [-.88,.88]){
 roundedPart(car,.15,.48,1.66,x,1.08,1.32,body);
 box(car,.06,.12,3.7,x,.57,0,mudMat);
 for(const z of [-.82,.2]){box(car,.028,.035,.22,x,1.35,z,black);box(car,.018,.48,.015,x,1.16,z+.32,frameMat);}
 roundedPart(car,.26,.17,.19,x*1.13,1.62,-1,black,.03);
}
roundedPart(car,1.83,.40,.17,0,1.07,2.12,body);box(car,1.6,.09,1.65,0,.87,1.3,black);
roundedPart(car,1.85,.22,.21,0,.66,-2.24,black,.04);roundedPart(car,1.8,.2,.22,0,.65,2.24,black,.04);
roundedPart(car,1.10,.25,.07,0,1.02,-2.25,black,.03);
for(let i=0;i<7;i++)box(car,.94,.014,.025,0,.92+i*.031,-2.3,silver);
const headMat=mat(0xece1c2,{emissive:0xffe6b1,emissiveIntensity:.08,roughness:.3});
const tailMat=mat(0xa32119,{emissive:0xe2180b,emissiveIntensity:.1,roughness:.3});
for(const x of [-.72,.72]){roundedPart(car,.34,.20,.06,x,1.07,-2.25,headMat,.03);roundedPart(car,.15,.31,.06,x,1.04,2.23,tailMat,.03);}
const wheels=[],frontHubs=[];
const tireGeo=new T.CylinderGeometry(.43,.43,.27,24,1),hubGeo=new T.CylinderGeometry(.255,.255,.285,20,1),rimGeo=new T.TorusGeometry(.205,.025,5,20);
for(const x of [-.97,.97])for(const z of [-1.45,1.45]){
 const steering=new T.Group();steering.position.set(x,.46,z);car.add(steering);if(z<0)frontHubs.push(steering);
 const pivot=new T.Group();steering.add(pivot);
 const tire=mesh(pivot,tireGeo,tireMat);tire.rotation.z=Math.PI/2;tire.castShadow=true;
 const hub=mesh(pivot,hubGeo,silver);hub.rotation.z=Math.PI/2;
 const rim=mesh(pivot,rimGeo,black,x<0?-.15:.15,0,0);rim.rotation.y=Math.PI/2;
 for(let j=0;j<6;j++){const t=j*Math.PI/3;mesh(pivot,new T.SphereGeometry(.027,5,4),black,x<0?-.151:.151,.12*Math.cos(t),.12*Math.sin(t));}
 const steps=[];for(let j=0;j<22;j++){const t=j*2*Math.PI/22;steps.push([0,.43*Math.cos(t),.43*Math.sin(t),1,1,1,t,0,0]);}instance(new T.BoxGeometry(.22,.018,.052),black,steps,pivot);
 wheels.push(pivot);
}
const cabin=new T.Group();scene.add(cabin);
roundedPart(cabin,1.68,.3,.43,0,1.24,-1.02,black,.05);roundedPart(cabin,1.7,.08,.4,0,1.41,-1.02,trim,.025);
for(const x of [-.38,.38]){roundedPart(cabin,.55,.12,.58,x,1.06,-.17,black,.05);roundedPart(cabin,.55,.65,.14,x,1.35,.13,black,.06);}
for(const x of [-.79,.79]){const pillar=box(cabin,.07,.69,.075,x,1.67,-.99,frameMat);pillar.rotation.x=-.25;box(cabin,.08,.11,1.35,x,1.4,-.3,trim);}
box(cabin,1.65,.07,1.35,0,2.03,-.3,frameMat);
const steeringWheel=mesh(cabin,new T.TorusGeometry(.18,.024,8,28),black,-.37,1.47,-.84);steeringWheel.rotation.x=-.3;
box(cabin,.24,.025,.022,-.37,1.47,-.84,silver);box(cabin,.31,.11,.06,-.37,1.48,-1.04,frameMat);
const gaugeMat=mat(0x25382c,{emissive:0x194d26,emissiveIntensity:.65});
for(const x of [-.44,-.30])mesh(cabin,new T.CircleGeometry(.044,16),gaugeMat,x,1.5,-1.002);
const lights=new T.Group();scene.add(lights);const headlights=[];
for(const x of [-.7,.7]){const l=new T.SpotLight(0xffe3a8,0,48,.31,.56,1.45);l.position.set(x,1.06,-2.28);l.target.position.set(x,-.6,-23);lights.add(l,l.target);headlights.push(l);}
const drone=new T.Group();scene.add(drone);const rotorGroups=[];
roundedPart(drone,.39,.20,.60,0,0,0,black,.04);roundedPart(drone,.31,.055,.40,0,.12,.04,frameMat,.015);
const lens=mesh(drone,new T.SphereGeometry(.085,16,10),glass,0,-.035,-.31);lens.scale.set(1,.85,.75);
for(const x of [-.55,.55])for(const z of [-.45,.45]){
 const arm=roundedPart(drone,.68,.055,.085,x/2,0,z*.82,black,.012);arm.rotation.y=(x*z>0?-.18:.18);
 mesh(drone,new T.CylinderGeometry(.071,.065,.11,12),silver,x,.045,z);
 const rotor=new T.Group();rotor.position.set(x,.12,z);drone.add(rotor);box(rotor,.44,.018,.05,0,0,0,black);rotorGroups.push(rotor);
 const blurMat=new T.MeshBasicMaterial({color:0xa4a8a8,transparent:true,opacity:.13,side:T.DoubleSide,depthWrite:false});const blur=mesh(drone,new T.CircleGeometry(.235,24),blurMat,x,.126,z);blur.rotation.x=-Math.PI/2;
}
const navRed=mat(0x91231d,{emissive:0xff1610,emissiveIntensity:1}),navGreen=mat(0x185b3c,{emissive:0x1eff81,emissiveIntensity:1});
mesh(drone,new T.SphereGeometry(.027,8,6),navRed,-.53,0,.42);mesh(drone,new T.SphereGeometry(.027,8,6),navGreen,.53,0,.42);
/* ---------- 5. Effects and optional lightweight post-processing ---------- */
const dustN=96,dustPos=new Float32Array(dustN*3),dustLife=new Float32Array(dustN),dustVelocity=new Float32Array(dustN*3);
for(let i=0;i<dustN;i++)dustPos[i*3+1]=-100;
const dustGeo=new T.BufferGeometry();dustGeo.setAttribute('position',new T.BufferAttribute(dustPos,3).setUsage(T.DynamicDrawUsage));
const dustC=document.createElement('canvas');dustC.width=dustC.height=32;const dg=dustC.getContext('2d'),gr=dg.createRadialGradient(16,16,0,16,16,16);gr.addColorStop(0,'rgba(185,169,143,.6)');gr.addColorStop(1,'rgba(185,169,143,0)');dg.fillStyle=gr;dg.fillRect(0,0,32,32);
const dustTex=new T.CanvasTexture(dustC);dustTex.colorSpace=T.SRGBColorSpace;
const dust=new T.Points(dustGeo,new T.PointsMaterial({map:dustTex,transparent:true,opacity:.42,size:1.15,depthWrite:false}));dust.frustumCulled=false;scene.add(dust);let dustCursor=0,dustAcc=0;
function dustTick(dt,mode,v,heading){
 if(quality>0&&Math.abs(v)>2&&mode!=='drone'&&Math.abs(car.position.x)>3.6){dustAcc+=dt*20;if(dustAcc>1){dustAcc-=1;let i=(dustCursor++%dustN),j=i*3;dustPos[j]=car.position.x+(rand()-.5)*1.4;dustPos[j+1]=.25;dustPos[j+2]=car.position.z+Math.cos(heading)*1.5;dustLife[i]=1.5+rand();dustVelocity[j]=(rand()-.5)*.8;dustVelocity[j+1]=.25+rand()*.3;dustVelocity[j+2]=Math.cos(heading)*.5;}}
 for(let i=0;i<dustN;i++){if(dustLife[i]<=0)continue;let j=i*3;dustLife[i]-=dt;dustPos[j]+=dustVelocity[j]*dt;dustPos[j+1]+=dustVelocity[j+1]*dt;dustPos[j+2]+=dustVelocity[j+2]*dt;if(dustLife[i]<=0)dustPos[j+1]=-100;}
 dustGeo.attributes.position.needsUpdate=true;dust.visible=quality>0;
}
let rt=null,post=null,postScene=null,postCam=null;
function initPost(){
 const type=renderer.extensions.has('EXT_color_buffer_float')?T.HalfFloatType:T.UnsignedByteType;
 rt=new T.WebGLRenderTarget(1,1,{type,depthBuffer:true});
 postScene=new T.Scene();postCam=new T.OrthographicCamera(-1,1,1,-1,0,2);postCam.position.z=1;
 post=new T.ShaderMaterial({uniforms:{source:{value:rt.texture},pixel:{value:new T.Vector2()},clock:{value:0}},depthTest:false,depthWrite:false,
 vertexShader:`varying vec2 uv0;void main(){uv0=uv;gl_Position=vec4(position.xy,0.,1.);}`,
 fragmentShader:`varying vec2 uv0;uniform sampler2D source;uniform vec2 pixel;uniform float clock;
 vec3 bright(vec2 uv){vec3 c=texture2D(source,uv).rgb;return c*smoothstep(.62,1.15,max(c.r,max(c.g,c.b)));}
 void main(){vec3 c=texture2D(source,uv0).rgb;vec2 d=pixel*4.;vec3 glow=bright(uv0+vec2(d.x,0.))+bright(uv0-vec2(d.x,0.))+bright(uv0+vec2(0.,d.y))+bright(uv0-vec2(0.,d.y));c+=glow*.045;
 vec2 q=uv0-.5;float vig=1.-dot(q,q)*.22;float n=fract(sin(dot(gl_FragCoord.xy+clock,vec2(12.9898,78.233)))*43758.5453)-.5;
 gl_FragColor=vec4(max(c*vig+n*.012,0.),1.);
 #include <tonemapping_fragment>
 #include <colorspace_fragment>
 }`});
 postScene.add(new T.Mesh(new T.PlaneGeometry(2,2),post));resizeRender();
}
const drawSize=new T.Vector2();
function resizeRender(){renderer.setSize(innerWidth,innerHeight);if(rt){renderer.getDrawingBufferSize(drawSize);rt.setSize(drawSize.x,drawSize.y);post.uniforms.pixel.value.set(1/drawSize.x,1/drawSize.y);}}
let videoMode=0,lastVideo=-1;
$('#video').onclick=()=>{videoMode=(videoMode+1)%3;$('#video').textContent=['Цвет','Аналог','Тепловой стиль'][videoMode];};
function videoTick(mode,chase){const active=mode==='drone'&&!chase;const video=active?videoMode:0;if(lastVideo===video)return;lastVideo=video;const f=video===1?'saturate(.68) contrast(1.08) sepia(.16)':video===2?'grayscale(1) contrast(1.65)':'none';if(renderer.domElement.style.filter!==f)renderer.domElement.style.filter=f;$('#visuals').classList.toggle('analog',video===1);}
/* ---------- 6. Adaptive rendering, without modifying movement ---------- */
const levels=[{label:'Низкое',dpr:.75,shadows:false,map:512,range:155,fog:.009},{label:'Среднее',dpr:1.1,shadows:true,map:1024,range:245,fog:.006},{label:'Высокое',dpr:1.5,shadows:true,map:2048,range:390,fog:.0042}];
function applyQuality(q){
 quality=q;const p=levels[q];renderer.setPixelRatio(Math.min(devicePixelRatio,p.dpr));renderer.shadowMap.enabled=p.shadows;sun.castShadow=p.shadows;
 if(sun.shadow.mapSize.x!==p.map){if(sun.shadow.map){sun.shadow.map.dispose();sun.shadow.map=null;}sun.shadow.mapSize.set(p.map,p.map);}
 scene.fog.density=p.fog;renderer.shadowMap.needsUpdate=true;camera.far=p.range+160;camera.updateProjectionMatrix();
 if(q===2&&!rt)initPost();resizeRender();$('#quality').textContent=(autoQuality?'Авто / ':'')+p.label.toLowerCase();
}
$('#quality').onclick=()=>{if(autoQuality){autoQuality=false;applyQuality(0);}else if(quality<2)applyQuality(quality+1);else{autoQuality=true;applyQuality(1);}qualityTimer=0;};
$('#daytime').onclick=()=>{timeIndex=(timeIndex+1)%3;applyTime();};
let qualityTimer=0,qualityCooldown=0,realFPS=60,visualSteer=0;const camFocus=new T.Vector3();
function visualsTick(dt,rawDt,steer,mode,chase,v,heading){
 elapsed+=dt;frame++;windTime.value=elapsed;skyUniform.time.value=elapsed;sky.position.copy(camera.position);
 // Geometry and cameras share the original motion state; only the cabin presentation changes.
 cabin.visible=mode!=='drone'&&!chase&&mode!=='observer';cabin.position.copy(car.position);cabin.rotation.copy(car.rotation);
 lights.position.copy(car.position);lights.rotation.copy(car.rotation);const night=timeIndex===2;headMat.emissiveIntensity=night?2.4:.08;tailMat.emissiveIntensity=night?.6:.1;
 for(const l of headlights)l.intensity=night?(quality===0?12:35):0;
 visualSteer+=((mode==='driver'?steer:0)*.31-visualSteer)*Math.min(1,dt*6);for(const hub of frontHubs)hub.rotation.y=visualSteer;
 steeringWheel.rotation.z=-visualSteer*3;
 for(const rotor of rotorGroups)rotor.rotation.y+=dt*55;
 navRed.emissiveIntensity=Math.sin(elapsed*8)>0?1.6:.2;navGreen.emissiveIntensity=1.2;
 if(frame%10===1){const range=levels[quality].range;for(const v of vegetation){const d=Math.abs(camera.position.z-v.z);v.group.visible=d<range+60;v.near.visible=d<(quality===2?160:85)&&quality>0;v.far.visible=!v.near.visible;v.grass.visible=quality>0&&d<(quality===2?110:65);v.bush.visible=d<120;}}
 if(quality>0&&frame%(quality===2?3:5)===1){camFocus.set(Math.round(camera.position.x/8)*8,0,Math.round(camera.position.z/8)*8);sun.target.position.copy(camFocus);sun.position.copy(camFocus).add(sunOffset);renderer.shadowMap.needsUpdate=true;}
 // Set sun location even with shadows off.
 if(quality===0){sun.target.position.set(0,0,0);sun.position.copy(sunOffset);}
 dustTick(dt,mode,v,heading);videoTick(mode,chase);
 const instantaneous=1/Math.max(rawDt,.001);realFPS+=(instantaneous-realFPS)*.04;
 qualityTimer+=rawDt;qualityCooldown=Math.max(0,qualityCooldown-rawDt);
 if(autoQuality&&qualityTimer>3&&qualityCooldown===0){if(realFPS<43&&quality>0){applyQuality(quality-1);qualityCooldown=7;}else if(realFPS>57&&quality<1){applyQuality(1);qualityCooldown=10;}qualityTimer=0;}
}
function renderVisuals(){
 if(quality===2&&rt){renderer.setRenderTarget(rt);renderer.render(scene,camera);renderer.setRenderTarget(null);post.uniforms.clock.value=elapsed;renderer.render(postScene,postCam);}else renderer.render(scene,camera);
}
// Height-dependent atmospheric haze on standard and physical surfaces.
const foggedMaterials=new Set();
scene.traverse(obj=>{if(!obj.isMesh||!obj.material)return;const materials=Array.isArray(obj.material)?obj.material:[obj.material];
 for(const m of materials){if(!m.isMeshStandardMaterial||foggedMaterials.has(m))continue;foggedMaterials.add(m);
 const old=m.onBeforeCompile,oldKey=m.customProgramCacheKey();
 m.onBeforeCompile=function(sh,renderer){
 old.call(this,sh,renderer);
 sh.vertexShader='varying float vHeightFog;\n'+sh.vertexShader;
 sh.vertexShader=sh.vertexShader.replace('#include <project_vertex>',`#include <project_vertex>
 vec4 fogWorld=vec4(transformed,1.);
 #ifdef USE_INSTANCING
 fogWorld=instanceMatrix*fogWorld;
 #endif
 vHeightFog=(modelMatrix*fogWorld).y;`);
 sh.fragmentShader='varying float vHeightFog;\n'+sh.fragmentShader;
 sh.fragmentShader=sh.fragmentShader.replace('#include <fog_fragment>',`
 #ifdef USE_FOG
 #ifdef FOG_EXP2
 float heightScale=mix(1.30,.58,smoothstep(0.,35.,vHeightFog));
 float fd=fogDensity*vFogDepth*heightScale;
 float fogFactor=1.-exp(-fd*fd);
 #else
 float fogFactor=smoothstep(fogNear,fogFar,vFogDepth);
 #endif
 gl_FragColor.rgb=mix(gl_FragColor.rgb,fogColor,fogFactor);
 #endif
 `);
 };m.customProgramCacheKey=()=>oldKey+'|height-haze-v1';m.needsUpdate=true;
 }});
applyTime();applyQuality(1);$('#notice').style.display='none';
return {renderer,scene,camera,car,drone,wheels,resizeRender,visualsTick,renderVisuals};
}
