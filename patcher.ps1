param(
    [string]$V8Branch = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
$PatchRoot = Join-Path $RepoRoot "patch"

if (-not (Test-Path $PatchRoot)) {
    # Compatibility: allow running the script from patch/ directly.
    if (Test-Path (Join-Path $PSScriptRoot "v8asm.patch")) {
        $PatchRoot = $PSScriptRoot
        $RepoRoot = Split-Path -Parent $PSScriptRoot
    }
}

$V8Dir = Join-Path $RepoRoot "v8"
if (-not (Test-Path $V8Dir)) {
    throw "v8 directory not found at: $V8Dir"
}

if ([string]::IsNullOrWhiteSpace($V8Branch)) {
    $V8Branch = (git -C $V8Dir rev-parse --abbrev-ref HEAD).Trim()
}

$patchFile = "v8asm.patch"
$PatchPath = Join-Path $PatchRoot $patchFile
if (-not (Test-Path $PatchPath)) {
    throw "Patch file not found: $PatchPath"
}

$toolSource = Join-Path $PatchRoot "main.cc"
$toolTarget = Join-Path $V8Dir "src\disassembler\main.cc"
if (-not (Test-Path $toolSource)) {
    throw "Tool source file not found: $toolSource"
}

Write-Host "Using patch: $patchFile for branch/version: $V8Branch"
$alreadyApplied = $false

Push-Location $V8Dir
try {
    # Already applied? skip gracefully.
    git apply --reverse --check --whitespace=nowarn "$PatchPath" *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Patch already applied, skipping"
        $alreadyApplied = $true
    }
    else {
        git apply --check --whitespace=nowarn "$PatchPath"
        if ($LASTEXITCODE -ne 0) {
            throw "Patch check failed: $PatchPath"
        }

        git apply --whitespace=nowarn "$PatchPath"
        if ($LASTEXITCODE -ne 0) {
            throw "Patch apply failed: $PatchPath"
        }

        Write-Host "Patch applied successfully"
    }
}
finally {
    Pop-Location
}

$toolDir = Split-Path -Parent $toolTarget
New-Item -ItemType Directory -Path $toolDir -Force | Out-Null
Copy-Item -Path $toolSource -Destination $toolTarget -Force
if ($alreadyApplied) {
    Write-Host "Tool source synced to $toolTarget"
}
