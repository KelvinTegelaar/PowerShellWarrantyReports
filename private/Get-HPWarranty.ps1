function get-HPWarranty([Parameter(Mandatory = $true)]$SourceDevice, $Client) {
    $MWSID = (invoke-restmethod -uri 'https://support.hp.com/us-en/checkwarranty/multipleproducts/' -SessionVariable 'session' -Method get) -match '.*mwsid":"(?<wssid>.*)".*'
    $HPBody = " { `"gRecaptchaResponse`":`"`", `"obligationServiceRequests`":[ { `"serialNumber`":`"$SourceDevice`", `"isoCountryCde`":`"US`", `"lc`":`"EN`", `"cc`":`"US`", `"modelNumber`":null }] }"
 
    $HPReq = Invoke-RestMethod -Uri "https://support.hp.com/hp-pps-services/os/multiWarranty?ssid=$($matches.wssid)" -WebSession $session -Method "POST" -ContentType "application/json" -Body $HPbody
    if ($HPreq.productWarrantyDetailsVO.warrantyResultList.obligationStartDate) {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = $hpreq.productWarrantyDetailsVO.warrantyResultList.warrantyType | Out-String
            'StartDate'             = $hpreq.productWarrantyDetailsVO.warrantyResultList.obligationStartDate | sort-object | select-object -last 1
            'EndDate'               = $hpreq.productWarrantyDetailsVO.warrantyResultList.obligationEndDate | sort-object | select-object -last 1
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
    return $WarObj
}