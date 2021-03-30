function  Get-WarrantyITG {
    [CmdletBinding()]
    Param(
        [string]$ITGAPIKey,
        [String]$ITGAPIURL,
        [boolean]$SyncWithSource,
        [boolean]$Missingonly,
        [boolean]$OverwriteWarranty
    )
    write-host "Source is IT-Glue. Grabbing all devices." -ForegroundColor Green
    If (Get-Module -ListAvailable -Name "ITGlueAPI") { 
        Import-module ITGlueAPI 
    }
    Else { 
        Install-Module ITGlueAPI -Force
        Import-Module ITGlueAPI
    }
    #Settings IT-Glue logon information
    Add-ITGlueBaseURI -base_uri $ITGAPIURL
    Add-ITGlueAPIKey  $ITGAPIKey
    write-host "Getting IT-Glue configuration list" -foregroundColor green
    $ResumeLast = test-path 'Devices.json'
    If ($ResumeLast) {
        write-host "Found previous run results. Starting from last object." -foregroundColor green
        $AllITGlueConfigs = get-content 'Devices.json' | convertfrom-json
    }
    else {
        $AllITGlueConfigs = do {
            $ITGlueConfigs = (Get-ITglueconfigurations -page_size 1000 -page_number $i).data
            $i++
            $ITGlueConfigs
            Write-Host "Retrieved $(1000 * $i) configurations" -ForegroundColor Yellow
        }while ($ITGlueConfigs.count % 1000 -eq 0 -and $ITGlueConfigs.count -ne 0) 
    }
    $i = 0
    $warrantyObject = foreach ($device in $AllITGlueConfigs) {
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($device.attributes.'serial-number'). Device $i of $($AllITGlueConfigs.Count)" -percentComplete ($i / $AllITGlueConfigs.Count * 100)
        $RemainingList = set-content 'Devices.json' -force -value ($AllITGlueConfigs | select-object -skip $AllITGlueConfigs.indexof($device) | convertto-json -depth 5)
        $WarState = Get-Warrantyinfo -DeviceSerial $device.attributes.'serial-number' -client $device.attributes.'organization-name'
        if ($Warstate.EndDate) {
            if ($SyncWithSource -eq $true) {
                $FlexAssetBody = @{
                    "type"       = "configurations"
                    "attributes" = @{
                        'warranty-expires-at' = ($warstate.EndDate).ToString('yyyy-MM-dd')
                    } 
                }
                switch ($OverwriteWarranty) {
                    $true {
                        if ($null -ne $warstate.EndDate) {
                            Set-ITGlueConfigurations -id $device.id -data $FlexAssetBody
                        }
                     
                    }
                    $false { 
                        if ($null -eq $device.WarrantyExpirationDate -and $null -ne $warstate.EndDate) { 
                            Set-ITGlueConfigurations -id $device.id -data $FlexAssetBody
                        } 
                    }
                }
            }
            $WarState
        }
    }
    Remove-item 'devices.json' -Force -ErrorAction SilentlyContinue
    return $warrantyObject
}