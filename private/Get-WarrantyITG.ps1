function  Get-WarrantyITG {
    [CmdletBinding()]
    Param(
        [string]$ITGAPIKey,
        [String]$ITGAPIURL,
        [boolean]$SyncWithSource,
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
    $i = 0
    $AllITGlueConfigs = do {
        $ITGlueConfigs = (Get-ITglueconfigurations -page_size 1000 -page_number $i).data
        $i++
        $ITGlueConfigs
        Write-Host "Retrieved $(1000 * $i) configurations" -ForegroundColor Yellow
    }while ($ITGlueConfigs.count % 1000 -eq 0 -and $ITGlueConfigs.count -ne 0) 
     
    $warrantyObject = foreach ($device in $AllITGlueConfigs) {
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($device.attributes.'serial-number'). Device $i of $($AllITGlueConfigs.Count)" -percentComplete ($i / $AllITGlueConfigs.Count * 100)
        $client = $device.attributes.'organization-name'
        switch ($device.attributes.'serial-number'.Length) {
            7 { $WarState = get-DellWarranty -SourceDevice $device.attributes.'serial-number' -client $Client }
            8 { $WarState = get-LenovoWarranty -SourceDevice $device.attributes.'serial-number' -client $Client }
            10 { $WarState = get-HPWarranty  -SourceDevice $device.attributes.'serial-number' -client $Client }
            12 { $WarState = if ($serial -match "^\d+$") { 
                Get-MSWarranty  -SourceDevice $device.attributes.'serial-number' -client $Client 
            } else {
                Get-AppleWarranty -SourceDevice $device.attributes.'serial-number' -client $Client
            } }
            default {
                [PSCustomObject]@{
                    'Serial'                = $device.attributes.'serial-number'
                    'Warranty Product name' = 'Could not get warranty information.'
                    'StartDate'             = $null
                    'EndDate'               = $null
                    'Warranty Status'       = 'Could not get warranty information'
                    'Client'                = $Client
                }
            }
        }
        if ($SyncWithSource -eq $true) {
            $FlexAssetBody = @{
                "type"       = "configurations"
                "attributes" = @{
                    'warranty-expires-at' = $warstate.EndDate
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
    return $warrantyObject
}