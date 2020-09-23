function Set-WarrantyAPIKeys {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName = 'Dell', Mandatory = $true)]
        [string]$DellClientID,
        [Parameter(ParameterSetName = 'Dell', Mandatory = $false)]
        [String]$DellClientSecret
    )
    write-host "Setting Dell Warranty API Keys" -ForegroundColor Green
    $script:DellClientID = $DellClientID
    $script:DellClientSecret = $DellClientSecret
}