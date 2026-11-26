using UnityEngine;
namespace R280 {
    [RequireComponent(typeof(Rigidbody))]
    public sealed class FlightVehicle : MonoBehaviour, IControllable {
        Rigidbody body;
        Vector3 spawn;
        Quaternion spawnRotation;
        PlayerCommand current;
        float throttle=.45f;
        public Transform Anchor=>transform;
        public float Speed=>body.linearVelocity.magnitude*3.6f;
        public void Configure() {
            body=GetComponent<Rigidbody>(); body.mass=12;
            body.interpolation=RigidbodyInterpolation.Interpolate;
            body.collisionDetectionMode=CollisionDetectionMode.ContinuousDynamic;
            body.linearDamping=.25f; body.angularDamping=3;
            spawn=transform.position; spawnRotation=transform.rotation;
        }
        public void Apply(PlayerCommand command) { current=command; }
        void FixedUpdate() {
            if(body==null) return;
            // Fictional game flight controller, not a model of any actual aircraft.
            throttle=Mathf.Clamp01(throttle+current.Move.y*Time.fixedDeltaTime*.5f);
            Vector3 localVelocity=transform.InverseTransformDirection(body.linearVelocity);
            float speed=Mathf.Max(0,localVelocity.z);
            body.AddForce(transform.forward*throttle*12f,ForceMode.Acceleration);
            body.AddForce(transform.up*Mathf.Min(15f,speed*1.05f),ForceMode.Acceleration);
            body.AddForce(-transform.right*localVelocity.x*1.8f,ForceMode.Acceleration);
            float targetBank=-current.Move.x*32;
            float targetPitch=-current.Look.y*18;
            float bank=Mathf.DeltaAngle(0,transform.eulerAngles.z);
            float pitch=Mathf.DeltaAngle(0,transform.eulerAngles.x);
            body.AddRelativeTorque(new Vector3((targetPitch-pitch)*.045f,current.Move.x*1.2f,(targetBank-bank)*.045f),ForceMode.Acceleration);
            if(current.Brake) body.AddForce(-body.linearVelocity*1.8f,ForceMode.Acceleration);
        }
        public void ResetPose() {
            current=default; throttle=.45f;
            body.linearVelocity=body.angularVelocity=Vector3.zero;
            body.position=spawn; body.rotation=spawnRotation;
            body.linearVelocity=spawnRotation*Vector3.forward*12f;
        }
    }
}
