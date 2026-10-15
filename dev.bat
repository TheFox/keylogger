@echo off

zig build install --release -Dci=true -Dmethod=loop
zig build install --release -Dci=true -Dmethod=hook

.\zig-out\bin\keylogger-loop.exe --help
.\zig-out\bin\keylogger-hook.exe --help
