# Keylogger

Keylogger for Windows.

## Project Outlines

The project outlines as described in my blog post about [Open Source Software Collaboration](https://blog.fox21.at/2019/02/21/open-source-software-collaboration.html).

- The one and only purpose of this software is to log keystrokes under Windows operating system.
- Since this keylogger already has all its features please do not request new features. It's designed by the [Unix philosophy](https://en.wikipedia.org/wiki/Unix_philosophy): *Write programs that do one thing and do it well.*

## Compiling

### Requirements

- OS minimum: Windows Vista Home Premium
- Compiler/IDE:
	- [MinGW-w64](http://sourceforge.net/projects/mingw-w64/)
	- or [Orwell Dev-Cpp 5.10](http://sourceforge.net/projects/orwelldevcpp/)
	- or [Dev-C++ 4.9.9.2](http://www.bloodshed.net/dev/devcpp.html) ([GCC 3.4.2](http://gcc.gnu.org/))

### Compile with MinGW

- [Install MinGW-w64](http://sourceforge.net/projects/mingw-w64/).
- Clone project.
- In project directory run in cmd: `mingw32-make`. The compiled keylogger is available in `build\keylogger.exe`.

### MinGW Warning

Under Windows Vista Home Premium I wasn't able to run a version compiled with [MinGW](http://www.mingw.org/). See [DWARF2 issue](http://answers.opencv.org/question/3740/opencv-243-mingw-cannot-run-program/).

## 	Tested under
- Windows Vista Home Premium, 64 Bit
- Windows XP Professional
- Windows 7, 64-bit

## Installation

Just start `keylogger.exe` from any directory. There is no such thing like an install or auto-start routine. This Keylogger acts according to the [Unix philosophy](https://en.wikipedia.org/wiki/Unix_philosophy): do one thing and do it well.

## Uninstall

Open the Task Manager, search for `keylogger.exe` and kill this process. Then delete `keylogger.exe`. That's it.
