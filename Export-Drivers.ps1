#Requires -RunAsAdministrator
#Requires -Version 5.1

function Export-Drivers {
  <#
  .SYNOPSIS
  Interactively export driver .inf files from a system in Audit Mode to a disk
  
  .DESCRIPTION
  This script exports drivers from the online Windows image to a .drivers\MODEL directory on a specified external disk.
  If the directory does not exist, it will be created. If an exact or wildcard match for the model directory is found,
  the user will be prompted to confirm overwriting it.
  
  .EXAMPLE
  PS D:\scripts> .\Export-Drivers.ps1
  Transcript started, output file is C:\Users\liam\AppData\Local\Temp\driver-export-OptiPlex 9020-1750886109
  System model detected: 'OptiPlex 9020'.
  Available volumes:

  DriveLetter FileSystemLabel FileSystemType         Size SizeRemaining DriveType
  ----------- --------------- --------------         ---- ------------- ---------
                              FAT32             268435456     233230336 Fixed
  C                           NTFS           999185969152  962233053184 Fixed
  D           Ventoy          exFAT          127997050880  108174770176 Fixed
  E           VTOYEFI         FAT                33277440       4793856 Fixed
                              NTFS              726659072     120832000 Fixed


  Please enter the drive letter for the target disk for driver export:
  External drive letter (e.g., E:): D
  Validating export path: 'D:\.drivers\OptiPlex 9020'...
  No existing directory found. Creating one at: 'D:\.drivers\OptiPlex 9020'.
  Creating model directory 'D:\.drivers\OptiPlex 9020'...
  Path 'D:\.drivers\OptiPlex 9020' created successfully.
  Exporting drivers from Windows image to D:\.drivers\OptiPlex 9020. This may take a while.

  Driver           : oem0.inf
  OriginalFileName : C:\Windows\System32\DriverStore\FileRepository\prnms009.inf_amd64_97613c6f44514bba\prnms009.inf
  Inbox            : False
  ClassName        : Printer
  BootCritical     : False
  ProviderName     : Microsoft
  Date             : 6/21/2006 12:00:00 AM
  Version          : 10.0.26100.1

  ...snip...

  Driver export completed. Drivers have been exported from the online image to 'D:\.drivers\OptiPlex 9020'.
  Export process completed. Cleaning up...
  Transcript stopped, output file is C:\Users\liam\AppData\Local\Temp\driver-export-OptiPlex 9020-1750886109
  Moving transcript to the export directory...
  Transcript moved to 'D:\.drivers\OptiPlex 9020\driver-export-OptiPlex 9020-1750886109'.
  Cleanup complete.
  #>

  function Select-ExportTargetDisk {
    <#
    .SYNOPSIS
    Select a target disk for driver export from available volumes.
    .DESCRIPTION
    This function lists all available volumes and prompts the user to select a drive letter,
    then returns the selected drive letter with a colon appended if not already present.
    .EXAMPLE
    $ExternalDrive = Select-ExportTargetDisk
    #>
    [CmdletBinding()]
    param ()
    
    $Volumes = (Get-Volume | Select-Object -Property DriveLetter, FileSystemLabel, FileSystemType, Size, SizeRemaining, DriveType)

    Write-Host @"
Available volumes:
$($Volumes | Format-Table -AutoSize | Out-String)
Please enter the drive letter of the disk you would like to export drivers to:
"@

    $ExternalDrive = Read-Host "External drive letter (e.g., E:)"

    # if drive letter does not end with a colon, append it
    if ($ExternalDrive -notlike "*:") {
        $ExternalDrive += ":"
    }

    return $ExternalDrive

  }

  function Initialize-ExportPath {
    <#
    .SYNOPSIS
    Validate that the selected export path exists and create it if it does not.

    .DESCRIPTION
    This function validates the export path for driver export, ensuring that it exists or creating it if necessary.
    If the directory already exists, it prompts the user for confirmation to overwrite it.

    .PARAMETER ExternalDrive
    The drive letter of the external drive where drivers will be exported. Provided by Select-ExportTargetDisk.

    .PARAMETER Directory
    The directory where drivers will be exported. In my case, this is ".drivers".

    .PARAMETER Model
    The model name of the machine, used to find and/or create a subdirectory to use for the driver export.

    .EXAMPLE
    $DriverPath = Initialize-ExportPath -ExternalDrive "D:" -Directory ".drivers" -Model "OptiPlex 9020"
    #>
    [CmdletBinding()]
    [OutputType([string])]
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

    $ExternalDrive = (Select-ExportTargetDisk)

    $DriverPath = (Initialize-ExportPath -ExternalDrive $ExternalDrive -Directory ".drivers" -Model $Model)

    if (-not (Test-Path $DriverPath 2> $null)) {

      Write-Error "Export path validation failed. Terminating script."
      return

    }

    Write-Host "Exporting drivers from Windows image to $($DriverPath). This may take a while."

    # export drivers from the online Windows image to the specified path
    Export-WindowsDriver -Online -Destination $DriverPath -ErrorAction Stop

    Write-Host "Driver export completed. Drivers have been exported from the online image to '$($DriverPath)'." -ForegroundColor Green
  
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
      Write-Host "Transcript moved to '$($DriverPath)\$(($TranscriptPath -split '\\')[-1])'." -ForegroundColor Green

      Write-Host "Cleanup complete." -ForegroundColor Green

    }
    
  }

}

Export-Drivers
