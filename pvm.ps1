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

function Enable-Extension {
    param(
        [string]$ext,
        [string]$version = "current"
    )

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

    $iniPath = "C:\phpvm\versions\$version\php.ini"
    
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

    $iniPath = "C:\phpvm\versions\$version\php.ini"
    
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

        # Prefer NTS (best for CLI)
        $url = "https://windows.php.net/downloads/releases/php-$version-nts-Win32-vs16-x64.zip"

        Write-Host "Downloading PHP $version (NTS)..."

        try {
            Invoke-WebRequest -Uri $url -OutFile $zip
        }
        catch {
            Write-Host "Release not found in main releases, trying archive..."

            $url = "https://windows.php.net/downloads/releases/archives/php-$version-nts-Win32-vs16-x64.zip"
            Invoke-WebRequest -Uri $url -OutFile $zip
        }

        Write-Host "Extracting..."
        Expand-Archive -Force $zip -DestinationPath $target
        Remove-Item $zip

        # Create php.ini if not present
        $iniPath = "$target\php.ini"
        if (-not (Test-Path $iniPath)) {

            # prefer production template
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