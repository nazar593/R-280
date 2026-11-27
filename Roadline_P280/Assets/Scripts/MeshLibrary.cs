using System;
using System.Collections.Generic;
using UnityEngine;
namespace Roadline {
public static class MeshLibrary {
 [Serializable] public class Part { public string name; public float[] color,vertices,normals,uv; public string texture; public int[] triangles; public float metallic,smoothness; }
 [Serializable] public class Model { public Part[] parts; }
 static readonly Dictionary<string,Model> cache=new();
 static readonly Dictionary<string,Mesh> meshes=new();
 static readonly Dictionary<string,Material> materials=new();
 public static Material MaterialFor(string key,Color color,float metal=0,float smooth=.25f) {
  if(materials.TryGetValue(key,out var m)) return m;
  var shader=Shader.Find("Standard"); if(!shader) shader=Shader.Find("Diffuse");
  m=new Material(shader){name=key,color=color}; if(m.HasProperty("_Metallic"))m.SetFloat("_Metallic",metal); if(m.HasProperty("_Glossiness"))m.SetFloat("_Glossiness",smooth); materials.Add(key,m);return m;
 }
 public static GameObject Spawn(string name,Transform parent) {
  // Authored, normalized visual-only prefabs take precedence over test meshes.
  var external=Resources.Load<GameObject>("ImportedVisuals/"+name);
  if(external){var instance=UnityEngine.Object.Instantiate(external,parent,false);instance.name=name;return instance;}
  if(!cache.TryGetValue(name,out var model)) { var file=Resources.Load<TextAsset>("Meshes/"+name); if(!file)throw new InvalidOperationException("Missing mesh: "+name); model=JsonUtility.FromJson<Model>(file.text);cache.Add(name,model); }
  var root=new GameObject(name);root.transform.SetParent(parent,false);
  foreach(var p in model.parts) {
   string key=name+"/"+p.name;var child=new GameObject(p.name);child.transform.SetParent(root.transform,false);
   if(!meshes.TryGetValue(key,out var mesh)) { var v=new Vector3[p.vertices.Length/3];for(int i=0;i<v.Length;i++)v[i]=new Vector3(p.vertices[3*i],p.vertices[3*i+1],p.vertices[3*i+2]);mesh=new Mesh{name=key};if(v.Length>65535)mesh.indexFormat=UnityEngine.Rendering.IndexFormat.UInt32;mesh.vertices=v;mesh.triangles=p.triangles;if(p.normals!=null&&p.normals.Length==p.vertices.Length){var n=new Vector3[v.Length];for(int i=0;i<n.Length;i++)n[i]=new Vector3(p.normals[i*3],p.normals[i*3+1],p.normals[i*3+2]);mesh.normals=n;}else mesh.RecalculateNormals();if(p.uv!=null&&p.uv.Length==v.Length*2){var uv=new Vector2[v.Length];for(int i=0;i<uv.Length;i++)uv[i]=new Vector2(p.uv[2*i],p.uv[2*i+1]);mesh.uv=uv;}mesh.RecalculateBounds();meshes.Add(key,mesh); }
   child.AddComponent<MeshFilter>().sharedMesh=mesh;var material=MaterialFor(key,new Color(p.color[0],p.color[1],p.color[2]),p.normals!=null&&p.normals.Length>0?p.metallic:(p.name.Contains("metal")||p.name.Contains("rim")? .55f : 0),p.normals!=null&&p.normals.Length>0?p.smoothness:(p.name.Contains("glazing")? .8f : .25f));if(!string.IsNullOrEmpty(p.texture)&&!material.mainTexture){var tex=Resources.Load<Texture2D>(p.texture);if(tex)material.mainTexture=tex;}child.AddComponent<MeshRenderer>().sharedMaterial=material;
  } return root;
 }
}
}
