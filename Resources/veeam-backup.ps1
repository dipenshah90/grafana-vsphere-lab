#requires -Version 3

# Pull in vars
$vars = (Get-Item $PSScriptRoot).Parent.FullName + '\vars.ps1'
Invoke-Expression -Command ($vars)

# Pull in Veeam backup path from the NAS
$nas = "\\nas4\Backups"

# Create arrays for the data points and column names
[System.Collections.ArrayList]$nasdata = @()
[System.Collections.ArrayList]$nascolumns = @()

# Freespace
$nasdata.Add(((cmd /c dir $nas)[-1] -replace '.+?([\d,]+) bytes free','$1' -replace '\D') / 1MB)
$nascolumns.Add("Freespace")

# Check each backup folder for size of the backups

$naspaths = Get-ChildItem -Path $nas

foreach ($naspath in $naspaths)
{
if ($naspath -notmatch "VeeamConfigBackup")
    {
    $files = Get-ChildItem -Path ($nas + "\" + $naspath)
    $nasdata.Add(($files | Measure-Object -Sum Length).Sum / 1GB)
    $nascolumns.Add($naspath.name)
    }
}

# Stick the data points into the null array for required JSON format
[System.Collections.ArrayList]$nullpoints = @()
$nullpoints.Add($nasdata)

# Build the post body
$body = @{}
$body.Add('name',"veeam_backup.veeam1.glacier.local")
$body.Add('columns',$nascolumns)
$body.Add('points',$nullpoints)

# Convert to json
$finalbody = $body | ConvertTo-Json

# Post to API
try 
{
    $r = Invoke-WebRequest -Uri $global:url -Body ('['+$finalbody+']') -ContentType 'application/json' -Method Post -ErrorAction:Stop
    Write-Host -Object "Data for SQL has been posted, status is $($r.StatusCode) $($r.StatusDescription)"        
}
catch 
{
    throw 'Could not POST to InfluxDB API endpoint'
}