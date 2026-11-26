using UnityEngine;
namespace R280 {
    public sealed class PrototypeGame : MonoBehaviour {
        enum Role { Menu, Pickup, Van, Flight }
        Role role;
        readonly LocalInput input=new LocalInput();
        IControllable controlled;
        GameObject activeObject;
        Camera view;
        float yaw, pitch, reticleY;
        int seat, quality=1;
        bool paused;
        float sensitivity=1f;
        GUIStyle heading, bodyText, small, button, green;
        Texture2D white;
        Material paint, dark, glass, road, ground, light, gravel;
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void StartGame() {
            if(FindFirstObjectByType<PrototypeGame>()==null)
                new GameObject("R-280 Runtime").AddComponent<PrototypeGame>();
        }
        void Awake() {
            Application.targetFrameRate=30;
            QualitySettings.vSyncCount=0;
            Time.fixedDeltaTime=.02f;
            Screen.orientation=ScreenOrientation.LandscapeLeft;
            Shader shader=Shader.Find("Standard") ?? Shader.Find("Diffuse");
            paint=Mat(shader,new Color(.31f,.36f,.24f)); dark=Mat(shader,new Color(.08f,.09f,.09f));
            glass=Mat(shader,new Color(.19f,.31f,.34f)); road=Mat(shader,new Color(.19f,.20f,.20f));
            ground=Mat(shader,new Color(.37f,.43f,.29f)); light=Mat(shader,new Color(.85f,.83f,.68f));
            gravel=Mat(shader,new Color(.46f,.40f,.31f));
            MakeWorld();
            view=new GameObject("Player Camera").AddComponent<Camera>();
            view.nearClipPlane=.12f; view.farClipPlane=850;
            view.fieldOfView=65; view.clearFlags=CameraClearFlags.Skybox;
            view.gameObject.AddComponent<AudioListener>();
            view.transform.SetPositionAndRotation(new Vector3(12,7,-17),Quaternion.Euler(15,-26,0));
            SetQuality(1);
        }
        Material Mat(Shader s,Color c) { var m=new Material(s); m.color=c; return m; }
        GameObject Shape(PrimitiveType type,string n,Transform parent,Vector3 pos,Vector3 scale,Material m,bool collider=false) {
            var go=GameObject.CreatePrimitive(type); go.name=n;
            go.transform.SetParent(parent,false); go.transform.localPosition=pos; go.transform.localScale=scale;
            go.GetComponent<Renderer>().sharedMaterial=m;
            if(!collider) { var c=go.GetComponent<Collider>(); c.enabled=false; Destroy(c); }
            return go;
        }
        void MakeWorld() {
            Transform world=new GameObject("Test Range").transform;
            Shape(PrimitiveType.Cube,"Ground",world,new Vector3(0,-.55f,0),new Vector3(600,1,600),ground,true);
            Shape(PrimitiveType.Cube,"Asphalt",world,new Vector3(0,-.025f,0),new Vector3(9,.05f,560),road,true);
            Shape(PrimitiveType.Cube,"Gravel strip",world,new Vector3(9,-.025f,0),new Vector3(7,.05f,560),gravel,true);
            for(int i=-14;i<=14;i++) Shape(PrimitiveType.Cube,"Road paint",world,new Vector3(0,.008f,i*18),new Vector3(.12f,.015f,6),light);
            var sun=new GameObject("Sun").AddComponent<Light>();
            sun.type=LightType.Directional; sun.intensity=1.1f; sun.shadows=LightShadows.Soft;
            sun.transform.rotation=Quaternion.Euler(48,-35,0);
            RenderSettings.ambientLight=new Color(.52f,.54f,.57f);
            RenderSettings.fog=true; RenderSettings.fogColor=new Color(.67f,.73f,.75f);
            RenderSettings.fogMode=FogMode.Linear; RenderSettings.fogStartDistance=160; RenderSettings.fogEndDistance=600;
            for(int i=0;i<20;i++) {
                float z=-230+i*24;
                Shape(PrimitiveType.Cylinder,"Trunk",world,new Vector3(-22,1.5f,z),new Vector3(.65f,1.5f,.65f),gravel);
                Shape(PrimitiveType.Sphere,"Canopy",world,new Vector3(-22,4.5f,z),new Vector3(4,5,4),paint);
                if(i%4==0) Shape(PrimitiveType.Cube,"Shed",world,new Vector3(30,2,z),new Vector3(6,4,8),gravel,true);
            }
        }
        void Spawn(Role selected) {
            if(activeObject!=null) { activeObject.SetActive(false); Destroy(activeObject); }
            role=selected; seat=0; yaw=pitch=reticleY=0; paused=false;
            Time.timeScale=1;
            activeObject=new GameObject(selected.ToString());
            var root=activeObject.transform;
            if(selected==Role.Flight) {
                root.position=new Vector3(0,22,-110);
                Shape(PrimitiveType.Cube,"Body",root,new Vector3(0,0,0),new Vector3(.55f,.38f,2.5f),dark,true);
                Shape(PrimitiveType.Cube,"Wing",root,new Vector3(0,0,-.2f),new Vector3(3.3f,.09f,.6f),dark);
                Shape(PrimitiveType.Cube,"Tail",root,new Vector3(0,.15f,-1.1f),new Vector3(1.05f,.08f,.38f),dark);
                Shape(PrimitiveType.Cube,"Fin",root,new Vector3(0,.35f,-1.1f),new Vector3(.08f,.55f,.38f),dark);
                var f=activeObject.AddComponent<FlightVehicle>(); f.Configure(); f.ResetPose(); controlled=f;
            } else {
                root.position=new Vector3(2,.85f,-30);
                bool van=selected==Role.Van;
                Shape(PrimitiveType.Cube,"Chassis",root,new Vector3(0,0,0),new Vector3(1.9f,.6f,4.7f),paint,true);
                Shape(PrimitiveType.Cube,"Cab",root,new Vector3(0,.65f,van?1.05f:.55f),new Vector3(1.8f,1.1f,van?2.3f:1.65f),paint,true);
                Shape(PrimitiveType.Cube,"Windscreen",root,new Vector3(0,.75f,van?2.22f:1.39f),new Vector3(1.65f,.55f,.05f),glass);
                Shape(PrimitiveType.Cube,"Bed",root,new Vector3(0,.38f,-1.35f),new Vector3(1.8f,.18f,1.7f),dark);
                for(int j=-1;j<=1;j+=2) Shape(PrimitiveType.Cube,"Bed rail",root,new Vector3(j*.87f,.61f,-1.38f),new Vector3(.10f,.42f,1.7f),paint);
                WheelCollider[] wc=new WheelCollider[4]; Transform[] wm=new Transform[4];
                for(int i=0;i<4;i++) {
                    float x=i%2==0?-.94f:.94f, z=i<2?1.48f:-1.48f;
                    GameObject hub=new GameObject("Wheel collider "+i); hub.transform.SetParent(root,false); hub.transform.localPosition=new Vector3(x,-.27f,z);
                    wc[i]=hub.AddComponent<WheelCollider>(); wc[i].radius=.43f; wc[i].mass=35; wc[i].suspensionDistance=.24f;
                    var spring=wc[i].suspensionSpring; spring.spring=31000; spring.damper=4200; spring.targetPosition=.5f; wc[i].suspensionSpring=spring;
                    wm[i]=Shape(PrimitiveType.Cylinder,"Wheel "+i,root,new Vector3(x,-.27f,z),new Vector3(.86f,.15f,.86f),dark).transform;
                }
                var g=activeObject.AddComponent<GroundVehicle>(); g.Configure(wc,wm); controlled=g;
            }
        }
        void Update() {
            if(role==Role.Menu) return;
            if(Input.GetKeyDown(KeyCode.Escape)) paused=!paused;
            if(Input.GetKeyDown(KeyCode.R)) controlled.ResetPose();
            if(Input.GetKeyDown(KeyCode.C)) seat=(seat+1)%(role==Role.Flight?2:4);
            Time.timeScale=paused?0:1;
            input.Poll(!paused);
            if(paused) {controlled.Apply(default);return;}
            controlled.Apply(new PlayerCommand{Move=input.Move,Look=input.Look*sensitivity,Brake=input.Brake});
            if(role==Role.Flight) reticleY=Mathf.MoveTowards(reticleY,Mathf.Clamp(input.Look.y*sensitivity,-1,1),Time.deltaTime*2f);
            else {
                yaw=Mathf.Clamp(yaw+input.Look.x*70*Time.deltaTime*sensitivity,-110,110);
                pitch=Mathf.Clamp(pitch-input.Look.y*55*Time.deltaTime*sensitivity,-28,45);
            }
        }
        void LateUpdate() {
            if(controlled==null || paused) return;
            Transform t=controlled.Anchor;
            Vector3 p; Quaternion q;
            if(role==Role.Flight && seat==0) {
                p=t.TransformPoint(new Vector3(0,.08f,1.34f)); q=t.rotation;
            } else if(role==Role.Flight) {
                p=t.TransformPoint(new Vector3(0,2,-5)); q=Quaternion.LookRotation(t.position+t.forward*4-p,Vector3.up);
            } else if(seat==0) {
                q=Quaternion.Euler(12+pitch,t.eulerAngles.y+yaw,0);
                p=t.position+Vector3.up*1.8f-q*Vector3.forward*7;
                view.transform.position=Vector3.Lerp(view.transform.position,p,1-Mathf.Exp(-10*Time.deltaTime));
                view.transform.rotation=q; return;
            } else {
                Vector3 offset=seat==1?new Vector3(-.35f,1.15f,1.0f):seat==2?new Vector3(0,1.65f,-1.1f):new Vector3(.35f,1.28f,.9f);
                p=t.TransformPoint(offset); q=t.rotation*Quaternion.Euler(pitch,yaw,0);
            }
            view.transform.SetPositionAndRotation(p,q);
        }
        void SetQuality(int q) {
            quality=q; QualitySettings.shadowDistance=q==0?0:q==1?45:85;
            QualitySettings.antiAliasing=q==2?2:0; Application.targetFrameRate=q==2?60:30;
        }
        void Styles() {
            if(white!=null)return;
            white=Texture2D.whiteTexture;
            heading=new GUIStyle(GUI.skin.label){fontSize=38,fontStyle=FontStyle.Bold,alignment=TextAnchor.MiddleCenter};
            bodyText=new GUIStyle(GUI.skin.label){fontSize=19,alignment=TextAnchor.MiddleCenter};
            small=new GUIStyle(GUI.skin.label){fontSize=16,alignment=TextAnchor.MiddleCenter};
            button=new GUIStyle(GUI.skin.button){fontSize=20};
            green=new GUIStyle(small); green.normal.textColor=new Color(.38f,1,.48f);
        }
        void Bar(Rect r,Color c) {var old=GUI.color;GUI.color=c;GUI.DrawTexture(r,white);GUI.color=old;}
        void Menu() {
            Bar(new Rect(0,0,960,540),new Color(.02f,.035f,.04f,.86f));
            GUI.Label(new Rect(0,34,960,64),"R-280  /  FIELD PROTOTYPE",heading);
            GUI.Label(new Rect(0,105,960,34),"SELECT ROLE   ·   STAGE 01",bodyText);
            if(GUI.Button(new Rect(105,174,350,68),"MOG  /  Pickup",button)) Spawn(Role.Pickup);
            if(GUI.Button(new Rect(105,255,350,68),"MOG  /  Utility van",button)) Spawn(Role.Van);
            if(GUI.Button(new Rect(505,174,350,149),"UAV  /  Hornet (prototype)",button)) Spawn(Role.Flight);
            GUI.Label(new Rect(105,345,750,32),"Graphics:  "+new[]{"LOW","MEDIUM","HIGH"}[quality],bodyText);
            for(int i=0;i<3;i++) if(GUI.Button(new Rect(262+i*150,386,140,40),new[]{"LOW","MEDIUM","HIGH"}[i],button)) SetQuality(i);
            GUI.Label(new Rect(0,458,960,34),"Temporary geometry · fictional flight tuning · no combat",small);
        }
        void Hud() {
            float speed=role==Role.Flight?((FlightVehicle)controlled).Speed:((GroundVehicle)controlled).Speed;
            Bar(new Rect(0,0,960,54),new Color(.03f,.05f,.06f,.75f));
            GUI.Label(new Rect(12,3,190,46),role==Role.Flight?"UAV / FLIGHT":"MOG / VEHICLE",bodyText);
            GUI.Label(new Rect(205,3,280,46),$"{speed:0} km/h    ALT {controlled.Anchor.position.y:0} m",bodyText);
            if(GUI.Button(new Rect(620,6,100,40),"VIEW",button)) {seat=(seat+1)%(role==Role.Flight?2:4); yaw=pitch=0;}
            if(GUI.Button(new Rect(727,6,100,40),"RESET",button)) controlled.ResetPose();
            if(GUI.Button(new Rect(834,6,115,40),paused?"RESUME":"PAUSE",button)) paused=!paused;
            Color g=new Color(.35f,1,.45f,.85f);
            if(role==Role.Flight && seat==0) {
                Bar(new Rect(185,268,247,2),g); Bar(new Rect(528,268,247,2),g);
                for(int i=0;i<48;i++){float a=i*Mathf.PI*2/48;Bar(new Rect(479+Mathf.Cos(a)*38,269+Mathf.Sin(a)*38,2,2),g);}
                float y=270-reticleY*95;
                Bar(new Rect(465,y-1,30,2),g); Bar(new Rect(479,y-15,2,30),g);
            }
            string viewName=role==Role.Flight?(seat==0?"CAMERA":"CHASE"):new[]{"CHASE","DRIVER","GUNNER VIEW","COMMANDER VIEW"}[seat];
            GUI.Label(new Rect(310,62,340,32),viewName,small);
            Bar(new Rect(34,357,148,148),new Color(.05f,.07f,.08f,.35f));
            Bar(new Rect(778,357,148,148),new Color(.05f,.07f,.08f,.35f));
            Bar(new Rect(100+input.Move.x*47,423-input.Move.y*47,16,16),g);
            Bar(new Rect(844+input.Look.x*47,423-input.Look.y*47,16,16),g);
            GUI.Label(new Rect(34,480,148,30),role==Role.Flight?"THROTTLE / BANK":"DRIVE / STEER",small);
            GUI.Label(new Rect(778,480,148,30),role==Role.Flight?"PITCH":"LOOK",small);
            GUI.Label(new Rect(415,440,130,54),"HOLD BRAKE",small);
            if(paused) {
                Bar(new Rect(0,54,960,486),new Color(.01f,.02f,.03f,.86f));
                GUI.Label(new Rect(0,126,960,60),"PAUSED",heading);
                GUI.Label(new Rect(270,205,420,35),$"Sensitivity {sensitivity:0.0}",bodyText);
                sensitivity=GUI.HorizontalSlider(new Rect(300,245,360,22),sensitivity,.4f,2.5f);
                if(GUI.Button(new Rect(330,290,300,54),"RESUME",button)) paused=false;
                if(GUI.Button(new Rect(330,356,300,54),"ROLE MENU",button)) {
                    activeObject.SetActive(false);Destroy(activeObject);activeObject=null;controlled=null;role=Role.Menu;paused=false;Time.timeScale=1;
                    view.transform.SetPositionAndRotation(new Vector3(12,7,-17),Quaternion.Euler(15,-26,0));
                }
            }
        }
        void OnGUI() {
            Styles();
            Matrix4x4 previous=GUI.matrix;
            GUI.matrix=Matrix4x4.TRS(Vector3.zero,Quaternion.identity,new Vector3(Screen.width/960f,Screen.height/540f,1));
            if(role==Role.Menu) Menu();else Hud();
            GUI.matrix=previous;
        }
        void OnDestroy(){Time.timeScale=1;}
    }
}
