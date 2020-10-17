function get-AppleWarranty([Parameter(Mandatory = $true)]$SourceDevice, $Client) {
    #Apple uses estimates
    if ($AppleWarranty) {
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