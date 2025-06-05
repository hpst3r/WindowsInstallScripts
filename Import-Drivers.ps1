# this script was authored by seton at carmichaelcomputing.com

# Search for .drivers folder
$driverFolderRoot = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $rootPath = "$($_.Root).drivers"
    if (Test-Path $rootPath) {
        $rootPath
    }
} | Select-Object -First 1

if ($driverFolderRoot) {
    Write-Log "Found .drivers folder at: $driverFolderRoot"
    
    # Look for a folder matching the exact model number (case-insensitive)
    $driverFolder = Get-ChildItem -Path $driverFolderRoot | 
        Where-Object { $_.PSIsContainer -and $_.Name -like "$ModelNumber*" -or $_.Name -eq $ModelNumber } | 
        Select-Object -First 1

    if ($driverFolder) {

        Write-Log "Found driver folder for model $($ModelNumber): $($driverFolder.FullName)"

        $driverFiles = Get-ChildItem -Path $driverFolder.FullName -Recurse -Include "*.inf"
    
        if ($driverFiles) {
            $totalDrivers = $driverFiles.Count
            $currentDriver = 0
            $successCount = 0
            $failureCount = 0
            
            Write-Log "Found $totalDrivers driver(s) to install"
            
            foreach ($driverFile in $driverFiles) {

                $currentDriver++

                try {
                    
                    Write-Log "($currentDriver/$totalDrivers) Installing driver: $($driverFile.FullName)"
                    
                    # cannot use Add-WindowsDriver here as it does not support online installation
                    $result = & pnputil.exe /add-driver "$($driverFile.FullName)" /install 2>&1

                    Write-Log "PnPUtil Output: $result"
                    
                    if ($result -match "Failed") {
                        $failureCount++
                        Write-Log "Failed to install driver: $($driverFile.Name)"
                    } else {
                        $successCount++
                        Write-Log "Successfully installed driver: $($driverFile.Name)"
                    }

                } catch {

                    $failureCount++
                    Write-Log "Error installing driver: $($_.Exception.Message)"

                }

            }
            
            Write-Log "Driver installation complete"
            Write-Log "Successfully installed: $successCount driver(s)"
            Write-Log "Failed to install: $failureCount driver(s)"
            
            # Create marker file only in non-interactive mode
            if (-not $interactive) {

                New-Item -ItemType File -Path $markerFile -Force | Out-Null
                Add-Content -Path $markerFile -Value "Driver installation completed on $(Get-Date)"

            }
            
            if ($successCount -gt 0) {

                if ($interactive) {

                    $restart = Read-Host "Would you like to restart the computer now to complete driver installation? (Y/N)"

                    if ($restart -eq 'Y' -or $restart -eq 'y') {

                        Write-Log "Initiating system restart..."
                        Restart-Computer -Force

                    }

                } else {

                    Write-Log "Scheduling restart in 10 seconds..."
                    Start-Sleep -Seconds 10
                    Restart-Computer -Force

                }
            }

        } else {

            Write-Log "Warning: No driver files (.inf) found in $($driverFolder.FullName)"

        }

    } else {

        Write-Log "No exact folder found for model $ModelNumber. Checking similar models..."
        $allFolders = Get-ChildItem -Path $driverFolderRoot | Where-Object { $_.PSIsContainer }
        
        if ($allFolders.Count -gt 0 -and $interactive) {

            Write-Log "Available driver folders"
            $folderChoices = @{}
            $index = 1
            
            # Sort folders by similarity to current model number
            $allFolders = $allFolders | Sort-Object -Property @{
                Expression = {
                    # Calculate similarity score
                    $similarity = 0
                    if ($_.Name -match [regex]::Escape($Manufacturer)) { $similarity += 2 }
                    if ($_.Name -match [regex]::Escape($ModelNumber.Substring(0, [Math]::Min(4, $ModelNumber.Length)))) { $similarity += 3 }
                    $similarity
                }
            } -Descending

            foreach ($folder in $allFolders) {

                Write-Log "$($index): $($folder.Name)"
                $folderChoices[$index] = $folder
                $index++

            }

            $selection = Read-Host "Enter the number of the folder to use for driver installation (or press Enter to skip)"

            if ($selection -and $folderChoices.ContainsKey([int]$selection)) {

                $selectedFolder = $folderChoices[[int]$selection]
                Write-Log "Selected folder: $($selectedFolder.FullName)"
                
                $driverFiles = Get-ChildItem -Path $selectedFolder.FullName -Recurse -Include "*.inf"
                
                if ($driverFiles) {

                    $totalDrivers = $driverFiles.Count
                    $currentDriver = 0
                    $successCount = 0
                    $failureCount = 0
                    
                    Write-Log "Found $totalDrivers driver(s) to install"
                    
                    foreach ($driverFile in $driverFiles) {

                        $currentDriver++

                        try {

                            Write-Log "($currentDriver/$totalDrivers) Installing driver: $($driverFile.FullName)"
                            $result = & pnputil.exe /add-driver "$($driverFile.FullName)" /install 2>&1
                            Write-Log "PnPUtil Output: $result"
                            
                            if ($result -match "Failed") {
                                $failureCount++
                                Write-Log "Failed to install driver: $($driverFile.Name)"
                            } else {
                                $successCount++
                                Write-Log "Successfully installed driver: $($driverFile.Name)"
                            }
                        } catch {

                            $failureCount++
                            Write-Log "Error installing driver: $($_.Exception.Message)"

                        }

                    }
                    
                    Write-Log "Driver installation complete"
                    Write-Log "Successfully installed: $successCount driver(s)"
                    Write-Log "Failed to install: $failureCount driver(s)"
                    
                    if ($successCount -gt 0) {

                        $restart = Read-Host "Would you like to restart the computer now to complete driver installation? (Y/N)"

                        if ($restart -eq 'Y' -or $restart -eq 'y') {

                            Write-Log "Initiating system restart..."
                            Restart-Computer -Force

                        }

                    }

                } else {

                    Write-Log "No driver files found in the selected folder: $($selectedFolder.FullName)"

                }

            } else {

                Write-Log "No folder selected. Installation skipped."

            }

        } else {

            Write-Log "No driver folders available in .drivers directory."

        }

    }

} else {

    Write-Log "No .drivers folder found on any attached drives."

}

Write-Log "Script execution completed"
