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
    Write-Host "Source is Connectwise Manage. Grabbing all devices." -ForegroundColor Green
    $Base64Key = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($CWcompanyid)+$($CWMpiKeyPublic):$($CWMpiKeyPrivate)"))
 
    $Header = @{
        'clientId'      = '3613dda6-fa25-49b9-85fb-7aa2b628befa' #This is the warranty script client id. Do not change. 
        'Authorization' = "Basic $Base64Key"
        'Content-Type'  = 'application/json'
    }
    $i = 0
    If ($ResumeLast) {
        Write-Host "Found previous run results. Starting from last object." -ForegroundColor green
        $Devices = Get-Content 'Devices.json' | ConvertFrom-Json
    } else {
        $Devices = do {
            $DeviceList = Invoke-RestMethod -Headers $header -Method GET -Uri "$($CWMAPIURL)/company/configurations?pageSize=250&page=$i"
            $i++
            $DeviceList
            Write-Host "Retrieved $(250 * $i) configurations" -ForegroundColor Yellow
        }while ($devices.count % 250 -eq 0 -and $devices.count -ne 0) 
    }
    $warrantyObject = foreach ($device in $Devices) {
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -Status "Processing $($device.serialnumber). Device $i of $($devices.Count)" -PercentComplete ($i / $Devices.Count * 100)
        $WarState = Get-Warrantyinfo -DeviceSerial $device.serialnumber -client $device.company.name
        $RemainingList = Set-Content 'Devices.json' -Force -Value ($Devices | Select-Object -Skip $i | ConvertTo-Json -Depth 5)

        if ($script:SyncWithSource -eq $true) {
            if (!$device.warrantyExpirationDate) {
                $device | Add-Member -NotePropertyName "warrantyExpirationDate" -NotePropertyValue "$($WarState.enddate)T00:00:00Z"
            } else { 
                $device.warrantyExpirationDate = "$($WarState.enddate)T00:00:00Z"
            }
            $CWBody = $device | ConvertTo-Json
            switch ($script:OverwriteWarranty) {
                $true {
                    if ($null -ne $warstate.EndDate) {
                        Invoke-RestMethod -Headers $header -Method put -Uri "$($CWMAPIURL)/company/configurations/$($device.id)" -Body $CWBody
                    }
                     
                }
                $false { 
                    if ($null -eq $device.WarrantyExpirationDate -and $null -ne $warstate.EndDate) { 
                        Invoke-RestMethod -Headers $header -Method put -Uri "$($CWMAPIURL)/company/configurations/$($device.id)" -Body $CWBody
                    } 
                }
            }
        }
        $WarState
    }
    Remove-Item 'devices.json' -Force -ErrorAction SilentlyContinue
    return $warrantyObject
}