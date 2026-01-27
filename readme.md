
# PHP Version Manager (PVM) for Windows [ work in progress]
```powershell
  pvm install <version>
  pvm uninstall <version>
  pvm use <version>
  pvm list
  pvm current
  pvm ext list [version]            List all available extensions (version defaults to current)
  pvm ext enable <extension> [version]     (version defaults to current)
  pvm ext disable <extension> [version]    (version defaults to current)

```
A simple PHP Version Manager for Windows (global), allowing you to:

- Install multiple PHP versions
- Switch between versions instantly
- Enable/disable PHP extensions
- Use PHP globally from any terminal
- Works without admin access

---

## 🚀 Features

✔ Install PHP versions (official Windows binaries)  
✔ Switch PHP version with one command  
✔ Enable PHP extensions on demand  
✔ Disable PHP extensions when not needed  
✔ Uses a single global path (`C:\phpvm\php`)  
✔ Compatible with Composer, Laravel, Artisan, etc.  
✔ Does NOT require admin rights  

---

## 📁 Installation

### 1. make a folder  `C:\phpvm`
```powershell
mkdir C:\phpvm
```


### 2. clone the repo

```powershell
git clone https://github.com/joydeep-bhowmik/phpvm-windows.git .
```

### 3. Rename the script (optional but recommended)

```powershell
ren C:\phpvm\pvm.ps1 pvm
```

---

## ✅ Add to PATH

### 1. Open Environment Variables

Press:

```
Win + R → sysdm.cpl
```

### 2. Add the following to your PATH

Add:

```
C:\phpvm
C:\phpvm\php
```

> Make sure `C:\phpvm\php` is **above any other PHP paths**
> (XAMPP, Herd, Laragon, etc.)

### 3. Restart your terminal

Close all PowerShell / CMD windows and open a new one.

---

## 🎯 Usage

### Install a PHP version

```powershell
pvm install 8.2.15
```

### Use a PHP version

```powershell
pvm use 8.2.15
```

### List installed versions

```powershell
pvm list
```

### Show current active version

```powershell
pvm current
```

### Enable a PHP extension

```powershell
# Enable extension on current active version (recommended)
pvm ext enable curl
pvm ext enable mbstring
pvm ext enable openssl
pvm ext enable pdo_mysql

# Enable extension on specific version
pvm ext enable curl 8.2.15
pvm ext enable mbstring 8.3.2
```

### Disable a PHP extension

```powershell
# Disable extension on current active version
pvm ext disable xdebug
pvm ext disable opcache

# Disable extension on specific version
pvm ext disable xdebug 8.2.15
pvm ext disable opcache 8.3.2
```

---

## 📋 Common PHP Extensions

Here are some commonly used extensions you can enable:

| Extension | Description | Common Use |
|-----------|-------------|------------|
| `curl` | Client URL Library | HTTP requests, API calls |
| `mbstring` | Multibyte String | UTF-8 support, string functions |
| `openssl` | OpenSSL | SSL/TLS, encryption |
| `pdo_mysql` | MySQL PDO Driver | Database access |
| `pdo_sqlite` | SQLite PDO Driver | SQLite database |
| `json` | JSON | JSON encode/decode |
| `zip` | Zip | Zip archive handling |
| `gd` | GD Library | Image processing |
| `exif` | EXIF | Image metadata |
| `intl` | Internationalization | Locale-aware operations |
| `bz2` | Bzip2 | Bzip2 compression |
| `fileinfo` | File Information | MIME type detection |
| `redis` | Redis | Redis cache/database |
| `mongodb` | MongoDB | MongoDB database |
| `imagick` | ImageMagick | Advanced image processing |
| `sqlsrv` | SQL Server | Microsoft SQL Server |

---

## ⚙️ How Extensions Work

PVM modifies the `php.ini` file for the specified PHP version:

- **Enable**: Uncomments or adds `extension=extname` in php.ini
- **Disable**: Comments out `extension=extname` in php.ini

Example: Enabling `curl` for current PHP version:

```ini
; Before:
;extension=curl

; After:
extension=curl
```

> **Note**: The version parameter is optional. If omitted, PVM targets the currently active PHP version.

---

## ⚠️ Important Notes

### Herd / Laragon / XAMPP conflict

If you have Herd or other tools installed, they may override PHP globally.

To disable Herd PHP:

```powershell
ren "$env:USERPROFILE\.config\herd\bin\php.bat" php.bat.disabled
ren "$env:USERPROFILE\.config\herd-lite\bin\php.exe" php.exe.disabled
```

To re-enable:

```powershell
ren "$env:USERPROFILE\.config\herd\bin\php.bat.disabled" php.bat
ren "$env:USERPROFILE\.config\herd-lite\bin\php.exe.disabled" php.exe
```

### Extension DLL Requirements

Most PHP extensions require corresponding DLL files in the `ext` directory. PVM uses the official PHP Windows binaries which include common extensions:

- Check available extensions: `dir C:\phpvm\versions\8.2.15\ext\*.dll`
- If an extension DLL is missing, it won't load even if enabled in php.ini
- Some extensions may need additional DLL dependencies in the main PHP directory




### Version Parameter is Optional

When using `pvm ext enable` or `pvm ext disable`, the version parameter is optional:
- Without version: Targets current active PHP version
- With version: Targets specific PHP version (e.g., `8.2.15`)

---

## 🧩 How it works

* PHP versions are stored in:

```
C:\phpvm\versions\<version>
```

* The active version is linked to:

```
C:\phpvm\php
```

* `pvm use` updates the link using a Windows junction.
* `pvm ext` modifies the php.ini file for the specified version (defaults to current).

---

## 🛠️ Troubleshooting

### `pvm` not recognized

* Make sure `C:\phpvm` is added to PATH
* Restart terminal
* Ensure PowerShell execution policy allows scripts:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### `php -v` still shows old PHP

* Make sure `C:\phpvm\php` is **above** other PHP paths in PATH
* If Herd is installed, disable its PHP shims
* Run `pvm current` to verify active version

### Extension not loading

1. Check if DLL exists: `dir C:\phpvm\versions\<version>\ext\<extension>.dll`
2. Verify php.ini: Check that `extension=<extension>` is uncommented
3. Restart terminal after enabling/disabling extensions
4. Check PHP error log: `C:\phpvm\versions\<version>\error_log`
5. Run `php -m` to see loaded extensions
6. Some extensions require thread-safe (TS) versions, ensure you're using correct build
7. `;extension_dir = "ext"` uncomment this if your php looking for C:\php\ext by default

### Permission errors

Run PowerShell as administrator for installation only, or:
```powershell
# For current user only
New-Item -ItemType Directory -Force -Path C:\phpvm
```

### "No active PHP version" error

When using `pvm ext enable <extension>` without specifying a version:
```powershell
# Set an active version first
pvm use 8.2.15

# Then enable extensions
pvm ext enable curl
```

---

## 📌 Example Workflow

```powershell
# Install PHP 8.2.15
pvm install 8.2.15

# Switch to it
pvm use 8.2.15

# Enable common extensions on current version
pvm ext enable curl
pvm ext enable mbstring
pvm ext enable openssl
pvm ext enable pdo_mysql

# Verify installation
php -v
php -m | findstr "curl mbstring"

# Install another version
pvm install 8.3.2

# Enable extensions for specific version (while keeping 8.2.15 active)
pvm ext enable curl 8.3.2
pvm ext enable mbstring 8.3.2

# Enable or disable extensions for current version
pvm ext enable curl
pvm ext disable mbstring 

# Switch to new version
pvm use 8.3.2

# Disable an extension
pvm ext disable xdebug

# List all installed versions
pvm list
```

---

## Enable Genral / Laravel extenstions

```powershell
pvm ext enable ctype
pvm ext enable curl
pvm ext enable dom
pvm ext enable fileinfo
pvm ext enable filter
pvm ext enable hash
pvm ext enable mbstring
pvm ext enable openssl
pvm ext enable pcre
pvm ext enable pdo
pvm ext enable session
pvm ext enable tokenizer
pvm ext enable xml

```

## 🔄 Updating

To update PVM to the latest version:

```powershell
cd C:\phpvm
git pull origin main
```

---

## 📄 License

MIT License

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## ⭐ Support

If you find this tool useful, please give it a star on GitHub!

[![GitHub stars](https://img.shields.io/github/stars/joydeep-bhowmik/phpvm-windows.svg?style=social)](https://github.com/joydeep-bhowmik/phpvm-windows)

