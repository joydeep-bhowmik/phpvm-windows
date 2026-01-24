param(
    [string]$command,
    [string]$version
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
"@
    exit
}

if (-not $command) { usage }

switch ($command) {

    "install" {
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
        } catch {
            Write-Host "Release not found in main releases, trying archive..."

            $url = "https://windows.php.net/downloads/releases/archives/php-$version-nts-Win32-vs16-x64.zip"
            Invoke-WebRequest -Uri $url -OutFile $zip
        }

        Write-Host "Extracting..."
        Expand-Archive -Force $zip -DestinationPath $target
        Remove-Item $zip

        Write-Host "Installed PHP $version"
    }

    "use" {
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
        } else {
            Write-Host "No active PHP version"
        }
    }

    default { usage }
}
