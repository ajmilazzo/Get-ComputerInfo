function Get-ComputerInfo {
    [CmdletBinding()]
    param (
        # Specfies the name of the computer to query for information
        [Parameter(
            Position = 0,
            ValueFromPipeline = $true)]
        [string[]]
        $ComputerName = $env:COMPUTERNAME
    )

    process {
        foreach ($computer in $ComputerName) {
            $output = New-Object -TypeName PSObject
            $disks = @(Get-WmiObject -Class Win32_LogicalDisk -ComputerName $computer |
                Where-Object { $_.DriveType -in 2..3 })
            $processors = @(Get-WmiObject -Class Win32_Processor -ComputerName $computer)
            $memory = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $computer

            $properties = [System.Collections.Specialized.OrderedDictionary]::new()
            $properties.Add("ComputerName", $computer)

            for ($i = 0; $i -lt $processors.Count; $i++) {
                $properties.Add("Processor$($i+1)Name", $processors[$i].Name)
                $properties.Add("Processor$($i+1)Caption", $processors[$i].Caption)
                $properties.Add("Processor$($i+1)Manufacturer", $processors[$i].Manufacturer)
                $properties.Add("Processor$($i+1)MaxClockSpeed", $processors[$i].Maxclockspeed)
            }

            $properties.Add("Memory(GB)", ([math]::Round(($memory.TotalPhysicalMemory / 1GB), 2)))

            for ($i = 0; $i -lt $disks.Count; $i++) {
                $properties.Add("Volume$($i+1)Letter", $disks[$i].DeviceId)
                $properties.Add("Volume$($i+1)Size(GB)", ([math]::Round(($disks[$i].Size / 1GB), 2)))
                $properties.Add("Volume$($i+1)FreeSpace(GB)", ([math]::Round(($disks[$i].FreeSpace / 1GB), 2)))
            }

            $output | Add-Member $properties
            $output
        }
    }
}