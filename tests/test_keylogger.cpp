
#include "../src/main.h"

using namespace std;

int main(int argc, char *argv[]){
	printf("%s %d.%d.%d (%s %s)\n", PROJECT_NAME, PROJECT_VERSION_MAJOR, PROJECT_VERSION_MINOR, PROJECT_VERSION_PATCH, __DATE__, __TIME__);
	puts(PROJECT_COPYRIGHT);
	puts("");
	
#if __MINGW32__
	puts("is __MINGW32__");
#else
	puts("not __MINGW32__");
#endif
#ifdef DEBUG
	puts("is DEBUG");
#else
	puts("not DEBUG");
#endif
	puts("");
	
	printf("function itoa:     %p\n", itoa);
	printf("function time:     %p\n", time);
	printf("function strftime: %p\n", strftime);
	printf("function sprintf:  %p\n", sprintf);
	puts("");
	
	printf("function GetCurrentDirectory: %p\n", GetCurrentDirectory);
	printf("function GetModuleFileName:   %p\n", GetModuleFileName);
	printf("function GetForegroundWindow: %p\n", GetForegroundWindow);
	printf("function GetWindowText:       %p\n", GetWindowText);
	printf("function GetAsyncKeyState:    %p\n", GetAsyncKeyState);
	printf("function Sleep:               %p\n", Sleep);
	puts("");
	
	printf("function intToString: %p\n", intToString);
	printf("function getCurrDir:  %p\n", getCurrDir);
	printf("function getSelfPath: %p\n", getSelfPath);
	printf("function dirBasename: %p\n", dirBasename);
	puts("");
	
	ofstream klogout;
	printf("type ofstream: %p\n", &klogout);
	puts("");
	
	string i1 = intToString(21);
	printf("intToString: '%s'\n", i1.c_str());
	
	string currDir = getCurrDir();
	printf("currDir:  '%s'\n", currDir.c_str());
	
	string selfPath = getSelfPath();
	printf("selfPath: '%s'\n", selfPath.c_str());
	
	string basepath = dirBasename(getSelfPath());
	printf("basepath: '%s'\n", basepath.c_str());
	
	cout << "c++ out" << endl;
	
	return 0;
}
