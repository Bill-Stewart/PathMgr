# PathMan

PathMan is a Windows console (text-based, command-line) program for managing the system Path and user Path.

# Author

Bill Stewart - bstewart at iname dot com

# License

PathMan.exe is covered by the GNU Lesser Public License (LPGL). See the file `LICENSE` for details.

# Download

https://github.com/Bill-Stewart/PathMgr/releases/

# Background

The system Path is found in the following location in the Windows registry:

Root: `HKEY_LOCAL_MACHINE`  
Subkey: `SYSTEM\CurrentControlSet\Control\Session Manager\Environment`  
Value name: `Path`  
Value type: `REG_EXPAND_SZ`

The current user Path is found in the following location in the registry:

Root: `HKEY_CURRENT_USER`  
Subkey: `Environment`  
Value name: `Path`  
Value type: `REG_EXPAND_SZ`

The registry value type `REG_EXPAND_SZ` means the string caan contain values surrounded by `%` characters that Windows will automatically expand to environment variable values. (For example, `%SystemRoot%` will be expanded to `C:\Windows` on most systems.)

The `Path` value contains a `;`-delimited list of directory names that the operating system should search for executables, library files, scripts, etc. Windows appends the content of the current user Path to the system Path, and expands the environment variable references, and sets the resulting string as the `Path` environment variable for new processes.

PathMan provides a command-line interface for managing the `Path` value in the system location (in `HKEY_LOCAL_MACHINE`) and the current user location (in `HKEY_CURRENT_USER`).

# Usage

The following describes the command-line usage for the program. Parameters are case-sensitive.

**PathMan** _scope_ _action_ [_option_ [...]]

You must specify only one of the following _scope_ parameters:

| _scope_      | Abbreviation | Description
| -------      | ------------ | -----------
| **--system** | **-s**       | Specifies the system Path
| **--user**   | **-u**       | Specifies the current user Path

You must specify only one of the following _action_ parameters:

| _action_                     | Abbreviation           | Description
| --------                     | ------------           | -----------
| **--list**                   | **-l**                 | Lists directories in Path
| **--test "**_dirname_**"**   | **-t "**_dirname_**"** | Tests if directory is in Path
| **--add "**_dirname_**"**    | **-a "**_dirname_**"** | Adds directory to Path
| **--remove "**_dirname_**"** | **-r "**_dirname_**"** | Removes directory from Path

The following parameters are optional:

| _option_        | Abbreviation | Description
| ---------       | ------------ | -----------
| **--expand**    | **-x**       | Expands environment variables (**--list** only)
| **--beginning** | **-b**       | Adds to beginning of Path (**--add** only)
| **--quiet**     | **-q**       | Suppresses result and error messages

# Exit Codes

The following table lists typical exit codes when not using **--test** (**-t**):

| Exit Code | Description
| --------- | -----------
| 0         | No errors
| 2         | The Path value is missing from the registry
| 3         | The specified directory does not exist in the Path
| 5         | Access is denied
| 87        | Incorrect parameter(s)
| 183       | The specified directory already exists in the Path

The following table lists typical exit codes when using **--test** (**-t**):

| Exit Code | Description
| --------- | -----------
| 1         | The specified directory exists in the unexpanded Path
| 2         | The specified directory exists in the expanded Path
| 3         | The specified directory does not exist in the Path

# Remarks

*   "Unexpanded" vs. "expanded" refers to whether PathMan expands environment variable references (i.e., names between `%` characters) after retrieving the Path value from the registry. For example, `%SystemRoot%` is unexpanded but `C:\Windows` is expanded.

*   The **--add** (**-a**) parameter checks whether the specified directory exists in both the unexpanded and expanded copies of the Path before adding the directory. For example, if the environment variable `TESTAPP` is set to `C:\TestApp` and `%TESTAPP%` is in the Path, specifying `--add C:\TestApp` will return exit code 183 (i.e., the directory already exists in the Path) because `%TESTAPP%` expands to `C:\TestApp`.

*   The **--remove** (**-r**) parameter does not expand environment variable references. For example, if the environment variable `TESTAPP` is set to `C:\TestApp` and `%TESTAPP%` is in the Path, specifying `--remove "C:\TestApp"` will return exit code 3 (i.e., the directory does not exist in the Path) because **--remove** does not expand `%TESTAPP%` to `C:\TestApp`. For the command to succeed, you would have to specify `--remove "%TESTAPP%"` instead.

*   The program will exit with error code 87 if a parameter (or an argument to a parameter) is missing or not valid, if mutually exclusive parameters are specified, etc.

*   The program will exit with error code 5 if the current user does not have permission to update the Path value in the registry (for example, if you try to update the system Path using a standard user account or an unelevated administrator account).

*   Working with environment variable strings at the cmd.exe command prompt can be tricky because cmd.exe always expands environment variable references. One way to work around this is to set a temporary environment variable using the `^` character to escape each `%` character, then use the temporary environment variable in the PathMan command. See **Examples**, below, for an example. This issue doesn't occur in PowerShell because PowerShell doesn't expand environment variables names enclosed in `%` characters.

*   If a directory name contains the `;` character, PathMan will add it to the Path in the registry with surrounding quote characters (`"`). The quotes around the directory name are required to inform the operating system that the enclosed string is a single directory name. For example, consider the following Path string:

        C:\dir 1;"C:\dir;2";C:\dir3

    Without the quote marks enclosing the `C:\dir;2` directory, the system would incorrectly "split" the path name into the following directory names:

        C:\dir 1
        C:\dir
        2
        C:\dir3

    In other words, the `"` characters around the `C:\dir;2` directory "protect" the `;` character and inform the system that `C:\dir;2` is a single directory name. (The `"` marks themselves are not part of the directory name.)

# Examples

1.  List directories in the system Path, expanding all environment varable references:

        PathMan --system --list --expand

    You can also write this command as `PathMan -s -l -x`.

2.  Add a directory to the current user from the cmd.exe command line:

        set _T=^%LOCALAPPDATA^%
        PathMan --user --add "%_T%\Programs\My App"
        set _T=

    This sequence of commands adds the directory `%LOCALAPPDATA%\Programs\My App` to the current user Path. The first command sets a temporary environment variable to the literal string `%LOCALAPPDATA%` (the `^` characters "escape" the `%` characters). The second command adds the directory to the current user Path (cmd.exe expands `%_T%` to the literal string `%LOCALAPPDATA%`), and the third command removes the temporary variable from the environment.

3.  Remove a directory from the system Path:

        PathMan -s -r "C:\Program Files\MyApp\bin"

4. Tests if a directory is in the path:

        PathMan -s --test "C:\Program Files (x86)\MyApp\bin"

    This command returns an exit code of 3 if the specified directory is not in the system Path, 1 if the specified directory is in the unexpanded copy of the system Path, or 2 if the specified directory is in the expanded copy of the system Path.
