function update-warrantyinfo {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName = 'CSV', Mandatory = $true)]
        [Switch]$CSV,
        [Parameter(ParameterSetName = 'CSV', Mandatory = $false)]
        [String]$CSVFilePath,
        [Parameter(ParameterSetName = 'Autotask', Mandatory = $true)]
        [switch]$Autotask,
        [Parameter(ParameterSetName = 'Autotask', Mandatory = $true)]
        [Pscredential]$AutotaskCredentials,
        [Parameter(ParameterSetName = 'Autotask', Mandatory = $true)]
        [String]$AutotaskAPIKey,
        [Parameter(ParameterSetName = 'CWManage', Mandatory = $true)]
        [switch]$CWManage,
        [Parameter(ParameterSetName = 'CWManage', Mandatory = $true)]
        [string]$CWManagePublicKey,
        [Parameter(ParameterSetName = 'CWManage', Mandatory = $true)]
        [String]$CWManagePrivateKey,
        [Parameter(ParameterSetName = 'CWManage', Mandatory = $true)]
        [String]$CWManageAPIURL,
        [Parameter(ParameterSetName = 'CWManage', Mandatory = $true)]
        [String]$CWManageCompanyID,
        [Parameter(ParameterSetName = 'ITGlue', Mandatory = $true)]
        [switch]$ITGlue,
        [Parameter(ParameterSetName = 'ITGlue', Mandatory = $true)]
        [string]$ITGlueAPIURL,
        [Parameter(ParameterSetName = 'ITGlue', Mandatory = $true)]
        [String]$ITGlueAPIKey,
        [Parameter(ParameterSetName = 'Nable', Mandatory = $true)]
        [switch]$Nable,
        [Parameter(ParameterSetName = 'Nable', Mandatory = $true)]
        [string]$NableJWT,
        [Parameter(ParameterSetName = 'Nable', Mandatory = $true)]
        [String]$NableURL,
        [Parameter(ParameterSetName = 'Datto', Mandatory = $true)]
        [switch]$DattoRMM,
        [Parameter(ParameterSetName = 'Datto', Mandatory = $true)]
        [string]$DattoAPIKey,
        [Parameter(ParameterSetName = 'Datto', Mandatory = $true)]
        [String]$DattoAPISecret,
        [Parameter(ParameterSetName = 'Datto', Mandatory = $true)]
        [String]$DattoAPIURL,
        [Parameter(ParameterSetName = 'Hudu', Mandatory = $true)]
        [switch]$Hudu,
        [Parameter(ParameterSetName = 'Hudu', Mandatory = $true)]
        [String]$HuduAPIKey,
        [Parameter(ParameterSetName = 'Hudu', Mandatory = $true)]
        [String]$HuduBaseURL,
        [Parameter(ParameterSetName = 'Hudu', Mandatory = $true)]
        [String]$HuduDeviceAssetLayout,
        [Parameter(ParameterSetName = 'Hudu', Mandatory = $true)]
        [String]$HuduWarrantyField,
        [Parameter(Mandatory = $false)]
        [Switch]$SyncWithSource,
        [Parameter(Mandatory = $false)]
        [Switch]$MissingOnly,
        [Parameter(Mandatory = $false)]
        [switch]$OverwriteWarranty,
        [Parameter(Mandatory = $false)]
        [switch]$LogActions,
        [Parameter(Mandatory = $false)]
        [String]$LogFile = ".\WarrantyUpdateLog.txt",
        [Parameter(Mandatory = $false)]
        [switch]$GenerateReports,
        [Parameter(Mandatory = $false)]
        [switch]$ReturnWarrantyObject,
        [Parameter(Mandatory = $false)]
        [switch]$ExcludeApple,
        [Parameter(Mandatory = $false)]
        [String]$ReportsLocation = "C:\Temp\"
    )
    $script:HPNotified = $false
    $script:ExcludeApple = $ExcludeApple
    $script:LogPath = $LogFile
    switch ($PSBoundParameters.Keys) {
        Autotask { $WarrantyStatus = Get-WarrantyAutotask -AutotaskCredentials $AutotaskCredentials -AutotaskAPIKey $AutotaskAPIKey -SyncWithSource $SyncWithSource -MissingOnly $Missingonly -OverwriteWarranty $OverwriteWarranty | Sort-Object -Property Client }
        CSV { $WarrantyStatus = Get-WarrantyCSV -Sourcefile $CSVFilePath | Sort-Object -Property Client }
        ITGlue { $WarrantyStatus = Get-WarrantyITG -ITGAPIKey $ITGlueAPIKey -ITGAPIURL $ITGlueAPIURL -SyncWithSource $SyncWithSource -MissingOnly $Missingonly -OverwriteWarranty $OverwriteWarranty | Sort-Object -Property Client }
        CWManage { $WarrantyStatus = Get-WarrantyCWM -CwCompanyID $CWManageCompanyID -CWMpiKeyPublic $CWManagePublicKey -CWMpiKeyprivate $CWManagePrivateKey -CWMAPIURL $CWManageAPIURL  -SyncWithSource $SyncWithSource -MissingOnly $Missingonly -OverwriteWarranty $OverwriteWarranty | Sort-Object -Property Client }
        Nable { $WarrantyStatus = Get-WarrantyNable -NableURL $NableURL -JWTKey $NableJWT | Sort-Object -Property Client }
        DattoRMM { $WarrantyStatus = Get-WarrantyDattoRMM -DRMMApiURL $DattoAPIURL -DRMMSecret $DattoAPISecret -DRMMAPIKey $DattoAPIKey -SyncWithSource $SyncWithSource -MissingOnly $Missingonly -OverwriteWarranty $OverwriteWarranty | Sort-Object -Property Client }
        Hudu { $WarrantyStatus = Get-WarrantyHudu -HuduAPIKey $HuduAPIKey -HuduBaseURL $HuduBaseURL -HuduDeviceAssetLayout $HuduDeviceAssetLayout -HuduWarrantyField $HuduWarrantyField -SyncWithSource $SyncWithSource -MissingOnly $Missingonly -OverwriteWarranty $OverwriteWarranty | Sort-Object -Property Client } 

    }
   
    if ($GenerateReports -eq $true) {
        write-host "Done collecting warranty information. Generating reports." -ForegroundColor Green

        If (Get-Module -ListAvailable -Name "PSWriteHTML") { 
            Import-module PSWriteHTML
        }
        Else { 
            Install-Module PSWriteHTML -Force
            Import-Module PSWriteHTML
        }
        $CheckReportFolder = Test-Path($ReportsLocation)
        if (!$CheckReportFolder) { new-item -ItemType Directory -Path $ReportsLocation -Force }
        foreach ($client in $WarrantyStatus.client | Select-Object -Unique) {
            $Client = $Client.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
            write-host "Generating report for $Client at $($ReportsLocation)$client.html" -ForegroundColor Green
            New-HTML {   
                New-HTMLTab -Name 'Warranty of devices' {
                    New-HTMLSection -Invisible {
                        New-HTMLSection -HeaderText "Currently in warranty" {
                            New-HTMLTable -DataTable ($WarrantyStatus | Where-Object { $_.Client -eq $client -and $_.'Warranty Status' -eq 'OK' })
                        }
                        New-HTMLSection -HeaderText "Devices out of Warranty or unknown" {
                            New-HTMLTable -DataTable ($WarrantyStatus | Where-Object { $_.Client -eq $client -and $_.'Warranty Status' -ne 'OK' })
                        }
                    }
                    New-HTMLSection -HeaderText "All devices" {
                        New-HTMLTable -DataTable ($WarrantyStatus | Where-Object { $_.Client -eq $client })
                    }
                }
            } -FilePath "$($ReportsLocation)\$client.html" -Online
            ($WarrantyStatus | Where-Object { $_.Client -eq $client }) | Export-Csv "$($ReportsLocation)\$client.CSV" -NoTypeInformation -Force
        }
    }

    if ($ReturnWarrantyObject -eq $true) { return $WarrantyStatus }

}
