function  Get-WarrantyDattoRMM {
    [CmdletBinding()]
    Param(
        [string]$DRMMAPIKey,
        [String]$DRMMApiURL,
        [String]$DRMMSecret,
        [boolean]$SyncWithSource,
        [boolean]$OverwriteWarranty
    )
    write-host "Source is Datto RMM. Grabbing all devices." -ForegroundColor Green
    If (Get-Module -ListAvailable -Name "DattoRMM") { 
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
    $AllDevices = Get-DrmmAccountDevices
    $i = 0
    $warrantyObject = foreach ($device in $AllDevices) {
        $DeviceSerial = (Get-DrmmAuditDevice -deviceUid $device.uid).bios.serialnumber
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($DeviceSerial). Device $i of $($AllDevices.Count)" -percentComplete ($i / $AllDevices.Count * 100)
        $client = $device.siteName
       
        switch ($DeviceSerial.Length) {
            7 { $WarState = get-DellWarranty -SourceDevice $DeviceSerial -client $Client }
            8 { $WarState = get-LenovoWarranty -SourceDevice $DeviceSerial -client $Client }
            10 { $WarState = get-HPWarranty  -SourceDevice $DeviceSerial -client $Client }
            12 { $WarState = if ($serial -match "^\d+$") { 
                Get-MSWarranty  -SourceDevice $DeviceSerial -client $Client 
            } else {
                Get-AppleWarranty -SourceDevice $DeviceSerial -client $Client
            } }
            default {
                [PSCustomObject]@{
                    'Serial'                = $DeviceSerial
                    'Warranty Product name' = 'Could not get warranty information.'
                    'StartDate'             = $null
                    'EndDate'               = $null
                    'Warranty Status'       = 'Could not get warranty information'
                    'Client'                = $Client
                }
            }
        }
        if ($SyncWithSource -eq $true) {
            switch ($OverwriteWarranty) {
                $true {
                    if ($null -ne $warstate.EndDate) {
                        Set-DrmmDeviceWarranty -deviceUid $device.uid -warranty $warstate.EndDate
                    }
                     
                }
                $false { 
                    if ($null -eq $device.WarrantyExpirationDate -and $null -ne $warstate.EndDate) { 
                        Set-DrmmDeviceWarranty -deviceuid $device.uid -warranty $warstate.EndDate
                    } 
                }
            }
        }
        $WarState
    }
    return $warrantyObject
}