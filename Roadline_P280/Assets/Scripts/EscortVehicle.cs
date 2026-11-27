using UnityEngine;

namespace Roadline
{
    public sealed class EscortVehicle : MonoBehaviour
    {
        readonly WheelCollider[] wheels = new WheelCollider[4];
        readonly Transform[] visuals = new Transform[4];
        MobileInput input;
        float steer, drive;
        bool van;
        public Rigidbody Body { get; private set; }
        public Transform Mount { get; private set; }
        public float Grip { get; set; } = 1f;
        public bool Gunner { get; set; }
        public int Profile { get; private set; }

        public static EscortVehicle Create(Vector3 spawn, Quaternion facing, MobileInput input, bool van, int profile)
        {
            var root = new GameObject(van ? "МОГ | Буханка" : "МОГ | Hilux");
            root.transform.SetPositionAndRotation(spawn,facing);
            var vehicle = root.AddComponent<EscortVehicle>();
            vehicle.van = van;
            vehicle.Profile = profile;
            vehicle.input = input;
            vehicle.Initialize();
            return vehicle;
        }

        void Initialize()
        {
            Body = gameObject.AddComponent<Rigidbody>();
            Body.mass = van ? 2490 : 1930;
            Body.centerOfMass = new Vector3(0,van ? .72f : .63f,van ? .14f : 0);
            Body.interpolation = RigidbodyInterpolation.Interpolate;
            Body.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
            var box = gameObject.AddComponent<BoxCollider>();
            box.center = new Vector3(0,1.01f,0);
            box.size = new Vector3(1.77f,1.05f,4.29f);
            Mount = FleetVisuals.Vehicle(transform,van,Profile);
            int i = 0;
            foreach (float z in new[] {1.52f,-1.52f})
            foreach (float x in new[] {-.91f,.91f})
            {
                var wheel = new GameObject("Suspension").transform;
                wheel.SetParent(transform,false);
                wheel.localPosition = new Vector3(x,.49f,z);
                var collider = wheel.gameObject.AddComponent<WheelCollider>();
                collider.radius = .345f;
                collider.mass = 26;
                collider.suspensionDistance = .27f;
                collider.wheelDampingRate = .8f;
                collider.forceAppPointDistance = .12f;
                collider.ConfigureVehicleSubsteps(6,5,3);
                var spring = collider.suspensionSpring;
                spring.spring = van ? 41000 : 33000;
                spring.damper = van ? 5200 : 4400;
                spring.targetPosition = .52f;
                collider.suspensionSpring = spring;
                wheels[i] = collider;
                visuals[i] = MeshLibrary.Spawn("wheel",transform).transform;
                i++;
            }
        }

        public void Recover(Vector3 point, Quaternion rotation)
        {
            Body.linearVelocity = Body.angularVelocity = Vector3.zero;
            Body.position = point;
            Body.rotation = rotation;
            drive = 0;
            steer = 0;
        }

        void FixedUpdate()
        {
            if (!Body || !input) return;
            Vector2 move = Gunner ? Vector2.zero : input.Move;
            float dt = Time.fixedDeltaTime;
            float forward = Vector3.Dot(Body.linearVelocity,transform.forward);
            float speed = Mathf.Abs(forward);
            steer = Mathf.MoveTowards(steer,move.x*Mathf.Lerp(32,10,Mathf.Clamp01(speed/25)),73*dt);
            drive = Mathf.MoveTowards(drive,move.y,2.4f*dt);
            bool reverseBrake = Mathf.Abs(drive)>.05f && speed>1.2f && Mathf.Sign(drive)!=Mathf.Sign(forward);
            bool brake = Gunner || input.Brake || reverseBrake;
            float throttle = brake ? 0 : drive*(1-Mathf.InverseLerp(22,34,speed));
            Body.AddForce(-Body.linearVelocity*speed*.39f,ForceMode.Force);
            for (int i=0;i<wheels.Length;i++)
            {
                var wheel = wheels[i];
                wheel.steerAngle = i<2 ? steer : 0;
                wheel.motorTorque = i<2 ? throttle*220 : throttle*(van ? 530 : 580);
                wheel.brakeTorque = brake ? 2250 : Mathf.Abs(drive)<.04f ? 70 : 0;
                if (!wheel.GetGroundHit(out WheelHit hit)) continue;
                float surface = hit.collider.name.StartsWith("Road surface") ? 1.08f :
                    hit.collider.name.Contains("shoulder") ? .76f : .57f;
                var longitudinal = wheel.forwardFriction;
                var lateral = wheel.sidewaysFriction;
                longitudinal.stiffness = surface*Grip;
                lateral.stiffness = surface*Grip*.94f;
                wheel.forwardFriction = longitudinal;
                wheel.sidewaysFriction = lateral;
            }
        }

        void LateUpdate()
        {
            for (int i=0;i<wheels.Length;i++)
            {
                if (!wheels[i]) continue;
                wheels[i].GetWorldPose(out var point,out var rotation);
                visuals[i].SetPositionAndRotation(point,rotation);
            }
        }
    }
}
