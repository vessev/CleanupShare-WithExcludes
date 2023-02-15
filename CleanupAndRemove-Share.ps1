[CmdletBinding()]
param (
[String]$Destination="\\<FileServer>\<ShareFolder>",
[int16]$MaxLogAgeDays=7,
[int16]$MaxFileAgeDays=30,
[Switch]$Remove,
[String]$Logprefix='<Server>-<Folder>-cleanup'
)

begin {
$Script:OutputBodyTXT = $null
$ScriptPath = Split-Path $script:MyInvocation.MyCommand.Path
[DateTime]$DatetoDeleteLog = (get-date).AddDays(-$MaxLogAgeDays)
[DateTime]$DatetoDeleteFiles = (get-date).AddDays(-$MaxFileAgeDays)
[string[]]$PathsToExclude = Get-Content -Path $ScriptPath\PathsToExclude.txt
}
#endregion Begin

process {
# Get all Paths which match your criteria
$Script:Files2 = Get-ChildItem "$Destination" -Recurse -File | Where CreationTime -lt $DatetoDeleteFiles | sort CreationTime

# EXCLUSION 
# Load all Paths/Files which you need to keep
$Files2Keep = $Files2 | Where-Object {
    ForEach($ExcludedPath in $PathsToExclude) {
        If($_.FullName -like $ExcludedPath){Return $true}
    }
}
Write-Host "$Files2Keep"
# Create a list were your Files2Keep are extracted from
$Files2Delete = $Files2 | Where-Object {$_ -notin $Files2Keep}

# Start Remove/Check over Files2Delete
IF ($Remove -eq $true) {
    $Type = "remove"
    # Remove Files older than $MaxFileAgeDays
    $Script:OutputBodyTXT += "The following Files were removed! `r`n"
    $Script:OutputBodyTXT += $Files2Delete | select CreationTime,FullName | Out-String -Width 1024
    $Files2Delete | Remove-Item -Force
    #end File cleanup

    # Remove Empty Folders (Not perfect cause if a folder is deleted a new "empty folder" could be forgotten)
    $Folders2 = Get-ChildItem "$Destination" -Recurse -dir | ?{!$_.GetFileSystemInfos().Count}
    # Get all Folders which you need to keep
    $Folders2Keep = $Folders2 | Where-Object {
        ForEach($ExcludedFolder in $PathsToExclude) {
            If($_.FullName -like $ExcludedFolder){Return $true}
        }
    }
    # Create a list were your Folders2Keep are extracted from
    $Folders2Delete = $Folders2 | Where-Object {$_ -notin $Folders2Keep} 
    $Script:OutputBodyTXT += "The following Empty Folders were removed! `r`n"
    $Script:OutputBodyTXT += $Folders2Delete | select FullName | Out-String -Width 1024
    $Folders2Delete | Remove-Item -Force
    #end Folder cleanup

}   ELSE {
        $Type = "check"
        # Check Files older than $MaxFileAgeDays
        $Script:OutputBodyTXT += "The following Files would be removed if [-Remove] Switch is given! `r`n"
        $Script:OutputBodyTXT += $Files2Delete | select CreationTime,FullName | Out-String -Width 1024
    }
}
#endregion process

end {
# Create Report
$OutputTxtReport = "$ScriptPath\$(get-date -f "yyyy-MM-dd_HH-mm-ss")-$Logprefix-$Type.log"
$OutputBodyTXT | Out-File -FilePath $OutputTxtReport

# Logrotation - delete after specific amount of time.
Get-ChildItem -Path $ScriptPath | Where-Object { $_.CreationTime -lt $DatetoDeleteLog -AND $_.name -like "*.log"} | Remove-Item -Recurse -Force
} 
#endregion end