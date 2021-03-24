function get-LenovoWarranty([Parameter(Mandatory = $true)]$SourceDevice, $client) {
    $today = Get-Date -Format yyyy-MM-dd
    $APIURL = "https://warrantyapiproxy.azurewebsites.net/api/Lenovo?Serial=$SourceDevice"
    $Req = Invoke-RestMethod -Uri $APIURL -Method get
    if ($req.Warproduct) {
        $warlatest = $Req.EndDate | sort-object | select-object -last 1 
        $WarrantyState = if ($warlatest -le $today) { "Expired" } else { "OK" }
        $WarObj = [PSCustomObject]@{
            'Serial'                = $Req.Serial
            'Warranty Product name' = $Req.WarProduct
            'StartDate'             = [DateTime]::ParseExact($Req.StartDate, 'MM/dd/yyyy HH:mm:ss', [Globalization.CultureInfo]::CreateSpecificCulture('en-NL'))
            'EndDate'               = [DateTime]::ParseExact($Req.EndDate, 'MM/dd/yyyy HH:mm:ss', [Globalization.CultureInfo]::CreateSpecificCulture('en-NL'))
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