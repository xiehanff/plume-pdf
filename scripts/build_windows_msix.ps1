param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$windowsIconSource = Join-Path $repoRoot 'assets\app_icon_1024.png'
$windowsIconRounded = Join-Path $repoRoot 'assets\windows_app_icon_1024.png'
$iconGenInputDir = Join-Path $repoRoot 'build\windows_icon_gen'
$iconGenOutputDir = Join-Path $repoRoot 'build\windows_icon_out'
$runnerIconPath = Join-Path $repoRoot 'windows\runner\resources\app_icon.ico'
$msixBuildDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
Push-Location $repoRoot
try {
    Remove-Item -LiteralPath $iconGenInputDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $iconGenOutputDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $iconGenInputDir | Out-Null
    New-Item -ItemType Directory -Path $iconGenOutputDir | Out-Null

    @'
from pathlib import Path
from PIL import Image, ImageDraw

root = Path.cwd()
source = root / 'assets' / 'app_icon_1024.png'
rounded = root / 'assets' / 'windows_app_icon_1024.png'
icon_dir = root / 'build' / 'windows_icon_gen'

img = Image.open(source).convert('RGBA')
crop = img.crop((96, 96, 928, 928)).resize((920, 920), Image.Resampling.LANCZOS)
canvas = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
mask = Image.new('L', (920, 920), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, 919, 919), radius=196, fill=255)
canvas.paste(crop, (52, 52), mask)
rounded.parent.mkdir(parents=True, exist_ok=True)
canvas.save(rounded)

for size in (16, 24, 32, 48, 64, 128, 256, 1024):
    canvas.resize((size, size), Image.Resampling.LANCZOS).save(icon_dir / f'{size}.png')
'@ | python -

    npx --yes icon-gen -i $iconGenInputDir -o $iconGenOutputDir --ico --ico-name app_icon | Out-Null
    Copy-Item -LiteralPath (Join-Path $iconGenOutputDir 'app_icon.ico') -Destination $runnerIconPath -Force

    fvm dart run msix:build
    fvm dart run msix:pack
}
finally {
    Pop-Location
}
