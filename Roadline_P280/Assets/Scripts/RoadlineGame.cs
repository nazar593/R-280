using System.Collections.Generic;
using UnityEngine;

namespace Roadline
{
    public sealed class RoadlineGame : MonoBehaviour
    {
        enum Mode { Menu, Escort, Observer, Result }
        Mode mode;
        RouteWorld route;
        Camera view;
        MobileInput input;
        EscortVehicle vehicle;
        HornetFlight drone;
        Transform alliedVehicle, scout;
        bool scoutLinked;
        AudioSource pickupEngine;
        TrafficTruck freight;
        readonly List<TrafficTruck> convoy = new();
        readonly List<Obstacle> obstacles = new();
        readonly List<GameObject> owned = new();
        readonly List<Shot> shots = new();
        readonly RaycastHit[] shotHits = new RaycastHit[24];
        static readonly float[] Intervals = {.122f,.26f,.38f};
        static readonly float[] Strength = {.20f,.34f,.50f};
        static readonly string[] Loadouts = {"2 × 12,7", "20 мм", "23 мм"};
        static readonly string[] Presets = {"Низкое","Среднее","Высокое"};
        static readonly string[] Times = {"День","Закат","Ночь"};
        static readonly Color Gold = new Color(.97f,.77f,.40f);
        static readonly Color Green = new Color(.40f,1f,.57f,.92f);
        static readonly Color Steel = new Color(.79f,.82f,.80f);
        static readonly Color Ink = new Color(.055f,.075f,.079f,.91f);
        bool van, wet, map, cab, thirdPerson, won;
        int loadout, quality, timeOfDay, reached;
        float orbit, pitch, recoil, nextAction, alliedDistance;
        float noticeUntil;
        string notice;
        GUIStyle heading, text, button, centered, tiny;

        sealed class Obstacle
        {
            public GameObject Root;
            public Transform Target;
            public float Distance, Health = 1, NextPulse, NextEscortPulse;
            public bool Spotted;
        }

        struct Shot
        {
            public Vector3 Position, Velocity;
            public float Remaining, Strength, TraceAt;
        }

        void Awake()
        {
            Screen.orientation = ScreenOrientation.LandscapeLeft;
            Input.simulateMouseWithTouches = true;
            input = gameObject.AddComponent<MobileInput>();
            input.Active = false;
            route = new RouteWorld();
            view = new GameObject("Main Camera").AddComponent<Camera>();
            view.gameObject.tag = "MainCamera";
            view.gameObject.AddComponent<AudioListener>();
            view.clearFlags = CameraClearFlags.SolidColor;
            view.nearClipPlane = .07f;
            view.farClipPlane = 950;
            view.fieldOfView = 65;
            quality = Mathf.Clamp(PlayerPrefs.GetInt("road.quality",1),0,2);
            wet = PlayerPrefs.GetInt("road.rain",0) == 1;
            timeOfDay = Mathf.Clamp(PlayerPrefs.GetInt("road.time",1),0,2);
            ApplyQuality();
            ApplyWeather();
            PresentRoad();
        }

        void PresentRoad()
        {
            route.Pose(route.Data.start,0,out var point,out var facing);
            view.transform.position = point + facing * new Vector3(12,8,-16);
            view.transform.LookAt(route.At(route.Data.start+42)+Vector3.up*2);
        }

        void Menu()
        {
            foreach (GameObject obj in owned)
            {
                if (!obj) continue;
                obj.SetActive(false);
                Destroy(obj);
            }
            owned.Clear();
            convoy.Clear();
            obstacles.Clear();
            shots.Clear();
            vehicle = null;
            drone = null;
            alliedVehicle = null;
            scout = null;
            scoutLinked = false;
            mode = Mode.Menu;
            input.Active = false;
            input.ResetInput();
            map = false;
            PresentRoad();
        }

        void StartScenario(bool observer)
        {
            Menu();
            reached = 0;
            orbit = 0;
            pitch = 10;
            recoil = 0;
            noticeUntil = 0;
            nextAction = 0;
            cab = false;
            thirdPerson = false;
            route.Pose(route.Data.start,RouteWorld.Lane,out var start,out var heading);
            freight = AddTruck(route.Data.start+34,1,FleetVisuals.Cargo.Canvas,0,true);
            for (int i=0;i<10;i++)
            {
                int direction = i%3==0 ? 1 : -1;
                float d = direction>0 ? route.Data.start+105+i*100 : 145+i*138;
                AddTruck(d,direction,(FleetVisuals.Cargo)(i%4),i+1);
            }
            foreach (var hazard in route.Data.hazards)
                obstacles.Add(CreateObstacle(hazard));

            mode = observer ? Mode.Observer : Mode.Escort;
            input.Active = true;
            input.ResetInput();
            if (observer)
            {
                drone = HornetFlight.Create(start+Vector3.up*19,heading,input);
                drone.Relay = start+Vector3.up*2;
                drone.Windy = wet;
                owned.Add(drone.gameObject);
                alliedVehicle = new GameObject("МОГ | AI").transform;
                FleetVisuals.Vehicle(alliedVehicle,van,loadout);
                foreach (float x in new[] {-.91f,.91f})
                foreach (float z in new[] {-1.52f,1.52f})
                    MeshLibrary.Spawn("wheel",alliedVehicle).transform.localPosition = new Vector3(x,.35f,z);
                alliedDistance = route.Data.start;
                alliedVehicle.SetPositionAndRotation(start,heading);
                owned.Add(alliedVehicle.gameObject);
                view.transform.SetPositionAndRotation(drone.transform.position,heading);
            }
            else
            {
                vehicle = EscortVehicle.Create(start+Vector3.up*.12f,heading,input,van,loadout);
                vehicle.Grip = wet ? .71f : 1;
                pickupEngine = Sounds.Loop(vehicle.transform,Sounds.Engine,2,75,.27f);
                owned.Add(vehicle.gameObject);
                scout = MeshLibrary.Spawn("hornet",null).transform;
                scout.SetPositionAndRotation(start+Vector3.up*17,heading);
                owned.Add(scout.gameObject);
                view.transform.SetPositionAndRotation(start+heading*new Vector3(0,3,-7),heading);
            }
        }

        TrafficTruck AddTruck(float distance,int direction,FleetVisuals.Cargo type,int livery,bool primary = false)
        {
            var truck = new TrafficTruck(route,distance,direction,type,livery,primary);
            convoy.Add(truck);
            owned.Add(truck.Tractor);
            if (truck.Trailer) owned.Add(truck.Trailer);
            return truck;
        }

        Obstacle CreateObstacle(RouteWorld.Hazard hazard)
        {
            Vector3 point = route.At(hazard.distance,Mathf.Sign(hazard.side)*8.3f);
            point.y = .16f;
            var obj = new GameObject("Фиктивная автоматическая турель");
            obj.transform.position = point;
            var shell = MeshLibrary.MaterialFor("target armor",new Color(.27f,.31f,.33f),.32f);
            var light = MeshLibrary.MaterialFor("target emitter",new Color(.93f,.32f,.17f));
            Visuals.Box("Stabilizer",obj.transform,new Vector3(0,.26f,0),new Vector3(1.75f,.51f,1.65f),shell,true);
            var core = Visuals.Shape("Chassis",PrimitiveType.Sphere,obj.transform,new Vector3(0,1.05f,0),
                new Vector3(1.48f,.95f,1.40f),shell,true);
            Visuals.Box("Orange band",obj.transform,new Vector3(0,1.11f,.59f),new Vector3(.61f,.15f,.18f),light);
            Visuals.Box("Orange band",obj.transform,new Vector3(0,1.11f,-.59f),new Vector3(.61f,.15f,.18f),light);
            owned.Add(obj);
            return new Obstacle {Root=obj,Target=core.transform,Distance=hazard.distance};
        }

        bool Active => mode == Mode.Escort || mode == Mode.Observer;

        void Update()
        {
            if (!Active) return;
            if (Input.GetKeyDown(KeyCode.Escape)) { if (map) ToggleMap(); else Menu(); return; }
            if (Input.GetKeyDown(KeyCode.Tab)) ToggleMap();
            if (Input.GetKeyDown(KeyCode.V)) ToggleView();
            if (Input.GetKeyDown(KeyCode.C) && vehicle) ToggleSeat();
            if (Input.GetKeyDown(KeyCode.R)) RecoverVehicle();
            if (Input.GetKeyDown(KeyCode.F)) Action();
            if (!map && vehicle && vehicle.Gunner && (Input.GetMouseButtonDown(0) && !Application.isMobilePlatform))
            {
                if (CameraButtonRegion(Input.mousePosition)) Action();
            }
            recoil *= Mathf.Exp(-15*Time.deltaTime);
            if (pickupEngine) pickupEngine.pitch = .72f+Mathf.Clamp01(vehicle.Body.linearVelocity.magnitude/26)*.74f;
        }

        void RecoverVehicle()
        {
            if (!vehicle) return;
            route.Pose(Mathf.Clamp(route.Nearest(vehicle.transform.position),route.Data.start-10,route.Data.finish),RouteWorld.Lane,
                out var point,out var facing);
            vehicle.Recover(point+Vector3.up*.13f,facing);
        }

        bool CameraButtonRegion(Vector3 point) => point.y>Screen.height*.20f && point.y<Screen.height*.87f;

        void FixedUpdate()
        {
            if (!Active) return;
            float dt = Time.fixedDeltaTime;
            StepShots(dt);
            Obstacle next = null;
            foreach (var obstacle in obstacles)
            {
                if (obstacle.Health <= 0 || obstacle.Distance+17 < freight.Distance) continue;
                next = obstacle;
                break;
            }

            foreach (var truck in convoy)
            {
                float gap = float.PositiveInfinity;
                foreach (var other in convoy) gap = Mathf.Min(gap,truck.GapTo(other));
                if (truck == freight && next != null) gap = Mathf.Min(gap,next.Distance+19-freight.Distance);
                truck.Tick(dt,gap,wet);
            }
            if (alliedVehicle)
            {
                alliedDistance = Mathf.MoveTowards(alliedDistance,freight.Distance-20,dt*18.0f);
                route.Pose(alliedDistance,RouteWorld.Lane,out var pos,out var rot);
                alliedVehicle.SetPositionAndRotation(pos,rot);
                drone.Relay = pos+Vector3.up*2.8f;
                if (next != null && next.Spotted && drone.Signal>.18f &&
                    next.Distance-alliedDistance<78 && Time.time>=next.NextEscortPulse)
                {
                    next.NextEscortPulse = Time.time+.72f;
                    Vector3 from = pos+Vector3.up*1.9f;
                    Effects.Trace(from,next.Target.position,Gold);
                    AudioSource.PlayClipAtPoint(Sounds.Pulse,from,.28f);
                    DamageObstacle(next,.33f);
                }
            }

            if (scout)
            {
                route.Pose(freight.Distance+48,0,out var pos,out var rot);
                scout.SetPositionAndRotation(pos+Vector3.up*(wet ? 22 : 16),rot);
                var receiver = vehicle.transform.position+Vector3.up*2.45f;
                scoutLinked = (scout.position-receiver).sqrMagnitude<230*230 && !Physics.Linecast(scout.position,receiver);
                if (next != null && scoutLinked && !next.Spotted && next.Distance-freight.Distance<120)
                {
                    var point = next.Target.position;
                    if (!Physics.Linecast(scout.position,point,out var hit) || hit.transform.IsChildOf(next.Root.transform))
                    {
                        next.Spotted = true;
                        Tell("Hornet передал метку на планшет");
                    }
                }
            }

            foreach (var obstacle in obstacles)
            {
                if (obstacle.Health<=0 || Mathf.Abs(obstacle.Distance-freight.Distance)>25) continue;
                if (Time.time < obstacle.NextPulse) continue;
                obstacle.NextPulse = Time.time+6.8f;
                var hit = freight.Position+Vector3.up*1.1f;
                Effects.Trace(obstacle.Target.position,hit,new Color(1,.34f,.21f));
                Effects.Burst(hit,true);
                AudioSource.PlayClipAtPoint(Sounds.Impact,hit,.65f);
                freight.Damage(TruckPart.Zone.Cab,.135f);
                TrafficAlert(hit);
            }

            while (reached < route.Data.landmarks.Length && freight.Distance>=route.Data.landmarks[reached].distance)
                reached++;
            if (freight.Lost) End(false);
            else if (freight.Distance >= route.Data.finish) End(true);
        }

        void TrafficAlert(Vector3 point)
        {
            foreach (var truck in convoy)
                if (!truck.MissionTruck && (truck.Position-point).sqrMagnitude<80*80) truck.Alert();
        }

        void DamageObstacle(Obstacle obstacle,float amount)
        {
            obstacle.Health -= amount;
            if (obstacle.Health>0)
            {
                Effects.Burst(obstacle.Target.position,false);
                return;
            }
            var point = obstacle.Target.position;
            Effects.Burst(point,true);
            AudioSource.PlayClipAtPoint(Sounds.Impact,point,.67f);
            obstacle.Root.SetActive(false);
            TrafficAlert(point);
            Tell("Участок очищен");
        }

        void Action()
        {
            if (map || Time.time<nextAction) return;
            if (mode == Mode.Observer && drone)
            {
                nextAction = Time.time+1.1f;
                if (drone.Signal<.18f) { Tell("Нет связи с МОГ"); return; }
                Obstacle best = null;
                float bestScore = .21f;
                foreach (var target in obstacles)
                {
                    if (target.Health<=0 || target.Spotted) continue;
                    Vector3 pos = target.Target.position;
                    if ((pos-drone.transform.position).sqrMagnitude>300*300) continue;
                    var aim = view.WorldToViewportPoint(pos);
                    if (aim.z<=0) continue;
                    float score = Vector2.Distance(new Vector2(.5f,.5f-ReticleDisplacement()/720f),new Vector2(aim.x,aim.y));
                    if (score>=bestScore) continue;
                    if (Physics.Linecast(drone.transform.position+Vector3.up*.5f,pos,out var hit) &&
                        !hit.transform.IsChildOf(target.Root.transform)) continue;
                    bestScore = score;
                    best = target;
                }
                if (best == null) { Tell("Наведи камеру на оранжевый маяк"); return; }
                best.Spotted = true;
                AudioSource.PlayClipAtPoint(Sounds.Scan,view.transform.position,.29f);
                Tell("Метка передана экипажу");
            }
            else if (mode == Mode.Escort && vehicle && vehicle.Gunner)
            {
                int profile = vehicle.Profile;
                nextAction = Time.time+Intervals[profile];
                recoil = 1f;
                var ray = view.ViewportPointToRay(new Vector3(.5f,.5f,0));
                var source = vehicle.Mount.TransformPoint(new Vector3(0,.86f,1.17f));
                Vector3 endpoint = AimPoint(ray);
                Vector3 normal = endpoint-source;
                if (normal.sqrMagnitude<.01f) normal = ray.direction;
                shots.Add(new Shot
                {
                    Position = source,
                    Velocity = normal.normalized*92f+Vector3.up*1.2f,
                    Remaining = 1.52f,
                    Strength = Strength[profile],
                    TraceAt = Time.time
                });
                Effects.Burst(source,false);
                AudioSource.PlayClipAtPoint(Sounds.Pulse,source,.44f);
                TrafficAlert(source);
            }
        }

        Vector3 AimPoint(Ray ray)
        {
            return FindImpact(ray,120,out var hit) ? hit.point : ray.GetPoint(120);
        }

        bool FindImpact(Ray ray,float length,out RaycastHit closest)
        {
            closest = default;
            float best = length+1;
            int count = Physics.RaycastNonAlloc(ray,shotHits,length,Physics.DefaultRaycastLayers,QueryTriggerInteraction.Ignore);
            for (int i=0;i<count;i++)
            {
                var hit = shotHits[i];
                if ((vehicle && hit.transform.IsChildOf(vehicle.transform)) || hit.distance>=best) continue;
                closest = hit;
                best = hit.distance;
            }
            return best<=length;
        }

        void StepShots(float dt)
        {
            for (int i=shots.Count-1;i>=0;i--)
            {
                Shot shot = shots[i];
                Vector3 move = shot.Velocity*dt;
                var ray = new Ray(shot.Position,move.normalized);
                if (FindImpact(ray,move.magnitude,out var hit))
                {
                    foreach (var obstacle in obstacles)
                    {
                        if (obstacle.Health<=0 || !hit.transform.IsChildOf(obstacle.Root.transform)) continue;
                        float retainedEnergy = Mathf.Clamp01(shot.Remaining/.93f);
                        DamageObstacle(obstacle,shot.Strength*Mathf.Lerp(.66f,1f,retainedEnergy));
                        break;
                    }
                    if (hit.collider.TryGetComponent<TruckPart>(out var part))
                    {
                        float resistance = part.Location==TruckPart.Zone.Trailer ? .20f : .31f;
                        part.Owner.Damage(part.Location,shot.Strength*resistance);
                    }
                    Effects.Burst(hit.point,false);
                    Effects.Trace(shot.Position,hit.point,Gold);
                    shots.RemoveAt(i);
                    continue;
                }
                Vector3 end = shot.Position+move;
                if (Time.time>=shot.TraceAt)
                {
                    Effects.Trace(shot.Position,end,Gold);
                    shot.TraceAt = Time.time+.05f;
                }
                shot.Velocity += Vector3.down*3.3f*dt;
                shot.Velocity *= 1f-.07f*dt;
                shot.Position = end;
                shot.Remaining -= dt;
                if (shot.Remaining<=0) shots.RemoveAt(i);
                else shots[i]=shot;
            }
        }

        float ReticleDisplacement() => Mathf.Clamp((drone.Pitch-10)*2.75f,-105,105);

        void Tell(string text)
        {
            notice = text;
            noticeUntil = Time.time+2.5f;
        }

        void End(bool success)
        {
            won = success;
            mode = Mode.Result;
            input.Active = false;
            input.ResetInput();
            map = false;
        }

        void ToggleMap()
        {
            map = !map;
            input.ResetInput();
            input.Active = !map;
        }

        void ToggleSeat()
        {
            if (!vehicle) return;
            vehicle.Gunner = !vehicle.Gunner;
            orbit = 0;
            pitch = vehicle.Gunner ? 2 : 10;
            vehicle.Mount.localRotation = Quaternion.identity;
        }

        void ToggleView()
        {
            if (mode == Mode.Observer) thirdPerson = !thirdPerson;
            else if (vehicle && !vehicle.Gunner) cab = !cab;
        }

        void LateUpdate()
        {
            if (!Active) return;
            Vector2 look = input.Look;
            if (vehicle)
            {
                Transform root = vehicle.transform;
                orbit = Mathf.Repeat(orbit+look.x*.18f+180,360)-180;
                pitch = Mathf.Clamp(pitch-look.y*.15f,-19,46);
                Quaternion facing = Quaternion.Euler(pitch,root.eulerAngles.y+orbit,0);
                if (vehicle.Gunner)
                {
                    vehicle.Mount.localRotation = Quaternion.Euler(0,orbit,0);
                    var seat = vehicle.Mount.position + Vector3.up*.82f;
                    view.transform.SetPositionAndRotation(seat,facing*Quaternion.Euler(-recoil*2.3f,0,0));
                }
                else if (cab)
                {
                    view.transform.SetPositionAndRotation(root.TransformPoint(new Vector3(-.29f,1.84f,1.04f)),facing);
                }
                else
                {
                    Vector3 focus = root.position+Vector3.up*1.24f;
                    Vector3 desired = focus-facing*new Vector3(0,-.65f,7.7f);
                    if (Physics.Linecast(focus+Vector3.up*.85f,desired,out var hit) &&
                        !hit.transform.IsChildOf(root)) desired = hit.point+hit.normal*.28f;
                    view.transform.position = Vector3.Lerp(view.transform.position,desired,1-Mathf.Exp(-8*Time.deltaTime));
                    Vector3 delta = focus-view.transform.position;
                    if (delta.sqrMagnitude>.001f) view.transform.rotation=Quaternion.LookRotation(delta);
                }
            }
            else if (drone)
            {
                if (drone.Airframe.gameObject.activeSelf!=thirdPerson)
                    drone.Airframe.gameObject.SetActive(thirdPerson);
                Quaternion facing = Quaternion.Euler(drone.Pitch,drone.Heading,0);
                Vector3 p = drone.transform.position;
                if (thirdPerson)
                {
                    view.transform.position = Vector3.Lerp(view.transform.position,p-facing*new Vector3(0,-.64f,6.7f),
                        1-Mathf.Exp(-10*Time.deltaTime));
                    if ((p-view.transform.position).sqrMagnitude>.01f) view.transform.LookAt(p);
                }
                else
                {
                    view.transform.SetPositionAndRotation(p+drone.transform.forward*.65f,facing);
                }
            }
        }

        void ApplyQuality()
        {
            Application.targetFrameRate = quality==0 ? 30 : 60;
            QualitySettings.vSyncCount = 0;
            QualitySettings.shadows = quality==0 ? ShadowQuality.Disable : ShadowQuality.All;
            QualitySettings.shadowDistance = quality==2 ? 115 : 60;
            QualitySettings.shadowCascades = quality==2 ? 2 : 0;
            QualitySettings.pixelLightCount = quality==2 ? 2 : 1;
            QualitySettings.antiAliasing = quality==2 ? 2 : 0;
            if (view) view.farClipPlane = quality==0 ? 560 : quality==1 ? 740 : 950;
            PlayerPrefs.SetInt("road.quality",quality);
        }

        void ApplyWeather()
        {
            Color ambient, sky;
            switch (timeOfDay)
            {
                case 0: sky=new Color(.54f,.68f,.74f); ambient=new Color(.55f,.57f,.60f); break;
                case 1: sky=new Color(.65f,.56f,.47f); ambient=new Color(.46f,.45f,.44f); break;
                default: sky=new Color(.078f,.13f,.19f); ambient=new Color(.19f,.23f,.30f); break;
            }
            if (wet) sky = Color.Lerp(sky,new Color(.32f,.38f,.43f),timeOfDay==2 ? .22f : .65f);
            route.Sun.transform.rotation = Quaternion.Euler(timeOfDay==0 ? 46 : 18,-26,0);
            route.Sun.color = timeOfDay==1 ? new Color(1,.74f,.50f) : timeOfDay==2 ? new Color(.55f,.62f,.85f) : Color.white;
            route.Sun.intensity = (timeOfDay==2 ? .26f : timeOfDay==1 ? 1f : 1.25f)*(wet ? .63f : 1f);
            RenderSettings.ambientLight = ambient;
            RenderSettings.fogColor = sky;
            RenderSettings.fogDensity = wet ? .007f : timeOfDay==2 ? .0047f : .0022f;
            view.backgroundColor = sky;
            PlayerPrefs.SetInt("road.rain",wet ? 1 : 0);
            PlayerPrefs.SetInt("road.time",timeOfDay);
        }

        void Styles()
        {
            heading = new GUIStyle(GUI.skin.label){fontSize=53,fontStyle=FontStyle.Bold};
            text = new GUIStyle(GUI.skin.label){fontSize=22,wordWrap=true};
            tiny = new GUIStyle(text){fontSize=17,wordWrap=false};
            centered = new GUIStyle(tiny){alignment=TextAnchor.MiddleCenter};
            button = new GUIStyle(GUI.skin.button){fontSize=21,fontStyle=FontStyle.Bold};
            foreach (var style in new[] {heading,text,tiny,centered})
                style.normal.textColor = Color.white;
        }

        static void Fill(Rect rect,Color color)
        {
            Color saved = GUI.color;
            GUI.color = color;
            GUI.DrawTexture(rect,Texture2D.whiteTexture);
            GUI.color = saved;
        }

        static void Line(Vector2 start,Vector2 end,Color color,float width=2)
        {
            var saved = GUI.matrix;
            var delta = end-start;
            GUIUtility.RotateAroundPivot(Mathf.Atan2(delta.y,delta.x)*Mathf.Rad2Deg,start);
            Fill(new Rect(start.x,start.y-width*.5f,delta.magnitude,width),color);
            GUI.matrix = saved;
        }

        static void Circle(Vector2 at,float radius,Color color,int steps=28)
        {
            Vector2 prev = at+Vector2.right*radius;
            for (int i=1;i<=steps;i++)
            {
                float a = i*Mathf.PI*2/steps;
                Vector2 next = at+new Vector2(Mathf.Cos(a),Mathf.Sin(a))*radius;
                Line(prev,next,color,1.55f);
                prev = next;
            }
        }

        bool Button(string label,float x,float y,float w,float h=47) => GUI.Button(new Rect(x,y,w,h),label,button);

        void OnGUI()
        {
            if (heading == null) Styles();
            float scale = Screen.height/720f;
            float w = Screen.width/scale;
            var saved = GUI.matrix;
            GUI.matrix = Matrix4x4.Scale(new Vector3(scale,scale,1));
            if (mode==Mode.Menu)
                MenuUi(w);
            else if (mode==Mode.Result)
                ResultUi(w);
            else
                Hud(w,scale);
            GUI.matrix = saved;
        }

        void MenuUi(float w)
        {
            float panel = Mathf.Min(w-48,505);
            Fill(new Rect(19,22,panel+10,676),Ink);
            Fill(new Rect(37,51,54,4),Gold);
            GUI.Label(new Rect(35,59,panel-25,70),"Р‑280",heading);
            GUI.Label(new Rect(38,133,panel-50,69),"Северный участок · Сопровождение груза",text);
            if (Button("МОГ · начать рейс",38,220,panel-34,53)) { StartScenario(false); return; }
            if (Button("Hornet · начать разведку",38,282,panel-34,53)) { StartScenario(true); return; }
            if (Button(van ? "МОГ · Буханка" : "МОГ · Hilux",38,354,panel-34)) van=!van;
            if (Button("Установка · "+Loadouts[loadout],38,408,panel-34)) loadout=(loadout+1)%Loadouts.Length;
            if (Button("Качество · "+Presets[quality],38,483,panel-34)) { quality=(quality+1)%3; ApplyQuality(); }
            if (Button(Times[timeOfDay],38,538,(panel-45)*.5f)) { timeOfDay=(timeOfDay+1)%3; ApplyWeather(); }
            if (Button(wet ? "Дождь" : "Сухо",44+(panel-45)*.5f,538,(panel-45)*.5f)) { wet=!wet; ApplyWeather(); }
            GUI.Label(new Rect(38,609,panel-28,65),"Зачисти маршрут за МОГ или передай экипажу метки с Hornet.",text);
        }

        void ResultUi(float w)
        {
            float x = w*.5f-220;
            Fill(new Rect(x,190,440,306),Ink);
            GUI.Label(new Rect(x+24,218,402,80),won ? "Груз доставлен" : "Рейс сорван",new GUIStyle(heading){fontSize=43});
            GUI.Label(new Rect(x+26,322,385,65),$"Пройдено {Mathf.Max(0,freight.Distance-route.Data.start):0} м",text);
            if (Button("Главное меню",x+24,409,391,55)) Menu();
        }

        void Hud(float w,float scale)
        {
            if (Button("Меню",18,17,95,42)) { Menu(); return; }
            if (Button(map ? "Закрыть" : "Планшет",123,17,132,42)) ToggleMap();
            if (Button("Камера",w-134,17,116,42)) ToggleView();
            if (vehicle && Button(vehicle.Gunner ? "Водитель" : "Стрелок",w-268,17,124,42)) ToggleSeat();
            if (vehicle && !vehicle.Gunner && Button("На дорогу",w-402,17,123,42)) RecoverVehicle();
            if (map) { MapUi(w); return; }

            float speed = vehicle ? vehicle.Body.linearVelocity.magnitude : drone ? drone.Speed : 0;
            Fill(new Rect(19,73,273,91),Ink);
            string status = drone ? $"Связь {drone.Signal*100:0}%  ·  АКБ {drone.Battery*100:0}%" :
                $"МОГ   ·   {(vehicle.Gunner ? "стрелок" : "водитель")}";
            GUI.Label(new Rect(30,78,265,28),status,tiny);
            GUI.Label(new Rect(30,105,265,28),$"{speed*3.6f:0} км/ч   ·   фура {freight.Condition*100:0}%",tiny);
            string poi = reached < route.Data.landmarks.Length ? route.Data.landmarks[reached].label : "Финиш";
            GUI.Label(new Rect(30,130,265,28),poi,tiny);
            Vector2 middle=new Vector2(w*.5f,360);
            if (drone && !thirdPerson)
            {
                Line(new Vector2(w*.14f,360),middle-Vector2.right*70,Green);
                Line(middle+Vector2.right*70,new Vector2(w*.86f,360),Green);
                Vector2 marker=middle+Vector2.up*ReticleDisplacement();
                Circle(marker,17,Green);
                Line(marker-Vector2.right*7,marker+Vector2.right*7,Green);
                Line(marker-Vector2.up*7,marker+Vector2.up*7,Green);
                if (drone.Returning)
                    GUI.Label(new Rect(w*.5f-220,110,440,34),"ВОЗВРАТ К ТОЧКЕ СВЯЗИ",centered);
            }
            if (vehicle && vehicle.Gunner)
            {
                Circle(middle,12,Gold);
                Line(middle-Vector2.right*22,middle-Vector2.right*5,Gold);
                Line(middle+Vector2.right*5,middle+Vector2.right*22,Gold);
            }
            if (Time.time<noticeUntil)
            {
                Fill(new Rect(w*.5f-190,174,380,32),Ink);
                GUI.Label(new Rect(w*.5f-176,176,352,28),notice,centered);
            }
            if (vehicle && vehicle.Gunner && Button("Огонь",w-144,530,124,60)) Action();
            if (drone && Button("Метка",w-144,298,124,60)) Action();
            if (vehicle && !vehicle.Gunner)
                GUI.Label(new Rect(w-140,584,124,66),"ТОРМОЗ",centered);
            if (drone)
            {
                GUI.Label(new Rect(w-140,430,124,62),"ВЫШЕ",centered);
                GUI.Label(new Rect(w-140,580,124,62),"НИЖЕ",centered);
            }
            Vector2 anchor = input.TouchActive ? new Vector2(input.Anchor.x/scale,720-input.Anchor.y/scale) :
                new Vector2(Mathf.Min(129,w*.135f),599);
            Circle(anchor,input.Radius/scale,Steel);
            Circle(anchor+new Vector2(input.Stick.x,-input.Stick.y)*input.Radius/scale,22,Steel);
        }

        void MapUi(float w)
        {
            float width = Mathf.Min(w-52,1000);
            var board = new Rect((w-width)*.5f,85,width,610);
            Fill(board,Ink);
            GUI.Label(new Rect(board.x+18,board.y+10,width-35,39),"ПЛАНШЕТ · СЕВЕРНЫЙ УЧАСТОК",text);
            Rect area = new Rect(board.x+25,board.y+64,board.width*.60f-36,board.height-100);
            Fill(area,new Color(.11f,.16f,.17f));
            Vector2 Plot(Vector3 point)
            {
                float z=Mathf.InverseLerp(route.Min.y,route.Max.y,point.z);
                float x=Mathf.InverseLerp(route.Min.x,route.Max.x,point.x);
                return new Vector2(area.x+x*area.width,area.yMax-z*area.height);
            }
            for (int n=1;n<8;n++)
            {
                float x=area.x+area.width*n/8, y=area.y+area.height*n/8;
                Line(new Vector2(x,area.y),new Vector2(x,area.yMax),new Color(.20f,.26f,.26f),1);
                Line(new Vector2(area.x,y),new Vector2(area.xMax,y),new Color(.20f,.26f,.26f),1);
            }
            Vector2 last=Plot(route.At(0));
            for (float d=21;d<route.Length;d+=21)
            {
                Vector2 next=Plot(route.At(d));
                Line(last,next,Steel,2);
                last=next;
            }
            foreach (var place in route.Data.landmarks) Dot(Plot(route.At(place.distance)),Steel,6);
            bool linked=mode!=Mode.Observer || drone.Signal>.18f;
            if (linked)
            {
                foreach (var truck in convoy) Dot(Plot(truck.Position),truck.MissionTruck ? Gold : Steel,truck.MissionTruck ? 11 : 5);
                foreach (var target in obstacles)
                    if (target.Spotted && target.Health>0 && (!scout || scoutLinked)) Dot(Plot(target.Target.position),new Color(1,.45f,.26f),8);
                Transform escort = vehicle ? vehicle.transform : alliedVehicle;
                if (escort) Dot(Plot(escort.position),new Color(.34f,.71f,1),9);
            }
            if (drone) Dot(Plot(drone.transform.position),Green,10);
            if (scout && scoutLinked) Dot(Plot(scout.position),Green,10);
            float x0=area.xMax+21;
            float sideWidth = board.xMax-x0-12;
            GUI.Label(new Rect(x0,140,sideWidth,33),"Грузовая машина",text);
            GUI.Label(new Rect(x0,177,sideWidth,32),linked ? $"Кабина   {freight.CabCondition*100:0}%" : "Сигнал потерян",tiny);
            if (!linked) return;
            GUI.Label(new Rect(x0,210,sideWidth,32),$"Кузов      {freight.LoadCondition*100:0}%",tiny);
            GUI.Label(new Rect(x0,243,sideWidth,32),$"Шины     {freight.TireCondition*100:0}%",tiny);
            GUI.Label(new Rect(x0,288,sideWidth,160),"Жёлтый · груз\nГолубой · МОГ\nЗелёный · Hornet\nОранжевый · метка",text);
            GUI.Label(new Rect(x0,484,sideWidth,126),$"Участок\n{Mathf.Max(0,freight.Distance-route.Data.start):0} / {route.Data.finish-route.Data.start:0} м",text);
        }

        static void Dot(Vector2 position,Color color,float size)
            => Fill(new Rect(position.x-size/2,position.y-size/2,size,size),color);
    }
}
