# WindowsInstallScripts

Scripts for managing drivers, software and Windows images for/during
Windows workstation installation/setup process.

## Credits

Thanks for Seton Carmichael (seton at carmichaelcomputing.com) for the idea of
pulling drivers from the OEM image to a Ventoy disk and the driver import script.

## Usage

### Driver management

#### Export drivers from a Windows image

Copy the Export-Drivers.ps1 script to accessible media of some kind.
You will need to run this from your new system.

Boot the OEM installation of your Windows system to Audit Mode
by pressing CTRL + SHIFT + F3.

Mount a drive that the script can write .drivers and $Model directories to
on the new system.

I use the wonderful [Ventoy, by longpanda](https://github.com/ventoy/Ventoy)
on NVME SSDs in USB 3.x enclosures for my multitool USB disks; this means
that I'm able to write my .drivers, some portable apps, and scripts
to the same drives I have 100+gb of ISOs on. Highly recommended.

This is roughly what my Ventoy drives look like:

```PowerShell
E:\
❯ gci

    Directory: E:\

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----            6/4/2025  7:56 PM                .drivers
d----            6/4/2025  8:11 PM                portableapps
d----            6/4/2025  8:04 PM                scripts
d----           5/24/2025  2:07 AM                Windows7-ThinkStationE32
-a---           4/21/2025  9:12 PM     7090688000 22000.3260.241003-0908.CO_RELEASE_SVC_PROD1_CLIENTPRO_OEMRET_X64FRE_E
                                                  N-US.ISO
# snip - lots of ISOs
```

From Audit Mode, run the script.
You will need to adjust your ExecutionMode first.

I'll be running it from my external drive's `scripts` directory.

Follow the prompts on screen to select a drive to export your `.inf`(s) to.

```PowerShell
Administrator in ~
❯ Set-ExecutionPolicy Unrestricted -Scope Process

Administrator in ~
❯ E:\scripts\Export-Drivers.ps1
System model detected: '21G2002CUS'.
Available Volumes:

DriveLetter FileSystemLabel FileSystemType          Size SizeRemaining DriveType
----------- --------------- --------------          ---- ------------- ---------
          D Data            ReFS            549688705024  203551711232 Fixed
                            FAT32              268435456     233246720 Fixed
          E Ventoy          exFAT           256017956864  172701384704 Fixed
          F VTOYEFI         FAT                 33277440           512 Fixed
                            NTFS               718270464     114454528 Fixed
          C                 NTFS           1023199408128   96016478208 Fixed


Please enter the drive letter for the target disk for driver export:
External drive letter (e.g., E:): E
Directory 'E:\.drivers\21G2002CUS' already exists. Do you want to overwrite it? (Y/N): y
Removing existing directory 'E:\.drivers\21G2002CUS'.
Creating model directory 'E:\.drivers\21G2002CUS'...
Path 'E:\.drivers\21G2002CUS' created successfully.
Exporting drivers from Windows image to E:\.drivers\21G2002CUS. This may take a while.
```

Once complete, the `.drivers` directory on your chosen disk
will be populated with a new `$Model` directory and some drivers.

Here's what the `.drivers` directory looks like, with a few models in it:

```PowerShell
E:\
❯ gci .drivers

    Directory: E:\.drivers

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----            6/4/2025  7:57 PM                21G2002CUS
d----            6/4/2025 10:15 PM                Dell Pro 16 PC16250
```

#### Import drivers on a running system (post-installation)

To import drivers from an external disk, you can use the aptly-named `Import-Drivers.ps1` script.

To use it, set your execution policy to `Unrestricted` for the current process, then call the script
(from an elevated PowerShell terminal):

```PowerShell
PS C:\WINDOWS\system32> Set-ExecutionPolicy Unrestricted -Scope Process
PS C:\WINDOWS\system32> D:\scripts\Import-Drivers.ps1
```

This requires a .drivers directory on a system disk, with a directory named with the system model
as returned by `(Get-CimInstance Win32_ComputerSystem).Model`.

If the directory is not found, the script will fail with two errors about a directory for the model not being found.

```PowerShellNoHighlighting
PS C:\WINDOWS\system32> D:\scripts\Import-Drivers.ps1
Transcript started, output file is C:\Users\nladmin\AppData\Local\Temp\driver-import-Dell Inc.-Dell Pro 16 PC16250-redacted-1749221259.71894.log
Found .drivers directory at: D:\.drivers
Get-DriverFiles : No directory for device model 'Dell Pro 16 PC16250' found at D:\.drivers. Execution cannot continue.
At D:\scripts\Import-Drivers.ps1:216 char:34
+ $DriverFiles, $DriverDirectory = Get-DriverFiles -Model $Model
+                                  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
    + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,Get-DriverFiles

D:\scripts\Import-Drivers.ps1 : Drivers for system model 'Dell Pro 16 PC16250' were not found and thus cannot be installed. No changes were made.
At line:1 char:1
+ D:\scripts\Import-Drivers.ps1
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
    + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,Import-Drivers.ps1

Transcript stopped, output file is C:\Users\nladmin\AppData\Local\Temp\driver-import-Dell Inc.-Dell Pro 16 PC16250-redacted-1749221259.71894.log
Script execution completed.
```

If the directory is found, but does not have .inf files in it, the script will fail
with an error mentioning that no drivers are available in the model's corresponding driver directory:

```PowerShellNoHighlighting
PS C:\WINDOWS\system32> D:\scripts\Import-Drivers.ps1
Transcript started, output file is C:\Users\nladmin\AppData\Local\Temp\driver-import-Dell Inc.-Dell Pro 16 PC16250-9YXK494-1749224394.2804.log
Found .drivers directory at: D:\.drivers
Found driver directory for model 'Dell Pro 16 PC16250': D:\.drivers\Dell Pro 16 PC16250
Get-DriverFiles : No driver files (.inf) found in D:\.drivers\Dell Pro 16 PC16250. Execution cannot continue.
At D:\scripts\Import-Drivers.ps1:200 char:34
+ $DriverFiles, $DriverDirectory = Get-DriverFiles -Model $Model
+                                  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
    + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,Get-DriverFiles

D:\scripts\Import-Drivers.ps1 : Drivers for system model 'Dell Pro 16 PC16250' were not found and thus cannot be installed. No changes were made.
At line:1 char:1
+ D:\scripts\Import-Drivers.ps1
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
    + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,Import-Drivers.ps1

Transcript stopped, output file is C:\Users\nladmin\AppData\Local\Temp\driver-import-Dell Inc.-Dell Pro 16 PC16250-9YXK494-1749224394.2804.log
Execution completed at 1749224394.47072.
```

If the directory is found, and has .inf files in it, the script will install all available `.inf` files with pnputil:

```PowerShellNoHighlighting
PS C:\WINDOWS\system32> D:\scripts\Import-Drivers.ps1
Transcript started, output file is C:\Users\nladmin\AppData\Local\Temp\driver-import-Dell Inc.-Dell Pro 16 PC16250-SERIAL-1749224113.66399.log
Found .drivers directory at: D:\.drivers
Found driver directory for model 'Dell Pro 16 PC16250': D:\.drivers\Dell Pro 16 PC16250
Starting driver installation from directory: D:\.drivers\Dell Pro 16 PC16250 at 1749224113.75985
(1/271) Installing driver: D:\.drivers\Dell Pro 16 PC16250\alderlakedmasecextension.inf_amd64_f0d7eea44ed4e421\AlderLakeDmaSecExtension.inf
Successfully installed driver: AlderLakeDmaSecExtension.inf
(2/271) Installing driver: D:\.drivers\Dell Pro 16 PC16250\alderlakepch-ndmasecextension.inf_amd64_c1a7e34728e428a8\AlderLakePCH-NDmaSecExtension.inf
Successfully installed driver: AlderLakePCH-NDmaSecExtension.inf
(3/271) Installing driver: D:\.drivers\Dell Pro 16 PC16250\alderlakepch-nsystem.inf_amd64_23100d9890c77cd8\AlderLakePCH-NSystem.inf
Successfully installed driver: AlderLakePCH-NSystem.inf
### snip ###
(270/271) Installing driver: D:\.drivers\Dell Pro 16 PC16250\wavesapo14de.inf_amd64_1525f9780cefa3f6\WavesAPO14De.inf
Successfully installed driver: WavesAPO14De.inf
(271/271) Installing driver: D:\.drivers\Dell Pro 16 PC16250\wavesapo14de_sc.inf_amd64_f361b9bb92dd7a31\WavesAPO14De_SC.inf
Successfully installed driver: WavesAPO14De_SC.inf
Driver import from D:\.drivers\Dell Pro 16 PC16250 completed at 1749224124.63893
Duration: 10.8859983 seconds
Processed 271 driver(s)
Successfully installed: 271
Failed to install: 0
Transcript stopped, output file is C:\Users\nladmin\AppData\Local\Temp\driver-import-Dell Inc.-Dell Pro 16 PC16250-SERIAL-1749224113.66399.log
Moving transcript to driver directory at: D:\.drivers\Dell Pro 16 PC16250.
Execution completed at 1749224124.77176.
```
