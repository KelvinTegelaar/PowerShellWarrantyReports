function  Get-WarrantyCWM {
    [CmdletBinding()]
    Param(
        [string]$CwCompanyID,
        [String]$CWMpiKeyPublic,
        [String]$CWMpiKeyprivate,
        [string]$CWMAPIURL,
        [boolean]$SyncWithSource,
        [boolean]$Missingonly,
        [boolean]$OverwriteWarranty,
        [array]$ConfigTypes
    )
 
    Write-Host "Source is Connectwise Manage. Grabbing all devices." -ForegroundColor Green
    $Base64Key = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($CWcompanyid)+$($CWMpiKeyPublic):$($CWMpiKeyPrivate)"))
 
    $Header = @{
        'clientId'      = '3613dda6-fa25-49b9-85fb-7aa2b628befa' #This is the warranty script client id. Do not change. 
        'Authorization' = "Basic $Base64Key"
        'Content-Type'  = 'application/json'
    }

    If (!($CWMAPIURL -match 'api')) {
        #https://developer.connectwise.com/Best_Practices/Manage_Cloud_URL_Formatting?mt-learningpath=manage
        $companyinfo = Invoke-RestMethod -Headers $header -Method GET -Uri "$CWMAPIURL/login/companyinfo/$cwcompanyid"
        If ($companyinfo.IsCloud) {
            $CWMAPIURL = "https://$($companyinfo.siteurl)/$($companyinfo.Codebase)apis/3.0"
        }
    }

    $ResumeLast = Test-Path 'Devices.json'
    If ($ResumeLast) {
        Write-Host "Found previous run results. Starting from last object." -ForegroundColor green
        $Devices = Get-Content 'Devices.json' | ConvertFrom-Json
    } else {
        $BaseUri = "$($CWMAPIURL)/company/configurations?pageSize=250"
        if ($ConfigTypes) {
            foreach ($Type in $ConfigTypes) {
                $CTParam += "type/name='$Type' or "
            }
            $CTParam = $CTParam.TrimEnd("or ")
            $BaseUri = "$($BaseUri)&conditions=$($CTParam)"
        }
        $i = 0
        $Devices = do {
            $DeviceList = Invoke-RestMethod -Headers $header -Method GET -Uri "$($BaseUri)&page=$i"
            $i++
            $DeviceList
            Write-Host "Retrieved $(250 * $i) configurations" -ForegroundColor Yellow
        }while ($devicelist.count % 250 -eq 0 -and $devicelist.count -ne 0) 
    }
    
    $i = 0
    $warrantyObject = foreach ($device in $Devices) {
        #Write-Host $device.serialnumber
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -Status "Processing $($device.serialnumber). Device $i of $($devices.Count)" -PercentComplete ($i / $Devices.Count * 100)
        $WarState = Get-Warrantyinfo -DeviceSerial $device.serialnumber -client $device.company.name
        $RemainingList = Set-Content 'Devices.json' -Force -Value ($Devices | Select-Object -Skip $i | ConvertTo-Json -Depth 5)

        if ($SyncWithSource -eq $true) {
            
            if (!$device.warrantyExpirationDate) {
                if ($warstate.EndDate) {
                    $EndDate = ($warstate.EndDate).ToString('yyyy-MM-ddT00:00:00Z')
                    $device | Add-Member -NotePropertyName "warrantyExpirationDate" -NotePropertyValue $EndDate
                }
            } else { 
                if ($warstate.EndDate) {
                    $EndDate = ($warstate.EndDate).ToString('yyyy-MM-ddT00:00:00Z')
                    $device.warrantyExpirationDate = $EndDate
                }
            }
            # Clear _info metadata that the CWM API doesn't like to receive in PUT commands.
            $device.type._info = "" 
            $device.status._info = "" 
            $device.company._info = ""

            $CWBody = $device | ConvertTo-Json

            switch ($OverwriteWarranty) {
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
