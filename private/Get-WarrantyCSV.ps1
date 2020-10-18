function  Get-WarrantyCSV($sourcefile) {
    write-host "Source is CSV file. Grabbing all devices." -ForegroundColor Green
    $CSVLines = import-csv -path $sourcefile -Delimiter ","
    $warrantyObject = foreach ($Line in $CSVLines) {
        $WarState = Get-Warrantyinfo -DeviceSerial $line.serialnumber -client $line.clientname -vendor $line.vendor

    }
    return $warrantyObject
}
 