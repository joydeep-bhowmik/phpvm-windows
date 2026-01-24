
# PHP Version Manager (PVM) for Windows

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

### 1. Clone this repository

```powershell
git clone https://github.com/<your-username>/phpvm-windows.git
```

### 2. Move files to `C:\phpvm`

```powershell
mkdir C:\phpvm
copy .\phpvm-windows\* C:\phpvm\ /y
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
pvm ext enable 8.2.15 curl
pvm ext enable 8.2.15 mbstring
pvm ext enable 8.2.15 openssl
pvm ext enable 8.2.15 pdo_mysql
```

### Disable a PHP extension

```powershell
pvm ext disable 8.2.15 xdebug
pvm ext disable 8.2.15 opcache
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

---

## ⚙️ How Extensions Work

PVM modifies the `php.ini` file for the specified PHP version:

- **Enable**: Uncomments or adds `extension=extname` in php.ini
- **Disable**: Comments out `extension=extname` in php.ini

Example: Enabling `curl` for PHP 8.2.15:

```ini
; Before:
;extension=curl

; After:
extension=curl
```

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
* `pvm ext` modifies the php.ini file for the specified version.

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

### Extension not loading

1. Check if DLL exists: `dir C:\phpvm\versions\<version>\ext\<extension>.dll`
2. Verify php.ini: Check that `extension=<extension>` is uncommented
3. Restart terminal after enabling/disabling extensions
4. Check PHP error log: `C:\phpvm\versions\<version>\error_log`

### Permission errors

Run PowerShell as administrator for installation only, or:
```powershell
# For current user only
New-Item -ItemType Directory -Force -Path C:\phpvm
```

---

## 📌 Example Workflow

```powershell
# Install PHP 8.2.15
pvm install 8.2.15

# Switch to it
pvm use 8.2.15

# Enable common extensions
pvm ext enable 8.2.15 curl
pvm ext enable 8.2.15 mbstring
pvm ext enable 8.2.15 openssl
pvm ext enable 8.2.15 pdo_mysql

# Verify installation
php -v
php -m | findstr "curl mbstring"

# Install another version
pvm install 8.3.2
pvm use 8.3.2
pvm ext enable 8.3.2 curl
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

https://github.com/joydeep-bhowmik/phpvm-windows