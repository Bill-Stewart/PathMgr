# PathMgr.dll

PathMgr.dll is a Windows DLL (dynamically linked library) for managing the system Path and user Path.

# Author

Bill Stewart - bstewart at iname dot com

# License

PathMgr.dll is covered by the GNU Lesser Public License (LPGL). See the file `LICENSE` for details.

# Download

https://github.com/Bill-Stewart/PathMgr/releases/

# Background

The system Path is found in the following location in the Windows registry:

Root: `HKEY_LOCAL_MACHINE`  
Subkey: `SYSTEM\CurrentControlSet\Control\Session Manager\Environment`  
Value name: `Path`

The current user Path is found in the following location in the registry:

Root: `HKEY_CURRENT_USER`  
Subkey: `Environment`  
Value name: `Path`

In both cases, the `Path` value is (or should be) the registry type `REG_EXPAND_SZ`, which means that it is a string that can contain values surrounded by `%` characters that Windows will automatically expand to environment variable values. (For example, `%SystemRoot%` will be expanded to `C:\Windows` on most systems.)

The `Path` value contains a `;`-delimited list of directory names that the system should search for executables, library files, scripts, etc. Windows appends the content of the current user Path to the system Path and expands the environment variable references. The resulting string is set as the `Path` environment variable for processes.

PathMgr.dll provides an API for managing the `Path` value in the system location (in `HKEY_LOCAL_MACHINE`) and the current user location (in `HKEY_CURRENT_USER`).

PathMgr.dll is designed for applications (such as installers) that don't provide a built-in set of APIs or interfaces to manage the system or current user Path. There are both 32-bit (x86) and 64-bit (x64) versions.

If you prefer, the EditPath program is a command-line tool that provides the same functionality as PathMgr.dll. (EditPath does not require PathMgr.dll.)

# Functions

This section documents the functions exported by PathMgr.dll.

---

## AddDirToPath()

The `AddDirToPath()` function adds a directory to the Path.

### Syntax

C/C++:
```
DWORD AddDirToPath(LPWSTR DirName; DWORD PathType; DWORD AddType);
```

Pascal:
```
function AddDirToPath(DirName: PWideChar; PathType, AddType: DWORD): DWORD;
```

### Parameters

`DirName`

A Unicode string containing the name of the directory to be added to the Path.

`PathType`

Specify 0 to add the directory to the system Path or 1 to add the directory to the current user Path.

`AddType`

Specify 0 to add the directory to the end of the Path or 1 to add the directory to the beginning of the Path. If you are adding to the system Path (i.e., `PathType` is 0), it is recommended to specify 0 for this parameter.

### Return Value

If the specified directory already exists in the Path, the function returns `ERROR_ALREADY_EXISTS` (183). Otherwise, the function returns 0 for success or non-zero for failure.

The function returns `ERROR_INVALID_PARAMETER` (87) for any of the following cases:

* `DirName` specifies an invalid directory name
* `PathType` is not a valid value
* `AddType` is not a valid value

Updating the system Path requires administrative permissions; if you attempt to update the system Path from an unelevated process, the function will return `ERROR_ACCESS_DENIED` (5).

### Remarks

The `AddDirToPath()` function checks whether the directory name exists in both the unexpanded and expanded copies of the Path. For example, if one of the directories in the Path is `%TESTAPP%`, and the `TESTAPP` environment variable is set to `C:\Test`, the function will return `ERROR_ALREADY_EXISTS` (183) if you specify either `%TESTAPP%` or `C:\Test` for the `DirName` parameter.

---

## GetPath()

The `GetPath()` function retrieves a newline-delimited list of directories in the Path.

### Syntax

C/C++:
```
DWORD GetPath(DWORD PathType; DWORD Expand; Buffer: LPWSTR; DWORD NumChars);
```

Pascal:
```
function GetPath(PathType, Expand: DWORD; Buffer: PWideChar; NumChars: DWORD): DWORD;
```

### Parameters

`PathType`

Specify 0 to get the list of directories in the system Path or 1 to get the list of directories in the user Path.

`Expand`

Specify 0 not to expand environment variable references in the directory names, or a non-zero value to expand environment variable references in the directory names.

`Buffer`

A pointer to a variable that receives a Unicode string that contains the newline-delimited list of directory names.

`NumChars`

Specifies the number of characters needed to store the newline-delimited list of directory names, not including the terminating null character. To get the required number of characters needed, call the function twice. In the first call to the function, specify a null pointer for the `Buffer` parameter and 0 for the `NumChars` parameter. The function will return with the number of characters required for the buffer (not including the terminating null character). Allocate a buffer of sufficient size (don't forget to include the terminating null character), then call the function a second time to retrieve the string.

### Return Value

The function returns zero if it failed, or non-zero if it succeeded.

---

## IsDirInPath()

The `IsDirInPath()` function checks whether a directory exists in the Path.

### Syntax

C/C++:
```
DWORD IsDirInPath(LPWSTR DirName; DWORD PathType; FindType: PDWORD);
```

Pascal:
```
function IsDirInPath(DirName: PWideChar; PathType: DWORD; FindType: PDWORD): DWORD;
```

### Parameters

`DirName`

A Unicode string containing the directory name.

`PathType`

Specify 0 to check the system Path or 1 to check the current user Path.

`FindType`

A pointer to a variable that gets set to one of the following values:

* 0 - the directory was not found in the Path
* 1 - the directory was found in the unexpanded Path
* 2 - the directory was found in the expanded Path
  
### Return Value

The function returns 0 if the directory was found in the Path. If the directory was not found in the Path, the function will return 3 (`ERROR_PATH_NOT_FOUND`). If the `Path` value is missing in the registry, the function will return 2 (`ERROR_FILE_NOT_FOUND`). Other return values indicate an error returned from the system.

The function returns `ERROR_INVALID_PARAMETER` (87) for any of the following cases:

* `DirName` specifies an invalid directory name
* `PathType` is not a valid value

### Remarks

The `IsDirInPath()` function tests whether the directory name exists in the unexpanded Path (i.e., the Path value extracted from the registry without expanding any environment variable references). If the directory name exists in the unexpanded Path, the function will return 0 and the variable pointed to by the `FindType` parameter will be set to 1.

If the directory name does not exist in the unexpanded Path, the function then expands the environment variable references in the directory name and and the Path. If the expanded directory name exists in the expanded Path, the function will return 0 and the variable pointed to by the `FindType` parameter will be set to 2.

### Example 1

Given the following sytem Path string:

`%SystemRoot%;%SystemRoot%\System32`

and given the function parameters:

* `DirName`: %SystemRoot%
* `PathType`: 0

`IsDirInPath()` will return 0 and the variable pointed to by the `FindType` parameter will be set to 1, because the directory name in the `DirName` parameter exists in the unexpanded copy of the system Path.

If the `%SystemRoot%` environment variable is `C:\Windows` and you specify `C:\Windows` for the `DirName` parameter, the function will also return 0 but the variable pointed to by the `FindType` parameter will be set to 2 instead of 1 because the directory name was found in the expanded copy of the system Path.

### Example 2

Given the following user path string:

`C:\Test;%LOCALAPPDATA%\Programs\My App`

and given the function parameters:

* `DirName`: C:\Users\myname\AppData\Local\Programs\My App
* `PathType`: 1

Presuming that the `LOCALAPPDATA` environment variable is `C:\Users\myname\AppData\Local`, `IsDirInPath()` will return 0 and the variable pointed to by the `FindType` parameter will be set to 2, because the directory name in the `DirName` parameter exists in the expanded copy of the current user Path.

If you specify `%LOCALAPPDATA%\Programs\My App` for the `DirName` parameter, the function will also return 0 but the variable pointed to by the `FindType` parameter will be set to 1 instead of 2 because the directory name was found in the unexpanded copy of the current user Path.

---

## RemoveDirFromPath()

The `RemoveDirFromPath()` function removes a directory from the Path.

### Syntax

C/C++:
```
DWORD RemoveDirFromPath(LPWSTR DirName; DWORD PathType);
```

Pascal:
```
function RemoveDirFromPath(DirName: PWideChar; PathType: DWORD): DWORD;
```

### Parameters

`DirName`

A Unicode string containing the name of the directory to be removed from the Path.

`PathType`

Specify 0 to remove the directory from the system Path or 1 to remove the directory from the current user Path.

### Return Value

If the specified directory doesn't exist in the unexpanded copy of the Path, the function returns `ERROR_PATH_NOT_FOUND` (3). Otherwise, the function returns 0 for success or non-zero for failure.

The function returns `ERROR_INVALID_PARAMETER` (87) for any of the following cases:

* `DirName` specifies an invalid directory name
* `PathType` is not a valid value

Updating the system Path requires administrative permissions; if you attempt to update the system Path from an unelevated process, the function will return `ERROR_ACCESS_DENIED` (5).

### Remarks

The `RemoveDirFromPath()` function only checks whether the directory name exists in the unexpanded copy of the Path. For example, if one of the directories in the Path is `%TESTAPP%`, the `TESTAPP` environment variable is set to `C:\Test`, and you specify `C:\Test` for the `DirName` parameter, the function will return `ERROR_PATH_NOT_FOUND` (3) because `C:\Test` does not exist in the unexpanded copy of the Path.
