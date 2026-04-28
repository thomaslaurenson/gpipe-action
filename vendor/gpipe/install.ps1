# {{GPIPE_GENERATED_BY}}
param(
  [switch]$User
)
$ErrorActionPreference = "Stop"

$Repo        = "{{REPO}}"
$Version     = "{{VERSION}}"
$Binary      = "{{BINARY}}"
$InstallName = "{{INSTALL_NAME}}"

# Detect OS and architecture
$OSPlatform = [System.Environment]::OSVersion.Platform
$Arch       = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture

$NormOS = switch ($OSPlatform) {
  "Win32NT" { "windows" }
  default {
    Write-Error "Unsupported OS: $OSPlatform"
    exit 1
  }
}

$NormArch = switch ($Arch) {
  "X64"   { "amd64" }
  "Arm64" { "arm64" }
  default {
    Write-Error "Unsupported architecture: $Arch"
    exit 1
  }
}

$Platform = "${NormOS}_${NormArch}"

# Validate detected platform against supported list (baked in at generation time)
{{SUPPORTED_PLATFORMS_BLOCK}}

# Asset name map: platform -> download filename (baked in at generation time)
{{ASSET_MAP_BLOCK}}

$AssetName   = $AssetNames[$Platform]
$DownloadUrl = "https://github.com/$Repo/releases/download/$Version/$AssetName"
$ChecksumsUrl = "https://github.com/$Repo/releases/download/$Version/checksums.txt"

{{PRE_INSTALL_HOOK}}

# Download binary and checksums
$TmpDir = [System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName()
New-Item -ItemType Directory -Path $TmpDir | Out-Null

try {
  Write-Host "Downloading $Binary $Version for $Platform..."
  Invoke-WebRequest -Uri $DownloadUrl  -OutFile "$TmpDir\$AssetName"  -UseBasicParsing
  Invoke-WebRequest -Uri $ChecksumsUrl -OutFile "$TmpDir\checksums.txt" -UseBasicParsing

  # Verify SHA256 checksum
  Write-Host "Verifying checksum..."
  $ChecksumLine = Get-Content "$TmpDir\checksums.txt" | Where-Object { $_ -match "^[a-f0-9]+  $([regex]::Escape($AssetName))$" }
  if (-not $ChecksumLine) {
    Write-Error "Checksum not found for $AssetName in checksums.txt"
    Remove-Item "$TmpDir\$AssetName" -Force
    exit 1
  }
  $ExpectedHash = ($ChecksumLine -split "\s+")[0]
  $ActualHash   = (Get-FileHash -Algorithm SHA256 "$TmpDir\$AssetName").Hash.ToLower()

  if ($ExpectedHash -ne $ActualHash) {
    Write-Error "Checksum mismatch for ${AssetName}:`n  expected: $ExpectedHash`n  actual:   $ActualHash"
    Remove-Item "$TmpDir\$AssetName" -Force
    exit 1
  }
  Write-Host "Checksum verified."

  # Install binary
  $UserInstall = $User.IsPresent

  if ($UserInstall) {
    $InstallDir = "$env:LOCALAPPDATA\Programs\$InstallName"
  } else {
    $InstallDir = "$env:ProgramFiles\$InstallName"
  }

  if (-not $UserInstall) {
    try {
      if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir | Out-Null
      }
      Copy-Item "$TmpDir\$AssetName" "$InstallDir\$InstallName.exe" -Force
    } catch {
      Write-Host "Insufficient permissions for system install. Installing to user directory instead."
      $UserInstall = $true
      $InstallDir = "$env:LOCALAPPDATA\Programs\$InstallName"
    }
  }

  if ($UserInstall) {
    if (-not (Test-Path $InstallDir)) {
      New-Item -ItemType Directory -Path $InstallDir | Out-Null
    }
    Copy-Item "$TmpDir\$AssetName" "$InstallDir\$InstallName.exe" -Force
  }

# BEGIN_BLOCK:COMPLETION_POWERSHELL
  # Install PowerShell completions
  try {
    $CompletionScript = & "$InstallDir\$InstallName.exe" completion powershell 2>&1
    if ($LASTEXITCODE -eq 0) {
      $ProfileDir = Split-Path $PROFILE
      if (-not (Test-Path $ProfileDir)) {
        New-Item -ItemType Directory -Path $ProfileDir | Out-Null
      }
      if (-not (Test-Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE | Out-Null
      }
      Add-Content -Path $PROFILE -Value "`n# $Binary completions`n$CompletionScript"
      Write-Host "Installed PowerShell completions to $PROFILE"
    } else {
      Write-Warning "PowerShell completion generation failed, skipping"
    }
  } catch {
    Write-Warning "PowerShell completion generation failed, skipping: $_"
  }
# END_BLOCK:COMPLETION_POWERSHELL

{{POST_INSTALL_HOOK}}

  # PATH verification and repair (user-local installs only)
  if ($UserInstall) {
    $UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($UserPath -notlike "*$InstallDir*") {
      [Environment]::SetEnvironmentVariable("PATH", "$InstallDir;$UserPath", "User")
      Write-Host "Added $InstallDir to user PATH. Restart your terminal for changes to take effect."
    }
  } else {
    if (-not (Get-Command $InstallName -ErrorAction SilentlyContinue)) {
      Write-Warning "$InstallName is not reachable via PATH"
    }
  }

  Write-Host "Successfully installed $InstallName $Version"

} finally {
  Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}
