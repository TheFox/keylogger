@echo off

zig build install --release -Dci=true -Dmethod=loop
zig build install --release -Dci=true -Dmethod=hook
