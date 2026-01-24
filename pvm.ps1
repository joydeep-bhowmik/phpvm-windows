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
  pvm ext enable <version> <extension>
  pvm ext disable <version> <extension>
"@
    exit
}

function Enable-Extension {
    param(
        [string]$version,
        [string]$ext
    )

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
        [string]$version,
        [string]$ext
    )

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
        $version = $arg2
        $ext = $arg3
        
        if ($action -eq "enable") {
            if (-not $version -or -not $ext) {
                Write-Host "Usage: pvm ext enable <version> <extension>"
                exit
            }
            Enable-Extension -version $version -ext $ext
        }
        elseif ($action -eq "disable") {
            if (-not $version -or -not $ext) {
                Write-Host "Usage: pvm ext disable <version> <extension>"
                exit
            }
            Disable-Extension -version $version -ext $ext
        }
        else {
            Write-Host "Usage: pvm ext enable <version> <extension>"
            Write-Host "       pvm ext disable <version> <extension>"
        }
    }

    default { usage }
}