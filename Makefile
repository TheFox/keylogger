
CC = gcc
CPP = g++
CFLAGS = -Wall -O3
#CFLAGS = -I"C:\MinGW\include"
LDFLAGS = 
#LDFLAGS = -L"C:\MinGW\lib" -mwindows -s
MKDIR = mkdir
RM = rm -frv


.PHONY: all clean

all: build/test_keylogger.exe build/keylogger.exe

build/keylogger.exe: build/main.o build/functions.o
	$(CPP) $(CFLAGS) $^ -o $@ $(LDFLAGS)

build/main.o: src/main.cpp src/main.h src/config.h build
	$(CPP) $(CFLAGS) -c $< -o $@

build/functions.o: src/functions.cpp src/functions.h build
	$(CPP) $(CFLAGS) -c $< -o $@

build/test_keylogger.exe: build/test_keylogger.o build/functions.o
	$(CPP) $(CFLAGS) $^ -o $@ $(LDFLAGS)
	$@

build/test_keylogger.o: tests/test_keylogger.cpp build
	$(CPP) $(CFLAGS) -c $< -o $@

build:
	$(MKDIR) "$@"

clean:
	$(RM) build/main.o build/functions.o build/keylogger.exe build/test_keylogger.o build/test_keylogger.exe
	@#$(RM) build
