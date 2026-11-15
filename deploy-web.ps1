[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Command,

        [Parameter()]
        [string[]] $Arguments = @()
    )

    Write-Host ''
    Write-Host (">> " + $Command + " " + ($Arguments -join ' ')) -ForegroundColor Cyan
    & $Command @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw ("Command '{0}' failed with exit code {1}." -f $Command, $LASTEXITCODE)
    }
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$appDirectory = Join-Path $repoRoot 'apps\songie'
$hostingConfig = Join-Path $repoRoot 'firebase.json'

if (-not (Test-Path (Join-Path $appDirectory 'pubspec.yaml'))) {
    throw "Flutter app not found at '$appDirectory'."
}

if (-not (Test-Path $hostingConfig)) {
    throw "Firebase configuration not found at '$hostingConfig'."
}

foreach ($commandName in @('flutter', 'firebase')) {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        throw "'$commandName' was not found on PATH. Please install it and reopen PowerShell."
    }
}

Push-Location $repoRoot
try {
    Write-Host 'Songie web deployment' -ForegroundColor Green
    Write-Host 'Target project: songie-prod'
    Write-Host 'Repository: ' $repoRoot

    # Match the CI setup: generate the web runner only when it is missing.
    $webIndex = Join-Path $appDirectory 'web\index.html'
    if (-not (Test-Path $webIndex)) {
        Push-Location $appDirectory
        try {
            Invoke-CheckedCommand -Command 'flutter' -Arguments @(
                'create', '--empty', '--platforms=web', '.'
            )
        }
        finally {
            Pop-Location
        }
    }

    # Verify the shared ChordPro importer package.
    Push-Location (Join-Path $repoRoot 'packages\chordpro')
    try {
        Invoke-CheckedCommand -Command 'flutter' -Arguments @('pub', 'get')
        Invoke-CheckedCommand -Command 'flutter' -Arguments @('analyze')
        Invoke-CheckedCommand -Command 'flutter' -Arguments @('test')
    }
    finally {
        Pop-Location
    }

    # Resolve Flutter dependencies, analyze and test the app, then build web.
    Push-Location $appDirectory
    try {
        Invoke-CheckedCommand -Command 'flutter' -Arguments @('pub', 'get')
        Invoke-CheckedCommand -Command 'flutter' -Arguments @('analyze')
        Invoke-CheckedCommand -Command 'flutter' -Arguments @('test')
        Invoke-CheckedCommand -Command 'flutter' -Arguments @(
            'build', 'web', '--release'
        )
    }
    finally {
        Pop-Location
    }

    $builtIndex = Join-Path $appDirectory 'build\web\index.html'
    if (-not (Test-Path $builtIndex)) {
        throw "Web build did not create '$builtIndex'. Deployment cancelled."
    }

    # Use an explicit project ID; this does not depend on the active Firebase alias.
    Invoke-CheckedCommand -Command 'firebase' -Arguments @(
        'deploy', '--only', 'hosting', '--project', 'songie-prod'
    )

    Write-Host ''
    Write-Host 'Songie was successfully deployed:' -ForegroundColor Green
    Write-Host 'https://songie-prod.web.app' -ForegroundColor Green
}
finally {
    Pop-Location -ErrorAction SilentlyContinue
}
