
#include "functions.h"

using namespace std;

string intToString(int i){
	char buffer[4];
	itoa(i, buffer, 10);
	return string(buffer);
}

string getCurrDir(){
	char *curdir = new char[MAX_PATH];
	GetCurrentDirectory(MAX_PATH, curdir);
	string rv(curdir);
	delete[] curdir;
	return rv;
}

string getSelfPath(){
	char selfpath[MAX_PATH];
	GetModuleFileName(NULL, selfpath, MAX_PATH);
	return string(selfpath);
}

string dirBasename(string path){
	if(path.empty())
		return string("");
	
	if(path.find("\\") == string::npos)
		return path;
	
	if(path.substr(path.length() - 1) == "\\")
		path = path.substr(0, path.length() - 1);
	
	size_t pos = path.find_last_of("\\");
	if(pos != string::npos)
		path = path.substr(0, pos);
	
	if(path.substr(path.length() - 1) == "\\")
		path = path.substr(0, path.length() - 1);
	
	return path;
}
