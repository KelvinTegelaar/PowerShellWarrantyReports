function  Get-WarrantyHalo {
    [CmdletBinding()]
    Param(
        [string]$HaloURL,
        [String]$HaloClientID,
        [String]$HaloClientSecret,
        [string]$HaloSerialField,
        [boolean]$SyncWithSource,
        [boolean]$Missingonly,
        [boolean]$OverwriteWarranty,
        [string]$ColumnsID,
        [switch]$resume
    )

    write-host "Source is Halo." -ForegroundColor Green
    #Get the Halo API Module if not installed
    if (Get-Module -ListAvailable -Name HaloAPI) {
        Import-Module HaloAPI 
    } else {
        Install-Module HaloAPI -RequiredVersion 1.20.0 -Force
        Import-Module  HaloAPI
    }

    Connect-HaloAPI -URL $HaloURL -ClientId $HaloClientID -ClientSecret $HaloClientSecret -Scopes "edit:assets"

    #Get Devices
    $ResumeLast = Test-Path 'Devices.json'
    If ($ResumeLast -and $script:resume) {
        write-host "Found previous run results. Starting from last object." -ForegroundColor green
        $Devices = Get-Content 'Devices.json' | ConvertFrom-Json
    } elseif ($script:ColumnsID){
        Write-Host "getting Halo Assets Using Columns ID $script:ColumnsID" -ForegroundColor Green
        $Devices = Get-HaloAsset -ColumnsID $script:ColumnsID
    } else {
        write-Host "Getting All Halo Asset Information" -ForegroundColor Green
        $Devices = Get-HaloAsset -FullObjects
    } 
    
    $i = 0
    $AssetArray = New-Object System.Collections.Generic.List[PSObject]  # Initialize a generic list

    foreach ($device in $Devices) {
        $i++
        if ($script:resume) {
        $null = Set-Content 'Devices.json' -Force -Value ($Devices | Select-Object -Skip $i | ConvertTo-Json -Depth 5)
        }
        # Find the Serial Number
        if ($Device."$($HaloSerialField)") {
            $Serial = $Device."$($HaloSerialField)"
            $ProductNumber = $Device."$($ProductNumber)"
        } else {
            $Serial = ($Device.Fields | Where-Object { $_.name -eq $HaloSerialField }).value
            if (($Serial | Measure-Object).count -ne 1) {
                $Serial = ($Device.customfields | Where-Object { $_.name -eq $HaloSerialField }).value
                if (($Serial | Measure-Object).count -ne 1) {
                    Write-Error "Serial field not found"
                    continue
                }
            }
        }

        Write-Progress -Activity "Grabbing Warranty information" -Status "Processing $Serial. Device $i of $($devices.Count)" -PercentComplete ($i / $Devices.Count * 100)      
        if ($ProductNumber) {
            $WarState = Get-Warrantyinfo -DeviceSerial $Serial -client $device.client_name -ProductNumber $ProductNumber
        } else { 
            $WarState = Get-Warrantyinfo -DeviceSerial $Serial -client $device.client_name
        }
        if ($SyncWithSource -eq $true) {

            $AssetUpdate = @{
                id = $Device.id
                warranty_start = $WarState.StartDate
                warranty_end = $WarState.EndDate
                warranty_note = $WarState.'Warranty Product name'
            }

            $AssetArray.Add((New-Object PSObject -Property $AssetUpdate))  # Add AssetUpdate to the generic list
            # If $i is a multiple of 100, set the warranties for all devices processed so far
            if ($i % 100 -eq 0) {
                #$AssetArrayJson = $AssetArray | ConvertTo-Json -Depth 10
                $maxRetries = 3  # Set the maximum number of retries
                $retryCount = 0
                while ($retryCount -lt $maxRetries) {
                    try {
                $null = Set-HaloAsset -Asset $AssetArray
                $AssetArray.Clear()  # Clear the list
                break  # Exit the loop on success
                    } catch {
                        Write-Warning "Attempt $retryCount failed. Retrying..."
                        $retryCount++  # Increment the retry counter
                        Start-Sleep -Seconds 2  # Wait for a bit before retrying (optional)
                    } 
                }

                if ($retryCount -eq $maxRetries) {
                    Write-Error "Failed to set asset warranties after $maxRetries attempts."
                }
            }
        }
    }
    
    # Process any remaining warranties
    if ($AssetArray.Count -gt 0) {
        #$AssetArrayJson = $AssetArray | ConvertTo-Json -Depth 10
        $null = Set-HaloAsset -Asset $AssetArray
    }
    
    Remove-Item 'devices.json' -Force -ErrorAction SilentlyContinue
    #return $warrantyObject
}