using UnityEngine;

namespace Roadline
{
    public sealed class TrafficTruck
    {
        readonly AudioSource engine;
        readonly Transform trailer, cargo;
        readonly Rigidbody body, trailerBody;
        readonly Transform[] tires;
        readonly RouteWorld world;
        readonly int direction;
        readonly float cruise, mass;
        readonly bool rigid;
        readonly ParticleSystem smoke;
        readonly ParticleSystem fire;
        float lane, slowUntil, roll, skidCooldown, previousSpeed;
        float cab = 1, trailerIntegrity = 1, tire = 1;
        public float Distance { get; private set; }
        public float Speed { get; private set; }
        public bool MissionTruck { get; }
        public bool Lost => cab <= 0 || trailerIntegrity <= 0;
        public float Condition => Mathf.Min(cab,trailerIntegrity);
        public float CabCondition => cab;
        public float LoadCondition => trailerIntegrity;
        public float TireCondition => tire;
        public Vector3 Position => body.position;
        public GameObject Tractor => body.gameObject;
        public GameObject Trailer => trailerBody ? trailer.gameObject : null;

        public TrafficTruck(RouteWorld world, float distance, int direction, FleetVisuals.Cargo type, int livery, bool mission = false)
        {
            this.world = world;
            Distance = distance;
            this.direction = direction;
            MissionTruck = mission;
            lane = direction * RouteWorld.Lane;
            cruise = mission ? 14 : 12 + livery % 4 * 1.7f;
            rigid = type == FleetVisuals.Cargo.Box;
            mass = type == FleetVisuals.Cargo.Tank ? 30500 : rigid ? 9600 : type == FleetVisuals.Cargo.Chilled ? 19700 : 15500;
            var rig = new GameObject(mission ? "Priority freight" : "Traffic truck "+livery);
            trailer = new GameObject("Articulated trailer").transform;
            if (rigid) trailer.SetParent(rig.transform,false);
            FleetVisuals.Truck(rig.transform,trailer,type,livery,out var cabin,out cargo,out tires);

            body = KinematicBody(rig,mass*(rigid ? 1 : .39f));
            AddZone(body.transform,cabin,new Vector3(0,1.65f,1.48f),new Vector3(2.42f,2.44f,2.29f),TruckPart.Zone.Cab);
            AddZone(body.transform,body.transform,new Vector3(0,.42f,-.08f),new Vector3(2.35f,.76f,4.09f),TruckPart.Zone.Tires);
            Transform loadBody = rigid ? body.transform : trailer;
            if (!rigid)
            {
                trailerBody = KinematicBody(trailer.gameObject,mass*.61f);
                AddZone(loadBody,loadBody,new Vector3(0,.43f,-6.61f),new Vector3(2.35f,.80f,2.35f),TruckPart.Zone.Tires);
            }
            AddZone(loadBody,cargo,new Vector3(0,1.98f,rigid ? -1.75f : -4.57f),
                new Vector3(2.46f,2.25f,rigid ? 4.32f : 9.14f),TruckPart.Zone.Trailer);
            engine = Sounds.Loop(rig.transform,Sounds.Engine,2,86,.18f);
            smoke = Effects.Emitter(cargo,rigid ? -2.0f : -4.3f,false);
            fire = Effects.Emitter(cargo,rigid ? -2.0f : -4.3f,true);
            Warp();
        }

        static Rigidbody KinematicBody(GameObject obj,float mass)
        {
            var rb = obj.AddComponent<Rigidbody>();
            rb.isKinematic = true;
            rb.useGravity = false;
            rb.mass = mass;
            rb.interpolation = RigidbodyInterpolation.Interpolate;
            rb.collisionDetectionMode = CollisionDetectionMode.ContinuousSpeculative;
            return rb;
        }

        void AddZone(Transform parent,Transform visual,Vector3 center,Vector3 size,TruckPart.Zone zone)
        {
            var part = new GameObject(visual.name+" hit volume");
            part.transform.SetParent(parent,false);
            var hit = part.AddComponent<BoxCollider>();
            hit.center = center;
            hit.size = size;
            var info = part.AddComponent<TruckPart>();
            info.Location = zone;
            info.Owner = this;
            var collision = part.AddComponent<TruckImpact>();
            collision.Owner = this;
            collision.Zone = zone;
        }

        void Pose(out Vector3 position,out Quaternion facing,out Vector3 tail,out Quaternion trailerFacing)
        {
            world.Pose(Distance,lane,out position,out facing);
            if (direction<0) facing *= Quaternion.Euler(0,180,0);
            Vector3 axle = world.At(Distance-direction*8,lane);
            Vector3 hitch = position-facing*Vector3.forward*1.75f;
            Vector3 heading = hitch-axle;
            var draft = heading.sqrMagnitude > 1 ? Quaternion.LookRotation(heading,Vector3.up) : facing;
            trailerFacing = draft*Quaternion.Euler(0,0,roll);
            tail = hitch;
        }

        void Warp()
        {
            Pose(out var pos,out var rot,out var tail,out var tailRot);
            body.position = pos;
            body.rotation = rot;
            if (trailerBody)
            {
                trailerBody.position = tail;
                trailerBody.rotation = tailRot;
            }
        }

        public void Damage(TruckPart.Zone zone,float amount)
        {
            bool wasBurning = cab < .38f || trailerIntegrity < .40f;
            switch (zone)
            {
                case TruckPart.Zone.Cab: cab = Mathf.Max(0,cab-amount); break;
                case TruckPart.Zone.Trailer: trailerIntegrity = Mathf.Max(0,trailerIntegrity-amount); break;
                case TruckPart.Zone.Tires: tire = Mathf.Max(0,tire-amount); break;
            }
            Alert();
            if (!wasBurning && (cab < .38f || trailerIntegrity < .40f))
            {
                smoke.Play();
                fire.Play();
            }
        }

        public void Collision(TruckPart.Zone zone,float relativeSpeed)
        {
            if (skidCooldown > Time.time || relativeSpeed < 5) return;
            skidCooldown = Time.time+.6f;
            Damage(zone,Mathf.InverseLerp(4,28,relativeSpeed)*.46f);
            AudioSource.PlayClipAtPoint(Sounds.Impact,body.position,.34f);
        }

        public void Alert()
        {
            slowUntil = Time.time+3.1f;
        }

        public void Tick(float dt,float obstacle,bool wet)
        {
            bool yielding = Time.time<slowUntil;
            float desiredLane = direction*RouteWorld.Lane;
            float target = cruise;
            if (yielding || tire<.48f)
            {
                desiredLane = direction*4.75f;
                target *= tire<.48f ? .32f : .50f;
            }
            if (obstacle<32)
                target = Mathf.Min(target,Mathf.Max(0,(obstacle-9)*.65f));
            else if (!yielding && tire>=.48f && !MissionTruck && obstacle<52)
                desiredLane += direction*.55f;
            if (Lost)
            {
                target = 0;
                desiredLane = direction*4.55f;
            }

            previousSpeed = Speed;
            Speed = Mathf.MoveTowards(Speed,target,(Speed>target ? (wet ? 2.8f : 4.1f) : 1.55f*15000/mass)*dt);
            lane = Mathf.MoveTowards(lane,desiredLane,(wet ? .56f : .81f)*dt);
            Distance += direction*Speed*dt;
            Vector3 before = world.At(Distance-7,lane), after = world.At(Distance+7,lane), center = world.At(Distance,lane);
            float change = Vector3.SignedAngle(center-before,after-center,Vector3.up);
            float loadShift = Mathf.Clamp(change*Speed*.095f,-7.5f,7.5f)*(mass/30500f);
            roll = Mathf.Lerp(roll,loadShift,1-Mathf.Exp(-2.6f*dt));
            cargo.localRotation = Quaternion.Euler(0,0,rigid ? roll : roll*.25f);

            if (!MissionTruck && (Distance<16 || Distance>world.Length-16))
            {
                Distance = direction>0 ? 22 : world.Length-22;
                Warp();
                return;
            }
            Pose(out var point,out var facing,out var tail,out var trailerFacing);
            body.MovePosition(point);
            body.MoveRotation(facing);
            if (trailerBody)
            {
                trailerBody.MovePosition(tail);
                trailerBody.MoveRotation(trailerFacing);
            }
            foreach (Transform wheel in tires)
                wheel.Rotate(Vector3.up,direction*Speed*dt*119.4f,Space.Self);
            engine.pitch = .58f + Speed/22f;
            engine.volume = Lost ? .035f : .08f+Speed*.007f;
            if (previousSpeed>8 && Speed<previousSpeed-.03f && Speed<8 && !Lost)
                AudioSource.PlayClipAtPoint(Sounds.Brakes,body.position,.12f);
        }

        public float GapTo(TrafficTruck other)
        {
            if (other == this || other.direction != direction || Mathf.Abs(other.lane-lane)>1.2f) return float.PositiveInfinity;
            float gap = (other.Distance-Distance)*direction;
            return gap>0 ? gap : float.PositiveInfinity;
        }
    }
}
