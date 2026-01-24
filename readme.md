
# PHP Version Manager (PVM) for Windows

A simple PHP Version Manager for Windows (global), allowing you to:

- Install multiple PHP versions
- Switch between versions instantly
- Use PHP globally from any terminal
- Works without admin access

---

## 🚀 Features

✔ Install PHP versions (official Windows binaries)  
✔ Switch PHP version with one command  
✔ Uses a single global path (`C:\phpvm\php`)  
✔ Compatible with Composer, Laravel, Artisan, etc.  
✔ Does NOT require admin rights  

---

## 📁 Installation

### 1. Clone this repository

```powershell
git clone https://github.com/<your-username>/phpvm-windows.git
````

### 2. Move files to `C:\phpvm`

```powershell
mkdir C:\phpvm
copy .\phpvm-windows\* C:\phpvm\ /y
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

---

## 🛠️ Troubleshooting

### `pvm` not recognized

* Make sure `C:\phpvm` is added to PATH
* Restart terminal

### `php -v` still shows old PHP

* Make sure `C:\phpvm\php` is **above** other PHP paths in PATH
* If Herd is installed, disable its PHP shims


---

## 📌 License

MIT License

---



