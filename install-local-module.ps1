# install module from source using local PSRepository instance
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string] $LocalModulePath = "./Modules",
    [Parameter(Mandatory=$false)]
    [string] $RepositoryName = 'pwshlocal',
    [Parameter(Mandatory=$true)] 
    [switch] $ShouldTeardown
)
$RelativePath = "./$RepositoryName"
# TODO could define as relative to user home - perhaps controlled by a switch ?

if (-not (Test-Path $LocalModulePath -PathType Container)) {
    throw "Unable to install modules - module path not found"
}
$ModuleName = $(Get-ChildItem -Directory -Path $LocalModulePath).Name
Uninstall-Module -Name $ModuleName -AllVersions
Get-Module -Name $ModuleName -ListAvailable -Refresh

New-Item -Path $RelativePath -ItemType 'Directory' -Force | Out-Null
$ResolvedPath = $(Resolve-Path $RelativePath)
Register-PSRepository -Name $RepositoryName `
    -SourceLocation "$ResolvedPath" `
    -PublishLocation "$ResolvedPath" `
    -InstallationPolicy 'Trusted'

$ManifestFile = "$LocalModulePath/${ModuleName}/${ModuleName}.psd1"
$ModuleVersion = $(Import-PowerShellDataFile -Path $ManifestFile).ModuleVersionpw
$ModulePackage = "$RelativePath/$ModuleName.$ModuleVersion.nupkg"
Remove-Item -Path $ModulePackage -ErrorAction 'SilentlyContinue'
Publish-Module -Path "$LocalModulePath/${ModuleName}" -Repository $RepositoryName
Install-Module -Name $ModuleName -Repository $RepositoryName -Scope CurrentUser

if ($ShouldTeardown) {
    Unregister-PSRepository -Name $RepositoryName
    Remove-Item -Path $RelativePath -Recurse -ErrorAction 'SilentlyContinue'
}
