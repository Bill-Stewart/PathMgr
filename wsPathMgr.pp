{ Copyright (C) 2021 by Bill Stewart (bstewart at iname.com)

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the Free
  Software Foundation; either version 3 of the License, or (at your option) any
  later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
  details.

  You should have received a copy of the GNU Lesser General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

{$MODE OBJFPC}
{$H+}

unit
  wsPathMgr;

interface

type
  TPathType = (SystemPath,UserPath);
  TPathAddType = (AppendDirToPath,AppendPathToDir);
  TPathFindType = (NotFound,FoundInUnexpandedPath,FoundInExpandedPath);

// Gets the system or user Path, expanding if requested, to the specified
// newline-delimited result string; returns 0 for success or non-zero for
// failure
function wsGetPath(const PathType: TPathType; const Expand: boolean; var ResultStr: unicodestring): DWORD;

// For all following functions: If the directory name is empty or contains one
// or more invalid characters, return value will be ERROR_INVALID_PARAMETER

// Checks if a directory exists in the system or user Path; typical return
// values:
// * ERROR_SUCCESS - directory was found in Path
// * ERROR_FILE_NOT_FOUND - Path registry value not found
// * ERROR_PATH_NOT_FOUND - directory was not found in Path
// Other exit codes indicate an error
function wsIsDirInPath(DirName: unicodestring; const PathType: TPathType; var PathFindType: TPathFindType): DWORD;

// Adds a directory to the end or beginning of the system or user Path; if the
// directory already exists in the unexpanded or expanded Path, returns
// ERROR_SUCCESS for success, or ERROR_ALREADY_EXISTS if the directory already
// exists in the unexpanded or expanded Path; other exit codes indicate an
// error
function wsAddDirToPath(DirName: unicodestring; const PathType: TPathType; const PathAddType: TPathAddType): DWORD;

// Removes the specified directory from the system or user Path; returns
// ERROR_SUCCESS for success, or ERROR_PATH_NOT_FOUND if the directory does not
// exit in the unexpanded Path; other exit codes indicate an error
function wsRemoveDirFromPath(DirName: unicodestring; const PathType: TPathType): DWORD;

implementation

uses
  windows,
  wsUtilArch,
  wsUtilEnv,
  wsUtilReg,
  wsUtilStr;

const
  REG_VALUE_NAME = 'Path';

// Initializes RegRoot and SubKeyName based on PathType
procedure InitRegKeyAndPath(const PathType: TPathType; var RegRoot: HKEY; var SubKeyName: unicodestring);
  begin
  if PathType = SystemPath then
    begin
    if IsWin64() then
      RegRoot := HKEY_LOCAL_MACHINE_64
    else
      RegRoot := HKEY_LOCAL_MACHINE;
    SubKeyName := 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';
    end
  else
    begin
    if IsWin64() then
      RegRoot := HKEY_CURRENT_USER_64
    else
      RegRoot := HKEY_CURRENT_USER;
    SubKeyName := 'Environment';
    end;
  end;

function wsGetPath(const PathType: TPathType; const Expand: boolean; var ResultStr: unicodestring): DWORD;
  const
    NEWLINE: unicodestring = #13 + #10;
  var
    RegRoot: HKEY;
    SubKeyName, Path: unicodestring;
    Dirs: TArrayOfString;
    I: longint;
  begin
  InitRegKeyAndPath(PathType, RegRoot, SubKeyName);
  result := RegQueryStringValue(RegRoot, SubKeyName, REG_VALUE_NAME, Path);
  if result <> ERROR_SUCCESS then exit();
  if Expand then Path := ExpandEnvStrings(Path);
  ResultStr := '';
  StrSplit(Path, ';', Dirs);
  for I := 0 to Length(Dirs) - 1 do
    if StrHasNonWhitespace(Dirs[I]) then JoinString(ResultStr, NormalizePath(Dirs[I]), NEWLINE);
  end;

function wsIsDirInPath(DirName: unicodestring; const PathType: TPathType; var PathFindType: TPathFindType): DWORD;
  var
    RegRoot: HKEY;
    SubKeyName, Path: unicodestring;
    Dirs: TArrayOfString;
    I: longint;
  begin
  if not IsValidPath(DirName) then exit(ERROR_INVALID_PARAMETER);
  InitRegKeyAndPath(PathType, RegRoot, SubKeyName);
  result := RegQueryStringValue(RegRoot, SubKeyName, REG_VALUE_NAME, Path);
  if result <> ERROR_SUCCESS then exit();
  // Normalize directory name
  DirName := NormalizePath(DirName);
  // Search without expanding environment variable references
  StrSplit(Path, ';', Dirs);
  for I := 0 to Length(Dirs) - 1 do
    if SameText(DirName, NormalizePath(Dirs[I])) then
      begin
      PathFindType := FoundInUnexpandedPath;
      exit(ERROR_SUCCESS);
      end;
  // Not found yet; expand environment variable references and try again
  DirName := ExpandEnvStrings(DirName);
  Path := ExpandEnvStrings(Path);
  StrSplit(Path, ';', Dirs);
  for I := 0 to Length(Dirs) - 1 do
    if SameText(DirName, NormalizePath(Dirs[I])) then
      begin
      PathFindType := FoundInExpandedPath;
      exit(ERROR_SUCCESS);
      end;
  PathFindType := NotFound;
  exit(ERROR_PATH_NOT_FOUND);
  end;

function wsAddDirToPath(DirName: unicodestring; const PathType: TPathType; const PathAddType: TPathAddType): DWORD;
  var
    PathFindType: TPathFindType;
    RegRoot: HKEY;
    SubKeyName, Path: unicodestring;
  begin
  if not IsValidPath(DirName) then exit(ERROR_INVALID_PARAMETER);
  result := wsIsDirInPath(DirName, PathType, PathFindType);
  if result = ERROR_SUCCESS then exit(ERROR_ALREADY_EXISTS);
  if not ((result = ERROR_FILE_NOT_FOUND) or (result = ERROR_PATH_NOT_FOUND)) then exit();
  InitRegKeyAndPath(PathType, RegRoot, SubKeyName);
  result := RegQueryStringValue(RegRoot, SubKeyName, REG_VALUE_NAME, Path);
  if (result = ERROR_SUCCESS) or (result = ERROR_FILE_NOT_FOUND) then
    begin
    DirName := NormalizePath(DirName);
    if result = ERROR_FILE_NOT_FOUND then
      Path := DirName
    else
      begin
      if PathAddType = AppendDirToPath then
        begin
        if (Path <> '') and (Path[Length(Path)] <> ';') then Path := Path + ';';
        Path := Path + DirName;
        end
      else if PathAddType = AppendPathToDir then
        begin
        if (Path <> '') and (Path[1] <> ';') then Path := ';' + Path;
        Path := DirName + Path;
        end;
      end;
    result := RegWriteExpandStringValue(RegRoot, SubKeyName, REG_VALUE_NAME, Path);
    end;
  end;

// Counts the number of times a directory name appears in an array of directory
// names
function CountDirInDirs(DirName: unicodestring; var Dirs: TArrayOfString): DWORD;
  var
    I: longint;
  begin
  result := 0;
  if Length(Dirs) > 0 then
    begin
    DirName := NormalizePath(DirName);
    for I := 0 to Length(Dirs) - 1 do
      if SameText(DirName, NormalizePath(Dirs[I])) then Inc(result);
    end;
  end;

function wsRemoveDirFromPath(DirName: unicodestring; const PathType: TPathType): DWORD;
  var
    PathFindType: TPathFindType;
    RegRoot: HKEY;
    SubKeyName, Path: unicodestring;
    InDirs, OutDirs: TArrayOfString;
    J, I: longint;
  begin
  if not IsValidPath(DirName) then exit(ERROR_INVALID_PARAMETER);
  result := wsIsDirInPath(DirName, PathType, PathFindType);
  if result <> ERROR_SUCCESS then exit();
  // Only look in unexpanded path
  if PathFindType <> FoundInUnexpandedPath then exit(ERROR_PATH_NOT_FOUND);
  InitRegKeyAndPath(PathType, RegRoot, SubKeyName);
  result := RegQueryStringValue(RegRoot, SubKeyName, REG_VALUE_NAME, Path);
  if result <> ERROR_SUCCESS then exit();
  if Length(Path) = 0 then exit(ERROR_PATH_NOT_FOUND);
  StrSplit(Path, ';', InDirs);
  Path := '';  // reuse this to write new registry value
  if Length(InDirs) > 1 then
    begin
    DirName := NormalizePath(DirName);
    // Output array length is length of original array less the number
    // of times DirName appears in input array
    SetLength(OutDirs, Length(InDirs) - CountDirInDirs(DirName, InDirs));
    J := 0;
    for I := 0 to Length(InDirs) - 1 do
      begin
      if not SameText(DirName, NormalizePath(InDirs[I])) then
        begin
        OutDirs[J] := InDirs[I];
        Inc(J);
        end;
      end;
    // Build new Path string using output array
    for I := 0 to Length(OutDirs) - 1 do
      JoinString(Path, OutDirs[I], ';');
    end;
  result := RegWriteExpandStringValue(RegRoot, SubKeyName, REG_VALUE_NAME, Path);
  end;

begin
end.
