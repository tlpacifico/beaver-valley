param(
    [ValidateSet('editor', 'run', 'cube', 'assets', 'check', 'export-windows', 'export-android', 'branch-export')]
    [string]$Action = 'run'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$gamePath = Join-Path $projectRoot 'game'
$godotDir = Join-Path $env:LOCALAPPDATA 'Programs\Godot\4.7.2'
$godotConsole = Join-Path $godotDir 'Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godotConsole)) {
    throw 'Godot 4.7.2 not found. See docs/castor/how-to-run.md.'
}

switch ($Action) {
    'editor' {
        # Opens a visible window, explicitly requested by running this action.
        & $godotConsole --path $gamePath --editor
    }
    'run' { & $godotConsole --path $gamePath }
    'cube' { & $godotConsole --path $gamePath res://scenes/bootstrap.tscn }
    'assets' { & $godotConsole --path $gamePath res://scenes/asset_import_test.tscn }
    'check' {
        & $godotConsole --headless --path $gamePath --import
        if ($LASTEXITCODE -ne 0) { throw 'The project resources failed to import.' }
        & $godotConsole --headless --path $gamePath res://scenes/bootstrap.tscn -- --smoke-test
        if ($LASTEXITCODE -ne 0) { throw 'The cube test failed.' }
        & $godotConsole --headless --path $gamePath --fixed-fps 60 --script res://tests/movement_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The movement test failed.' }
        & $godotConsole --headless --path $gamePath --script res://tests/asset_import_test.gd
    }
    'export-windows' {
        $outputDir = Join-Path $projectRoot 'builds\windows'
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        & $godotConsole --headless --path $gamePath --export-debug 'Windows Desktop' (Join-Path $outputDir 'Castor.exe')
    }
    'export-android' {
        $outputDir = Join-Path $projectRoot 'builds\android'
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        & $godotConsole --headless --path $gamePath --export-debug Android (Join-Path $outputDir 'castor-debug.apk')
    }
    'branch-export' {
        # Re-exports the test branch from its .blend source and reimports it into the project.
        $blender = Join-Path $env:LOCALAPPDATA 'Programs\Blender\blender-5.2.3-windows-x64\blender.exe'
        if (-not (Test-Path -LiteralPath $blender)) {
            throw 'Blender 5.2.3 not found. See docs/castor/how-to-run.md.'
        }
        & $blender --background --factory-startup (Join-Path $projectRoot 'art\props\test_branch.blend') --python (Join-Path $projectRoot 'art\props\test_branch.py') -- export
        if ($LASTEXITCODE -ne 0) { throw "Blender exited with code $LASTEXITCODE." }
        & $godotConsole --headless --path $gamePath --import
    }
}
if ($LASTEXITCODE -ne 0) { throw "Godot exited with code $LASTEXITCODE." }
