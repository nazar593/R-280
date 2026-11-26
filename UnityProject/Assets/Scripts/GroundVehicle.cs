using UnityEngine;
namespace R280 {
    [RequireComponent(typeof(Rigidbody))]
    public sealed class GroundVehicle : MonoBehaviour, IControllable {
        Rigidbody body;
        WheelCollider[] wheels;
        Transform[] meshes;
        Vector3 spawn;
        Quaternion spawnRotation;
        float steer, throttle;
        public Transform Anchor => transform;
        public float Speed => body.linearVelocity.magnitude * 3.6f;
        public void Configure(WheelCollider[] colliders, Transform[] visuals) {
            body=GetComponent<Rigidbody>(); wheels=colliders; meshes=visuals;
            body.mass=1800; body.centerOfMass=new Vector3(0,-.3f,0);
            body.interpolation=RigidbodyInterpolation.Interpolate;
            body.collisionDetectionMode=CollisionDetectionMode.ContinuousDynamic;
            spawn=transform.position; spawnRotation=transform.rotation;
        }
        PlayerCommand current;
        public void Apply(PlayerCommand command) { current=command; }
        void FixedUpdate() {
            if(wheels==null) return;
            steer=Mathf.MoveTowards(steer,current.Move.x,Time.fixedDeltaTime*1.7f);
            throttle=Mathf.MoveTowards(throttle,current.Move.y,Time.fixedDeltaTime*2.0f);
            float angle=Mathf.Lerp(30,9,Mathf.Clamp01(Speed/75f))*steer;
            for(int i=0;i<wheels.Length;i++) {
                wheels[i].steerAngle=i<2?angle:0;
                wheels[i].motorTorque=current.Brake?0:throttle*420f;
                wheels[i].brakeTorque=current.Brake?1800f:Mathf.Abs(throttle)<.03f?30f:0;
            }
        }
        void LateUpdate() {
            if(wheels==null) return;
            for(int i=0;i<wheels.Length;i++) {
                wheels[i].GetWorldPose(out Vector3 p,out Quaternion q);
                meshes[i].SetPositionAndRotation(p,q*Quaternion.Euler(0,0,90));
            }
        }
        public void ResetPose() {
            current=default; steer=throttle=0;
            body.linearVelocity=body.angularVelocity=Vector3.zero;
            body.position=spawn; body.rotation=spawnRotation;
        }
    }
}
