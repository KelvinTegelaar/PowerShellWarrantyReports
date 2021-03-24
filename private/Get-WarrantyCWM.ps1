function  Get-WarrantyCWM {
    [CmdletBinding()]
    Param(
        [string]$CwCompanyID,
        [String]$CWMpiKeyPublic,
        [String]$CWMpiKeyprivate,
        [string]$CWMAPIURL,
        [boolean]$SyncWithSource,
        [boolean]$Missingonly,
        [boolean]$OverwriteWarranty
    )
    write-host "Source is Connectwise Manage. Grabbing all devices." -ForegroundColor Green
    $Base64Key = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($CWcompanyid)+$($CWMpiKeyPublic):$($CWMpiKeyPrivate)"))
 
    $Header = @{
        'clientId'      = '3613dda6-fa25-49b9-85fb-7aa2b628befa' #This is the warranty script client id. Do not change. 
        'Authorization' = "Basic $Base64Key"
        'Content-Type'  = 'application/json'
    }
    $i = 0
    If ($ResumeLast) {
        write-host "Found previous run results. Starting from last object." -foregroundColor green
        $Devices = get-content 'Devices.json' | convertfrom-json
    }
    else {
        $Devices = do {
            $DeviceList = invoke-restmethod -headers $header -method GET -uri "$($CWMAPIURL)/company/configurations?pageSize=250&page=$i"
            $i++
            $DeviceList
            Write-Host "Retrieved $(250 * $i) configurations" -ForegroundColor Yellow
        }while ($devices.count % 250 -eq 0 -and $devices.count -ne 0) 
    }
    $warrantyObject = foreach ($device in $Devices) {
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($device.serialnumber). Device $i of $($devices.Count)" -percentComplete ($i / $Devices.Count * 100)
        $WarState = Get-Warrantyinfo -DeviceSerial $device.serialnumber -client $device.company.name
        $RemainingList = set-content 'Devices.json' -force -value ($Devices | select-object -skip $i | convertto-json -depth 5)

        if ($script:SyncWithSource -eq $true) {
            if (!$device.warrantyExpirationDate) {
                $device | Add-Member -NotePropertyName "warrantyExpirationDate" -NotePropertyValue "$($WarState.enddate)T00:00:00Z"
            }
            else { 
                $device.warrantyExpirationDate = "$($WarState.enddate)T00:00:00Z"
            }
            $CWBody = $device | ConvertTo-Json
            switch ($script:OverwriteWarranty) {
                $true {
                    if ($null -ne $warstate.EndDate) {
                        invoke-restmethod -headers $header -method put -uri "$($CWMAPIURL)/company/configurations/$($device.id)" -body $CWBody
                    }
                     
                }
                $false { 
                    if ($null -eq $device.WarrantyExpirationDate -and $null -ne $warstate.EndDate) { 
                        invoke-restmethod -headers $header -method put -uri "$($CWMAPIURL)/company/configurations/$($device.id)" -body $CWBody
                    } 
                }
            }
        }
        $WarState
    }
    Remove-item 'devices.json' -Force -ErrorAction SilentlyContinue
    return $warrantyObject
}