function Get-ComputerInfo {
    [CmdletBinding()]
    param (
        # Specifies the name of the computer to query for information
        [Parameter(
            Position = 0,
            ValueFromPipeline = $true)]
        [string[]]
        $ComputerName = $env:COMPUTERNAME
    )

    begin {
        $driveType = @{
            2 = "Removable Disk"
            3 = "Fixed Local Disk"
            4 = "Network Disk"
            5 = "Compact Disk"
        }
    }
    process {
        foreach ($computer in $ComputerName) {
            $volumes = @(Get-WmiObject -Class Win32_LogicalDisk -ComputerName $computer)
            $processors = @(Get-WmiObject -Class Win32_Processor -ComputerName $computer)
            $memory = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $computer

            $properties = New-Object -TypeName System.Collections.Specialized.OrderedDictionary
            $properties.Add("ComputerName", $computer)

            for ($i = 0; $i -lt $processors.Count; $i++) {
                $properties.Add("Processor$($i+1)Name", $processors[$i].Name)
                $properties.Add("Processor$($i+1)Caption", $processors[$i].Caption)
                $properties.Add("Processor$($i+1)Manufacturer", $processors[$i].Manufacturer)
                $properties.Add("Processor$($i+1)MaxClockSpeed", $processors[$i].Maxclockspeed)
                $properties.Add("Processor$($i+1)NumberOfCores", $processors[$i].NumberOfCores)
                $properties.Add("Processor$($i+1)NumberOfLogicalProcessors",
                    $processors[$i].NumberOfLogicalProcessors)
            }

            $properties.Add("TotalCPUs",
                ($processors | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum)
            $properties.Add("TotalMemory(GB)",
                [math]::Ceiling(($memory.TotalPhysicalMemory / 1GB)))

            for ($i = 0; $i -lt $volumes.Count; $i++) {
                $volId = $volumes[$i].DeviceId.Substring(0,1)
                $properties.Add("Volume$($volId)Size(GB)",
                    ([math]::Round(($volumes[$i].Size / 1GB), 2)))
                $properties.Add("Volume$($volId)FreeSpace(GB)",
                    ([math]::Round(($volumes[$i].FreeSpace / 1GB), 2)))
                $properties.Add("Volume$($volId)DriveType",
                    $driveType[[int]$volumes[$i].DriveType])
            }

            $output = New-Object -TypeName PSObject
            $properties.GetEnumerator() | ForEach-Object {
                $output | Add-Member -MemberType NoteProperty -Name $_.Key -Value $_.Value
            }

            $output
        }
    }
}
