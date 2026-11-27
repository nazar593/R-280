using UnityEngine;

namespace Roadline
{
    public sealed class TruckPart : MonoBehaviour
    {
        public enum Zone { Cab, Trailer, Tires }
        public Zone Location { get; set; }
        public TrafficTruck Owner { get; set; }
    }
}
