param(
    [ValidateSet('editor', 'run', 'playtest', 'beaver-playtest', 'follow', 'cube', 'assets', 'relief', 'relief-capture', 'traversal', 'traversal-capture', 'check', 'export-windows', 'export-android', 'branch-export')]
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
    'playtest' { & $godotConsole --path $gamePath -- --fresh-save }
    'beaver-playtest' { & $godotConsole --path $gamePath -- --beaver-playtest --fresh-save }
    'follow' { & $godotConsole --path $gamePath -- --camera-follow }
    'cube' { & $godotConsole --path $gamePath res://scenes/bootstrap.tscn }
    'assets' { & $godotConsole --path $gamePath res://scenes/asset_import_test.tscn }
    'relief' { & $godotConsole --path $gamePath res://scenes/valley_relief_preview.tscn }
    'relief-capture' { & $godotConsole --path $gamePath res://scenes/valley_relief_preview.tscn -- --capture-relief }
    'traversal' { & $godotConsole --path $gamePath res://scenes/valley_traversal_preview.tscn }
    'traversal-capture' { & $godotConsole --path $gamePath res://scenes/valley_traversal_preview.tscn -- --capture-traversal }
    'check' {
        & $godotConsole --headless --path $gamePath --import
        if ($LASTEXITCODE -ne 0) { throw 'The project resources failed to import.' }
        & $godotConsole --headless --path $gamePath res://scenes/bootstrap.tscn -- --smoke-test
        if ($LASTEXITCODE -ne 0) { throw 'The cube test failed.' }
        & $godotConsole --headless --path $gamePath --fixed-fps 60 --script res://tests/movement_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The movement test failed.' }
        & $godotConsole --headless --path $gamePath --fixed-fps 60 --script res://tests/chapter_feedback_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The chapter feedback test failed.' }
        & $godotConsole --headless --path $gamePath --fixed-fps 60 --script res://tests/construction_feedback_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The construction feedback test failed.' }
        & $godotConsole --headless --path $gamePath --fixed-fps 60 --script res://tests/branch_flight_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The branch flight test failed.' }
        & $godotConsole --headless --path $gamePath --script res://tests/valley_terrain_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The valley terrain test failed.' }
        & $godotConsole --headless --path $gamePath --script res://tests/valley_water_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The valley water test failed.' }
        & $godotConsole --headless --path $gamePath --script res://tests/valley_collision_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The valley collision test failed.' }
        & $godotConsole --headless --path $gamePath --script res://tests/valley_navigation_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The valley navigation test failed.' }
        & $godotConsole --headless --path $gamePath --fixed-fps 60 --script res://tests/valley_traversal_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The valley traversal test failed.' }
        & $godotConsole --headless --path $gamePath --script res://tests/valley_preview_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The valley preview test failed.' }
        & $godotConsole --headless --path $gamePath --script res://tests/dam_save_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The dam save test failed.' }
        & $godotConsole --headless --path $gamePath --fixed-fps 60 --script res://tests/save_fixture_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The save fixture test failed.' }
        & $godotConsole --headless --path $gamePath --script res://tests/home_stage_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The home stage test failed.' }
        & $godotConsole --headless --path $gamePath --script res://tests/food_stage_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The food stage test failed.' }
        & $godotConsole --headless --path $gamePath --script res://tests/ending_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The ending test failed.' }
        & $godotConsole --headless --path $gamePath --script res://tests/support_characters_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The support character test failed.' }
        & $godotConsole --headless --path $gamePath --script res://tests/visual_environment_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The visual environment test failed.' }
        & $godotConsole --headless --path $gamePath --script res://tests/beaver_actor_test.gd
        if ($LASTEXITCODE -ne 0) { throw 'The beaver actor test failed.' }
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
