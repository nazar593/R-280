using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
namespace R280.Editor {
    public static class AndroidBuild {
        const string ScenePath="Assets/Scenes/Stage01.unity";
        [MenuItem("R-280/Create or open Stage 01")]
        public static void OpenScene() {
            if(File.Exists(ScenePath)) {EditorSceneManager.OpenScene(ScenePath);return;}
            Directory.CreateDirectory("Assets/Scenes");
            var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
            EditorSceneManager.SaveScene(scene,ScenePath);
            EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene(ScenePath,true)};
        }
        [MenuItem("R-280/Build Android APK")]
        public static void Build() {
            OpenScene();
            PlayerSettings.companyName="R280";
            PlayerSettings.productName="R-280 Field Prototype";
            PlayerSettings.bundleVersion="0.1.0";
            PlayerSettings.SetApplicationIdentifier(UnityEditor.Build.NamedBuildTarget.Android,"com.r280.fieldprototype");
            PlayerSettings.defaultInterfaceOrientation=UIOrientation.LandscapeLeft;
            PlayerSettings.SetScriptingBackend(UnityEditor.Build.NamedBuildTarget.Android,ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures=AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion=AndroidSdkVersions.AndroidApiLevel26;
            PlayerSettings.Android.bundleVersionCode=1;
            EditorUserBuildSettings.buildAppBundle=false;
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android,new[]{UnityEngine.Rendering.GraphicsDeviceType.OpenGLES3});
            Directory.CreateDirectory("Builds");
            var options=new BuildPlayerOptions { scenes=new[]{ScenePath},locationPathName="Builds/R280-stage01.apk",target=BuildTarget.Android,options=BuildOptions.None };
            BuildReport report=BuildPipeline.BuildPlayer(options);
            if(report.summary.result!=BuildResult.Succeeded) throw new System.Exception("Android build failed: "+report.summary.result);
            Debug.Log("APK: "+report.summary.outputPath);
        }
    }
}
