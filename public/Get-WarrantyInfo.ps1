function  Get-Warrantyinfo {
    [CmdletBinding()]
    Param(
        [string]$DeviceSerial,
        [String]$client,
        [String]$vendor,
        [switch]$LocalDevice
    )
    if ($LocalDevice) {
        $DeviceInfo = Get-CimInstance -ClassName "Win32_Bios" -Property "SerialNumber", "Manufacturer" | Select-Object "Manufacturer", "SerialNumber"
        if ($DeviceInfo) {
            if ($DeviceInfo.Manufacturer) {
                $vendor = $DeviceInfo.Manufacturer
            }
            if ($DeviceInfo.SerialNumber) {
                $DeviceSerial = $DeviceInfo.SerialNumber
            }
        }
    }
    if ($LogActions) { add-content -path $LogFile -Value "Starting lookup for $($DeviceSerial),$($Client)" -force }
    if ($vendor) {
        switch ($vendor) {
            HP { get-HPWarranty -SourceDevice $DeviceSerial -Client $line.client }
            Dell { get-DellWarranty -SourceDevice $DeviceSerial -Client $line.client }
            Lenovo { get-LenovoWarranty -SourceDevice $DeviceSerial -Client $line.client }
            MS { Get-MSWarranty -SourceDevice $DeviceSerial -Client $line.client }
            Apple { get-AppleWarranty -SourceDevice $DeviceSerial -client $line.client }
            Toshiba { get-ToshibaWarranty -SourceDevice $DeviceSerial -client $line.client }
        }
    }
    else {
        switch ($DeviceSerial.Length) {
            7 { get-DellWarranty -SourceDevice $DeviceSerial -client $Client }
            8 { get-LenovoWarranty -SourceDevice $DeviceSerial -client $Client }
            9 { get-ToshibaWarranty -SourceDevice $DeviceSerial -client $line.client }
            10 { get-HPWarranty  -SourceDevice $DeviceSerial -client $Client }
            12 {
                if ($DeviceSerial -match "^\d+$") {
                    Get-MSWarranty  -SourceDevice $DeviceSerial -client $Client 
                }
                else {
                    Get-AppleWarranty -SourceDevice $DeviceSerial -client $Client
                } 
            }
            default {
                [PSCustomObject]@{
                    'Serial'                = $DeviceSerial
                    'Warranty Product name' = 'Could not get warranty information.'
                    'StartDate'             = $null
                    'EndDate'               = $null
                    'Warranty Status'       = 'Could not get warranty information'
                    'Client'                = $Client
                }
            }
        }
    }
    if ($LogActions) { add-content -path $LogFile -Value "Ended lookup for $($DeviceSerial),$($Client)" }
}