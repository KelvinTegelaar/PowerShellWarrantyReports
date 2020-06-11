$source = "CSV" #AT, CSV, ITG, CW
##### Sync Settings
$SyncWithSource = $true  #Sync status warranty dates/status back to PSA/Management system. Only works with dynamic sources like ITG and AT.
$OverwriteWarranty = $true #Overwrites the date already found in AT with the one based on this API, unless the API could not find information.
$CreateHTMLReport = $true #Creates an HTML report.
###### File locations
$ReportsLocation = "C:\temp\reports" #Only required if Reporting is enabled.
$sourcefile = "C:\temp\temp.csv" #only required if source is not autotask.
$ATLogPath = "C:\temp\AT.txt" #Only used to log which objects have been synced with AT as AT does not have a audit log.
##### AT API Settings
$ATAPIKey = "Your-API-Key-For-Autotask" #only required if source is Autotask.
##### ITG API Settings
$ITGAPIKey = "Your-API-Key-For-ITG"  #only required if source is ITG
$ITGAPIURL = "https://api.eu.itglue.com" #only required if source is ITG
##### CW API Settings
$CWAPIURL = "https://api-staging.connectwisedev.com/v4_6_release/apis/3.0" #https://developer.connectwise.com/Best_Practices/Manage_Cloud_URL_Formatting?mt-learningpath=manage
$CWApiKeyPublic = "CWPublicKey" #Only required if source is CW
$CWApiKeyPrivate = "CwPrivateKey" #Only required if source is CW
$CWcompanyid = "CompanyID_1" #Only required if source is CW
##### Warranty Vendor API Keys
$DellClientID = "Dell-Client-ID"
$DellClientSecret = "Dell-Client-Secret"



function get-HPWarranty([Parameter(Mandatory = $true)]$SourceDevice, $Client) {
    $MWSID = (invoke-restmethod -uri 'https://support.hp.com/us-en/checkwarranty/multipleproducts/' -SessionVariable 'session' -Method get) -match '.*mwsid":"(?<wssid>.*)".*'
    $HPBody = " { `"gRecaptchaResponse`":`"`", `"obligationServiceRequests`":[ { `"serialNumber`":`"$SourceDevice`", `"isoCountryCde`":`"US`", `"lc`":`"EN`", `"cc`":`"US`", `"modelNumber`":null }] }"
 
    $HPReq = Invoke-RestMethod -Uri "https://support.hp.com/hp-pps-services/os/multiWarranty?ssid=$($matches.wssid)" -WebSession $session -Method "POST" -ContentType "application/json" -Body $HPbody
    if ($HPreq.productWarrantyDetailsVO.warrantyResultList.obligationStartDate) {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = $hpreq.productWarrantyDetailsVO.warrantyResultList.warrantyType | Out-String
            'StartDate'             = $hpreq.productWarrantyDetailsVO.warrantyResultList.obligationStartDate | sort-object | select-object -last 1
            'EndDate'               = $hpreq.productWarrantyDetailsVO.warrantyResultList.obligationEndDate | sort-object | select-object -last 1
            'Warranty Status'       = $hpreq.productWarrantyDetailsVO.obligationStatus
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
function get-DellWarranty([Parameter(Mandatory = $true)]$SourceDevice, $client) {
    $today = Get-Date -Format yyyy-MM-dd
    $AuthURI = "https://apigtwb2c.us.dell.com/auth/oauth/v2/token"
    if ($Global:TokenAge -lt (get-date).AddMinutes(-55)) { $global:Token = $null }
    If ($null -eq $global:Token) {
        $OAuth = "$global:DellClientID`:$global:DellClientSecret"
        $Bytes = [System.Text.Encoding]::ASCII.GetBytes($OAuth)
        $EncodedOAuth = [Convert]::ToBase64String($Bytes)
        $headersAuth = @{ "authorization" = "Basic $EncodedOAuth" }
        $Authbody = 'grant_type=client_credentials'
        $AuthResult = Invoke-RESTMethod -Method Post -Uri $AuthURI -Body $AuthBody -Headers $HeadersAuth
        $global:token = $AuthResult.access_token
        $Global:TokenAge = (get-date)
    }

    $headersReq = @{ "Authorization" = "Bearer $global:Token" }
    $ReqBody = @{ servicetags = $SourceDevice }
    $WarReq = Invoke-RestMethod -Uri "https://apigtwb2c.us.dell.com/PROD/sbil/eapi/v5/asset-entitlements" -Headers $headersReq -Body $ReqBody -Method Get -ContentType "application/json"
    $warlatest = $warreq.entitlements.enddate | sort-object | select-object -last 1 
    $WarrantyState = if ($warlatest -le $today) { "Expired" } else { "OK" }
    if ($warreq.entitlements.serviceleveldescription) {
        $WarObj = [PSCustomObject]@{
            'Serial'                = $SourceDevice
            'Warranty Product name' = $warreq.entitlements.serviceleveldescription -join "`n"
            'StartDate'             = (($warreq.entitlements.startdate | sort-object -Descending | select-object -last 1) -split 'T')[0]
            'EndDate'               = (($warreq.entitlements.enddate | sort-object | select-object -last 1) -split 'T')[0]
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
function get-LenovoWarranty([Parameter(Mandatory = $true)]$SourceDevice, $client) {
    $today = Get-Date -Format yyyy-MM-dd
    $APIURL = "https://ibase.lenovo.com/POIRequest.aspx"
    $SourceXML = "xml=<wiInputForm source='ibase'><id>LSC3</id><pw>IBA4LSC3</pw><product></product><serial>$SourceDevice</serial><wiOptions><machine/><parts/><service/><upma/><entitle/></wiOptions></wiInputForm>"
    $Req = Invoke-RestMethod -Uri $APIURL -Method POST -Body $SourceXML -ContentType 'application/x-www-form-urlencoded'
    if ($req.wiOutputForm) {
        $warlatest = $Req.wiOutputForm.warrantyInfo.serviceInfo.wed | sort-object | select-object -last 1 
        $WarrantyState = if ($warlatest -le $today) { "Expired" } else { "OK" }
         
        $WarObj = [PSCustomObject]@{
            'Serial'                = $Req.wiOutputForm.warrantyInfo.machineinfo.serial
            'Warranty Product name' = $Req.wiOutputForm.warrantyInfo.machineinfo.productname -join "`n"
            'StartDate'             = $Req.wiOutputForm.warrantyInfo.serviceInfo.warstart | sort-object -Descending | select-object -last 1
            'EndDate'               = $Req.wiOutputForm.warrantyInfo.serviceInfo.wed | sort-object | select-object -last 1
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
function Get-MSWarranty([Parameter(Mandatory = $true)]$SourceDevice, $client) {
    $body = ConvertTo-Json @{
        sku          = "Surface_"
        SerialNumber = $SourceDevice
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
            'StartDate'             = (($WarReq.warranties.effectivestartdate | sort-object -Descending | select-object -last 1) -split 'T')[0]
            'EndDate'               = (($WarReq.warranties.effectiveenddate | sort-object | select-object -last 1) -split 'T')[0]
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
 
function Get-WarrantyAutotask($APIKey) {
    write-host "Source is Autotask." -ForegroundColor Green
    If (Get-Module -ListAvailable -Name "Autotask") { Import-module "Autotask" } Else { install-module "Autotask" -Force }
    $Credential = Get-Credential -Message "Enter your Autotask Credentials"
    remove-module autotask
    Import-Module Autotask -ArgumentList $Credential, $global:ATAPIKey
    write-host "Logging into Autotask. Grabbing all client information." -ForegroundColor "Green"
    $AllClients = $AllAccounts = Get-AtwsAccount -All | Where-Object { $_.Active -eq $true }
    write-host "Client information found. Grabbing all devices" -ForegroundColor "Green"
    $AllDevices = Get-AtwsInstalledProduct -All | Where-Object { $_.Active -eq $true -and $null -ne $_.SerialNumber }
    write-host "Collecting information. This can take a long time." -ForegroundColor "Green"
    $i = 0
    $warrantyObject = foreach ($Device in $AllDevices) {
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($device.serialnumber). Device $i of $($Alldevices.Count)" -percentComplete ($i / $Alldevices.Count * 100)
        $Client = ($AllClients | Where-Object { $_.id -eq $device.AccountID }).AccountName
        #We use a guess-smart method for serialnumbers. 
        #Dell is always 7, Lenovo is always 8, 10 is HP, 12 is Surface. 
        #This is because we cannot safely find the manafacture in the AT info.
        switch ($device.SerialNumber.Length) {
            7 { $WarState = get-DellWarranty -SourceDevice $device.SerialNumber -client $Client }
            8 { $WarState = get-LenovoWarranty -SourceDevice $device.SerialNumber -client $Client }
            10 { $WarState = get-HPWarranty  -SourceDevice $device.SerialNumber -client $Client }
            12 { $WarState = Get-MSWarranty  -SourceDevice $device.SerialNumber -client $Client }
        }
        if ($script:SyncWithSource -eq $true) {
            switch ($script:OverwriteWarranty) {
                $true {
                    if ($null -ne $warstate.EndDate) {
                        $device | Set-AtwsInstalledProduct -WarrantyExpirationDate $warstate.EndDate
                        "$Client / $($device.SerialNumber) with AT ID $($device.id) warranty has been overwritten to $($warstate.EndDate)" | out-file $script:ATLogPath -Append -Force
                    }
                     
                }
                $false { 
                    if ($null -eq $device.WarrantyExpirationDate -and $null -ne $warstate.EndDate) { 
                        $device | Set-AtwsInstalledProduct -WarrantyExpirationDate $warstate.EndDate 
                        "$Client / $($device.SerialNumber) with AT ID $($device.id) warranty has been set to $($warstate.EndDate)" | out-file $script:ATLogPath -Append -Force
                    } 
                }
            }
        }
        $WarState
    }
 
    return $warrantyObject
}
function  Get-WarrantyITG() {
    write-host "Source is IT-Glue. Grabbing all devices." -ForegroundColor Green
    If (Get-Module -ListAvailable -Name "ITGlueAPI") { 
        Import-module ITGlueAPI 
    }
    Else { 
        Install-Module ITGlueAPI -Force
        Import-Module ITGlueAPI
    }
    #Settings IT-Glue logon information
    Add-ITGlueBaseURI -base_uri $Global:ITGAPIURL
    Add-ITGlueAPIKey  $Global:ITGAPIKey
    write-host "Getting IT-Glue configuration list" -foregroundColor green
    $i = 0
    $AllITGlueConfigs = @()
    do {
        $AllITGlueConfigs += (Get-ITglueconfigurations -page_size 1000 -page_number $i).data
        $i++
        Write-Host "Retrieved $($AllITGlueConfigs.count) configurations" -ForegroundColor Yellow
    }while ($AllITGlueConfigs.count % 1000 -eq 0 -and $AllITGlueConfigs.count -ne 0) 
     
    $warrantyObject = foreach ($device in $AllITGlueConfigs) {
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($device.attributes.'serial-number'). Device $i of $($AllITGlueConfigs.Count)" -percentComplete ($i / $AllITGlueConfigs.Count * 100)
        $Client = ($AllClients | Where-Object { $_.id -eq $device.AccountID }).AccountName
        $client = $device.attributes.'organization-name'
        switch ($device.attributes.'serial-number'.Length) {
            7 { $WarState = get-DellWarranty -SourceDevice $device.attributes.'serial-number' -client $Client }
            8 { $WarState = get-LenovoWarranty -SourceDevice $device.attributes.'serial-number' -client $Client }
            10 { $WarState = get-HPWarranty  -SourceDevice $device.attributes.'serial-number' -client $Client }
            12 { $WarState = Get-MSWarranty  -SourceDevice $device.attributes.'serial-number' -client $Client }
        }
        if ($script:SyncWithSource -eq $true) {
            $FlexAssetBody = @{
                "type"       = "configurations"
                "attributes" = @{
                    'warranty-expires-at' = $warstate.EndDate
                } 
            }
            switch ($script:OverwriteWarranty) {
                $true {
                    if ($null -ne $warstate.EndDate) {
                        Set-ITGlueConfigurations -id $device.id -data $FlexAssetBody
                    }
                     
                }
                $false { 
                    if ($null -eq $device.WarrantyExpirationDate -and $null -ne $warstate.EndDate) { 
                        Set-ITGlueConfigurations -id $device.id -data $FlexAssetBody
                    } 
                }
            }
        }
        $WarState
    }
    return $warrantyObject
}
 
function  Get-WarrantyCW() {
    write-host "Source is Connectwise Manage. Grabbing all devices." -ForegroundColor Green
    $Base64Key = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($Global:CWcompanyid)+$($Global:CWApiKeyPublic):$($global:CWApiKeyPrivate)"))
 
    $Header = @{
        'clientId'      = '3613dda6-fa25-49b9-85fb-7aa2b628befa' #This is the warranty script client id. Do not change. 
        'Authorization' = "Basic $Base64Key"
        'Content-Type'  = 'application/json'
    }
    $i = 0
    $Devices = @()
    do {
        $Devices += invoke-restmethod -headers $header -method GET -uri "$($Global:CWAPIURL)/company/configurations?pageSize=250&page=$i"
        $i++
        Write-Host "Retrieved $($devices.count) configurations" -ForegroundColor Yellow
    }while ($devices.count % 250 -eq 0 -and $devices.count -ne 0) 
 
    $warrantyObject = foreach ($device in $Devices) {
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($device.serialnumber). Device $i of $($devices.Count)" -percentComplete ($i / $Devices.Count * 100)
        $client = $device.company.name
        switch ($device.serialnumber.Length) {
            7 { $WarState = get-DellWarranty -SourceDevice $device.serialnumber -client $Client }
            8 { $WarState = get-LenovoWarranty -SourceDevice $device.serialnumber -client $Client }
            10 { $WarState = get-HPWarranty  -SourceDevice $device.serialnumber -client $Client }
            12 { $WarState = Get-MSWarranty  -SourceDevice $device.serialnumber -client $Client }
        }
        if ($script:SyncWithSource -eq $true) {
            if (!$device.warrantyExpirationDate) {
                $device | Add-Member -NotePropertyName "warrantyExpirationDate" -NotePropertyValue "$($WarState.enddate)T00:00:00Z"
            }
            else { 
                $device.warrantyExpirationDate = "$($WarState.enddate)T00:00:00Z"
            }
            $CWBody = $device | ConvertTo-Json
            switch ($script:OverwriteWarranty) {
                $true {
                    if ($null -ne $warstate.EndDate) {
                        invoke-restmethod -headers $header -method put -uri "$($Global:CWAPIURL)/company/configurations/$($device.id)" -body $CWBody
                    }
                     
                }
                $false { 
                    if ($null -eq $device.WarrantyExpirationDate -and $null -ne $warstate.EndDate) { 
                        invoke-restmethod -headers $header -method put -uri "$($Global:CWAPIURL)/company/configurations/$($device.id)" -body $CWBody
                    } 
                }
            }
        }
        $WarState
    }
    return $warrantyObject
}
 
 
switch ($source) {
    AT { $warrantyObject = Get-WarrantyAutotask -APIKey $ATAPIKey | Sort-Object -Property Client }
    CSV { $warrantyObject = Get-WarrantyCSV -Sourcefile $sourcefile | Sort-Object -Property Client }
    ITG { $warrantyObject = Get-WarrantyITG | Sort-Object -Property Client }
    CW { $warrantyObject = Get-WarrantyCW | Sort-Object -Property Client }
}
write-host "Done updating warrenties. Generating reports if required." -ForegroundColor Green
$head = @"
<script>
function myFunction() {
    const filter = document.querySelector('#myInput').value.toUpperCase();
    const trs = document.querySelectorAll('table tr:not(.header)');
    trs.forEach(tr => tr.style.display = [...tr.children].find(td => td.innerHTML.toUpperCase().includes(filter)) ? '' : 'none');
  }</script>
<Title>Warranty Report</Title>
<style>
body { background-color:#E5E4E2;
      font-family:Monospace;
      font-size:10pt; }
td, th { border:0px solid black; 
        border-collapse:collapse;
        white-space:pre; }
th { color:white;
    background-color:black; }
table, tr, td, th {
     padding: 2px; 
     margin: 0px;
     white-space:pre; }
tr:nth-child(odd) {background-color: lightgray}
table { width:95%;margin-left:5px; margin-bottom:20px; }
h2 {
font-family:Tahoma;
color:#6D7B8D;
}
.footer 
{ color:green; 
 margin-left:10px; 
 font-family:Tahoma;
 font-size:8pt;
 font-style:italic;
}
#myInput {
  background-image: url('https://www.w3schools.com/css/searchicon.png'); /* Add a search icon to input */
  background-position: 10px 12px; /* Position the search icon */
  background-repeat: no-repeat; /* Do not repeat the icon image */
  width: 50%; /* Full-width */
  font-size: 16px; /* Increase font-size */
  padding: 12px 20px 12px 40px; /* Add some padding */
  border: 1px solid #ddd; /* Add a grey border */
  margin-bottom: 12px; /* Add some space below the input */
}
</style>
"@
   
$PreContent = @"
<H1> Warranty Report </H1> <br>
   
Please consult the report for more information. you can use the search window to find a specific device, date, or warranty state.
<br/>
<br/>
    
<input type="text" id="myInput" onkeyup="myFunction()" placeholder="Search...">
"@
   
 
if ($CreateHTMLReport -eq $true) {
    $CheckReportFolder = Test-Path($ReportsLocation)
    if (!$CheckReportFolder) { new-item -ItemType Directory -Path $ReportsLocation -Force | Out-Null }
    foreach ($client in $warrantyObject.client | Select-Object -Unique) {
        write-host "Generating report for $Client at $($ReportsLocation)\$client.html" -ForegroundColor Green
        $warrantyObject | Where-Object { $_.Client -eq $client } | convertto-html -Head $head -precontent $precontent | out-file "$($ReportsLocation)\$client.html"
    }
 
}