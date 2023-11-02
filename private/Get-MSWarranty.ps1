function Get-MSWarranty([Parameter(Mandatory = $true)][string]$SourceDevice, $client) {
    if ($ExcludeMS -ne $True){
    $body = ConvertTo-Json @{
        sku          = "Surface_"
        SerialNumber = "$SourceDevice"
        ForceRefresh = $false
    }
    $today = Get-Date -Format yyyy-MM-dd
    $PublicKey = Invoke-RestMethod -Uri 'https://surfacewarrantyservice.azurewebsites.net/api/key' -Method Get
    $AesCSP = New-Object System.Security.Cryptography.AesCryptoServiceProvider 
    $AesCSP.GenerateIV()
    $AesCSP.GenerateKey()
    $AESIVString = [System.Convert]::ToBase64String($AesCSP.IV)
    $AESKeyString = [System.Convert]::ToBase64String($AesCSP.Key)
    $AesKeyPair = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$AESIVString,$AESKeyString"))
    $bodybytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $bodyenc = [System.Convert]::ToBase64String($AesCSP.CreateEncryptor().TransformFinalBlock($bodybytes, 0, $bodybytes.Length))
    $RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider
    $RSA.ImportCspBlob([System.Convert]::FromBase64String($PublicKey))
    $EncKey = [System.Convert]::ToBase64String($rsa.Encrypt([System.Text.Encoding]::UTF8.GetBytes($AesKeyPair), $false))
     
    $FullBody = @{
        Data = $bodyenc
        Key  = $EncKey
    } | ConvertTo-Json
    
    $WarReq = Invoke-RestMethod -uri "https://surfacewarrantyservice.azurewebsites.net/api/v2/warranty" -Method POST -body $FullBody -ContentType "application/json"
    
    if ($WarReq.warranties) {
        $WarrantyState = foreach ($War in ($WarReq.warranties.effectiveenddate -split 'T')[0]) {
            if ($War -le $today) { "Expired" } else { "OK" }
        }
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = $WarReq.warranties.name -join "`n"
            'StartDate'             = [DateTime](($WarReq.warranties.effectivestartdate | sort-object -Descending | select-object -last 1) -split 'T')[0]
            'EndDate'               = [DateTime](($WarReq.warranties.effectiveenddate | sort-object | select-object -last 1) -split 'T')[0]
            'Warranty Status'       = $WarrantyState
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
} else {
    $WarObj = [PSCustomObject]@{
        'Serial'                = $SourceDevice
        'Warranty Product name' = 'MS Lookups Excluded'
        'StartDate'             = $null
        'EndDate'               = $null
        'Warranty Status'       = 'MS Lookups Excluded'
        'Client'                = $Client
    } 
}
    return $WarObj
}