# PathMgr/PathMan Version History

## 2.0.0 (18 Mar 2024)

* Added support for directory names containing the `;` character. Such directories are enclosed in quotes (`"`) in the Path string.

* Updated all character and string processing code to use Unicode only.

* Fix: If adding an environment variable as a directory name and it expands to a drive letter and path only (e.g., `%SystemDrive%`), add trailing `\`).

* Redesigned EditPath utility, renamed it to PathMan, and set at version 2.0.0.0 to match the PathMgr.dll file.

* Corrected file type in PathMgr.dll resource.

## 1.0.4 (18 Jan 2023)

* Fix Inno Setup script sample: Delete PathMgr.dll only if uninstall was not canceled by user. (Thanks to vadimgrn on GitHub for reporting this issue.)

* Fix: Strings containing non-whitespace characters detected correctly.

* Minor tweaks.

## 1.0.3 (10 Jun 2021)

* Update code formatting.

* String-read from registry updated to avoid potential (but very low probability) buffer overflow error.

* Correct typographical errors in EditPath markdown doc.

* Compile using FPC 3.2.2.

* Minor tweaks.

## 1.0.2 (18 Mar 2021)

* Fix Inno Setup script sample: Modify path both when task was previously selected or currently selected.

* Fix PowerShell sample script: Get full path of DLL file when running script.

## 1.0.1 (29 Jan 2021)

* Fix: Validate `PathType` parameter for `IsDirInPath` function.

* Fix: Corrected version check for Inno Setup sample script (thanks to Martijn Laan).

## 1.0.0 (27 Jan 2021)

* Initial version.
