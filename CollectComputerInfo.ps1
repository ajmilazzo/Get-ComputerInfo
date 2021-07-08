param (
    [Parameter(Mandatory = $true)]
    [string[]]
    $ComputerName
)

Write-Host -Object @"

  CollectComputerInfo
  (c) 2019 LISS Consulting, Corp. All rights reserved.

"@ -ForegroundColor Magenta

Write-Host -Object @"
  ---> Begin at $(Get-Date -Format "G") 
  ---> Processing $($ComputerName.Count) computers.

"@ -ForegroundColor Cyan

$pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
$pool.ApartmentState = "MTA"
$pool.Open()

$output = New-Object -TypeName System.Collections.ArrayList
$runspaces = New-Object -TypeName System.Collections.ArrayList

$PSScriptRoot = $MyInvocation.MyCommand.Path | Split-Path -Parent

$scriptBlock = {
    param (
        [string]$ComputerName,
        [string]$PSScriptRoot
    )

    . "$PSScriptRoot\Get-ComputerInfo.ps1"

    if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) {
        Get-ComputerInfo -ComputerName $ComputerName
    } else {
        Write-Error "$ComputerName is offline" -TargetObject $ComputerName
    }
}

foreach ($computer in $ComputerName) {
    $runspace = [PowerShell]::Create()
    $null = $runspace.AddScript($scriptBlock)
    $null = $runspace.AddArgument($computer)
    $null = $runspace.AddArgument($PSScriptRoot)
    $runspace.RunspacePool = $pool

    $null = $runspaces.Add((
            New-Object -TypeName PSObject -Property @{
                Pipe   = $runspace
                Status = $runspace.BeginInvoke()
            }
        ))
}

while ($completed.Count -lt $runspaces.Count) {
    $completed = $runspaces | Where-Object { $_.Processed }
    foreach ($runspace in $runspaces) {
        if ($runspace.Processed -ne $true -and $runspace.Status.IsCompleted) {
            $result = $runspace.Pipe.EndInvoke($runspace.Status)
            $runspace.Pipe.Dispose()
            $null = $output.Add($result)

            $result | Select-Object -Property @(
                "ComputerName"
                "TotalCPUs"
                "TotalMemory(GB)"
                @{
                    Name       = 'SystemVolumeSize(GB)'
                    Expression = { $_.'VolumeCSize(GB)' }
                }
            )
            $runspace |
                Add-Member -MemberType NoteProperty -Name "Processed" -Value "$true"
        }
    }
}

$pool.Close()
$pool.Dispose()

$datatable = New-Object -TypeName System.Data.DataTable
$columns = foreach ($item in $output) { $item | Get-Member -MemberType Properties }
$columns = $columns | Select-Object -ExpandProperty Name -Unique | Sort-Object
$columns | ForEach-Object { $null = $datatable.Columns.Add($_) }

foreach ($item in $output) {
    $row = $datatable.NewRow()
    $columns | ForEach-Object { $row."$($_)" = $item."$($_)" }
    $null = $datatable.Rows.Add($row)
}

$datatable | Export-Clixml .\ComputerInfo.xml
