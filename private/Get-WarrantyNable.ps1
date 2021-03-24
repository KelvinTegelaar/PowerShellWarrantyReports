function  Get-WarrantyNable {
    [CmdletBinding()]
    Param(
        [string]$NableURL,
        [String]$JWTKey,
        [boolean]$SyncWithSource,
        [boolean]$Missingonly,
        [boolean]$OverwriteWarranty
    )

    # Generate a pseudo-unique namespace to use with the New-WebServiceProxy and
    # associated types.
    $NWSNameSpace = "NAble" + ([guid]::NewGuid()).ToString().Substring(25)

    # Bind to the namespace, using the Webserviceproxy
    $bindingURL = "https://" + $NableURL + "/dms/services/ServerEI?wsdl"
    $nws = New-Webserviceproxy $bindingURL -Namespace ($NWSNameSpace)
    If ($ResumeLast) {
        write-host "Found previous run results. Starting from last object." -foregroundColor green
        $Devices = get-content 'Devices.json' | convertfrom-json
    }
    else {
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
    }
    $i = 0
    $warrantyObject = foreach ($device in $Devices) {
        $i++
        $RemainingList = set-content 'Devices.json' -force -value ($Devices | select-object -skip $i | convertto-json -depth 5)

        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($device.serial). Device $i of $($Devices.Count)" -percentComplete ($i / $Devices.Count * 100)
        $WarState = Get-Warrantyinfo -DeviceSerial $device.serial -client $device.client
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
    Remove-item 'devices.json' -Force -ErrorAction SilentlyContinue
    return $warrantyObject

}