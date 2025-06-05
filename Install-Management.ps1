# get and install the latest version of management tools

function Get-RemoteDirectoryListingChildItems {
  param (
    [Parameter(Mandatory = $true)]
    [string]$Uri
  )
  # Download the HTML content
  $html = Invoke-WebRequest -Uri $Uri | Select-Object -ExpandProperty Content

  # Use regex to extract href values from <a> tags (excluding ../)
  [Object[]] $links = [regex]::Matches($html, '<a href="([^"]+)">([^<]+)</a>') |
    Where-Object {
      $_.Groups[1].Value -ne "../"
    } | ForEach-Object {
      [string] $_.Groups[1].Value
    }

  # this is returned as an Object[] and values can be accessed like an array
  return $links

}

Get-RemoteDirectoryListingChildItems -Uri "https://deployment.wporter.org/files/s1/"