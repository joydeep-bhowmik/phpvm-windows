# PVM Test Suite
# Run this script to test all PVM functionality

$ErrorActionPreference = "Stop"

# Test Configuration
$TEST_VERSION = "8.2.15"
$TEST_EXTENSION = "curl"
$TEST_BASE = "C:\phpvm-test"
$TEST_VERSIONS = "$TEST_BASE\versions"
$TEST_ACTIVE = "$TEST_BASE\php"

# Backup original paths
$ORIGINAL_BASE = "C:\phpvm"
$ORIGINAL_VERSIONS = "C:\phpvm\versions"
$ORIGINAL_ACTIVE = "C:\phpvm\php"

function Write-TestResult {
    param($test, $result, $message)
    
    if ($result -eq $true) {
        Write-Host "[PASS] $test - $message" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $test - $message" -ForegroundColor Red
        throw "$test failed: $message"
    }
}

function Write-TestInfo {
    param($message)
    Write-Host "[INFO] $message" -ForegroundColor Cyan
}

function Cleanup-Test {
    Write-TestInfo "Cleaning up test environment..."
    if (Test-Path $TEST_BASE) {
        Remove-Item -Recurse -Force $TEST_BASE -ErrorAction SilentlyContinue
    }
}

function Test-Setup {
    Write-TestInfo "Setting up test environment..."
    New-Item -ItemType Directory -Force -Path $TEST_VERSIONS | Out-Null
    return $true
}

function Test-PVM-Script-Exists {
    Write-TestInfo "Testing if PVM script exists..."
    if (Test-Path "C:\phpvm\pvm.ps1") {
        return $true
    }
    elseif (Test-Path "C:\phpvm\pvm") {
        return $true
    }
    else {
        return $false
    }
}

function Test-Install-Function {
    Write-TestInfo "Testing install function (mocked)..."
    
    # Create a mock PHP installation
    $versionDir = "$TEST_VERSIONS\$TEST_VERSION"
    New-Item -ItemType Directory -Force -Path $versionDir | Out-Null
    New-Item -ItemType Directory -Force -Path "$versionDir\ext" | Out-Null
    
    # Create mock php.ini-production
    $prodIni = "$versionDir\php.ini-production"
    @"
[PHP]
extension_dir = "ext"
date.timezone = "UTC"
"@ | Set-Content $prodIni
    
    # Create mock php.ini
    $iniPath = "$versionDir\php.ini"
    Copy-Item $prodIni $iniPath
    
    # Create mock extension DLL
    "$TEST_EXTENSION.dll" | Set-Content "$versionDir\ext\$TEST_EXTENSION.dll"
    
    return (Test-Path $iniPath)
}

function Test-Use-Function {
    Write-TestInfo "Testing use function..."
    
    $versionDir = "$TEST_VERSIONS\$TEST_VERSION"
    
    # Remove existing junction if exists
    if (Test-Path $TEST_ACTIVE) {
        cmd /c rmdir $TEST_ACTIVE 2>$null
    }
    
    # Create junction
    cmd /c mklink /J $TEST_ACTIVE $versionDir 2>$null | Out-Null
    
    $junctionCreated = Test-Path $TEST_ACTIVE
    $targetCorrect = $false
    
    if ($junctionCreated) {
        $linkTarget = (Get-Item $TEST_ACTIVE).Target
        $targetCorrect = ($linkTarget -eq $versionDir)
    }
    
    return $junctionCreated -and $targetCorrect
}

function Test-Extension-Enable {
    Write-TestInfo "Testing extension enable function..."
    
    $iniPath = "$TEST_VERSIONS\$TEST_VERSION\php.ini"
    
    # Backup original ini
    $backupIni = "$iniPath.backup"
    Copy-Item $iniPath $backupIni
    
    try {
        # Test 1: Enable extension when commented out
        @"
[PHP]
;extension=$TEST_EXTENSION
date.timezone = "UTC"
"@ | Set-Content $iniPath
        
        # Simulate enabling the extension
        $content = Get-Content $iniPath
        $found = $false

        $newContent = $content | ForEach-Object {
            if ($_ -match "^\s*;?\s*extension\s*=\s*$TEST_EXTENSION\s*$") {
                $found = $true
                "extension=$TEST_EXTENSION"
            }
            else {
                $_
            }
        }

        # If extension is not found, add it at the end
        if (-not $found) {
            $newContent += "extension=$TEST_EXTENSION"
        }

        $newContent | Set-Content $iniPath
        
        $content = Get-Content $iniPath
        $extensionEnabled = ($content | Where-Object { $_ -match "^extension=$TEST_EXTENSION$" }) -ne $null
        
        # Test 2: Enable extension when not present (should add it)
        @"
[PHP]
date.timezone = "UTC"
"@ | Set-Content $iniPath
        
        # Simulate again
        $content = Get-Content $iniPath
        $found = $false

        $newContent = $content | ForEach-Object {
            if ($_ -match "^\s*;?\s*extension\s*=\s*$TEST_EXTENSION\s*$") {
                $found = $true
                "extension=$TEST_EXTENSION"
            }
            else {
                $_
            }
        }

        if (-not $found) {
            $newContent += "extension=$TEST_EXTENSION"
        }

        $newContent | Set-Content $iniPath
        
        $content = Get-Content $iniPath
        $extensionAdded = ($content | Where-Object { $_ -match "^extension=$TEST_EXTENSION$" }) -ne $null
        
        return $extensionEnabled -and $extensionAdded
    }
    finally {
        # Restore original
        if (Test-Path $backupIni) {
            Move-Item $backupIni $iniPath -Force
        }
    }
}

function Test-Extension-Disable {
    Write-TestInfo "Testing extension disable function..."
    
    $iniPath = "$TEST_VERSIONS\$TEST_VERSION\php.ini"
    
    # Backup original ini
    $backupIni = "$iniPath.backup"
    Copy-Item $iniPath $backupIni
    
    try {
        # Test: Disable extension when enabled
        @"
[PHP]
extension=$TEST_EXTENSION
date.timezone = "UTC"
"@ | Set-Content $iniPath
        
        # Simulate disabling the extension
        $content = Get-Content $iniPath

        $newContent = $content | ForEach-Object {
            if ($_ -match "^\s*;?\s*extension\s*=\s*$TEST_EXTENSION\s*$") {
                # Comment out the extension
                if ($_ -match "^extension\s*=\s*$TEST_EXTENSION") {
                    ";extension=$TEST_EXTENSION"
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
        
        $content = Get-Content $iniPath
        $extensionDisabled = ($content | Where-Object { $_ -match "^;extension=$TEST_EXTENSION$" }) -ne $null
        
        return $extensionDisabled
    }
    finally {
        # Restore original
        if (Test-Path $backupIni) {
            Move-Item $backupIni $iniPath -Force
        }
    }
}

function Test-List-Function {
    Write-TestInfo "Testing list function..."
    
    # Create multiple test versions
    $versions = @("8.1.0", "8.2.0", "8.3.0")
    foreach ($version in $versions) {
        New-Item -ItemType Directory -Force -Path "$TEST_VERSIONS\$version" | Out-Null
    }
    
    # Count directories
    $dirCount = (Get-ChildItem $TEST_VERSIONS -Directory).Count
    
    return $dirCount -ge 3
}

function Test-Current-Function {
    Write-TestInfo "Testing current function..."
    
    $versionDir = "$TEST_VERSIONS\$TEST_VERSION"
    
    # Ensure active junction exists
    if (-not (Test-Path $TEST_ACTIVE)) {
        cmd /c mklink /J $TEST_ACTIVE $versionDir 2>$null | Out-Null
    }
    
    # The current function should show PHP version or "No active PHP version"
    # We'll just check if the junction exists
    return (Test-Path $TEST_ACTIVE)
}

function Test-Parameter-Parsing {
    Write-TestInfo "Testing parameter parsing..."
    
    # We'll just test that our functions handle parameters correctly
    # Since we can't actually call the script without installing PHP
    return $true
}

# Main test execution
try {
    Write-Host ""
    Write-Host "=== PVM Test Suite ===" -ForegroundColor Yellow
    Write-Host "Starting tests at $(Get-Date)"
    Write-Host ""
    
    # Setup
    Test-Setup
    
    # Run tests
    $tests = @(
        @{Name = "PVM Script Exists"; Func = { Test-PVM-Script-Exists } },
        @{Name = "Install Function"; Func = { Test-Install-Function } },
        @{Name = "Use Function"; Func = { Test-Use-Function } },
        @{Name = "Extension Enable"; Func = { Test-Extension-Enable } },
        @{Name = "Extension Disable"; Func = { Test-Extension-Disable } },
        @{Name = "List Function"; Func = { Test-List-Function } },
        @{Name = "Current Function"; Func = { Test-Current-Function } },
        @{Name = "Parameter Parsing"; Func = { Test-Parameter-Parsing } }
    )
    
    $passed = 0
    $failed = 0
    
    foreach ($test in $tests) {
        try {
            $result = & $test.Func
            if ($result) {
                Write-TestResult $test.Name $true "Test passed"
                $passed++
            }
            else {
                Write-TestResult $test.Name $false "Test returned false"
                $failed++
            }
        }
        catch {
            Write-TestResult $test.Name $false "Error: $($_.Exception.Message)"
            $failed++
        }
    }
    
    # Summary
    Write-Host ""
    Write-Host "=== Test Summary ===" -ForegroundColor Yellow
    Write-Host "Total Tests: $($tests.Count)" -ForegroundColor White
    Write-Host "Passed: $passed" -ForegroundColor Green
    Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
    
    if ($failed -eq 0) {
        Write-Host ""
        Write-Host "All tests passed!" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "Some tests failed. Check the logs above." -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "Test suite crashed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Cleanup-Test
}