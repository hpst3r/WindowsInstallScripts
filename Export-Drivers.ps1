#Requires -RunAsAdministrator

# Interactively export driver .inf files from a system in Audit Mode to a disk

function Export-Drivers {

  function Select-ExportTargetDisk {
    param (
      [Parameter(Mandatory = $true)]
      [string]$Model
    )
    
    $Volumes = (Get-Volume | Select-Object -Property DriveLetter, FileSystemLabel, FileSystemType, Size, SizeRemaining, DriveType)

    Write-Host @"
Available volumes:
$($Volumes | Format-Table -AutoSize | Out-String)
Please enter the drive letter for the target disk for driver export:
"@

    $ExternalDrive = Read-Host "External drive letter (e.g., E:)"

    # if drive letter does not end with a colon, append it
    if ($ExternalDrive -notlike "*:") {
        $ExternalDrive += ":"
    }

    return $ExternalDrive

  }

  # validate the export path exists and create it if it does not
  function Initialize-ExportPath {
    param (
      [Parameter(Mandatory = $true)]
      [string]$ExternalDrive,
      [string]$Directory,
      [string]$Model
    )

    $AssembledPath = "$($ExternalDrive)\$($Directory)\$($Model)"

    Write-Host "Validating export path: '$($ExternalDrive)\$($Directory)\$($Model)'..."

    # Try to resolve the exact path first
    if (Test-Path $AssembledPath) {
      $ResolvedPath = (Resolve-Path $AssembledPath).Path
    } else {
      # Try to find a near match containing the model name
      $PathMatches = Get-ChildItem -Path "$($ExternalDrive)\$($Directory)" -Directory -Filter "*$($Model)*" -ErrorAction SilentlyContinue
      # use the first match if found
      if ($PathMatches) {
        $ResolvedPath = $PathMatches[0].FullName
        Write-Host "Exact match for this model was not found, but similar directory '$($ResolvedPath)' was."
      } else { # otherwise use the exact model name
        $ResolvedPath = $AssembledPath
        Write-Host "No existing directory found. Creating one at: '$($ResolvedPath)'."
      }

    }

    # if directory already exists, prompt for confirmation to overwrite
    if (Test-Path $ResolvedPath 2> $null) {

      $Confirm = Read-Host "Directory '$($ResolvedPath)' already exists. Do you want to overwrite it? (Y/N)"

      if ($Confirm.Trim().ToUpper() -eq 'Y') {

        Write-Host "Removing existing directory '$($ResolvedPath)'..."

        try {

          Remove-Item $ResolvedPath -Recurse -Force -ErrorAction Stop | Out-Null

        } # try
        catch {
          
          throw "An error occurred while removing the existing directory: $($_.Exception.Message)"

        }

      } # fi
      else { # if not Y

        throw "Terminating: Export cancelled by user."

      }

    }

    try {

      # attempt to create the directory if it does not exist or if we've removed it

      if (-not (Test-Path -Path $ResolvedPath)) {

        Write-Host "Creating model directory '$($ResolvedPath)'..."

        New-Item -ItemType Directory -Path $ResolvedPath -Force -ErrorAction Stop | Out-Null

        Write-Host "Path '$($ResolvedPath)' created successfully."

      }

    } # try
    catch {

      throw "An error occurred while creating the path: $($_.Exception.Message)"

    }

    return $ResolvedPath

  }

  $Model = (Get-CimInstance -Class Win32_ComputerSystem).Model

  $TranscriptPath = "$($env:TEMP)\driver-export-$($Model)-$(Get-Date -UFormat %s)"
  Start-Transcript -Path $TranscriptPath

  try {

    Write-Host "System model detected: '$($Model)'."

    $ExternalDrive = (Select-ExportTargetDisk -Model $Model)

    $DriverPath = (Initialize-ExportPath -ExternalDrive $ExternalDrive -Directory ".drivers" -Model $Model)

    if (-not (Test-Path $DriverPath 2> $null)) {

      Write-Error "Export path validation failed. Terminating script."
      return

    }

    Write-Host "Exporting drivers from Windows image to $($DriverPath). This may take a while."

    # export drivers from the online Windows image to the specified path
    Export-WindowsDriver -Online -Destination $DriverPath -ErrorAction Stop

    Write-Host "Driver export completed. Drivers have been exported from the online image to '$($DriverPath)'."
  
  }
  finally {

    Write-Host "Export process completed. Cleaning up..."

    # stop the transcript and move it to the removable disk
    Stop-Transcript

    if (-not (Test-Path -Path $DriverPath 2> $null)) {

      Write-Warning "The machine export path does not exist. Transcript will not be moved from $($env:TEMP)."

    } else {

      Write-Host "Moving transcript to the export directory..."
      Move-Item -Path $TranscriptPath -Destination $DriverPath
      Write-Host "Transcript moved to '$($DriverPath)\$(($TranscriptPath -split '\\')[-1])'."

      Write-Host "Cleanup complete."

    }
    
  }

}

Export-Drivers
