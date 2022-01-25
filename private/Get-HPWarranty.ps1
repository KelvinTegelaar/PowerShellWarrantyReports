function get-HPWarranty([Parameter(Mandatory = $true)]$SourceDevice, $Client) {
    if ($script:ExcludeHP -eq $false) {
        $MWSID = (invoke-restmethod -uri 'https://support.hp.com/us-en/checkwarranty/multipleproducts/' -SessionVariable 'session' -Method get) -match '.*mwsid":"(?<wssid>.*)".*'
        $HPBody = " { `"gRecaptchaResponse`":`"`", `"obligationServiceRequests`":[ { `"serialNumber`":`"$SourceDevice`", `"isoCountryCde`":`"US`", `"lc`":`"EN`", `"cc`":`"US`", `"modelNumber`":null }] }"
    
        try{ 
            $HPReq = Invoke-RestMethod -Uri "https://support.hp.com/hp-pps-services/os/multiWarranty?ssid=$($matches.wssid)" -WebSession $session -Method "POST" -ContentType "application/json" -Body $HPbody 
        }
        catch{
            $HPReq = $null
            if ($script:HPNotified -eq $false){
            write-host "HP Requests currently failing: No HP data will be returned. The HP API is currently spotty. A new API will be coming `"soon`"" -ForegroundColor Red
            $script:HPNotified = $true
            }
        }
        if ($HPreq.productWarrantyDetailsVO.warrantyResultList.obligationStartDate) {
            $WarObj = [PSCustomObject]@{
                'Serial'                = $SourceDevice
                'Warranty Product name' = $hpreq.productWarrantyDetailsVO.warrantyResultList.warrantyType | Out-String
                'StartDate'             = [DateTime]::Parse($($hpreq.productWarrantyDetailsVO.warrantyResultList.obligationStartDate | sort-object | select-object -last 1))
                'EndDate'               = [DateTime]::Parse($($hpreq.productWarrantyDetailsVO.warrantyResultList.obligationEndDate | sort-object | select-object -last 1))
                'Warranty Status'       = $hpreq.productWarrantyDetailsVO.obligationStatus
                'Client'                = $Client
            }
        }
        else {
            $WarObj = [PSCustomObject]@{
                'Serial'                = $SourceDevice
                'Warranty Product name' = 'Could not get warranty information'
                'StartDate'             = $null
                'EndDate'               = $null
                'Warranty Status'       = 'Could not get warranty information'
                'Client'                = $Client
            }
        }

    }
    else {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = 'Could not get warranty information'
            'StartDate'             = $null
            'EndDate'               = $null
            'Warranty Status'       = 'Could not get warranty information'
            'Client'                = $Client
        }
    }
    return $WarObj
}