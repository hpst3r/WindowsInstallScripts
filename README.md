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
