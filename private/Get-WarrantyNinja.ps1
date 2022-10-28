function  Get-WarrantyNinja {
    [CmdletBinding()]
    Param(
        [string]$NinjaURL,
        [String]$Secretkey,
        [boolean]$AccessKey,
        [boolean]$SyncWithSource,
        [boolean]$OverwriteWarranty,
        [string]$NinjaFieldName
    )
    $AuthBody = @{
        'grant_type'    = 'client_credentials'
        'client_id'     = $AccessKey
        'client_secret' = $Secretkey
        'scope'         = 'monitoring' 
    }
    
    $Result = Invoke-WebRequest -uri "$($NinjaURL)/ws/oauth/token" -Method POST -Body $AuthBody -ContentType 'application/x-www-form-urlencoded'
    
    $AuthHeader = @{
        'Authorization' = "Bearer $(($Result.content | convertfrom-json).access_token)"
    }

    $OrgsRaw = Invoke-WebRequest -uri "$($NinjaURL)/v2/organizations" -Method GET -Headers $AuthHeader
    $NinjaOrgs = $OrgsRaw | ConvertFrom-Json
    
    $date1 = Get-Date -Date "01/01/1970"

    $DevicesRaw = Invoke-WebRequest -uri "$($NinjaURL)/v2/devices-detailed" -Method GET -Headers $AuthHeader
    $Devices = $DevicesRaw.content | ConvertFrom-Json
    
    If ($ResumeLast) {
        write-host "Found previous run results. Starting from last object." -foregroundColor green
        $Devices = get-content 'Devices.json' | convertfrom-json
    }
    else {
        $DevicesRaw = Invoke-WebRequest -uri "$($NinjaURL)/v2/devices-detailed" -Method GET -Headers $AuthHeader
        $Devices = $DevicesRaw.content | ConvertFrom-Json
    }
    $i = 0
    $warrantyObject = foreach ($device in $Devices) {
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($device.system.biosSerialNumber). Device $i of $($Devices.Count)" -percentComplete ($i / $Devices.Count * 100)
        $DeviceOrg = ($NinjaOrgs | Where-Object { $_.id -eq $Device.organizationId }).name
        $WarState = Get-Warrantyinfo -DeviceSerial $device.system.biosSerialNumber -client $DeviceOrg
        $Null = set-content 'Devices.json' -force -value ($Devices | select-object -skip $i | convertto-json -depth 5)
        $Milliseconds = (New-TimeSpan -Start $date1 -End $warstate.EndDate).TotalMilliseconds

        if ($SyncWithSource -eq $true) {
            switch ($OverwriteWarranty) {
                $true {
                    $UpdateBody = @{
                        "$NinjaFieldName" = $Milliseconds
                    }
                    try {
                        $Result = Invoke-WebRequest -uri "$($NinjaURL)/v2/device/$($Device.id)/custom-fields" -Method POST -Headers $AuthHeader -body $UpdateBody
                        Write-Host "Updated $($Device.Name)"
                    }
                    catch {
                        Write-Error "Failed to update device: $($Device.name)"
                    }
                }
                $false {
                    $DeviceFields = Invoke-WebRequest -uri "$($NinjaURL)/v2/device/$($Device.id)/custom-fields" -Method GET -Headers $AuthHeader
                    $WarrantyDate = ($DeviceFields.content | convertfrom-json)."$($NinjaFieldName)"

                    if ($null -eq $WarrantyDate -and $null -ne $warstate.EndDate) { 
                        try {
                            $Result = Invoke-WebRequest -uri "$($NinjaURL)/v2/device/$($Device.id)/custom-fields" -Method POST -Headers $AuthHeader -body $UpdateBody
                            Write-Host "Updated $($Device.name)"
                        }
                        catch {
                            Write-Error "Failed to update device: $($Device.name)"
                        }        
                    } 
                }
            }
        }
        $WarState
    }
    Remove-item 'devices.json' -Force -ErrorAction SilentlyContinue
    return $warrantyObject

}