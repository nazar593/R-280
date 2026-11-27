using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Roadline
{
    public sealed class RouteWorld
    {
        [Serializable] public class Node { public float x, z, elevation; }
        [Serializable] public class Landmark { public string label, kind; public float distance, side; }
        [Serializable] public class Hazard { public float distance, side; }
        [Serializable] public class Plan { public Node[] nodes; public Landmark[] landmarks; public Hazard[] hazards; public float start, finish; }

        public const float Lane = 2.05f;
        public Plan Data { get; }
        public Light Sun { get; }
        public float Length => distances[distances.Count - 1];
        public Vector2 Min { get; }
        public Vector2 Max { get; }
        readonly List<Vector3> samples = new();
        readonly List<float> distances = new();
        readonly Transform root;

        public RouteWorld()
        {
            Data = JsonUtility.FromJson<Plan>(Resources.Load<TextAsset>("Route/p280").text);
            root = new GameObject("П280 | участок Северный").transform;
            var points = Array.ConvertAll(Data.nodes, n => new Vector3(n.x, n.elevation, n.z));
            samples.Add(points[0]);
            distances.Add(0);
            Vector2 min = new Vector2(points[0].x, points[0].z), max = min;
            for (int segment = 0; segment < points.Length - 1; segment++)
            {
                Vector3 a = points[Mathf.Max(0, segment - 1)], b = points[segment];
                Vector3 c = points[segment + 1], d = points[Mathf.Min(segment + 2, points.Length - 1)];
                float previous = distances[distances.Count - 1];
                int low = Mathf.CeilToInt(Vector3.Distance(b,c) / 4);
                for (int step = 1; step <= low; step++)
                {
                    float t = step / (float)low;
                    Vector3 sample = .5f * ((2*b) + (c-a)*t + (2*a-5*b+4*c-d)*t*t + (d-a+3*(b-c))*t*t*t);
                    sample.y = Mathf.Max(.16f, sample.y);
                    previous += Vector3.Distance(samples[samples.Count - 1], sample);
                    samples.Add(sample);
                    distances.Add(previous);
                    min = Vector2.Min(min, new Vector2(sample.x, sample.z));
                    max = Vector2.Max(max, new Vector2(sample.x, sample.z));
                }
            }
            Min = min - new Vector2(105,65);
            Max = max + new Vector2(105,65);
            Build();
            Sun = new GameObject("Sun").AddComponent<Light>();
            Sun.type = LightType.Directional;
            Sun.shadows = LightShadows.Soft;
            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.Exponential;
        }

        Vector3 Tangent(int i)
        {
            return (samples[Mathf.Min(samples.Count - 1, i + 1)] - samples[Mathf.Max(0,i - 1)]).normalized;
        }

        public void Pose(float distance, float side, out Vector3 point, out Quaternion facing)
        {
            int index = distances.BinarySearch(Mathf.Clamp(distance,0,Length));
            if (index < 0) index = ~index;
            int i = Mathf.Max(0,index-1);
            float t = Mathf.InverseLerp(distances[i],distances[index],distance);
            Vector3 tangent = Vector3.Lerp(Tangent(i),Tangent(index),t).normalized;
            facing = Quaternion.LookRotation(tangent,Vector3.up);
            point = Vector3.Lerp(samples[i],samples[index],t) + facing * Vector3.right * side;
        }

        public Vector3 At(float distance, float side = 0)
        {
            Pose(distance,side,out var point,out _);
            return point;
        }

        public float Nearest(Vector3 position)
        {
            int best = 0;
            position.y = 0;
            float square = float.PositiveInfinity;
            for (int i = 0; i < samples.Count; i++)
            {
                Vector3 delta = samples[i] - position;
                float distance = delta.x*delta.x + delta.z*delta.z;
                if (distance >= square) continue;
                square = distance;
                best = i;
            }
            return distances[best];
        }

        void Build()
        {
            var grass = Tiled("grass",new Color(.72f,.75f,.59f));
            var asphalt = Tiled("asphalt",new Color(.62f,.64f,.65f));
            var gravel = Tiled("gravel",new Color(.71f,.66f,.59f));
            var line = MeshLibrary.MaterialFor("road-paint",new Color(.88f,.85f,.74f));
            var metal = MeshLibrary.MaterialFor("rail",new Color(.46f,.50f,.48f),.25f);
            var concrete = MeshLibrary.MaterialFor("concrete",new Color(.47f,.46f,.41f));
            var wood = MeshLibrary.MaterialFor("tree-trunk",new Color(.25f,.20f,.13f));
            var leaf = MeshLibrary.MaterialFor("tree-leaf",new Color(.31f,.39f,.21f));
            var roof = MeshLibrary.MaterialFor("roof",new Color(.41f,.25f,.19f));
            var post = MeshLibrary.MaterialFor("post-panel",new Color(.17f,.28f,.27f));
            var terrain = Visuals.Box("Steppe",root,new Vector3(8,-.22f,300),new Vector3(1450,.4f,2600),grass,true);
            var tile = new MaterialPropertyBlock();
            tile.SetVector("_MainTex_ST",new Vector4(190,320,0,0));
            terrain.GetComponent<Renderer>().SetPropertyBlock(tile);
            Ribbon("Road surface | asphalt",asphalt,-4.1f,4.1f,0,true);
            Ribbon("Left shoulder | gravel",gravel,-5.75f,-4.1f,-.025f,true);
            Ribbon("Right shoulder | gravel",gravel,4.1f,5.75f,-.025f,true);
            Ribbon("Edge strip left",line,-3.91f,-3.80f,.008f,false);
            Ribbon("Edge strip right",line,3.80f,3.91f,.008f,false);
            var dashes = new List<Vector3>();
            for (float distance = 2; distance < Length-6; distance += 12)
            {
                dashes.Add(At(distance,-.065f)+Vector3.up*.009f);
                dashes.Add(At(distance+5,-.065f)+Vector3.up*.009f);
                dashes.Add(At(distance,.065f)+Vector3.up*.009f);
                dashes.Add(At(distance+5,.065f)+Vector3.up*.009f);
            }
            CreateStrip("Dashes",dashes,line,false);

            var random = new System.Random(280);
            for (float distance = 15; distance < Length-15; distance += 15)
            {
                foreach (int side in new[] { -1,1 })
                {
                    Vector3 p = At(distance,side * (17+(float)random.NextDouble()*27));
                    p.y = 0;
                    float size = 4+(float)random.NextDouble()*6;
                    Visuals.Box("Tree trunk",root,p+Vector3.up*(size*.27f),new Vector3(.27f,size*.54f,.27f),wood);
                    Visuals.Shape("Tree canopy",PrimitiveType.Sphere,root,p+Vector3.up*(size*.73f),new Vector3(size*.65f,size*.82f,size*.72f),leaf);
                }

                Vector3 deck = At(distance);
                if (deck.y < 1.6f) continue;
                if (((int)distance / 15) % 2 == 1)
                    Visuals.Box("Bridge pier",root,new Vector3(deck.x,deck.y*.5f-.22f,deck.z),new Vector3(6,deck.y,.85f),concrete,true);
                foreach (int side in new[] {-1,1})
                    Connect("Bridge rail",At(distance-7,side*4.35f)+Vector3.up*.68f,At(distance+8,side*4.35f)+Vector3.up*.68f,.15f,.30f,metal,true);
            }
            foreach (var landmark in Data.landmarks)
            {
                Pose(landmark.distance,0,out var p,out var rot);
                float side = Mathf.Sign(landmark.side);
                if (landmark.kind == "junction" || landmark.kind == "bridge")
                {
                    Vector3 b = p + rot * new Vector3(side*100,0,landmark.kind == "bridge" ? 0 : 46);
                    Vector3 a = landmark.kind == "bridge" ? p-rot*Vector3.right*65 : p+rot*Vector3.right*4;
                    a.y = b.y = .05f;
                    Connect("Road surface | exit",a,b,6,.12f,asphalt,true);
                }
                if (landmark.kind == "village")
                {
                    for (int i = 0; i < 11; i++)
                    {
                        Vector3 b = p + rot * new Vector3(side*(22+i%3*13),0,(i-5)*12);
                        b.y = 0;
                        var house = Visuals.Box("House",root,b+Vector3.up*1.65f,new Vector3(8,3.3f,6),concrete,true);
                        house.transform.rotation = rot;
                        var top = Visuals.Box("Building roof",root,b+Vector3.up*3.5f,new Vector3(8.5f,.65f,6.5f),roof);
                        top.transform.rotation = rot;
                    }
                }
                if (landmark.kind == "gate")
                {
                    Vector3 b = At(landmark.distance,side*6.5f);
                    Visuals.Box("Checkpoint booth",root,b+Vector3.up*1.4f,new Vector3(2.3f,2.8f,3.1f),post,true).transform.rotation = rot;
                    foreach (int s in new[] {-1,1})
                        Visuals.Box("Gantry",root,At(landmark.distance,s*5)+Vector3.up*2.6f,new Vector3(.26f,5.2f,.26f),metal);
                    Connect("Crossbar",At(landmark.distance,-5)+Vector3.up*5.1f,At(landmark.distance,5)+Vector3.up*5.1f,.25f,.30f,metal);
                    Visuals.Box("Checkpoint sign",root,p+Vector3.up*4.86f,new Vector3(4.3f,.95f,.18f),post).transform.rotation = rot;
                }
            }
        }

        Material Tiled(string key, Color tint)
        {
            var material = MeshLibrary.MaterialFor(key,tint,0,.16f);
            material.mainTexture = Resources.Load<Texture2D>("Textures/roadtest/"+key);
            return material;
        }

        void Connect(string name, Vector3 a, Vector3 b, float width, float height, Material mat, bool collider = false)
        {
            var item = Visuals.Box(name,root,(a+b)*.5f,new Vector3(width,height,Vector3.Distance(a,b)),mat,collider);
            item.transform.rotation = Quaternion.LookRotation(b-a,Vector3.up);
        }

        void Ribbon(string name, Material mat, float left, float right, float lift, bool collider)
        {
            var quads = new List<Vector3>(4*(samples.Count-1));
            for (int i = 0; i < samples.Count-1; i++)
            {
                Vector3 a = Vector3.Cross(Vector3.up,Tangent(i));
                Vector3 b = Vector3.Cross(Vector3.up,Tangent(i+1));
                Vector3 p = samples[i]+Vector3.up*lift, q = samples[i+1]+Vector3.up*lift;
                quads.Add(p+a*left); quads.Add(q+b*left); quads.Add(p+a*right); quads.Add(q+b*right);
            }
            CreateStrip(name,quads,mat,collider);
        }

        void CreateStrip(string name, List<Vector3> verts, Material mat, bool collider)
        {
            int[] indices = new int[verts.Count/4*6];
            var uv = new Vector2[verts.Count];
            for (int i = 0, j = 0; i < verts.Count; i += 4, j += 6)
            {
                indices[j]=i; indices[j+1]=i+1; indices[j+2]=i+2;
                indices[j+3]=i+2; indices[j+4]=i+1; indices[j+5]=i+3;
                for (int k = i; k < i+4; k++) uv[k] = new Vector2(verts[k].x*.27f,verts[k].z*.27f);
            }
            var mesh = new Mesh { name = name, vertices = verts.ToArray(), uv = uv, triangles = indices };
            mesh.RecalculateNormals();
            var obj = new GameObject(name);
            obj.transform.SetParent(root,false);
            obj.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = obj.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = mat;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            if (collider) obj.AddComponent<MeshCollider>().sharedMesh = mesh;
        }
    }

    public static class Visuals
    {
        public static GameObject Box(string name, Transform parent, Vector3 position, Vector3 scale, Material mat, bool collider = false)
            => Shape(name,PrimitiveType.Cube,parent,position,scale,mat,collider);

        public static GameObject Shape(string name, PrimitiveType type, Transform parent, Vector3 position, Vector3 scale, Material mat, bool collider = false)
        {
            var obj = GameObject.CreatePrimitive(type);
            obj.name = name;
            obj.transform.SetParent(parent,false);
            obj.transform.localPosition = position;
            obj.transform.localScale = scale;
            obj.GetComponent<Renderer>().sharedMaterial = mat;
            if (!collider)
            {
                var shape = obj.GetComponent<Collider>();
                shape.enabled = false;
                UnityEngine.Object.Destroy(shape);
            }
            return obj;
        }
    }
}
