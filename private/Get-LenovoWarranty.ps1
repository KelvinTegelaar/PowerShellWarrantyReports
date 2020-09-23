function get-LenovoWarranty([Parameter(Mandatory = $true)]$SourceDevice, $client) {
    $today = Get-Date -Format yyyy-MM-dd
    $APIURL = "https://ibase.lenovo.com/POIRequest.aspx"
    $SourceXML = "xml=<wiInputForm source='ibase'><id>LSC3</id><pw>IBA4LSC3</pw><product></product><serial>$SourceDevice</serial><wiOptions><machine/><parts/><service/><upma/><entitle/></wiOptions></wiInputForm>"
    $Req = Invoke-RestMethod -Uri $APIURL -Method POST -Body $SourceXML -ContentType 'application/x-www-form-urlencoded'
    if ($req.wiOutputForm) {
        $warlatest = $Req.wiOutputForm.warrantyInfo.serviceInfo.wed | sort-object | select-object -last 1 
        $WarrantyState = if ($warlatest -le $today) { "Expired" } else { "OK" }
         
        $WarObj = [PSCustomObject]@{
            'Serial'                = $Req.wiOutputForm.warrantyInfo.machineinfo.serial
            'Warranty Product name' = $Req.wiOutputForm.warrantyInfo.machineinfo.productname -join "`n"
            'StartDate'             = $Req.wiOutputForm.warrantyInfo.serviceInfo.warstart | sort-object -Descending | select-object -last 1
            'EndDate'               = $Req.wiOutputForm.warrantyInfo.serviceInfo.wed | sort-object | select-object -last 1
            'Warranty Status'       = $WarrantyState
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