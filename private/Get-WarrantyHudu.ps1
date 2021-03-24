function  Get-WarrantyHudu {
    [CmdletBinding()]
    Param(
        [string]$HuduAPIKey,
        [String]$HuduBaseURL,
        [String]$HuduDeviceAssetLayout,
        [string]$HuduWarrantyField,
        [boolean]$SyncWithSource,
        [boolean]$Missingonly,
        [boolean]$OverwriteWarranty
    )


    write-host "Source is Hudu. Grabbing all devices." -ForegroundColor Green
    #Get the Hudu API Module if not installed
    if (Get-Module -ListAvailable -Name HuduAPI) {
        Import-Module HuduAPI 
    }
    else {
        Install-Module HuduAPI -Force
        Import-Module HuduAPI
    }

    New-HuduAPIKey $HuduAPIKey
    New-HuduBaseUrl $HuduBaseURL

    #Get the Asset Layout from Hudu
    $layout = Get-HuduAssetLayouts -name $HuduDeviceAssetLayout
    if (!$layout) {
        Write-Error "Hudu Layout Not Found"
        exit
    }
    
    #Process field name into API format
    $HuduProcessedFieldName = ($HuduWarrantyField.ToLower()) -replace " ", "_"

    #Get Devices
    $ResumeLast = test-path 'Devices.json'
    If ($ResumeLast) {
        write-host "Found previous run results. Starting from last object." -foregroundColor green
        $Devices = get-content 'Devices.json' | convertfrom-json
    }
    else {
        $Devices = Get-HuduAssets -assetlayoutid $layout.id
    }
    $i = 0
    $warrantyObject = foreach ($device in $Devices) {
        $i++
        $RemainingList = set-content 'Devices.json' -force -value ($Devices | select-object -skip $i | convertto-json -depth 5)
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($device.primary_serial). Device $i of $($devices.Count)" -percentComplete ($i / $Devices.Count * 100)      
        $WarState = Get-Warrantyinfo -DeviceSerial $device.primary_serial -client $device.company_name

        if ($WarState.enddate) {
            if ($(($WarState.enddate).GetType().name) -eq "DateTime" ) {
                $WarState.enddate = $WarState.enddate.ToString("o")
            }
        }

        if ($SyncWithSource -eq $true) {
            $field = $device.fields | where-object { $_.label -eq $HuduWarrantyField }
            $device.fields = @{
                "$HuduProcessedFieldName" = "$($WarState.enddate)"
            }            
            
            switch ($OverwriteWarranty) {
                $true {
                    if ($null -ne $warstate.EndDate) {
                        $null = set-huduasset -name $device.name -company_id $device.company_id -asset_layout_id $layout.id -fields $device.fields -asset_id $device.id
                    }
                     
                }
                $false { 
                    if ($null -eq $field.value -and $null -ne $warstate.EndDate) { 
                        $null = set-huduasset -name $device.name -company_id $device.company_id -asset_layout_id $layout.id -fields $device.fields -asset_id $device.id
                    } 
                }
            }
        }
        $WarState
    }
    Remove-item 'devices.json' -Force -ErrorAction SilentlyContinue
    return $warrantyObject
}