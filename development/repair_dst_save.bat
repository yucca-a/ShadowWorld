@echo off
setlocal DisableDelayedExpansion
set "DST_REPAIR_SCRIPT=%~f0"
set "DST_REPAIR_INPUT=%~1"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -Command "$s=[IO.File]::ReadAllText($env:DST_REPAIR_SCRIPT); $body=[regex]::Split($s,'(?m)^# DST REPAIR PAYLOAD\r?$'); & ([scriptblock]::Create($body[1]))"
set "DST_REPAIR_STATUS=%ERRORLEVEL%"
if /i not "%~2"=="/nopause" pause
exit /b %DST_REPAIR_STATUS%
# DST REPAIR PAYLOAD
$ErrorActionPreference = 'Stop'
$bytes = [Text.Encoding]::GetEncoding(28591)
$sessionPattern = '[0-9A-F]{16}'
$translationBlock = '(?m)(^[ \t]*\["workshop-3597225156"\]\s*=\s*\{\s*configuration_options\s*=\s*\{\s*\}\s*,\s*enabled\s*=\s*)(true|false)(?=\s*\})'
$translationError = 'MOD ERROR: workshop-3597225156[^\r\n]*\r?\n\[string "[^\r\n]*workshop-3597225156[^\r\n]*\]:355: attempt to compare number with nil'

function Read-BytesAsText($Path) {
    $bytes.GetString([IO.File]::ReadAllBytes($Path))
}

function Copy-SaveDirectory($From, $To) {
    [IO.Directory]::CreateDirectory($To) | Out-Null
    foreach ($entry in Get-ChildItem -LiteralPath $From -Force) {
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Linked path in source: $($entry.FullName)"
        }
        $destination = Join-Path $To $entry.Name
        if ($entry.PSIsContainer) {
            Copy-SaveDirectory $entry.FullName $destination
        } else {
            [IO.File]::Copy($entry.FullName, $destination)
        }
    }
}

function Expand-SaveArchive($From, $To) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($From)
    try {
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName
            $key = $name.TrimEnd('/')
            if ($name -match '[\\:<>"|?*\x00-\x1f]' -or
                $key -match '(?i)(^|/)(?:[ .]*|[^/]*[ .]|(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.[^/]*)?)(/|$)' -or
                -not $seen.Add($key)) {
                throw "Unsafe or duplicate archive entry: $name"
            }
        }
        [IO.Compression.ZipFileExtensions]::ExtractToDirectory($archive, $To)
    } finally {
        $archive.Dispose()
    }
}

function Find-Snapshots($Shard, $Current) {
    $sessions = Join-Path $Shard 'save\session'
    $directories = Get-ChildItem -LiteralPath $sessions -Directory -Force |
        Where-Object { $_.Name -cmatch "^$sessionPattern$" -and (!$Current -or $_.Name -ceq $Current) }
    $candidates = @(
        foreach ($folder in $directories) {
            $snapshot = Get-ChildItem -LiteralPath $folder.FullName -File -Force |
                Where-Object {
                    $_.Name -cmatch '^\d{10}$' -and $_.Length -gt 0 -and
                    [IO.File]::Exists($_.FullName + '.meta') -and
                    [IO.FileInfo]::new($_.FullName + '.meta').Length -gt 0
                } | Sort-Object Name -Descending | Select-Object -First 1
            if ($snapshot) {
                [pscustomobject]@{ Session = $folder.Name; Snapshot = $snapshot.Name }
            }
        }
    )
    if ($candidates.Count -ne 1) {
        throw "$Shard needs exactly one session with complete world snapshots."
    }
    $candidates[0]
}

function Test-SessionLog($Shard, $Session) {
    $paths = @((Join-Path $Shard 'server_log.txt'))
    $backup = Join-Path $Shard 'backup\server_log'
    if ([IO.Directory]::Exists($backup)) {
        $paths += @(Get-ChildItem -LiteralPath $backup -Filter '*.txt' -File | ForEach-Object FullName)
    }
    foreach ($path in $paths) {
        if (![IO.File]::Exists($path)) { continue }
        $loading = $null
        $reader = [IO.File]::OpenText($path)
        try {
            while ($null -ne ($line = $reader.ReadLine())) {
                if ($line -cmatch "Loading world: session/($sessionPattern)/[0-9]{10}\b") {
                    $loading = $Matches[1]
                } elseif ($line -cmatch "Begin Session: ($sessionPattern)\b") {
                    if ($loading -ceq $Session -and $Matches[1] -ceq $Session) { return $true }
                    $loading = $null
                }
            }
        } finally {
            $reader.Dispose()
        }
    }
    return $false
}

function Disable-Translation($Text, $Path) {
    $mentions = [regex]::Matches($Text, '\["workshop-3597225156"\]').Count
    if ($mentions -eq 0) { return $Text }
    if ($mentions -ne 1 -or [regex]::Matches($Text, $translationBlock).Count -ne 1) {
        throw "Unsupported translation mod entry in $Path."
    }
    [regex]::Replace($Text, $translationBlock, '${1}false')
}

function Repair-Shard($Shard, $DisableCn) {
    $index = Join-Path $Shard 'save\shardindex'
    $original = Read-BytesAsText $index
    if (!$original.StartsWith('KLEI     1 return {') -or $original -cnotmatch '(?m)^  version=5,\r?$') {
        throw "Unsupported shardindex format in $Shard."
    }
    $id = [regex]::Matches($original, ('(?m)^  session_id="(' + $sessionPattern + ')",[ \t]*\r?$'))
    if ($id.Count -gt 1 -or $id.Count -ne [regex]::Matches($original, '(?m)^  session_id\s*=').Count) {
        throw "Invalid session ID field in $Shard."
    }
    $current = if ($id.Count) { $id[0].Groups[1].Value }
    $found = Find-Snapshots $Shard $current
    $repaired = $original
    $action = 'ID verified'
    if (!$current) {
        if (!(Test-SessionLog $Shard $found.Session)) {
            throw "No successful startup log confirms $($found.Session) in $Shard."
        }
        $worldField = '(?m)^  world=\{'
        if ([regex]::Matches($original, $worldField).Count -ne 1) {
            throw "Unsupported world field in $Shard."
        }
        $newline = if ($original.Contains("`r`n")) { "`r`n" } else { "`n" }
        $repaired = [regex]::Replace($original, $worldField, ('  session_id="' + $found.Session + '",' + $newline + '  world={'))
        $action = 'missing ID restored'
    }
    if ($DisableCn) {
        $repaired = Disable-Translation $repaired $index
        $override = Join-Path $Shard 'modoverrides.lua'
        if ([IO.File]::Exists($override)) {
            $config = Read-BytesAsText $override
            $changed = Disable-Translation $config $override
            if ($changed -cne $config) { [IO.File]::WriteAllBytes($override, $bytes.GetBytes($changed)) }
        }
    }
    if ($repaired -cne $original) { [IO.File]::WriteAllBytes($index, $bytes.GetBytes($repaired)) }
    Write-Host "$(Split-Path -Leaf $Shard): $($found.Session), snapshot $($found.Snapshot), $action"
}

$staging = $null
try {
    $inputPath = $env:DST_REPAIR_INPUT
    if (!$inputPath) {
        Write-Host 'Stop the game and both server shards before copying a live save folder.'
        $inputPath = Read-Host 'Enter the cluster ZIP or folder path'
    }
    $source = Get-Item -LiteralPath $inputPath.Trim().Trim('"') -Force
    if ($source.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Choose the actual save, not a linked path.' }
    if (!$source.PSIsContainer -and $source.Extension -ine '.zip') { throw 'Choose a cluster ZIP or folder.' }
    $parent = Split-Path -Parent $source.FullName
    $base = if ($source.PSIsContainer) { $source.Name } else { $source.BaseName }
    $output = Join-Path $parent ($base + '_recovered')
    if (Test-Path -LiteralPath $output) { throw "Output already exists: $output" }

    $staging = Join-Path $parent ('.dst-repair-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($staging) | Out-Null
    $cluster = Join-Path $staging 'cluster'
    if ($source.PSIsContainer) {
        Copy-SaveDirectory $source.FullName $cluster
    } else {
        Expand-SaveArchive $source.FullName $cluster
        if (![IO.File]::Exists((Join-Path $cluster 'cluster.ini'))) {
            $roots = @(Get-ChildItem -LiteralPath $cluster -Directory -Force |
                Where-Object { [IO.File]::Exists((Join-Path $_.FullName 'cluster.ini')) })
            if ($roots.Count -ne 1) { throw 'Expected exactly one cluster in the ZIP.' }
            $cluster = $roots[0].FullName
        }
    }

    $ini = Join-Path $cluster 'cluster.ini'
    if (![IO.File]::Exists($ini)) { throw 'Missing cluster.ini. Choose the complete cluster.' }
    $shards = @((Join-Path $cluster 'Master'))
    $caves = Join-Path $cluster 'Caves'
    if ([IO.Directory]::Exists($caves)) {
        $shards += $caves
    } elseif ((Read-BytesAsText $ini) -match '(?m)^\s*shard_enabled\s*=\s*true\s*$') {
        throw 'The cluster uses shards but Caves is missing.'
    }
    $disableCn = $false
    foreach ($shard in $shards) {
        $log = Join-Path $shard 'server_log.txt'
        if ([IO.File]::Exists($log) -and (Read-BytesAsText $log) -match $translationError) {
            $disableCn = $true
        }
    }
    foreach ($shard in $shards) { Repair-Shard $shard $disableCn }

    [IO.Directory]::Move($cluster, $output)
    if ($disableCn) { Write-Host 'Disabled beta Chinese translation mod 3597225156 in the copy due to its logged line 355 startup error.' }
    Write-Host "Recovered copy: $output"
} catch {
    Write-Host "Recovery stopped: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    if ($staging -and [IO.Directory]::Exists($staging)) {
        $resolved = (Resolve-Path -LiteralPath $staging).ProviderPath
        if ((Split-Path -Parent $resolved) -ieq $parent -and (Split-Path -Leaf $resolved) -cmatch '^\.dst-repair-[a-f0-9]{32}$') {
            Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Continue
        }
    }
}
