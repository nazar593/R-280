using UnityEngine;

namespace Roadline
{
    public static class FleetVisuals
    {
        public enum Cargo { Canvas, Chilled, Tank, Box }

        static Material Paint(string name, float r, float g, float b, float metal = 0)
            => MeshLibrary.MaterialFor(name,new Color(r,g,b),metal,.34f);

        static GameObject Box(Transform parent, string name, float x, float y, float z,
            float width, float height, float depth, Material mat)
            => Visuals.Box(name,parent,new Vector3(x,y,z),new Vector3(width,height,depth),mat);

        static GameObject Roller(Transform parent, string name, Vector3 center, Vector3 scale, Quaternion facing, Material material)
        {
            var obj = Visuals.Shape(name,PrimitiveType.Cylinder,parent,center,scale,material);
            obj.transform.localRotation = facing;
            return obj;
        }

        public static Transform Vehicle(Transform root, bool van, int profile)
        {
            var olive = Paint("escort olive",.36f,.40f,.27f,.15f);
            var dark = Paint("frame",.12f,.13f,.12f,.24f);
            var glass = Paint("dark glass",.16f,.24f,.26f,.15f);
            var light = Paint("head lamp",.83f,.77f,.57f);
            var metal = Paint("painted steel",.32f,.35f,.32f,.28f);
            if (van)
            {
                Box(root,"Bukhanka | frame",0,.61f,0,1.91f,.31f,4.39f,dark);
                Box(root,"Cab and bonnet",0,1.04f,1.02f,1.87f,.86f,2.28f,olive);
                Box(root,"Cab pillars",0,1.60f,1.05f,1.84f,.54f,1.70f,olive);
                Box(root,"Split front glass",0,1.62f,1.914f,1.59f,.39f,.06f,glass);
                Box(root,"Center seal",0,1.62f,1.95f,.05f,.42f,.03f,dark);
                Box(root,"Roof",0,1.94f,1.05f,1.92f,.18f,1.96f,olive);
                Box(root,"Grille",0,.98f,2.17f,.68f,.24f,.06f,dark);
                Box(root,"Bed floor",0,.93f,-1.17f,1.95f,.17f,2.10f,olive);
                foreach (float x in new[] {-.89f,.89f})
                {
                    Box(root,"Bed side",x,1.10f,-1.14f,.13f,.31f,2.10f,olive);
                    Box(root,"Side window",x,1.65f,1.04f,.07f,.39f,1.16f,glass);
                    Box(root,"Front lamp",x*.77f,1.08f,2.19f,.24f,.24f,.045f,light);
                }
            }
            else
            {
                MeshLibrary.Spawn("pickup",root);
            }

            var mount = new GameObject("Turret ring").transform;
            mount.SetParent(root,false);
            mount.localPosition = new Vector3(0,van ? 1.07f : .97f,-1.03f);
            Roller(mount,"Ring",Vector3.zero,new Vector3(.76f,.08f,.76f),Quaternion.identity,metal);
            Box(mount,"Pedestal",0,.43f,0,.20f,.75f,.22f,metal);
            int count = profile == 0 ? 2 : 1;
            for (int i = 0; i < count; i++)
            {
                float x = count == 2 ? (i-.5f)*.23f : 0;
                float length = profile == 0 ? 1.15f : profile == 1 ? 1.34f : 1.53f;
                Box(mount,"Receiver",x,.84f,0,.20f,.20f,.43f,dark);
                Roller(mount,"Barrel",new Vector3(x,.84f,length*.43f),
                    new Vector3(.085f,length*.5f,.085f),Quaternion.Euler(90,0,0),metal);
            }
            return mount;
        }

        public static void Truck(Transform tractor, Transform trailer, Cargo type, int livery,
            out Transform cab, out Transform load, out Transform[] tires)
        {
            var frame = Paint("truck chassis",.11f,.13f,.13f,.26f);
            var glass = Paint("freight glass",.14f,.24f,.28f,.20f);
            var rubber = Paint("rubber",.071f,.076f,.075f);
            var silver = Paint("hubcap",.61f,.62f,.59f,.45f);
            var lamp = Paint("marker red",.58f,.13f,.075f);
            var headlamp = Paint("freight lamp",.93f,.88f,.69f);
            var paint = livery % 3 == 0 ? Paint("truck ivory",.70f,.72f,.67f) :
                livery % 3 == 1 ? Paint("truck tomato",.53f,.23f,.17f) : Paint("truck petrol",.25f,.38f,.43f);
            var canvas = Paint("canvas load",.36f,.43f,.38f);
            var reefer = Paint("sealed load",.66f,.73f,.71f);
            cab = new GameObject("Cab structure").transform;
            cab.SetParent(tractor,false);
            Box(tractor,"Chassis",0,.71f,0,1.85f,.34f,5.9f,frame);
            Box(cab,"Cabin",0,1.75f,1.47f,2.43f,2.45f,2.22f,paint);
            Box(cab,"Windshield",0,2.37f,2.60f,2.03f,.62f,.04f,glass);
            Box(cab,"Sun visor",0,2.80f,2.67f,2.26f,.14f,.30f,paint);
            Box(cab,"Grille",0,1.21f,2.61f,1.62f,.43f,.08f,frame);
            Box(cab,"Bumper",0,.81f,2.67f,2.44f,.19f,.26f,frame);
            foreach (float side in new[] {-1f,1f})
            {
                Box(cab,"Side glass",side*1.223f,2.37f,1.77f,.045f,.63f,1.17f,glass);
                Box(cab,"Mirror",side*1.41f,2.26f,2.35f,.14f,.38f,.19f,frame);
                Box(cab,"Lamp",side*.99f,1.0f,2.65f,.40f,.21f,.10f,headlamp);
                Roller(tractor,"Fuel tank",new Vector3(side*.96f,.75f,-.25f),new Vector3(.52f,.64f,.52f),Quaternion.Euler(90,0,0),silver);
            }

            bool rigid = type == Cargo.Box;
            load = new GameObject("Cargo body").transform;
            load.SetParent(rigid ? tractor : trailer,false);
            float rear = rigid ? -1.75f : -4.57f;
            float length = rigid ? 4.35f : 9.15f;
            if (!rigid) Box(trailer,"Trailer chassis",0,.76f,rear,2.26f,.24f,length,frame);
            if (type == Cargo.Tank)
            {
                Roller(load,"Tank",new Vector3(0,1.92f,rear),new Vector3(2.32f,length*.49f,2.1f),Quaternion.Euler(90,0,0),silver);
                for (int i=0;i<3;i++)
                    Roller(load,"Retaining band",new Vector3(0,1.92f,rear+(i-1)*2.7f),new Vector3(2.38f,.09f,2.17f),Quaternion.Euler(90,0,0),frame);
                Box(load,"Access platform",0,3.01f,rear,.78f,.11f,length*.65f,frame);
            }
            else
            {
                var panels = type == Cargo.Canvas ? canvas : reefer;
                Box(load,"Cargo shell",0,1.98f,rear,2.48f,2.28f,length,panels);
                Box(load,"Roof cap",0,3.13f,rear,2.51f,.095f,length,reefer);
                Box(load,"Rear center latch",0,1.99f,rear-length*.5f-.025f,.07f,2.10f,.06f,frame);
                for (int i=0;i<7;i++)
                    foreach (int side in new[] {-1,1})
                        Box(load,"Cargo rib",side*1.247f,1.98f,rear+length*(i/7f-.43f),.04f,2.06f,.049f,frame);
                if (type == Cargo.Chilled)
                    Box(load,"Cooling unit",0,2.70f,rear+length*.5f+.085f,1.18f,.60f,.17f,frame);
            }
            foreach (float x in new[] {-.97f,.97f})
                Box(load,"Tail lamp",x,.89f,rear-length*.5f-.06f,.29f,.18f,.14f,lamp);

            var wheelList = new System.Collections.Generic.List<Transform>();
            void Axle(Transform parent, float z)
            {
                foreach (float side in new[] {-1f,1f})
                {
                    var wheel = Roller(parent,"Tire",new Vector3(side*1.08f,.48f,z),new Vector3(.96f,.165f,.96f),Quaternion.Euler(0,0,90),rubber);
                    Roller(wheel.transform,"Hub",new Vector3(0,-side*1.02f,0),new Vector3(.51f,.10f,.51f),Quaternion.identity,silver);
                    wheelList.Add(wheel.transform);
                }
            }
            Axle(tractor,1.63f);
            Axle(tractor,-1.36f);
            if (!rigid) { Axle(trailer,-6.15f); Axle(trailer,-7.31f); }
            tires = wheelList.ToArray();
        }
    }
}
