function Format-ParamAsString() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Parameters
    )
    @(
        (($Parameters.ProjectId) -match "\d") ? $Parameters.ProjectId : ($Parameters.ProjectId).Split('/')[-1] 
        $Parameters.Branch
        $Parameters.HostEnv
        $Parameters.PipelineStage
        (Get-Date -Date $Parameters.CompletedAfter -Format d)
    ) -join "_"
}

class JobParam {
    [string] $ProjectId
    [string] $Branch = 'main'
    [datetime] $CompletedAfter = (Get-Date).AddDays(-30)
    [string] $HostEnv = 'test'
    [string] $PipelineStage = 'test'
    JobParam([string] $projectId) {
        $this.ProjectId = $projectId
    }
    [string] ToString() { return ($this.Build() | Format-ParamAsString) }
    [hashtable] Build() {
        return @{ 
            ProjectId = $this.ProjectId
            Branch = $this.Branch
            CompletedAfter = $this.CompletedAfter
            HostEnv = $this.HostEnv
            PipelineStage = $this.PipelineStage
        }
    }
}

function New-JobParam() {
    param (
        [Parameter(Mandatory=$false)]
        [string] $ProjectId = '',
        [Parameter(Mandatory=$false)]
        [string] $Branch = $null,
        [Parameter(Mandatory=$false)]
        [string] $HostEnv = $null,
        [Parameter(Mandatory=$false)]
        [string] $PipelineStage = $null,
        [Parameter(Mandatory=$false)]
        [nullable[datetime]] $CreatedAfter = $null
    )
    $JobParam = [JobParam]::new($ProjectId)
    if(-not [string]::IsNullOrEmpty($Branch)){
        $JobParam.Branch = $Branch
    }
    if(-not [string]::IsNullOrEmpty($HostEnv)){
        $JobParam.HostEnv = $HostEnv
    }
    if(-not [string]::IsNullOrEmpty($PipelineStage)){
        $JobParam.PipelineStage = $PipelineStage
    }
    if(($null -ne $CreatedAfter)){
        $JobParam.CompletedAfter = $CreatedAfter
    }
    $JobParam.Build()
}
