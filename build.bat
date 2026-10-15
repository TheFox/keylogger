@echo off

REM Builds all platforms.

zig build install --release -Dmethod=loop
zig build install --release -Dmethod=loop -Dtarget=x86_64-windows
zig build install --release -Dmethod=loop -Dtarget=x86-windows -Dcpu=i386
zig build install --release -Dmethod=loop -Dtarget=x86-windows -Dcpu=i686
zig build install --release -Dmethod=loop -Dtarget=aarch64-windows

zig build install --release -Dmethod=hook
zig build install --release -Dmethod=hook -Dtarget=x86_64-windows
zig build install --release -Dmethod=hook -Dtarget=x86-windows -Dcpu=i386
zig build install --release -Dmethod=hook -Dtarget=x86-windows -Dcpu=i686
zig build install --release -Dmethod=hook -Dtarget=aarch64-windows
