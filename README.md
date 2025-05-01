# Keylogger

Keylogger for Windows.

## Project Outlines

The project outlines as described in my blog post about [Open Source Software Collaboration](https://blog.fox21.at/2019/02/21/open-source-software-collaboration.html).

- The one and only purpose of this software is to log keystrokes under Windows operating system.
- Since this keylogger already has all its features please do not request new features. It's designed by the [Unix philosophy](https://en.wikipedia.org/wiki/Unix_philosophy): *Write programs that do one thing and do it well.*

## Download

Download the latest pre-build exe files from the [Releases](https://github.com/TheFox/keylogger/releases) section.

## Compiling

### Requirements

- OS: Windows 11
- Visual Studio Community 2022
	- MSVC v143 x64/x86 build tools
	- Windows 11 SDK (10.0.22621.0)

### Build

```sh
zig build --release
```

### Build for x86 (i386/i686)

```sh
zig build --release -Dtarget=x86-windows -Dcpu=i386
zig build --release -Dtarget=x86-windows -Dcpu=i686
```

## Tested under

- Windows 11

## Installation

Just start `keylogger.exe` from any directory. There is no such thing like an install or auto-start routine. This Keylogger acts according to the [Unix philosophy](https://en.wikipedia.org/wiki/Unix_philosophy): do one thing and do it well.

## Uninstall

Open the Task Manager, search for `keylogger.exe` and kill this process. Then delete `keylogger.exe`. That's it.
