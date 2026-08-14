# Builds NullHaptics-setup.exe into dist\.
# Requires Visual Studio 2022 with the "Desktop development with C++" workload
# (which bundles CMake). Run from anywhere: .\build.ps1
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

function Find-CMake {
    $onPath = Get-Command cmake -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vs = & $vswhere -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($vs) {
            $bundled = Join-Path $vs "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
            if (Test-Path $bundled) { return $bundled }
        }
    }
    throw "CMake not found. Install Visual Studio 2022 with the 'Desktop development with C++' workload, or put cmake on PATH."
}

$cmake = Find-CMake
Write-Host "Using CMake: $cmake"
& $cmake -S $root -B "$root\build" -G "Visual Studio 17 2022" -A x64
& $cmake --build "$root\build" --config Release
Write-Host "`nBuilt: $root\dist\NullHaptics-setup.exe"
