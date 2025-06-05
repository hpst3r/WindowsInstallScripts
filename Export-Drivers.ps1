# Interactively export driver .inf files from a system in Audit Mode to a disk

function Export-Drivers {

  $Model = (Get-CimInstance -Class Win32_ComputerSystem).Model

  function Select-ExportTargetDisk {
    param (
      [Parameter(Mandatory = $true)]
      [string]$Model
    )
    
    $Volumes = (Get-Volume | Select-Object -Property DriveLetter, FileSystemLabel, FileSystemType, Size, SizeRemaining, DriveType)

    Write-Host @"
Available Volumes:
$($Volumes | Format-Table -AutoSize | Out-String)
Please enter the drive letter for the target disk for driver export:
"@

    $ExternalDrive = Read-Host "External drive letter (e.g., E:)"

    # if drive letter does not end with a colon, append it
    if ($ExternalDrive -notlike "*:") {
        $ExternalDrive += ":"
    }

    return "$($ExternalDrive)\.drivers\$($Model)"

  }

  # half-assed validate the export path exists and create it if it does not
  # TODO: dress this up a bit
  function Initialize-ExportPath {
    param (
      [Parameter(Mandatory = $true)]
      [string]$Path
    )

          # if directory already exists, prompt for confirmation to overwrite
    if (Test-Path -Path $DriverPath) {

        $Confirm = Read-Host "Directory '$($DriverPath)' already exists. Do you want to overwrite it? (Y/N)"

        if ($Confirm.Trim().ToUpper() -ne 'Y') {

            Write-Host "Export cancelled by user."
            
            return $false

        } # fi
        else {

          Write-Host "Removing existing directory '$($DriverPath)'."

          try {

            Remove-Item $DriverPath -Recurse -Force -ErrorAction Stop | Out-Null

          } # try
          catch {
            
            Write-Error "An error occurred while removing the existing directory: $($_.Exception.Message)"

            return $false

          }

        }

    }

    $ParentPath = (Split-Path -Path $Path -Parent)

    try {

      # attempt to create the parent directory if it does not exist

      if (-not $ParentPath) {

        Write-Host "The specified parent path does not exist. Creating it now."

        New-Item -ItemType Directory -Path $ParentPath -Force -ErrorAction Stop | Out-Null

        Write-Host "Parent path '$($ParentPath)' created successfully."

      }

      # attempt to create the model directory if it does not exist

      if (-not (Test-Path -Path $Path)) {

        Write-Host "Creating model directory '$($Path)'..."

        New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null

        Write-Host "Path '$($Path)' created successfully."

      }

    } # try
    catch {

      Write-Error "An error occurred while creating the path: $($_.Exception.Message)"

      return $false

    }

    return $true

  }

  Write-Host "System model detected: '$($Model)'."

  $DriverPath = (Select-ExportTargetDisk -Model $Model)

  if (-not (Validate-ExportPath -Path $DriverPath)) {

    Write-Error "Export path validation failed. Terminating script."

    return

  }

  Write-Host "Exporting drivers from Windows image to $($DriverPath). This may take a while."

  $Drivers = (Export-WindowsDriver -Online -Destination $DriverPath -ErrorAction Stop)

  $env:ExportResult = $Drivers

  Write-Host @"
Driver export completed successfully. Drivers saved to '$($DriverPath)'.
Check environment variable `$env:ExportResult` for the output object from Export-WindowsDriver.
"@

}

Export-Drivers