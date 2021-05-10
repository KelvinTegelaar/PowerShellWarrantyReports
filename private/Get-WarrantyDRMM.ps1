function  Get-WarrantyDattoRMM {
    [CmdletBinding()]
    Param(
        [string]$DRMMAPIKey,
        [String]$DRMMApiURL,
        [String]$DRMMSecret,
        [boolean]$SyncWithSource,
        [boolean]$Missingonly,
        [boolean]$OverwriteWarranty
    )
    write-host "Source is Datto RMM. Grabbing all devices." -ForegroundColor Green
    If (Get-Module -ListAvailable -Name "DattoRMM" | where-object {$_.version -ge "1.0.0.25"}) { 
        Import-module DattoRMM
    }
    Else { 
        Install-Module DattoRMM -Force
        Import-Module DattoRMM
    }
    #Settings DRMM
    # Provide API Parameters
    $params = @{
        Url       = $DRMMApiURL
        Key       = $DRMMAPIKey
        SecretKey = $DRMMSecret
    }

    # Set API Parameters
    Set-DrmmApiParameters @params
    write-host "Getting DattoRMM Devices" -foregroundColor green
    $ResumeLast = test-path 'Devices.json'
    If ($ResumeLast) {
        write-host "Found previous run results. Starting from last object." -foregroundColor green
        $AllDevices = get-content 'Devices.json' | convertfrom-json
    }
    else {
        $AllDevices = Get-DrmmAccountDevices | select-object DeviceClass, uid, SiteName, warrantyDate
    }
    if ($Missingonly -eq $true){
        $Alldevices = $AllDevices | Where-Object {[string]::IsNullOrWhiteSpace($_.warrantyDate)}
    }
    $i = 0
    $warrantyObject = foreach ($device in $AllDevices) {
        try {
            if ($Device.DeviceClass -eq 'esxihost') {
                $DeviceSerial = (Get-DrmmAuditesxi  -deviceUid $device.uid).systeminfo.servicetag
            }
            else {
                $DeviceSerial = (Get-DrmmAuditDevice -deviceUid $device.uid).bios.serialnumber
            }
        }
        catch {
            write-host "Could not retrieve serialnumber for $device"
            continue
        }
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($DeviceSerial). Device $i of $($AllDevices.Count)" -percentComplete ($i / $AllDevices.Count * 100)

        $WarState = Get-Warrantyinfo -DeviceSerial $DeviceSerial -client $device.siteName
        $RemainingList = set-content 'Devices.json' -force -value ($AllDevices | select-object -skip $i | convertto-json -depth 5)
        if ($SyncWithSource -eq $true) {
            switch ($OverwriteWarranty) {
                $true {
                    if ($null -ne $warstate.EndDate) {
                        Set-DrmmDeviceWarranty -deviceUid $device.uid -warranty ($warstate.EndDate).ToString('yyyy-MM-dd')
                    }
                     
                }
                $false { 
                    if ([string]::IsNullOrWhiteSpace($device.warrantyDate) -and $null -ne $warstate.EndDate) { 
                        Set-DrmmDeviceWarranty -deviceuid $device.uid -warranty ($warstate.EndDate).ToString('yyyy-MM-dd')
                    } 
                }
            }
        }
        $WarState
    }
    Remove-item 'devices.json' -Force -ErrorAction SilentlyContinue
    return $warrantyObject
}