using System;
using UnityEngine;

namespace Roadline
{
    public static class Sounds
    {
        public static AudioClip Engine { get; } = Make("Diesel idle",.5f,(t,r)=>.44*Math.Sin(t*2*Math.PI*48)+.22*Math.Sin(t*2*Math.PI*96)+.08*Math.Sin(t*2*Math.PI*152)+.025*r);
        public static AudioClip Propeller { get; } = Make("Electric propeller",.4f,(t,r)=>.34*Math.Sin(t*2*Math.PI*140)+.20*Math.Sin(t*2*Math.PI*280)+.08*Math.Sin(t*2*Math.PI*565)+.025*r);
        public static AudioClip Pulse { get; } = Make("Game turret pulse",.19f,(t,r)=>Math.Exp(-24*t)*(.55*r+.30*Math.Sin((137-320*t)*t*2*Math.PI)));
        public static AudioClip Impact { get; } = Make("Impact",.66f,(t,r)=>Math.Exp(-8*t)*(.37*r+.51*Math.Sin((78-39*t)*t*2*Math.PI)));
        public static AudioClip Brakes { get; } = Make("Air brakes",.46f,(t,r)=>Math.Sin(Math.Min(1,t/.46)*Math.PI)*Math.Exp(-4*t)*r*.7);
        public static AudioClip Scan { get; } = Make("Telemetry chime",.22f,(t,r)=>Math.Exp(-12*t)*.46*Math.Sin((520+650*t)*t*2*Math.PI));

        static AudioClip Make(string name,float seconds,Func<double,double,double> wave)
        {
            const int rate = 16000;
            var samples = new float[Mathf.RoundToInt(seconds*rate)];
            var noise = new System.Random(280+name.Length);
            for (int i=0;i<samples.Length;i++)
                samples[i]=(float)wave(i/(double)rate,noise.NextDouble()*2-1);
            var clip = AudioClip.Create(name,samples.Length,1,rate,false);
            clip.SetData(samples,0);
            return clip;
        }

        public static AudioSource Loop(Transform parent,AudioClip clip,float near,float far,float volume)
        {
            var source = parent.gameObject.AddComponent<AudioSource>();
            source.clip = clip;
            source.spatialBlend = 1;
            source.minDistance = near;
            source.maxDistance = far;
            source.rolloffMode = AudioRolloffMode.Linear;
            source.dopplerLevel = .85f;
            source.volume = volume;
            source.loop = true;
            source.Play();
            return source;
        }
    }

    public static class Effects
    {
        static Material dots;
        static Material line;
        public static ParticleSystem Emitter(Transform parent,float z,bool flame)
        {
            var obj = new GameObject(flame ? "Freight fire" : "Freight smoke");
            obj.transform.SetParent(parent,false);
            obj.transform.localPosition = new Vector3(0,2.28f,z);
            var particles = obj.AddComponent<ParticleSystem>();
            particles.Stop(true,ParticleSystemStopBehavior.StopEmittingAndClear);
            var main = particles.main;
            main.loop = true;
            main.playOnAwake = false;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.startLifetime = flame ? .71f : 2.8f;
            main.startSpeed = new ParticleSystem.MinMaxCurve(.9f,2.3f);
            main.startSize = new ParticleSystem.MinMaxCurve(.3f,flame ? .83f : 1.45f);
            main.startColor = flame ? new Color(1,.37f,.07f,.80f) : new Color(.25f,.23f,.21f,.64f);
            main.gravityModifier = -.24f;
            main.maxParticles = flame ? 25 : 42;
            var emission = particles.emission;
            emission.rateOverTime = flame ? 16 : 11;
            var shape = particles.shape;
            shape.shapeType = ParticleSystemShapeType.Sphere;
            shape.radius = .55f;
            particles.GetComponent<ParticleSystemRenderer>().sharedMaterial = Dots();
            return particles;
        }

        static Material Dots()
        {
            if (dots) return dots;
            dots = new Material(Shader.Find("Particles/Standard Unlit") ?? Shader.Find("Sprites/Default"));
            var texture = new Texture2D(32,32,TextureFormat.RGBA32,false);
            var pixels = new Color[1024];
            for (int y = 0; y<32; y++)
            for (int x = 0; x<32; x++)
            {
                float r = Vector2.Distance(new Vector2(x,y),new Vector2(15.5f,15.5f))/15.5f;
                pixels[y*32+x] = new Color(1,1,1,Mathf.Pow(Mathf.Clamp01(1-r),1.7f));
            }
            texture.SetPixels(pixels);
            texture.Apply(false,true);
            dots.mainTexture = texture;
            if (dots.HasProperty("_Mode"))
            {
                dots.SetFloat("_Mode",2);
                dots.SetInt("_SrcBlend",(int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                dots.SetInt("_DstBlend",(int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                dots.SetInt("_ZWrite",0);
                dots.renderQueue = 3000;
            }
            return dots;
        }

        public static void Burst(Vector3 point,bool damage)
        {
            var container = new GameObject("Impact particles");
            container.transform.position = point;
            var smoke = Emitter(container.transform,0,false);
            var f = Emitter(container.transform,0,true);
            foreach (var p in new[] {smoke,f})
            {
                p.transform.localPosition = Vector3.zero;
                var main = p.main;
                main.loop = false;
                main.startSpeed = new ParticleSystem.MinMaxCurve(1,damage ? 8 : 3);
                var emission = p.emission;
                emission.rateOverTime = 0;
                p.Play();
                p.Emit(damage ? 13 : 5);
            }
            if (damage)
            {
                var flash = container.AddComponent<Light>();
                flash.type = LightType.Point;
                flash.color = new Color(1,.54f,.22f);
                flash.intensity = 3;
                flash.range = 9;
                UnityEngine.Object.Destroy(flash,.075f);
            }
            UnityEngine.Object.Destroy(container,3.05f);
        }

        public static void Trace(Vector3 start,Vector3 end,Color color)
        {
            if (!line) line = new Material(Shader.Find("Sprites/Default"));
            var obj = new GameObject("Trace");
            var renderer = obj.AddComponent<LineRenderer>();
            renderer.sharedMaterial = line;
            renderer.startColor = color;
            renderer.endColor = new Color(color.r,color.g,color.b,0);
            renderer.startWidth = .033f;
            renderer.endWidth = .012f;
            renderer.positionCount = 2;
            renderer.SetPosition(0,start);
            renderer.SetPosition(1,end);
            UnityEngine.Object.Destroy(obj,.052f);
        }
    }
}
