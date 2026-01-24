param(
    [string]$command,
    [string]$arg1,
    [string]$arg2,
    [string]$arg3
)

$ErrorActionPreference = "Stop"

$BASE = "C:\phpvm"
$VERSIONS = "$BASE\versions"
$ACTIVE = "$BASE\php"

New-Item -ItemType Directory -Force -Path $VERSIONS | Out-Null

function usage {
    @"
PHP Version Manager (Windows)

Commands:
  pvm install <version>
  pvm uninstall <version>
  pvm use <version>
  pvm list
  pvm current
  pvm ext enable <extension> [version]     (version defaults to current)
  pvm ext disable <extension> [version]    (version defaults to current)
"@
    exit
}

function Get-CurrentVersion {
    if (Test-Path $ACTIVE) {
        $linkTarget = (Get-Item $ACTIVE).Target
        if ($linkTarget) {
            return Split-Path $linkTarget -Leaf
        }
    }
    return $null
}



function Get-ClosestPHPVersion {
    param(
        [string]$RequestedVersion
    )
    
    try {
        Write-Host "`nFetching available PHP versions from windows.php.net..."
        
        # Get versions from both main releases and archives
        $allVersions = @()
        
        # Get from main releases
        Write-Host "Checking main releases..." -ForegroundColor Cyan
        $mainVersions = Get-VersionsFromReleasesPage -Url "https://windows.php.net/downloads/releases/"
        
        # Get from archives
        Write-Host "Checking archive releases..." -ForegroundColor Cyan
        $archiveVersions = Get-VersionsFromReleasesPage -Url "https://windows.php.net/downloads/releases/archives/"
        
        # Combine and deduplicate
        $allVersions = @($mainVersions + $archiveVersions) | Sort-Object -Unique -Descending
        
        if ($allVersions.Count -eq 0) {
            Write-Host "Could not retrieve version list."
            return $null
        }
        
        # Display recent versions
        Write-Host "`nRecent PHP versions (last 20):" -ForegroundColor Yellow
        $allVersions | Select-Object -First 20 | ForEach-Object { 
            Write-Host "  $_" 
        }
        
        if ($allVersions.Count -gt 20) {
            Write-Host "  ... and $($allVersions.Count - 20) more total versions" -ForegroundColor DarkGray
        }
        
        # Find closest match
        $closestVersion = Find-ClosestVersion -RequestedVersion $RequestedVersion -AvailableVersions $allVersions
        
        return $closestVersion
        
    }
    catch {
        Write-Host "Error fetching version list: $_" -ForegroundColor Red
        return $null
    }
}

function Get-VersionsFromReleasesPage {
    param(
        [string]$Url
    )
    
    $versions = @()
    
    try {
        $page = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
        
        # Extract ALL version patterns - PHP uses different VC versions over time
        $versionPatterns = @(
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-nts-Win32-vs17-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-nts-Win32-vs16-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-nts-Win32-vs15-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-Win32-vs17-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-Win32-vs16-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-Win32-vs15-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)\.zip'  # Generic fallback
        )
        
        foreach ($pattern in $versionPatterns) {
            $matches = [regex]::Matches($page.Content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            foreach ($match in $matches) {
                $versions += $match.Groups[1].Value
            }
        }
        
        return $versions | Sort-Object -Unique -Descending
        
    }
    catch {
        Write-Host "  Warning: Could not access $Url" -ForegroundColor DarkYellow
        return @()
    }
}

function Find-ClosestVersion {
    param(
        [string]$RequestedVersion,
        [string[]]$AvailableVersions
    )
    
    # Try to parse the requested version
    $requestedParts = $RequestedVersion -split '\.'
    
    $bestMatch = $null
    $bestScore = [double]::MaxValue
    
    foreach ($availableVersion in $AvailableVersions) {
        $availableParts = $availableVersion -split '\.'
        
        # Calculate a weighted distance score
        $score = 0
        
        # Compare major, minor, and patch versions with different weights
        for ($i = 0; $i -lt [Math]::Max($requestedParts.Count, $availableParts.Count); $i++) {
            $requestedPart = if ($i -lt $requestedParts.Count -and [int]::TryParse($requestedParts[$i], [ref]$null)) { 
                [int]$requestedParts[$i] 
            }
            else { 0 }
            
            $availablePart = if ($i -lt $availableParts.Count -and [int]::TryParse($availableParts[$i], [ref]$null)) { 
                [int]$availableParts[$i] 
            }
            else { 0 }
            
            # Weight: major=1000, minor=100, patch=1
            $weight = switch ($i) {
                0 { 1000 }  # Major version - most important
                1 { 100 }   # Minor version
                2 { 1 }     # Patch version
                default { 0.1 }
            }
            
            $score += [Math]::Abs($requestedPart - $availablePart) * $weight
        }
        
        # Bonus: Exact match gets best score
        if ($availableVersion -eq $RequestedVersion) {
            $score = -1
        }
        
        # Bonus: Prefer same major version
        if ($requestedParts.Count -gt 0 -and $availableParts.Count -gt 0) {
            if ([int]$requestedParts[0] -eq [int]$availableParts[0]) {
                $score -= 50  # Bonus for same major version
            }
        }
        
        # Update best match if this is closer
        if ($score -lt $bestScore) {
            $bestScore = $score
            $bestMatch = $availableVersion
        }
    }
    
    return $bestMatch
}

function Get-VersionsFromURL {
    param(
        [string]$Url
    )
    
    try {
        $page = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
        
        # Extract version numbers from zip file links
        # Looking for patterns like: php-8.3.1-nts-Win32-vs16-x64.zip
        # or: php-8.3.1-nts-Win32-vs16-x64.zip
        $versionPattern = 'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-nts-Win32-vs16-x64\.zip'
        $matches = [regex]::Matches($page.Content, $versionPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        $versions = @()
        foreach ($match in $matches) {
            $versions += $match.Groups[1].Value
        }
        
        return $versions | Sort-Object -Unique -Descending
        
    }
    catch {
        Write-Host "  Warning: Could not access $Url" -ForegroundColor DarkYellow
        return @()
    }
}


function Normalize-VersionString {
    param(
        [string]$Version
    )
    
    # Remove RC/alpha/beta suffixes for comparison
    # e.g., "8.3.0-RC1" -> "8.3.0"
    $normalized = $Version -replace '-(RC\d+|alpha\d+|beta\d+).*$', ''
    
    # Ensure we have at least 3 parts (major.minor.patch)
    $parts = $normalized -split '\.'
    
    while ($parts.Count -lt 3) {
        $parts += "0"
    }
    
    return $parts -join '.'
}

function Enable-Extension {
    param(
        [string]$ext,
        [string]$version = "current"
    )
    if (-not $version) {
        $version = "current"
    }
    # Handle 'current' keyword
    if ($version -eq "current") {
        $currentVersion = Get-CurrentVersion
        if (-not $currentVersion) {
            Write-Host "No active PHP version. Use 'pvm use <version>' first."
            return
        }
        $version = $currentVersion
        Write-Host "Targeting current active version: $version"
    }

    $iniPath = "C:\phpvm\versions\$version\php.ini";

    if ($version -eq "current") {
        $iniPath = "C:\phpvm\versions\$version\php.ini";
    }
    
    if (-not (Test-Path $iniPath)) {
        Write-Host "PHP version $version not found or php.ini doesn't exist"
        return
    }

    $content = Get-Content $iniPath
    $found = $false

    $newContent = $content | ForEach-Object {
        if ($_ -match "^\s*;?\s*extension\s*=\s*$ext\s*$") {
            $found = $true
            "extension=$ext"
        }
        else {
            $_
        }
    }

    # If extension is not found, add it at the end
    if (-not $found) {
        $newContent += "extension=$ext"
    }

    $newContent | Set-Content $iniPath
    Write-Host "Enabled $ext for PHP $version"
}



    
function Disable-Extension {
    param(
        [string]$ext,
        [string]$version = "current"
    )

    if (-not $version) {
        $version = "current"
    }
    
    # Handle 'current' keyword
    if ($version -eq "current") {
        $currentVersion = Get-CurrentVersion
        if (-not $currentVersion) {
            Write-Host "No active PHP version. Use 'pvm use <version>' first."
            return
        }
        $version = $currentVersion
        Write-Host "Targeting current active version: $version"
    }

    $iniPath = "C:\phpvm\versions\$version\php.ini";

    if ($version -eq "current") {
        $iniPath = "C:\phpvm\versions\$version\php.ini";
    }
    
    if (-not (Test-Path $iniPath)) {
        Write-Host "PHP version $version not found or php.ini doesn't exist"
        return
    }

    $content = Get-Content $iniPath

    $newContent = $content | ForEach-Object {
        if ($_ -match "^\s*;?\s*extension\s*=\s*$ext\s*$") {
            # Comment out the extension
            if ($_ -match "^extension\s*=\s*$ext") {
                ";extension=$ext"
            }
            else {
                $_
            }
        }
        else {
            $_
        }
    }

    $newContent | Set-Content $iniPath
    Write-Host "Disabled $ext for PHP $version"
}

if (-not $command) { usage }

switch ($command) {
    "install" {
        $version = $arg1
        if (-not $version) { Write-Host "Version required"; exit }

        $target = "$VERSIONS\$version"
        if (Test-Path $target) {
            Write-Host "PHP $version already installed"
            exit
        }

        $zip = "$env:TEMP\php-$version.zip"
    
        # Try multiple URL patterns since PHP uses different VC versions
        $urlPatterns = @(
            "https://windows.php.net/downloads/releases/php-$version-nts-Win32-vs17-x64.zip",
            "https://windows.php.net/downloads/releases/php-$version-nts-Win32-vs16-x64.zip",
            "https://windows.php.net/downloads/releases/php-$version-nts-Win32-vs15-x64.zip"
        )
    
        Write-Host "Downloading PHP $version..."
    
        $downloadSuccess = $false
        foreach ($url in $urlPatterns) {
            try {
                Write-Host "Trying: $url" -ForegroundColor DarkGray
                Invoke-WebRequest -Uri $url -OutFile $zip
                $downloadSuccess = $true
                Write-Host "Download successful!" -ForegroundColor Green
                break
            }
            catch {
                # Continue to next pattern
                continue
            }
        }
    
        if (-not $downloadSuccess) {
            Write-Host "Release not found in main releases, trying archive..."
        
            # Try archive with multiple patterns
            $urlPatterns = @(
                "https://windows.php.net/downloads/releases/archives/php-$version-nts-Win32-vs17-x64.zip",
                "https://windows.php.net/downloads/releases/archives/php-$version-nts-Win32-vs16-x64.zip",
                "https://windows.php.net/downloads/releases/archives/php-$version-nts-Win32-vs15-x64.zip"
            )
        
            $archiveSuccess = $false
            foreach ($url in $urlPatterns) {
                try {
                    Write-Host "Trying archive: $url" -ForegroundColor DarkGray
                    Invoke-WebRequest -Uri $url -OutFile $zip
                    $archiveSuccess = $true
                    Write-Host "Download successful from archive!" -ForegroundColor Green
                    break
                }
                catch {
                    continue
                }
            }
        
            if (-not $archiveSuccess) {
                Write-Host "`nPHP version $version not found!"
            
                # Get available versions and suggest closest match
                $suggestedVersion = Get-ClosestPHPVersion -RequestedVersion $version
                if ($suggestedVersion) {
                    Write-Host "Did you mean: PHP $suggestedVersion ?"
                    Write-Host "Run: pvm install $suggestedVersion"
                }
                else {
                    Write-Host "No PHP versions found. Check available versions at:"
                    Write-Host "https://windows.php.net/download/"
                }
                exit 1
            }
        }

        Write-Host "Extracting..."
        Expand-Archive -Force $zip -DestinationPath $target
        Remove-Item $zip

        # Create php.ini if not present
        $iniPath = "$target\php.ini"
        if (-not (Test-Path $iniPath)) {
            $prodIni = "$target\php.ini-production"
            $devIni = "$target\php.ini-development"
        
            if (Test-Path $prodIni) {
                Copy-Item $prodIni $iniPath
            }
            elseif (Test-Path $devIni) {
                Copy-Item $devIni $iniPath
            }
        }

        Write-Host "Installed PHP $version"
    }



    "uninstall" {
        $version = $arg1
        if (-not $version) { Write-Host "Version required"; exit }

        $target = "$VERSIONS\$version"
        if (-not (Test-Path $target)) {
            Write-Host "PHP $version is not installed"
            exit
        }

        # If this version is currently active, remove the active symlink first
        if (Test-Path $ACTIVE) {
            $linkTarget = (Get-Item $ACTIVE).Target
            if ($linkTarget -eq $target) {
                cmd /c rmdir $ACTIVE
            }
        }

        Remove-Item -Recurse -Force $target
        Write-Host "Uninstalled PHP $version"
    }

    "use" {
        $version = $arg1
        if (-not $version) { Write-Host "Version required"; exit }

        $target = "$VERSIONS\$version"
        if (-not (Test-Path $target)) {
            Write-Host "PHP $version not installed"
            exit
        }

        if (Test-Path $ACTIVE) {
            cmd /c rmdir $ACTIVE
        }

        cmd /c mklink /J $ACTIVE $target | Out-Null

        Write-Host "Now using PHP $version"
        php -v
    }

    "list" {
        Write-Host "Installed PHP versions:"
        Get-ChildItem $VERSIONS -Directory | ForEach-Object {
            Write-Host " - $($_.Name)"
        }
    }

    "current" {
        if (Test-Path $ACTIVE) {
            php -v
        }
        else {
            Write-Host "No active PHP version"
        }
    }

    "ext" {
        $action = $arg1
        $ext = $arg2
        $version = $arg3
        
        if ($action -eq "enable") {
            if (-not $ext) {
                Write-Host "Usage: pvm ext enable <extension> [version]"
                Write-Host "       Version is optional and defaults to current active version"
                exit
            }
            Enable-Extension -ext $ext -version $version
        }
        elseif ($action -eq "disable") {
            if (-not $ext) {
                Write-Host "Usage: pvm ext disable <extension> [version]"
                Write-Host "       Version is optional and defaults to current active version"
                exit
            }
            Disable-Extension -ext $ext -version $version
        }
        else {
            Write-Host "Usage: pvm ext enable <extension> [version]"
            Write-Host "       pvm ext disable <extension> [version]"
            Write-Host ""
            Write-Host "Examples:"
            Write-Host "  pvm ext enable curl              # Enable for current version"
            Write-Host "  pvm ext disable xdebug           # Disable for current version"
            Write-Host "  pvm ext enable mbstring 8.2.15   # Enable for specific version"
            Write-Host "  pvm ext disable opcache 8.3.2    # Disable for specific version"
        }
    }

    default { usage }
}