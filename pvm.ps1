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

function Get-AvailablePHPVersions {
    param(
        [string]$MajorVersionFilter = $null
    )
    
    try {
        Write-Host "`nFetching available PHP versions from windows.php.net..." -ForegroundColor Cyan
        
        # Get versions from both main releases and archives
        $allVersions = @()
        
        # Get from main releases
        Write-Host "Checking main releases..." -ForegroundColor Gray
        $mainVersions = Get-VersionsFromReleasesPage -Url "https://windows.php.net/downloads/releases/"
        
        # Get from archives
        Write-Host "Checking archive releases..." -ForegroundColor Gray
        $archiveVersions = Get-VersionsFromReleasesPage -Url "https://windows.php.net/downloads/releases/archives/"
        
        # Combine and deduplicate
        $allVersions = @($mainVersions + $archiveVersions) | Sort-Object -Unique -Descending
        
        if ($allVersions.Count -eq 0) {
            Write-Host "Could not retrieve version list."
            return @()
        }
        
        Write-Host "Found $($allVersions.Count) total PHP versions" -ForegroundColor Green
        
        # Filter by major version if specified
        if ($MajorVersionFilter) {
            $filteredVersions = $allVersions | Where-Object { $_ -like "$MajorVersionFilter.*" }
            Write-Host "Filtered to $($filteredVersions.Count) PHP $MajorVersionFilter versions" -ForegroundColor Green
            return $filteredVersions
        }
        
        return $allVersions
        
    }
    catch {
        Write-Host "Error fetching version list: $_" -ForegroundColor Red
        return @()
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
            # PHP 8.x patterns
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-nts-Win32-vs17-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-nts-Win32-vs16-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-Win32-vs17-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-Win32-vs16-x64\.zip',
            
            # PHP 7.x patterns (VC15, VC14)
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-nts-Win32-vc15-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-Win32-vc15-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-nts-Win32-vc14-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-Win32-vc14-x64\.zip',
            
            # Older PHP 5.x patterns (VC11, VC9)
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-nts-Win32-VC11-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-Win32-VC11-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-nts-Win32-VC9-x64\.zip',
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)-Win32-VC9-x64\.zip',
            
            # Generic fallback
            'php-(\d+\.\d+\.\d+(?:-(?:RC\d+|alpha\d+|beta\d+))?)\.zip'
        )
        
        foreach ($pattern in $versionPatterns) {
            $matches = [regex]::Matches($page.Content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            foreach ($match in $matches) {
                $version = $match.Groups[1].Value
                # Clean up any remaining file extensions in version string
                $version = $version -replace '\.zip$', ''
                $versions += $version
            }
        }
        
        return $versions | Sort-Object -Unique -Descending
        
    }
    catch {
        Write-Host "  Warning: Could not access $Url" -ForegroundColor DarkYellow
        return @()
    }
}

function Show-AvailableReleases {
    param(
        [string]$RequestedVersion
    )
    
    # Extract major version from requested version
    $majorVersion = $RequestedVersion -replace '^(\d+).*$', '$1'
    
    Write-Host "`nSearching for available PHP $majorVersion releases..." -ForegroundColor Yellow
    
    $availableVersions = Get-AvailablePHPVersions -MajorVersionFilter $majorVersion
    
    if ($availableVersions.Count -eq 0) {
        Write-Host "No PHP $majorVersion releases found." -ForegroundColor Red
        Write-Host "`nAvailable major PHP versions:" -ForegroundColor Cyan
        
        # Show all available major versions
        $allVersions = Get-AvailablePHPVersions
        $majorVersions = $allVersions | ForEach-Object { $_ -replace '^(\d+).*$', '$1' } | Sort-Object -Unique -Descending
        
        foreach ($ver in $majorVersions) {
            $count = ($allVersions | Where-Object { $_ -like "$ver.*" }).Count
            Write-Host "  PHP $ver ($count releases available)"
        }
        return $null
    }
    
    # Display releases for the requested major version
    Write-Host "`nAvailable PHP $majorVersion releases (latest first):" -ForegroundColor Green
    
    $groupedVersions = $availableVersions | Group-Object { $_ -replace '^(\d+\.\d+).*$', '$1' }
    
    foreach ($group in $groupedVersions) {
        $latestMinor = $group.Group | Select-Object -First 1
        Write-Host "`n  $($group.Name) series:" -ForegroundColor Cyan
        $group.Group | Select-Object -First 10 | ForEach-Object {
            $isLatest = ($_ -eq $latestMinor)
            $latestMarker = if ($isLatest) { " [LATEST]" } else { "" }
            Write-Host "    - $_$latestMarker"
        }
        
        if ($group.Group.Count -gt 10) {
            Write-Host "    ... and $($group.Group.Count - 10) more" -ForegroundColor DarkGray
        }
    }
    
    # Suggest the latest stable release in this major version
    $latestStable = $availableVersions | Where-Object { $_ -notmatch 'RC|alpha|beta' } | Select-Object -First 1
    
    if ($latestStable) {
        Write-Host "`nSuggested version: $latestStable" -ForegroundColor Yellow
        Write-Host "Run: pvm install $latestStable" -ForegroundColor Green
    }
    else {
        $latestOverall = $availableVersions | Select-Object -First 1
        if ($latestOverall) {
            Write-Host "`nLatest available: $latestOverall" -ForegroundColor Yellow
            Write-Host "Run: pvm install $latestOverall" -ForegroundColor Green
        }
    }
    
    return $latestStable
}

function Get-PHPUrlPatterns {
    param(
        [string]$version
    )
    
    # Parse the major version
    $majorVersion = [int]($version -split '\.')[0]
    
    $patterns = @()
    
    if ($majorVersion -ge 8) {
        # PHP 8.x uses VS17/VS16
        $patterns = @(
            "https://windows.php.net/downloads/releases/php-$version-nts-Win32-vs17-x64.zip",
            "https://windows.php.net/downloads/releases/php-$version-nts-Win32-vs16-x64.zip",
            "https://windows.php.net/downloads/releases/php-$version-Win32-vs17-x64.zip",
            "https://windows.php.net/downloads/releases/php-$version-Win32-vs16-x64.zip",
            "https://windows.php.net/downloads/releases/archives/php-$version-nts-Win32-vs17-x64.zip",
            "https://windows.php.net/downloads/releases/archives/php-$version-nts-Win32-vs16-x64.zip",
            "https://windows.php.net/downloads/releases/archives/php-$version-Win32-vs17-x64.zip",
            "https://windows.php.net/downloads/releases/archives/php-$version-Win32-vs16-x64.zip"
        )
    }
    elseif ($majorVersion -ge 7) {
        # PHP 7.x uses VC15/VC14
        $patterns = @(
            "https://windows.php.net/downloads/releases/php-$version-nts-Win32-vc15-x64.zip",
            "https://windows.php.net/downloads/releases/php-$version-Win32-vc15-x64.zip",
            "https://windows.php.net/downloads/releases/archives/php-$version-nts-Win32-vc15-x64.zip",
            "https://windows.php.net/downloads/releases/archives/php-$version-Win32-vc15-x64.zip",
            "https://windows.php.net/downloads/releases/php-$version-nts-Win32-vc14-x64.zip",
            "https://windows.php.net/downloads/releases/php-$version-Win32-vc14-x64.zip",
            "https://windows.php.net/downloads/releases/archives/php-$version-nts-Win32-vc14-x64.zip",
            "https://windows.php.net/downloads/releases/archives/php-$version-Win32-vc14-x64.zip"
        )
    }
    else {
        # PHP 5.x uses VC11/VC9
        $patterns = @(
            "https://windows.php.net/downloads/releases/php-$version-nts-Win32-VC11-x64.zip",
            "https://windows.php.net/downloads/releases/php-$version-Win32-VC11-x64.zip",
            "https://windows.php.net/downloads/releases/archives/php-$version-nts-Win32-VC11-x64.zip",
            "https://windows.php.net/downloads/releases/archives/php-$version-Win32-VC11-x64.zip",
            "https://windows.php.net/downloads/releases/php-$version-nts-Win32-VC9-x64.zip",
            "https://windows.php.net/downloads/releases/php-$version-Win32-VC9-x64.zip",
            "https://windows.php.net/downloads/releases/archives/php-$version-nts-Win32-VC9-x64.zip",
            "https://windows.php.net/downloads/releases/archives/php-$version-Win32-VC9-x64.zip"
        )
    }
    
    return $patterns
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


function Set-PhpExtensionState {
    param(
        [Parameter(Mandatory)]
        [string]$Extension,

        [Parameter(Mandatory)]
        [bool]$Enable,

        [string]$Version = "current"
    )

    $paths = @()

    if (-not $Version) {
        $Version = "current"
    }

    if ($Version -eq "current") {
        $resolvedVersion = (Get-CurrentVersion).Trim()

        if ([string]::IsNullOrWhiteSpace($resolvedVersion)) {
            Write-Host "No active PHP version. Use 'pvm use <version>' first."
            return
        }

        $paths += "C:\phpvm\versions\$resolvedVersion\php.ini"
    }
    else {
        $paths += "C:\phpvm\versions\$Version\php.ini"
    }

    foreach ($iniPath in $paths) {
        if (-not (Test-Path $iniPath)) {
            Write-Host "php.ini not found: $iniPath"
            continue
        }

        $content = Get-Content $iniPath
        $found = $false

        $newContent = $content | ForEach-Object {
            # match enabled or commented extension
            if ($_ -match "^\s*;?\s*extension\s*=\s*['""]?$Extension(\.dll)?['""]?") {
                $found = $true

                if ($Enable) {
                    "extension=$Extension"
                }
                else {
                    ";extension=$Extension"
                }
            }
            else {
                $_
            }
        }

        if ($Enable -and -not $found) {
            $newContent += "extension=$Extension"
        }

        $newContent | Set-Content $iniPath -Encoding UTF8

        $state = if ($Enable) { "Enabled" } else { "Disabled" }
        Write-Host "$state $Extension in $iniPath"
    }
}

function Enable-Extension {
    param(
        [Parameter(Mandatory)]
        [string]$ext,
        [string]$version = "current"
    )

    Set-PhpExtensionState -Extension $ext -Enable $true -Version $version
}

function Disable-Extension {
    param(
        [Parameter(Mandatory)]
        [string]$ext,
        [string]$version = "current"
    )

    Set-PhpExtensionState -Extension $ext -Enable $false -Version $version
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
    
        # Get appropriate URL patterns based on PHP version
        $urlPatterns = Get-PHPUrlPatterns -version $version
    
        Write-Host "Downloading PHP $version..."
    
        $downloadSuccess = $false
        foreach ($url in $urlPatterns) {
            try {
                Write-Host "Trying: $url" -ForegroundColor DarkGray
                Invoke-WebRequest -Uri $url -OutFile $zip -TimeoutSec 30
                $downloadSuccess = $true
                Write-Host "Download successful!" -ForegroundColor Green
                break
            }
            catch {
                # Continue to next pattern
                Write-Host "  Not found: $([System.Net.HttpStatusCode] $_.Exception.Response.StatusCode)" -ForegroundColor DarkGray
                continue
            }
        }
    
        if (-not $downloadSuccess) {
            Write-Host "`nPHP exact version ($version) not found!" -ForegroundColor Red
            
            # Check if user requested just a major version (like "8", "7", "5")
            #$isMajorVersion = ($version -match '^\d+$')
            
            # User requested something like "pvm install 8" or "pvm install 7.6.3"
            Show-AvailableReleases -RequestedVersion $version

            exit 1
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
        & $MyInvocation.MyCommand.Path list
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
        
        # Optionally show available versions too
        Write-Host "`nTo see available PHP versions for installation, use:"
        Write-Host "  pvm install <major-version>" -ForegroundColor Cyan
        Write-Host "  Example: pvm install 8  (to see PHP 8 releases)" -ForegroundColor Cyan
        Write-Host "           pvm install 7  (to see PHP 7 releases)" -ForegroundColor Cyan
        Write-Host "           pvm install 5  (to see PHP 5 releases)" -ForegroundColor Cyan
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