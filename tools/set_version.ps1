param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [int]$Code
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$projectPath = Join-Path $root "project.godot"
$exportPath = Join-Path $root "export_presets.cfg"

function Update-Or-Insert-Line {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Replacement,
        [string]$InsertAfterPattern
    )

    if ($Content -match $Pattern) {
        return [regex]::Replace($Content, $Pattern, $Replacement)
    }

    return [regex]::Replace($Content, $InsertAfterPattern, "`$0`r`n$Replacement")
}

$project = Get-Content -Raw -Path $projectPath
$project = Update-Or-Insert-Line $project 'config/version="[^"]*"' "config/version=`"$Version`"" 'config/name="[^"]*"'
$project = Update-Or-Insert-Line $project 'config/version_code=\d+' "config/version_code=$Code" 'config/version="[^"]*"'
Set-Content -Path $projectPath -Value $project -NoNewline

$export = Get-Content -Raw -Path $exportPath
$export = [regex]::Replace($export, 'version/code=\d+', "version/code=$Code")
$export = [regex]::Replace($export, 'version/name="[^"]*"', "version/name=`"$Version`"")
Set-Content -Path $exportPath -Value $export -NoNewline

Write-Host "Version updated: $Version ($Code)"
