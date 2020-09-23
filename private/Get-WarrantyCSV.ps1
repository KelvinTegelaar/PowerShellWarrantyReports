function  Get-WarrantyCSV($sourcefile) {
    write-host "Source is CSV file. Grabbing all devices." -ForegroundColor Green
    $CSVLines = import-csv -path $sourcefile -Delimiter ","
    $warrantyObject = foreach ($Line in $CSVLines) {
        switch ($line.vendor) {
            HP { get-HPWarranty -SourceDevice $line.SerialNumber -Client $line.client }
            Dell { get-DellWarranty -SourceDevice $line.SerialNumber -Client $line.client }
            Lenovo { get-LenovoWarranty -SourceDevice $line.SerialNumber -Client $line.client }
            MS { Get-MSWarranty -SourceDevice $line.SerialNumber -Client $line.client }
        }
    }
    return $warrantyObject
}
 