function  Get-WarrantyNable {
    [CmdletBinding()]
    Param(
        [string]$NableURL,
        [String]$JWTKey,
        [boolean]$SyncWithSource,
        [boolean]$OverwriteWarranty
    )

    # Generate a pseudo-unique namespace to use with the New-WebServiceProxy and
    # associated types.
    $NWSNameSpace = "NAble" + ([guid]::NewGuid()).ToString().Substring(25)

    # Bind to the namespace, using the Webserviceproxy
    $bindingURL = "https://" + $NableURL + "/dms/services/ServerEI?wsdl"
    $nws = New-Webserviceproxy $bindingURL -Namespace ($NWSNameSpace)

    # Set up and execute the query
    Try {
        write-host "Grabbing devices from N-Central" -ForegroundColor Green
        $global:deviceslist = $nws.DeviceAssetInfoExport2('0.0', $username, $JWTKey)
    }
    Catch {
        Write-Host "Could not connect: $($_.Exception.Message)"
        exit
    }
    write-host "Collecting serial numbers from N-Central" -ForegroundColor Green
    $Devices = ForEach ($Entity in $deviceslist) {
        $CustomerAssetInfo = @{}
        ForEach ($item in $Entity.Info) { $CustomerAssetInfo[$item.key] = $item.Value }
        [PSCustomObject]@{
            Serial        = $Customerassetinfo.'asset.computersystem.serialnumber'
            Client        = $CustomerAssetInfo.'asset.customer.customername'
            NableDeviceID = $CustomerAssetInfo.'asset.device.deviceid'
        }
    }

    $warrantyObject = foreach ($device in $Devices) {
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($device.serial). Device $i of $($Devices.Count)" -percentComplete ($i / $Devices.Count * 100)
        $client = $device.client
        switch ($device.serial.length) {
            7 { $WarState = get-DellWarranty -SourceDevice $device.serial -client $Client }
            8 { $WarState = get-LenovoWarranty -SourceDevice $device.serial -client $Client }
            10 { $WarState = get-HPWarranty  -SourceDevice $device.serial -client $Client }
            12 { $WarState = if ($serial -match "^\d+$") { 
                Get-MSWarranty  -SourceDevice $device.serial -client $Client 
            } else {
                Get-AppleWarranty -SourceDevice $device.Serial -client $Client
            } }
            default {
                [PSCustomObject]@{
                    'Serial'                = $device.Serial
                    'Warranty Product name' = 'Could not get warranty information.'
                    'StartDate'             = $null
                    'EndDate'               = $null
                    'Warranty Status'       = 'Could not get warranty information'
                    'Client'                = $Client
                }
            }
        }
        if ($SyncWithSource -eq $true) {
            switch ($OverwriteWarranty) {
                $true {
                    write-host "N-Central does not support Warranty write-back."               
                }
                $false { 
                    if ($null -eq $device.WarrantyExpirationDate -and $null -ne $warstate.EndDate) { 
                        write-host "N-Central does not support Warranty write-back."      
                    } 
                }
            }
        }
        $WarState
    }
    return $warrantyObject

}