param(
    [Parameter(Mandatory = $true)]
    [string]$UnityExe
)
$ErrorActionPreference = "Stop"
$projectPath = $PSScriptRoot
$logPath = Join-Path $projectPath "android-build.log"
$apkPath = Join-Path $projectPath "Builds/Roadline-P280.apk"
$unity = (Resolve-Path -LiteralPath $UnityExe).Path
$arguments = @(
    "-batchmode", "-nographics", "-quit",
    "-projectPath", ('"' + $projectPath + '"'),
    "-buildTarget", "Android",
    "-executeMethod", "Roadline.Editor.RoadlineBuild.BuildAndroid",
    "-logFile", ('"' + $logPath + '"')
)
$process = Start-Process -FilePath $unity -ArgumentList $arguments -Wait -PassThru -NoNewWindow
if ($process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $apkPath)) {
    throw "APK build failed. See $logPath"
}
Write-Host $apkPath
