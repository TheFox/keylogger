@echo off

REM Builds all platforms.

zig build install --verbose --summary all --release
zig build install --verbose --summary all --release -Dtarget=x86_64-windows
zig build install --verbose --summary all --release -Dtarget=x86-windows -Dcpu=i386
zig build install --verbose --summary all --release -Dtarget=x86-windows -Dcpu=i686
zig build install --verbose --summary all --release -Dtarget=aarch64-windows
