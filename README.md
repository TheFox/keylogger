# Keylogger
Keylogger for Windows.

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

## License
Copyright (C) 2009 Christian Mayer <http://fox21.at>

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
