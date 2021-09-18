function  Get-WarrantyHalo {
    [CmdletBinding()]
    Param(
        [string]$HaloURL,
        [String]$HaloClientID,
        [String]$HaloClientSecret,
        [string]$HaloSerialField,
        [boolean]$SyncWithSource,
        [boolean]$Missingonly,
        [boolean]$OverwriteWarranty
    )


    write-host "Source is Halo. Grabbing all devices." -ForegroundColor Green
    #Get the Halo API Module if not installed
    if (Get-Module -ListAvailable -Name HaloAPI) {
        Import-Module HaloAPI 
    } else {
        Install-Module HaloAPI -Force
        Import-Module HaloAPI
    }

    Connect-HaloAPI -URL $HaloURL -ClientId $HaloClientID -ClientSecret $HaloClientSecret -Scopes "edit:assets"

    #Get Devices
    $ResumeLast = test-path 'Devices.json'
    If ($ResumeLast) {
        write-host "Found previous run results. Starting from last object." -foregroundColor green
        $Devices = get-content 'Devices.json' | convertfrom-json
    } else {
        $Devices = Get-HaloAsset -FullObjects
    }
    $i = 0
    $warrantyObject = foreach ($device in $Devices) {
        $i++
        $null = set-content 'Devices.json' -force -value ($Devices | select-object -skip $i | convertto-json -depth 5)
       
        # Find the Serial Number
        if ($Device."$($HaloSerialField)") {
            $Serial = $Device."$($HaloSerialField)"
        } else {
            $Serial = ($Device.Fields | where-object { $_.name -eq $HaloSerialField }).value
            if (($Serial | measure-object).count -ne 1) {
                $Serial = ($Device.customfields | where-object { $_.name -eq $HaloSerialField }).value
                if (($Serial | measure-object).count -ne 1) {
                    Write-Error "Serial field not found"
                    continue
                }
            }
        }

   

        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $Serial. Device $i of $($devices.Count)" -percentComplete ($i / $Devices.Count * 100)      
        $WarState = Get-Warrantyinfo -DeviceSerial $Serial -client $device.client_name


        if ($SyncWithSource -eq $true) {

            $AssetUpdate = @{
                id = $Device.id
                warranty_start = $WarState.StartDate
                warranty_end = $WarState.EndDate
            }
            
            switch ($OverwriteWarranty) {
                $true {
                    if ($null -ne $warstate.EndDate) {
                        $null = Set-HaloAsset -Asset $AssetUpdate
                    }
                     
                }
                $false { 
                    if ($null -eq $Device.warranty_end -and $null -ne $warstate.EndDate) { 
                        $null = Set-HaloAsset -Asset $AssetUpdate
                    } 
                }
            }
        }
        $WarState
    }
    Remove-item 'devices.json' -Force -ErrorAction SilentlyContinue
    return $warrantyObject
}