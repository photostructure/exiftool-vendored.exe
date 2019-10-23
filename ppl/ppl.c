/*
 * Portable Perl launcher for Windows
 *
 * Approach: Run the Perl interpreter from perl5xx.dll and:
 * - Insert a script name as parameter
 * - Optionally insert include directories as parameter(s)
 *
 * The PAR Packager pp can be used to collect all dependencies of the Perl application
 * Use only the contents of the "lib" directory plus the script from the "script" directory.
 *
 * Inspired by "runperl.c" used to compile the original perl.exe
 *
 * If configured for "implicit linking", the exe needs to
 * be linked with "lib/CORE/libperl5xx.a" from your Perl distribution
 * an perl5xx.dll needs to be placed in the same directory as the exe
 *
 * 20190516 - proof of concept, request for comments
 * 20190518 - catch strrchr not found, add "perl.exe mode"
 * 20190519 - lint-safe
 * 20190521 - explicit linking to build an universal exe (optional)
 * 20190523 - support subdirectory for DLL
 * 20190603 - support for Perl w/ many DLLs (Strawberry Perl)
 * 20190624 - _CRT_glob didn't work on MinGW_i686-8.1.0-release-posix-dwarf-rt_v6-rev0
 * 20190706 - fixed wrong calling convention in RunPerl_t declaration
 *
 * Possible extensions:
 * - set additional lib search path(s)
 * - set an environment variable to let the script know the calling method
 *
 * Author: Oliver Betz https://OliverBetz.de
 * License: Public domain, no liability, no support (useful feedback welcome)
 * Please send comments to ppl@oliverbetz.de
 *
 * Known limitations: Do not put more than one perl5*.dll next to the exe
 * because the FindFirstFile() result would be ambiguous then
 */

#define CASSERT(pred) switch(0){case 0:case (pred):;} // compile time assert

#ifdef _MSC_VER
#include <crtdbg.h> // Copied from runperl.c without further check
#endif

#ifdef __GNUC__
int _CRT_glob = 0; // Why the hell should a compiler glob command line arguments?
int _dowildcard = 0; // _CRT_glob should be an alias for _dowildcard but doesn't work
#endif

//#define EXPLICITLINKING ///< load Perl*.dll dynamically (could be set by makefile)

#ifdef EXPLICITLINKING
#include <stdio.h>
#include <windows.h>
#else
// includes from your Perl distribution to access the DLL by implicit linking
#include "EXTERN.h"
#include "perl.h"
#endif

// Three flavours of mangling the path to the exe can be chosen
// by the format of the pathreplace[] string:
// - "\\myscript.pl" makes a fixed script name, independent of the exe name
// - ".pl" replaces just the extension from .exe to .pl
// - "." removes the .exe extension
// The latter two make an "universal" exe (rename it to match the script name)
// No safety belts - don't omit "\\" or "." at the beginning of the string!

//static const char pathreplace[] = ".pl"; ///< variable path conversion to Perl script
static const char pathreplace[] = "\\exiftool_files\\exiftool.pl"; ///< fixed path conversion to Perl script

//static const char dllsearch[] = "perl5*.dll"; ///< search string for Perl DLL, used only with "EXPLICITLINKING"
static const char dllsearch[] = "exiftool_files\\perl5*.dll"; ///< search string for Perl DLL, used only with "EXPLICITLINKING"

// act like the original "perl.exe" if our name is "perl.exe" (case sensitive!)
static const char perlexe[] = "perl.exe"; // set to NULL to disable

#define ARGS_ADDED 1 ///< number of arguments we put in front of the user provided args
//#define DEBUGOUT stderr  ///< debug output. Comment to disable debug output
#define PATHBUFLEN 1000 ///< PATH_MAX is obsolete since Win10?
#define NAMEBUFLEN   50 ///< additional buffer size for the dll name

// original definition in win32.h: DllExport int RunPerl(int argc, char **argv, char **env);
// resolving to: __declspec(dllimport) int RunPerl(int argc, char **argv, char **env);
// "__declspec(dllimport)" is not applicable to explicit linking
typedef int (* RunPerl_t)(int argc, char **argv, char **env);

int main(int argc, char **argv, char **env)
{
    char scriptpath[PATHBUFLEN]; ///< to construct script path from exe path
    char dllpath[PATHBUFLEN+NAMEBUFLEN]; ///< to construct DLL (search) path from exe path
    char *dlldir; // pointer past (!) last backslash in dllpath buffer
    int i, emulate_perlexe;

// Copied from runperl.c without further check:
#ifdef _MSC_VER
    int currentFlag = _CrtSetDbgFlag(_CRTDBG_REPORT_FLAG);
    currentFlag |= _CRTDBG_LEAK_CHECK_DF;
    _CrtSetDbgFlag(currentFlag);
    _CrtSetBreakAlloc(-1L);
#endif

    scriptpath[0]=0; // ensure a null terminated string
    i = GetModuleFileName(NULL, scriptpath, sizeof(scriptpath));
    if ((i > 0) && (i < ((int)ARRAYSIZE(scriptpath)-(int)ARRAYSIZE(pathreplace)-(int)1))){

        scriptpath[ARRAYSIZE(scriptpath)-1] = 0; // limit strrchr search in case of errors (paranoia)

        (void)memmove(dllpath, scriptpath, sizeof scriptpath); // the buffer for the DLL path
        dlldir = strrchr(dllpath, '\\'); // find the last backslash in path to get the file name
        dlldir = dlldir ? (dlldir + 1) : dllpath; // if find no backslash (unlikely), use the whole buffer
        emulate_perlexe = ((perlexe != 0) &&  (!strncmp(dlldir, perlexe, sizeof perlexe))); //lint !e506

        char *rep = strrchr(scriptpath, pathreplace[0]); // find the last delimiter in path
        if(!rep){
            (void)fprintf(stderr, "Failed to find '%c' in %s\n", pathreplace[0], scriptpath);
            return 1; // ---> early return
        }
        if((pathreplace[0] == '.') && (pathreplace[1] == 0)){
            *rep = 0; // Perl script without extension, drop the '.'
        } else {
            (void)memmove(rep, pathreplace, sizeof pathreplace); // paste replacement
        }
    }
    else {
        (void)fprintf(stderr, "Path to %s is too long for my %i bytes buffer \n", argv[0], sizeof(scriptpath));
        return 1; // ---> early return
    }

#ifdef DEBUGOUT
    fprintf(DEBUGOUT, "***** debug info *****\n%i argv parameters were passed to the exe:\n", argc);
    for(i = 0; i < argc; i++){
        fprintf(DEBUGOUT, "%i:%s\n", i, argv[i]);
    }
    if(!emulate_perlexe) fprintf(DEBUGOUT, "\nScript to be called: \"%s\"\n", scriptpath);
    else                 fprintf(DEBUGOUT, "\nWe emulate the original perl.exe\n");
#endif

#ifdef EXPLICITLINKING
    HINSTANCE hDLL;      // Handle to Perl DLL
    RunPerl_t RunPerl;   // Function pointer
    HANDLE hFind;        // for FindFirstFile()
    WIN32_FIND_DATA ffd; // for FindFirstFile()

    CASSERT(((sizeof dllsearch)+(sizeof scriptpath)) < (sizeof dllpath));
    // the dllpath buffer is longer than the scriptpath buffer => memmove can't overflow:
    (void)memmove(dlldir, dllsearch, sizeof dllsearch); // build search spec for the Perl DLL
    // remember that dlldir currently points to the last backslash of the path to the exe

#ifdef DEBUGOUT
    fprintf(DEBUGOUT, "DLL search spec:     \"%s\"\n", dllpath);
#endif

    hFind = FindFirstFile(dllpath, &ffd);
    if(hFind == INVALID_HANDLE_VALUE){
        (void)fprintf(stderr, "Could not find %s\n", dllpath);
        return 1; // ---> early return
    }
    // now we have the name of the DLL (without path) in ffd.cFileName

    // search again since our DLL search spec could contain again a backslash!
    dlldir = strrchr(dllpath, '\\'); // find the last backslash in path to get the DLL directory
    dlldir = dlldir ? (dlldir + 1) : dllpath; // if find no backslash (unlikely), set to start of buffer
    // note: a trailing slash is needed for the (stupid) case of a directory with a trailing space!

    *dlldir = 0; // strip the file name spec from the path
    (void)SetDllDirectory(dllpath); // add the directory to the search path
    // as a positive side-effect, this removes the current directory from the search path

#ifdef DEBUGOUT
    fprintf(DEBUGOUT, "DLL name found:      \"%s\" (length = %i)\n", ffd.cFileName, strlen(ffd.cFileName) );
    fprintf(DEBUGOUT, "DLL search path set: \"%s\"\n", dllpath);
#endif

    hDLL = LoadLibrary(ffd.cFileName); // searches first in the directory set by SetDllDirectory()
    if (!hDLL){
        (void)fprintf(stderr, "Failed to load Perl DLL \"%s\" code %li\n", ffd.cFileName, GetLastError());
        (void)FindClose(hFind); // invalidates / frees ffd.cFileName
        return 1; // ---> early return
    }
    (void)FindClose(hFind); // invalidates / frees ffd.cFileName

    RunPerl = (RunPerl_t)GetProcAddress(hDLL, "RunPerl"); // this name works with ActiveState and Strawberry
    if (!RunPerl){
       (void)FreeLibrary(hDLL);
       (void)fprintf(stderr, "Failed to get RunPerl address in DLL. Check the DLL for name mangling.\n");
       return 1; // ---> early return
    }
#endif // EXPLICITLINKING

#ifdef DEBUGOUT
    fprintf(DEBUGOUT, "***** end of debug info *****\n");
#endif

    if(emulate_perlexe){
        i = RunPerl(argc, argv, env); // emulate the standard perl.exe
#ifdef EXPLICITLINKING
        if(hDLL) (void)FreeLibrary(hDLL);
#endif
    } else {
        // generate "our" argument list with additional entries and terminating NULL pointer
        char **ourargv = (char **)malloc((argc+ARGS_ADDED+1) * sizeof(char**));
        if (!ourargv) { (void)fprintf(stderr, "Out of memory building new arg list\n"); return 1; } // ---> early return

        ourargv[0] = argv[0]; // keep filename, although it seems to be dropped by perl
        ourargv[1] = scriptpath; // pass script path to Perl interpreter

        // copy the remaining user provided arguments and the terminating NULL pointer
        for (i=1; i<=argc; ++i) {
            ourargv[i+ARGS_ADDED] = argv[i];
        }

        i = RunPerl(argc+ARGS_ADDED, ourargv, env);
#ifdef EXPLICITLINKING
        if(hDLL) (void)FreeLibrary(hDLL);
#endif
        free(ourargv);
    }
    return i; // pass the return code from the Perl interpreter like original perl.exe does
}

