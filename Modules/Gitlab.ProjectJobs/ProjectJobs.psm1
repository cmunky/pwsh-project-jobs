# Gitlab Project Pipeline Jobs

# Import-Module GitlabCli # import dependency if required

function Get-JobDurationSummary () {    
    param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [psobject[]]
    $Value,

    [Parameter(Mandatory=$true, Position=1)]
    [string]
    $Status
    )
    begin { $ProjectJobs = @()}
    process { $ProjectJobs += $Value }
    end {
    ($ProjectJobs | 
        Where-Object Status -eq $Status | 
        Measure-Object -Property duration -Minimum -Maximum -Average | 
        Select-Object -Property Average, Minimum, Maximum, Count)
    }
}

function ConvertTo-JobSummary {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [psobject[]]
        $Value
    )
    begin { $ProjectJobs = @()}
    process { $ProjectJobs += $Value }
    end {
        [PSCustomObject]@{
            Success = $ProjectJobs | Get-JobDurationSummary -Status success
            Failed = $ProjectJobs | Get-JobDurationSummary -Status failed
        }
    }
}

function Find-GitlabProjectJobs() {
    param (
        [Parameter(Mandatory=$false)]
        [string]
        $ProjectId = ".",

        [Parameter(Mandatory=$true, Position=0)]
        [datetime]
        $CompletedAfter,

        [Parameter(Mandatory=$true, Position=1)]
        [ValidateSet('test', 'deploy')]
        [string] $PipelineStage,

        [Parameter(Mandatory=$false, Position=2)]
        [string] 
        $Branch = 'main', 

        [Parameter(Mandatory=$false, Position=3)]
        [string] 
        $HostEnv = 'test',

        [Parameter(Mandatory=$false, Position=4)]
        [switch] 
        $IncludeJobSummary,

        [Parameter(Mandatory=$false, Position=5)]
        [string[]] 
        $Scopes = @('success', 'failed')
    )
    $ProjectPath = (Get-GitlabProject $ProjectId ).PathWithNamespace
    $JobStatus = "[$($Scopes -join ",")]".ToUpper() 
    $StartCursor = ""
    $JobDetails = @()
    
    $page = 0
    $found = $false
    while (-not $found) {
        $page++
        $Data = Invoke-GitlabGraphQL -Query @"
        {
            project(fullPath: "$ProjectPath") {
                jobs(statuses: $JobStatus, after: "$StartCursor") {
                    count
                    pageInfo {
                        hasNextPage
                        startCursor
                        endCursor
                    }
                    nodes {
                        name
                        refName
                        finishedAt
                        duration
                        queuedDuration
                        stage {
                            name
                            status
                        }
                    }
                }
            }
        }
"@
        $Jobs = $Data.Project.Jobs
        $JobDetails += $Jobs.nodes
        $found = ($JobDetails | Select-Object -Last 1).finishedAt -lt $CompletedAfter
        $StartCursor = $Jobs.pageInfo.hasNextPage ? $Jobs.pageInfo.endCursor : ""
    }
    $FilteredJobs = ($JobDetails
    | Where-Object { 
        $_.finishedAt -gt $CompletedAfter -and 
        $_.refName -ieq $Branch -and 
        $_.name.Contains($HostEnv) -and 
        $_.stage.name.Contains([string]$PipelineStage)} 
    | ForEach-Object {[PSCustomObject]@{
        Name = $_.name
        Ref = $_.refName
        Duration = $_.duration
        QueuedDuration = $_.queuedDuration
        FinishedAt = $_.finishedAt
        Stage = $_.stage.Name
        Status = $_.stage.status
    }})

    $Response = [PSCustomObject]@{
        Service = ($ProjectPath).Split('/')[-1] 
        CompletedAfter = $CompletedAfter
        Jobs = $FilteredJobs
    }
    if ($IncludeJobSummary) {
        $Response | Add-Member -MemberType 'NoteProperty' -Name 'JobSummary' -Value $($FilteredJobs | ConvertTo-JobSummary)
    }
    $Response
}
Export-ModuleMember -Function Find-GitlabProjectJobs