using UnityEngine;

namespace Roadline
{
    public sealed class HornetFlight : MonoBehaviour
    {
        MobileInput input;
        Rigidbody body;
        Transform airframe, blade;
        AudioSource engine;
        Vector3 lastReturn;
        public Transform Airframe => airframe;
        public float Heading { get; private set; }
        public float Pitch { get; private set; } = 10;
        public float Signal { get; private set; } = 1;
        public float Battery { get; private set; } = 1;
        public float Speed => body.linearVelocity.magnitude;
        public bool Windy { get; set; }
        public Vector3 Relay { get; set; }
        public bool Returning => Signal < .12f || Battery < .055f;

        public static HornetFlight Create(Vector3 point,Quaternion rotation,MobileInput input)
        {
            var obj = new GameObject("Hornet");
            obj.transform.SetPositionAndRotation(point,rotation);
            var flight = obj.AddComponent<HornetFlight>();
            flight.input = input;
            flight.body = obj.AddComponent<Rigidbody>();
            flight.body.mass = 7.5f;
            flight.body.useGravity = false;
            flight.body.interpolation = RigidbodyInterpolation.Interpolate;
            flight.body.constraints = RigidbodyConstraints.FreezeRotation;
            flight.body.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
            obj.AddComponent<SphereCollider>().radius = .37f;
            flight.airframe = MeshLibrary.Spawn("hornet",obj.transform).transform;
            var propeller = flight.airframe.Find("propeller");
            flight.blade = new GameObject("Propeller pivot").transform;
            flight.blade.SetParent(flight.airframe,false);
            flight.blade.localPosition = new Vector3(0,0,-38.205f/27);
            propeller.SetParent(flight.blade,true);
            flight.engine = Sounds.Loop(obj.transform,Sounds.Propeller,3,125,.27f);
            flight.Heading = rotation.eulerAngles.y;
            flight.lastReturn = point;
            return flight;
        }

        void Update()
        {
            if (!body) return;
            blade.Rotate(0,0,2180*Time.deltaTime,Space.Self);
            engine.pitch = .78f + Mathf.Min(1,Speed/31)*.45f;
            if (Returning || !input.Active) return;
            Heading += input.Look.x*.12f;
            Pitch = Mathf.Clamp(Pitch-input.Look.y*.13f,-38,56);
        }

        void FixedUpdate()
        {
            if (!body) return;
            float dt = Time.fixedDeltaTime;
            Vector3 delta = Relay-transform.position;
            bool blocked = Physics.Linecast(transform.position+Vector3.up*.46f,Relay,out var hit) &&
                hit.distance+1.1f<delta.magnitude;
            float targetSignal = Mathf.Clamp01(1-Mathf.InverseLerp(315,650,delta.magnitude));
            if (blocked) targetSignal *= .10f;
            Signal = Mathf.MoveTowards(Signal,targetSignal,dt*.85f);
            if (Signal>.35f) lastReturn = transform.position;
            Quaternion yaw = Quaternion.Euler(0,Heading,0);
            Vector2 move = input.Move;
            Vector3 nominal = yaw*new Vector3(move.x*11,input.Lift*6,move.y*28);
            if (Returning)
            {
                var seek = Vector3.MoveTowards(lastReturn,Relay,26)+Vector3.up*14-transform.position;
                nominal = Vector3.ClampMagnitude(seek*1.15f,20);
                if (nominal.sqrMagnitude>5)
                {
                    Heading = Mathf.MoveTowardsAngle(Heading,Mathf.Atan2(nominal.x,nominal.z)*Mathf.Rad2Deg,dt*70);
                    yaw = Quaternion.Euler(0,Heading,0);
                }
            }
            if (Battery<=0) nominal = Vector3.down*2.7f;
            var wind = Windy ? new Vector3(2.4f+Mathf.Sin(Time.time*.67f)*1.5f,.13f,.51f) : new Vector3(.32f,0,.14f);
            if (transform.position.y<4 && Battery>0) nominal.y = Mathf.Max(nominal.y,3);
            if (transform.position.y>115) nominal.y = Mathf.Min(nominal.y,-2);
            Battery = Mathf.Max(0,Battery-dt*(.0011f+nominal.magnitude*.000048f));
            body.AddForce(Vector3.ClampMagnitude((nominal+wind-body.linearVelocity)*1.8f,10),ForceMode.Acceleration);
            body.MoveRotation(yaw);
            Vector3 local = Quaternion.Inverse(yaw)*body.linearVelocity;
            airframe.localRotation = Quaternion.Slerp(airframe.localRotation,Quaternion.Euler(local.z*.33f,0,-local.x*1.9f),dt*4);
        }
    }
}
