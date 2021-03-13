function get-AppleWarranty([Parameter(Mandatory = $true)]$SourceDevice, $Client) {
    #Apple warranty check uses estimates, not exacts as they have no API.
    $ManafactureDateEstimate = [PSCustomObject]@{
        "C" = @{ 
            StartDate = "2010 (1st half)"
            EndDate   = "2012 (Estimate)"
        }
        "D" = @{ 
            StartDate = "2010 (2nd half)"
            EndDate   = "2012/2013 (Estimate)"
        }
        
        "F" = @{ 
            StartDate = "2011 (1st half)"
            EndDate   = "2013 (Estimate)"
        }
        "G" = @{ 
            StartDate = "2011 (2nd half)"
            EndDate   = "2013/2014 (Estimate)"
        }
        "H" = @{ 
            StartDate = "2012 (1st half)"
            EndDate   = "2014 (Estimate)"
        }
        "J" = @{ 
            StartDate = "2012 (2nd half)"
            EndDate   = "2014/2015 (Estimate)"
        }
        "K" = @{ 
            StartDate = "2013 (1st half)"
            EndDate   = "2015 (Estimate)"
        }
        "L" = @{ 
            StartDate = "2013 (2nd half)"
            EndDate   = "2015/2016 (Estimate)"
        }
        "M" = @{ 
            StartDate = "2014 (1st half)"
            EndDate   = "2016 (Estimate)"
        }
        "N" = @{ 
            StartDate = "2014 (2nd half)"
            EndDate   = "2016/2017 (Estimate)"
        }
        "P" = @{ 
            StartDate = "2015 (1st half)"
            EndDate   = "2017 (Estimate)"
        }
        "Q" = @{ 
            StartDate = "2015 (2nd half)"
            EndDate   = "2017/2018 (Estimate)"
        }
        "R" = @{ 
            StartDate = "2016 (1st half)"
            EndDate   = "2018 (Estimate)"
        } 
        "S" = @{ 
            StartDate = "2016 (2nd half)"
            EndDate   = "2018/2019 (Estimate)"
        } 
        "T" = @{ 
            StartDate = "2017 (1st half)"
            EndDate   = "2019 (Estimate)"
        } 
        "V" = @{ 
            StartDate =  "2017 (2nd half)"
            EndDate   = "2019/2020 (Estimate)"
        }
        "W" = @{ 
            StartDate = "2018 (1st half)"
            EndDate   = "2020 (Estimate)"
        }
        "X" = @{ 
            StartDate = "2018 (2nd half)"
            EndDate   = "2020/2021 (Estimate)"
        }
        "Y" = @{ 
            StartDate = "2019 (1st half)"
            EndDate   = "2021 (Estimate)"
        } 
        "Z" = @{ 
            StartDate = "2019 (2nd half)"
            EndDate   = "2021/2022 (Estimate)"
        }
    }
    $ManafactureDateSerial = $SourceDevice[3]
    $AppleWarranty = $ManafactureDateEstimate.$ManafactureDateSerial
    if ($AppleWarranty -and $script:ExcludeApple -eq $false) {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = "This warranty end date is an estimate."
            'StartDate'             = $AppleWarranty.StartDate
            'EndDate'               = $AppleWarranty.EndDate
            'Warranty Status'       = "Estimate"
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