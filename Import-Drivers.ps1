# this script was originally authored by
# seton at carmichaelcomputing.com, many thanks to him for the original code

<#
.SYNOPSIS
Search for driver files for a machine's model
in a .drivers directory at the root of mounted drives.

.INPUTS
$Model:
  the machine's Win32_ComputerSystem.Model identifier, e.g. '21G2002CUS'
  or 'Dell Pro 16 PC16250' This is the directory that the function
  will search for in the .drivers directory.

.OUTPUTS
$DriverFiles:
  .inf children of located system model driver directory, if found
  $false, if not found.

$DriverDirectoryRoot:
  the PATH to .drivers at the root of a system drive, if found
  $false, if not found.

.DESCRIPTION
Searches for .drivers\MachineModel (e.g. .drivers\21G2002CUS) directory at the
root of all system drives. This directory will have been previously populated
with drivers by the Export-Drivers.ps1 script distributed in the same repository.

Returns objects pertaining to the driver files found in the model's directory,
and the discovered .drivers directory itself (e.g. D:\.drivers or
D:\.drivers\Dell Pro 16 PC16250, whichever is available).

The directory is used to move the execution log (transcript) to the removable disk.

e.g.:

PS C:\WINDOWS\system32> $DriverFiles | Select FullName

FullName
--------
D:\.drivers\Dell Pro 16 PC16250\alderlakedmasecextension.inf_amd64_f0d7eea44ed4e421\AlderLakeDmaSecExtension.inf
D:\.drivers\Dell Pro 16 PC16250\alderlakepch-ndmasecextension.inf_amd64_c1a7e34728e428a8\AlderLakePCH-NDmaSecExtensi...
D:\.drivers\Dell Pro 16 PC16250\alderlakepch-nsystem.inf_amd64_23100d9890c77cd8\AlderLakePCH-NSystem.inf
D:\.drivers\Dell Pro 16 PC16250\alderlakepch-nsystemnorthpeak.inf_amd64_5300f2fe1668d958\AlderLakePCH-NSystemNorthpe...
D:\.drivers\Dell Pro 16 PC16250\alderlakepch-pdmasecextension.inf_amd64_c26ba4a8cd64b537\AlderLakePCH-PDmaSecExtensi...
D:\.drivers\Dell Pro 16 PC16250\alderlakepch-psystem.inf_amd64_c27bc8858e991c72\AlderLakePCH-PSystem.inf

.EXAMPLE
$DriverFiles, $DriverDirectory = Get-DriverFiles -Model 'Dell Pro 16 PC16250'
#>
function Get-DriverFiles {
  param (
    [Parameter(Mandatory = $true)]
    [string]$Model
  )
  
  # Search for .drivers directory at the root of all filesystem PS drives
  $DriverDirectoryRoot = (
    Get-PSDrive -PSProvider FileSystem | ForEach-Object {

      $RootPath = "$($_.Root).drivers"

      if (Test-Path $RootPath) {
        $RootPath
      }

    } | Select-Object -First 1
  )

  if ($DriverDirectoryRoot) {

    Write-Host "Found .drivers directory at: $DriverDirectoryRoot"
    
    # Look for a Directory matching the exact model number (case-insensitive)
    $DriverDirectory = (
      Get-ChildItem -Path $DriverDirectoryRoot | 
        Where-Object {
          $_.PSIsContainer -and (
            $_.Name -like "$($Model)*" -or
            $_.Name -eq $Model
          )
        } | 
        Select-Object -First 1
    )

    if ($DriverDirectory) {

      Write-Host "Found driver directory for model '$($Model)': $($DriverDirectory.FullName)"

      $DriverFiles = Get-ChildItem -Path $DriverDirectory.FullName -Recurse -Include "*.inf"

      if ($DriverFiles) {
        
        return $DriverFiles, $DriverDirectory

      } else {

        Write-Error "No driver files (.inf) found in $($DriverDirectory.FullName). Execution cannot continue."

        return $false, $DriverDirectory

      }

    } else {

      Write-Error "No directory for device model '$($Model)' found at $($DriverDirectoryRoot). Execution cannot continue."
      
      return $false, $DriverDirectoryRoot

    }

  } else {

    Write-Error "No '.drivers' directory found at the root of drives on this system. Execution cannot continue."

    return $false, $false

  }

}

<#
.SYNOPSIS
Install an array of .infs with pnputil.

.INPUTS
Object[] $DriverFiles:
  Output from Get-Drivers or Get-ChildItem -Recurse -Include "*.inf" -
  an array of System.IO.FileSystemInfo objects pointing to driver .inf
  files to be installed.

.OUTPUTS
$SuccessCount:
  The total number of drivers successfully installed with pnputil.

$FailureCount:
  The total number of drivers that pnputil failed to install.

.DESCRIPTION
Simple wrapper to install .inf files passed via an array of FileInfo objects
produced by G-CItem by calling pnputil. Counts success and failures.
#>
function Install-Drivers {
  param (
    [Parameter(Mandatory = $true)]
    [Object[]]$DriverFiles
  )
        
  $TotalDrivers = $DriverFiles.Count
  $CurrentDriver, $SuccessCount, $FailureCount = 0, 0, 0

  foreach ($DriverFile in $DriverFiles) {

    $CurrentDriver++

    try {
        
      Write-Host "($CurrentDriver/$TotalDrivers) Installing driver: $($DriverFile.FullName)"
      
      # cannot use Add-WindowsDriver here as it does not support online installation
      $Result = & pnputil.exe /add-driver "$($DriverFile.FullName)" /install
      
      if ($Result -match "Failed") {

          $FailureCount++
          Write-Host "Failed to install driver: $($DriverFile.Name)"

      } else {

          $SuccessCount++
          Write-Host "Successfully installed driver: $($DriverFile.Name)"

      }

    } catch {

      $FailureCount++
      Write-Host "Error installing driver: $($_.Exception.Message)"

    }

  }

  return $SuccessCount, $FailureCount

}

# get the system model, manufacturer, and serial number
# model will be used to search for the driver directory
# mfg, s/n will be used to label execution log
$Model = (Get-CimInstance -Class Win32_ComputerSystem).Model
$Manufacturer = (Get-CimInstance -Class Win32_ComputerSystem).Manufacturer
$SerialNumber = (Get-CimInstance -Class Win32_BIOS).SerialNumber

# create an identifiable transcript
$TranscriptPath = "$($env:TEMP)\driver-import-$($Manufacturer)-$($Model)-$($SerialNumber)-$(Get-Date -UFormat %s).log"

Start-Transcript -Path $TranscriptPath

$DriverFiles, $DriverDirectory = Get-DriverFiles -Model $Model

if ($DriverFiles) {

  Write-Host "Starting driver installation from directory: $($DriverDirectory.FullName) at $(Get-Date -UFormat %s)"

  $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

  $SuccessCount, $FailureCount = Install-Drivers -DriverFiles $DriverFiles

  $Stopwatch.Stop()

  # this is in Install-Drivers, but it's probably clearer to redefine it here than receive it, too.
  $TotalDrivers = $DriverFiles.Count

  # log details about 'transaction' (god I wish I had dnf) to console and transcript.
  Write-Host @"
Driver import from $($DriverDirectory.FullName) completed at $(Get-Date -UFormat %s)
Duration: $($Stopwatch.Elapsed.TotalSeconds) seconds
Processed $($TotalDrivers) driver(s)
Successfully installed: $SuccessCount
Failed to install: $FailureCount
"@

} else {

  Write-Error "Drivers for system model '$($Model)' were not found and thus cannot be installed. No changes were made."

  $DriverDirectory = $false

}

Stop-Transcript

# if the $DriverDirectory was found by Get-DriverFiles, move the transcript there
# this will drop the transcript in either drive:\.drivers\model or drive:\.drivers
# if model's directory is or is not found.
if ($DriverDirectory) {

  Write-Host "Moving transcript to driver directory at: $($DriverDirectory.FullName)."

  Move-Item -Path $TranscriptPath -Destination $DriverDirectory.FullName

}

Write-Host "Execution completed at $(Get-Date -UFormat %s)."
