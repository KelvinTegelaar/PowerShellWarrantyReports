function get-HPWarranty([Parameter(Mandatory = $true)]$SourceDevice, $Client) {
    if ($script:ExcludeHP -ne $True) {
        try { 
            $HPReq = Invoke-RestMethod -Uri "https://warrantyapiproxy.azurewebsites.net/api/HP?serial=$($SourceDevice)"
        } catch {
            $HPReq = $null
        }


        if ($HPreq.StartDate) {
            $today = Get-Date
            $WarrantyState = if ([DateTime]$HPReq.endDate -le $today) { "Expired" } else { "OK" }
            $WarObj = [PSCustomObject]@{
                'Serial'                = $SourceDevice
                'Warranty Product name' = $hpreq.warProduct
                'StartDate'             = [DateTime]$HPReq.StartDate
                'EndDate'               = [DateTime]$HPReq.endDate
                'Warranty Status'       = $WarrantyState
                'Client'                = $Client
            }
        } else {
            $WarObj = [PSCustomObject]@{
                'Serial'                = $SourceDevice
                'Warranty Product name' = 'Could not get warranty information'
                'StartDate'             = $null
                'EndDate'               = $null
                'Warranty Status'       = 'Could not get warranty information'
                'Client'                = $Client
            }
        }
    } else {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = 'HP Lookups Excluded'
            'StartDate'             = $null
            'EndDate'               = $null
            'Warranty Status'       = 'HP Lookups Excluded'
            'Client'                = $Client
        }
    }
    return $WarObj
}