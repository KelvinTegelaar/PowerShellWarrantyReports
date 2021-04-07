function  Get-WarrantyBTIO {
    [CmdletBinding()]
    Param(
        [String]$BTAPIKEY,
        [string]$BTAPIURL,
        [boolean]$SyncWithSource,
        [boolean]$Missingonly,
        [boolean]$OverwriteWarranty
    )
    write-host "Source is BluetraitIO. Grabbing all devices." -ForegroundColor Green



	$JSON = @{
		"api_key" = $BTAPIKEY
		"api_action" = "msp_get_agents"
		"api_version" = 1
	} | ConvertTo-Json
	
	
	try {	
		$Devices = Invoke-RestMethod -Uri "$($BTAPIURL)" -Method Post -Body $JSON -ContentType "application/json"
	}
	catch [System.Net.WebException] {   
		$respStream = $_.Exception.Response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($respStream)
		$respBody = $reader.ReadToEnd() | ConvertFrom-Json
		#$respBody;
	}
	

	
	write-host $Devices
		
    $warrantyObject = foreach ($device in $Devices) {
		$device_name = $device.name
		Write-Host "Processing $device_name"
        $WarState = Get-Warrantyinfo -DeviceSerial $device.hw_serial_number -client $device.company_name
        
		if ($SyncWithSource -eq $true) {
		
			write-host "Updating BluetraitIO" -foregroundColor green
       			
			$JSON = @{
				"api_key" = $BTAPIKEY
				"api_action" = "msp_edit_agent"
				"api_version" = 1
				"id" = $($device.id)
				"columns" = @{
					"warranty_expires" = $WarState.EndDate
				}
			} | ConvertTo-Json
		
			$JSON
			
            switch ($OverwriteWarranty) {	
                $true {
                    if ($null -ne $warstate.EndDate) {
						Invoke-RestMethod -Uri "$($BTAPIURL)" -Method Post -Body $JSON -ContentType "application/json"	
                    }
                     
                }
                $false { 
                    if ($null -eq $device.warranty_expires -and $null -ne $warstate.EndDate) { 
						Invoke-RestMethod -Uri "$($BTAPIURL)" -Method Post -Body $JSON -ContentType "application/json"	
                    } 
                }
            }
        }
        $WarState
    }
    return $warrantyObject
}