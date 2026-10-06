@echo off

REM Builds all platforms.

zig build install --release
zig build install --release -Dtarget=x86_64-windows
zig build install --release -Dtarget=x86-windows -Dcpu=i386
zig build install --release -Dtarget=x86-windows -Dcpu=i686
zig build install --release -Dtarget=aarch64-windows
