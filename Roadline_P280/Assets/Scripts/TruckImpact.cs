using UnityEngine;

namespace Roadline
{
    public sealed class TruckImpact : MonoBehaviour
    {
        public TrafficTruck Owner { get; set; }
        public TruckPart.Zone Zone { get; set; }

        void OnCollisionEnter(Collision collision)
        {
            if (collision.rigidbody && !collision.rigidbody.isKinematic)
                Owner?.Collision(Zone,collision.relativeVelocity.magnitude);
        }
    }
}
