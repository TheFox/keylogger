# Keylogger

Keylogger for Windows.

## Project Outlines

The project outlines as described in my blog post about [Open Source Software Collaboration](https://blog.fox21.at/2019/02/21/open-source-software-collaboration.html).

- The one and only purpose of this software is to log keystrokes under Windows operating system.
- Since this keylogger already has all its features please do not request new features. It's designed by the [Unix philosophy](https://en.wikipedia.org/wiki/Unix_philosophy): *Write programs that do one thing and do it well.*

## Compiling

### Requirements

1. OS minimum: Windows Vista Home Premium
2. Compiler/IDE:
	1. [MinGW-w64](http://sourceforge.net/projects/mingw-w64/)
	2. [Orwell Dev-Cpp 5.10](http://sourceforge.net/projects/orwelldevcpp/)
	3. [Dev-C++ 4.9.9.2](http://www.bloodshed.net/dev/devcpp.html) ([GCC 3.4.2](http://gcc.gnu.org/))

### MinGW

1. [Install MinGW-w64](http://sourceforge.net/projects/mingw-w64/).
2. Clone project.
3. In project directory run in cmd: `mingw32-make`. The compiled keylogger is available in `build\keylogger.exe`.

Windows Vista Home Premium with MinGW is not supported. See [DWARF2 issue](http://answers.opencv.org/question/3740/opencv-243-mingw-cannot-run-program/).

## Tested

| Major Version | Edition       | Version | Build      | Arch   |
|:------------- |:------------- |:------- |:---------- |:------ |
| Windows Vista | Home Premium  |         |            | 64 bit |
| Windows XP    | Pro           |         |            |        |
| Windows 7     |               |         |            | 64 bit |
| Windows 10    | Home          | 1903    | 18362.476  | 64 bit |

## Running

### Starting

Just start `keylogger.exe` from any directory. There is no such thing like an install or auto-start routine. This Keylogger acts according to the [Unix philosophy](https://en.wikipedia.org/wiki/Unix_philosophy): do one thing and do it well.

### Stopping

1. Open Task Manager
2. Go to "Details" tab
3. Highlight any process
4. Press "k" on keyboard
5. Highlight "keylogger.exe"
6. Press <del> on keyboard (to kill it)

## License

Copyright (C) 2009 Christian Mayer <https://fox21.at>

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
