# This is a list of Service Level Codes that may be returned by the API that are not related to hardware warranties
$SLCBlacklist = @("D", "DL", "PJ", "PR");

function get-DellWarranty([Parameter(Mandatory = $true)]$SourceDevice, $Client) {
    if ($null -eq $Script:DellClientID) {
        write-error "Cannot continue: Dell API information not found. Please run Set-WarrantyAPIKeys before checking Dell Warranty information."
        return  [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = 'Could not get warranty information - No API key'
            'StartDate'             = $null
            'EndDate'               = $null
            'Warranty Status'       = 'Could not get warranty information - No API key'
            'Client'                = $Client
        }
    } 
    $today = Get-Date -Format yyyy-MM-dd
    $AuthURI = "https://apigtwb2c.us.dell.com/auth/oauth/v2/token"
    if ($Script:TokenAge -lt (get-date).AddMinutes(-55)) { $Script:Token = $null }
    If ($null -eq $Script:Token) {
        $OAuth = "$Script:DellClientID`:$Script:DellClientSecret"
        $Bytes = [System.Text.Encoding]::ASCII.GetBytes($OAuth)
        $EncodedOAuth = [Convert]::ToBase64String($Bytes)
        $headersAuth = @{ "authorization" = "Basic $EncodedOAuth" }
        $Authbody = 'grant_type=client_credentials'
        $AuthResult = Invoke-RESTMethod -Method Post -Uri $AuthURI -Body $AuthBody -Headers $HeadersAuth
        $Script:token = $AuthResult.access_token
        $Script:TokenAge = (get-date)
    }

    $headersReq = @{ "Authorization" = "Bearer $Script:Token" }
    $ReqBody = @{ servicetags = $SourceDevice }
    $WarReq = Invoke-RestMethod -Uri "https://apigtwb2c.us.dell.com/PROD/sbil/eapi/v5/asset-entitlements" -Headers $headersReq -Body $ReqBody -Method Get -ContentType "application/json"
    $warEntitlements = $warreq.entitlements | Where-Object { $_.serviceLevelCode -notin $SLCBlacklist }
    $warlatest = $warEntitlements.enddate | sort-object | select-object -last 1 
    $WarrantyState = if ($warlatest -le $today) { "Expired" } else { "OK" }
    if ($warlatest) {
        $StartDate = $warEntitlements.startdate | ForEach-Object { [DateTime]$_ } | sort-object -Descending | select-object -last 1
        $EndDate = $warEntitlements.enddate | ForEach-Object { [DateTime]$_ } | sort-object -Descending | select-object -first 1
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = ($warEntitlements.serviceleveldescription | Sort-Object -Unique) -join "`n"
            'StartDate'             = $StartDate
            'EndDate'               = $EndDate
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
    return $WarObj
}