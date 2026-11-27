using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.Rendering;

namespace Roadline.Editor
{
    public static class RoadlineBuild
    {
        const string Scene = "Assets/Scenes/Main.unity";
        const string Apk = "Builds/Roadline-P280.apk";

        [MenuItem("Roadline/Prepare project")]
        public static void Prepare()
        {
            PlayerSettings.companyName = "Roadline";
            PlayerSettings.productName = "Roadline P280";
            PlayerSettings.bundleVersion = "0.7.0";
            PlayerSettings.Android.bundleVersionCode = 7;
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android,"com.roadline.mobile");
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = true;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android,ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.Android,false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android,new[] {GraphicsDeviceType.OpenGLES3});
            EditorBuildSettings.scenes = new[] {new EditorBuildSettingsScene(Scene,true)};
            IncludeShaders();
            AssetDatabase.SaveAssets();
        }

        static void IncludeShaders()
        {
            UnityEngine.Object[] loaded = AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/GraphicsSettings.asset");
            if (loaded.Length == 0) return;
            var settings = new SerializedObject(loaded[0]);
            var shaders = settings.FindProperty("m_AlwaysIncludedShaders");
            if (shaders == null) return;
            foreach (string name in new[] {"Standard","Particles/Standard Unlit","Sprites/Default"})
            {
                Shader shader = Shader.Find(name);
                if (!shader) continue;
                bool seen = false;
                for (int i=0;i<shaders.arraySize;i++)
                    if (shaders.GetArrayElementAtIndex(i).objectReferenceValue==shader) seen=true;
                if (seen) continue;
                int index = shaders.arraySize;
                shaders.InsertArrayElementAtIndex(index);
                shaders.GetArrayElementAtIndex(index).objectReferenceValue=shader;
            }
            settings.ApplyModifiedPropertiesWithoutUndo();
        }

        [MenuItem("Roadline/Build Android APK")]
        public static void BuildAndroid()
        {
            Prepare();
            if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.Android &&
                !EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android,BuildTarget.Android))
                throw new InvalidOperationException("Install Android Build Support and switch the project to Android.");
            EditorUserBuildSettings.buildAppBundle = false;
            Directory.CreateDirectory("Builds");
            var result = BuildPipeline.BuildPlayer(new[] {Scene},Apk,BuildTarget.Android,BuildOptions.None);
            if (result.summary.result != BuildResult.Succeeded || !File.Exists(Apk))
                throw new InvalidOperationException("APK build failed: "+result.summary.result);
            Debug.Log("APK built: "+Path.GetFullPath(Apk));
        }
    }
}
