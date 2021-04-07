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
 
    $i = 0
    If ($ResumeLast) {
        write-host "Found previous run results. Starting from last object." -foregroundColor green
        $Devices = get-content 'Devices.json' | convertfrom-json
    }
    else {
	
		$JSON = @{
			"api_key" = $BTAPIKEY
			"api_action" = "msp_get_agents"
			"api_version" = 1
		} | ConvertTo-Json
		
		
		try {	
			$Devices = Invoke-RestMethod -Uri "$($BTAPIURL)" -Method Post -Body $JSON -ContentType "application/json" | ConvertTo-Json		
		}
		catch [System.Net.WebException] {   
			$respStream = $_.Exception.Response.GetResponseStream()
			$reader = New-Object System.IO.StreamReader($respStream)
			$respBody = $reader.ReadToEnd() | ConvertFrom-Json
			#$respBody;
		}
		
    }
		
    $warrantyObject = foreach ($device in $Devices) {
        $i++
        Write-Progress -Activity "Grabbing Warranty information" -status "Processing $($device.name)."
        $WarState = Get-Warrantyinfo -DeviceSerial $device.hw_serial_number -client $device.company_name
        $RemainingList = set-content 'Devices.json' -force -value ($Devices | select-object -skip $i | convertto-json -depth 5)

        if ($script:SyncWithSource -eq $true) {
		
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
			
            switch ($script:OverwriteWarranty) {	
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
    Remove-item 'devices.json' -Force -ErrorAction SilentlyContinue
    return $warrantyObject
}