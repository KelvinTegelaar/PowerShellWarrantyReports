function get-LenovoWarranty([Parameter(Mandatory = $true)]$SourceDevice, $client) {
    $today = Get-Date -Format yyyy-MM-dd
    $APIURL = "https://warrantyapiproxy.azurewebsites.net/api/Lenovo?Serial=$SourceDevice"
    $Req = Invoke-RestMethod -Uri $APIURL -Method get
    if ($req.Warproduct) {
        $warlatest = $Req.EndDate | ForEach-Object { [datetime]$_ } | sort-object | select-object -last 1 
        $WarrantyState = if ($warlatest -le $today) { "Expired" } else { "OK" }
        $WarObj = [PSCustomObject]@{
            'Serial'                = $Req.Serial
            'Warranty Product name' = $Req.WarProduct
            'StartDate'             = [DateTime]($Req.StartDate)
            'EndDate'               = [DateTime]($Req.EndDate)
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