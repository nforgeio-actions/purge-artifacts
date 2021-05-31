#Requires -Version 7.0 -RunAsAdministrator
#------------------------------------------------------------------------------
# FILE:         action.ps1
# CONTRIBUTOR:  Jeff Lill
# COPYRIGHT:    Copyright (c) 2005-2021 by neonFORGE LLC.  All rights reserved.
#
# The contents of this repository are for private use by neonFORGE, LLC. and may not be
# divulged or used for any purpose by other organizations or individuals without a
# formal written and signed agreement with neonFORGE, LLC.

# Verify that we're running on a properly configured neonFORGE GitHub runner 
# and import the deployment and action scripts from neonCLOUD.

# NOTE: This assumes that the required [$NC_ROOT/Powershell/*.ps1] files
#       in the current clone of the repo on the runner are up-to-date
#       enough to be able to obtain secrets and use GitHub Action functions.
#       If this is not the case, you'll have to manually pull the repo 
#       first on the runner.

$ncRoot = $env:NC_ROOT
$naRoot = $env:NA_ROOT

if ([System.String]::IsNullOrEmpty($ncRoot) -or ![System.IO.Directory]::Exists($ncRoot))
{
    throw "Runner Config: neonCLOUD repo is not present."
}

$ncPowershell = [System.IO.Path]::Combine($ncRoot, "Powershell")

Push-Location $ncPowershell | Out-Null
. ./includes.ps1
Pop-Location | Out-Null

try
{
    # Here's what we're going to do:
    #
    #   1. Pull the artifacts repo
    #   2. Read the [setting-retention-days] file
    #   3. List all of the files in the repo and delete any that are too old
    #   4. Push the repo if we actually deleted anything

    Push-Cwd $naRoot | Out-Null

        Invoke-CaptureStreams "git reset --quiet --hard" | Out-Null
        Invoke-CaptureStreams "git fetch --quiet" | Out-Null
        Invoke-CaptureStreams "git checkout --quiet master" | Out-Null    
        Invoke-CaptureStreams "git pull --quiet" | Out-Null

        $retentionDaysPath = [System.IO.Path]::Combine($naRoot, "setting-retention-days")
        $retentionDays     = [int][System.IO.File]::ReadAllText($retentionDaysPath).Trim()
        $utcNow            = [System.DateTime]::UtcNow
        $minRetainTime     = $utcNow.Date - $(New-TimeSpan -Days $retentionDays)
        $timestampRegex    = [regex]'^\d\d\d\d-\d\d-\d\dT\d\d_\d\d_\d\dZ.*'
        $artifactsPurged   = 0

        ForEach ($artifactPath in $([System.IO.Directory]::GetFiles($naRoot, "*", "AllDirectories")))
        {
            # Skip files that don't include a timestamp in the name

            $filename = [System.IO.Path]::GetFileName($artifactPath)

            if (!$timestampRegex.IsMatch($filename))
            {
                Continue
            }

            # Extract and parse the timestamp from the file name

            $timestring = $filename.SubString(0, 20)        # Extract the "yyyy-MM-ddThh_mm_ssZ" part
            $timeString = $timeString.Replace("_", ":")     # Convert to: "yyyy-MM-ddThh:mm:ssZ"
            $timestamp  = [System.DateTime]::ParseExact($timeString, "yyyy-MM-ddThh:mm:ssZ", $([System.Globalization.CultureInfo]::InvariantCulture)).ToUniversalTime()

            if ($timestamp -lt $minRetainTime)
            {
                Write-ActionOutput "purging: $artifactPath"
                [System.IO.File]::Delete($artifactPath)
                $artifactsPurged++
            }
        }

        Write-ActionOutput "------------------------------"
        Write-ActionOutput "$artifactsPurged artifacts purged"

        if ($artifactsPurged -gt 0)
        {
            Invoke-CaptureStreams "fit push --quiet"
        }

    Pop-Cwd | Out-Null
}
catch
{
    Write-ActionException $_
    exit 1
}