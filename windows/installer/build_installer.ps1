param(
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$issPath = Join-Path $scriptDir 'plume_pdf.iss'

if (-not (Test-Path -LiteralPath $pubspecPath)) {
  throw "pubspec.yaml not found: $pubspecPath"
}

$pubspecContent = Get-Content -LiteralPath $pubspecPath
$versionLine = $pubspecContent | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
if (-not $versionLine) {
  throw 'Missing version field in pubspec.yaml'
}

$appVersion = (($versionLine -replace '^version:\s*', '').Split('+')[0]).Trim()

Push-Location $repoRoot
try {
  if (-not $SkipBuild) {
    & fvm flutter build windows --release --verbose
  }

  if (-not (Test-Path -LiteralPath $releaseDir)) {
    throw "Release directory not found: $releaseDir"
  }

  $isccCommand = Get-Command iscc.exe -ErrorAction SilentlyContinue
  $isccPath = $isccCommand.Source

  if (-not $isccPath) {
    $candidatePaths = @(
      (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
      (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
    )

    foreach ($candidatePath in $candidatePaths) {
      if ($candidatePath -and (Test-Path -LiteralPath $candidatePath)) {
        $isccPath = $candidatePath
        break
      }
    }
  }

  if (-not $isccPath) {
    $compilerShortcutPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Inno Setup 6\Inno Setup Compiler.lnk'
    if (Test-Path -LiteralPath $compilerShortcutPath) {
      $wshShell = New-Object -ComObject WScript.Shell
      $compilerShortcut = $wshShell.CreateShortcut($compilerShortcutPath)
      if ($compilerShortcut.TargetPath) {
        $shortcutDir = Split-Path -Parent $compilerShortcut.TargetPath
        $shortcutIsccPath = Join-Path $shortcutDir 'ISCC.exe'
        if (Test-Path -LiteralPath $shortcutIsccPath) {
          $isccPath = $shortcutIsccPath
        }
      }
    }
  }

  if (-not $isccPath) {
    throw 'ISCC.exe not found. Install Inno Setup first.'
  }

  & $isccPath "/DMyAppVersion=$appVersion" $issPath
}
finally {
  Pop-Location
}
