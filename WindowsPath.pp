{ Copyright (C) 2024 by Bill Stewart (bstewart at iname.com)

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

unit WindowsPath;

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}

interface

uses
  windows,
  WindowsRegistry;

type
  TPathType = (PathTypeSystem, PathTypeUser);
  TPathAddType = (PathAddTypeEnd, PathAddTypeBeginning);
  TPathFindType = (PathFindTypeNotFound, PathFindTypeUnexpanded, PathFindTypeExpanded);

function GetPath(const PathType: TPathType; const Expand: Boolean;
  out Path: string): LSTATUS;

function IsDirInPath(DirName: string; const PathType: TPathType;
  out FindType: TPathFindType): LSTATUS;

function AddDirToPath(DirName: string; const PathType: TPathType;
  const PathAddType: TPathAddType): LSTATUS;

function RemoveDirFromPath(DirName: string; const PathType: TPathType): LSTATUS;

implementation

const
  WINDOWS_PATH_DELIMITER = ';';
  WINDOWS_PATH_MACHINE_REGISTRY_SUBKEY = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';
  WINDOWS_PATH_USER_REGISTRY_SUBKEY = 'Environment';
  {$IFDEF DEBUG}
  WINDOWS_PATH_REGISTRY_VALUE = 'Test';
  {$ELSE}
  WINDOWS_PATH_REGISTRY_VALUE = 'Path';
  {$ENDIF}

type
  TStringArray = array of string;

function ExpandEnvStrings(const S: string): string;
var
  NumChars, BufSize: DWORD;
  pBuffer: PChar;
begin
  result := S;
  NumChars := ExpandEnvironmentStringsW(PChar(S),  // LPCWSTR lpSrc
    nil,                                           // LPWSTR  lpDst
    0);                                            // DWORD   nSize
  if NumChars = 0 then
    exit;
  BufSize := NumChars * SizeOf(Char);
  GetMem(pBuffer, BufSize);
  if ExpandEnvironmentStringsW(PChar(S),  // LPCWSTR lpSrc
    pBuffer,                              // LPWSTR  lpDst
    NumChars) > 0 then                    // DWORD   nSize
  begin
    result := string(pBuffer);
  end;
  FreeMem(pBuffer);
end;

function TrimPathElement(S: string; const KeepQuotes: Boolean): string;
var
  I, J: Integer;
begin
  if not KeepQuotes then
  begin
    // Trim leading quotes
    I := Length(S);
    if I > 0 then
    begin
      J := 1;
      while (J <= I) and (S[J] = '"') do
        Inc(J);
      if J > 1 then
        Delete(S, 1, J - 1);
    end;
    // Trim trailing quotes
    I := Length(S);
    if I > 0 then
    begin
      J := I;
      while (J > 0) and (S[J] = '"') do
        Dec(J);
      if J <> I then
        SetLength(S, J);
    end;
  end;
  // Trim trailing tabs, spaces
  I := Length(S);
  if I > 0 then
  begin
    J := I;
    while (J > 0) and ((S[J] = #9) or (S[J] = ' ')) do
      Dec(J);
    if J <> I then
      SetLength(S, J);
  end;
  result := S;
end;

// Splits a Windows path string into individual path elements:
// * Path elements are delimited by the semicolon (';') character
// * Path elements can be enclosed in quotes (") to include ';' characters
// * Quotes are not included in path elements
// * Trailing whitespace is removed from path elements
// * Empty path elements are skipped
procedure GetPathElements(const PathString: string; var PathElements: TStringArray);
var
  Path: string;
  Delims, I, NumEmpty: Integer;
  InQuote: Boolean;
  pD, pC: PChar;
  PathElement: string;
begin
  // Copy path string to local variable (we explicitly want a copy of the
  // passed PathString, because we are modifying it in-place by embedding
  // nulls; if we don't copy the string, the pointer dereferencing modifies
  // the original reference-counted copy of the string)
  SetLength(Path, Length(PathString));
  if PathString <> '' then
    Move(PathString[1], Path[1], Length(PathString) * SizeOf(Char));
  // true = keep leading and trailing quotes if present
  Path := TrimPathElement(Path, true);
  if Path = '' then
  begin
    // If path string empty, array length is zero
    SetLength(PathElements, 0);
    exit;
  end;
  // Count number of path delimiters
  Delims := 0;
  pD := PChar(Path);
  InQuote := false;
  while pD^ <> #0 do
  begin
    if (pD^ = WINDOWS_PATH_DELIMITER) and (not InQuote) then
      Inc(Delims)
    else if pD^ = '"' then
      InQuote := not InQuote;
    Inc(pD);
  end;
  // Set array length
  SetLength(PathElements, Delims + 1);
  // Populate array
  I := 0;             // Current array element index
  NumEmpty := 0;      // No empty elements yet
  pD := PChar(Path);  // Delimiter pointer
  pC := pD;
  InQuote := false;
  while pD^ <> #0 do
  begin
    if (pD^ = WINDOWS_PATH_DELIMITER) and (not InQuote) then
    begin
      pD^ := #0;  // Terminate path element string
      Inc(pD);
      PathElement := TrimPathElement(string(pC), false);
      if PathElement <> '' then
      begin
        PathElements[I] := PathElement;
        Inc(I);
      end
      else
        Inc(NumEmpty);
      pC := pD;
    end
    else if pD^ = '"' then
    begin
      InQuote := not InQuote;
      Inc(pD);
    end
    else
      Inc(pD);
  end;
  // Final path element
  PathElement := TrimPathElement(string(pC), false);
  if PathElement <> '' then
    PathElements[I] := PathElement
  else
    Inc(NumEmpty);
  // Drop empty elements, if any
  if NumEmpty > 0 then
    SetLength(PathElements, Length(PathElements) - NumEmpty);
end;

function GetPathString(const PathType: TPathType; out PathString: string): LSTATUS;
var
  RootKey: HKEY;
  SubKeyName: string;
begin
  if PathType = PathTypeSystem then
  begin
    RootKey := HKEY_LOCAL_MACHINE;
    SubKeyName := WINDOWS_PATH_MACHINE_REGISTRY_SUBKEY;
  end
  else
  begin
    RootKey := HKEY_CURRENT_USER;
    SubKeyName := WINDOWS_PATH_USER_REGISTRY_SUBKEY;
  end;
  result := RegGetStringValue('', RootKey, SubKeyName,
    WINDOWS_PATH_REGISTRY_VALUE, PathString);
end;

function SetPathString(const PathType: TPathType; const PathString: string): LSTATUS;
var
  RootKey: HKEY;
  SubKeyName: string;
begin
  if PathType = PathTypeSystem then
  begin
    RootKey := HKEY_LOCAL_MACHINE;
    SubKeyName := WINDOWS_PATH_MACHINE_REGISTRY_SUBKEY;
  end
  else
  begin
    RootKey := HKEY_CURRENT_USER;
    SubKeyName := WINDOWS_PATH_USER_REGISTRY_SUBKEY;
  end;
  result := RegSetExpandStringValue('', RootKey, SubKeyName, WINDOWS_PATH_REGISTRY_VALUE, PathString);
end;

function GetPath(const PathType: TPathType; const Expand: Boolean;
  out Path: string): LSTATUS;
var
  PathString: string;
  PathElements: TStringArray;
  I: Integer;
begin
  result := GetPathString(PathType, PathString);
  if result <> ERROR_SUCCESS then
    exit;
  if Expand then
    PathString := ExpandEnvStrings(PathString);
  GetPathElements(PathString, PathElements);
  if Length(PathElements) = 0 then
    exit;
  Path := PathElements[0];
  for I := 1 to Length(PathElements) - 1 do
    Path := Path + sLineBreak + PathElements[I];
end;

function IsPathElementValid(const Path: string): Boolean;
var
  I: Integer;
begin
  result := Path <> '';
  if not result then
    exit;
  // See https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file
  // ':' and '\' not included since they can be in a path element
  for I := 1 to Length(Path) do
  begin
    case Path[I] of
      #0..#31, '<', '>', '"', '/', '|', '?', '*':
      begin
        result := false;
        break;
      end;
    end;
  end;
  if not result then
    exit;
  case Path[Length(Path)] of
    #9, ' ', '.':
    begin
      result := false;
    end;
  end;
end;

function CountSubstring(const Substring, S: string): Integer;
var
  P: Integer;
begin
  result := 0;
  P := Pos(Substring, S, 1);
  while P <> 0 do
  begin
    Inc(result);
    P := Pos(Substring, S, P + Length(Substring));
  end;
end;

procedure StrSplit(S, Delim: string; var Dest: TStringArray);
var
  I, P: Integer;
begin
  I := CountSubstring(Delim, S);
  // If no delimiters, then Dest is a single-element array
  if I = 0 then
  begin
    SetLength(Dest, 1);
    Dest[0] := S;
    exit;
  end;
  SetLength(Dest, I + 1);
  for I := 0 to Length(Dest) - 1 do
  begin
    P := Pos(Delim, S);
    if P > 0 then
    begin
      Dest[I] := Copy(S, 1, P - 1);
      Delete(S, 1, P + Length(Delim) - 1);
    end
    else
      Dest[I] := S;
  end;
end;

function StandardizePathElement(PathElement: string): string;
var
  I: Integer;
  Parts: TStringArray;
  Prefix, ExpandedPathElement: string;
begin
  // Remove quotes
  I := Pos('"', PathElement);
  while I > 0 do
    Delete(PathElement, I, 1);
  result := PathElement;
  StrSplit(PathElement, '\', Parts);
  // No delimiters
  if Length(Parts) < 2 then
    exit;
  // Preserve leading '\\' or '\'
  if Pos('\\', PathElement) = 1 then
    Prefix := '\\'
  else if PathElement[1] = '\' then
    Prefix := '\'
  else
    Prefix := '';
  PathElement := Parts[0];
  for I := 1 to Length(Parts) - 1 do
  begin
    if Parts[I] <> '' then
      PathElement := PathElement + '\' + Parts[I];
  end;
  ExpandedPathElement := ExpandEnvStrings(PathElement);
  // If expanded path element is drive letter and ':' only, add trailing '\'
  if (Length(ExpandedPathElement) = 2) and (ExpandedPathElement[2] = ':') then
    PathElement := PathElement + '\';
  result := Prefix + PathElement;
end;

function SameText(const S1, S2: string): Boolean;
const
  CSTR_EQUAL = 2;
begin
  result := CompareStringW(GetThreadLocale(),  // LCID    Local
    LINGUISTIC_IGNORECASE,                     // DWORD   dwCmpFlags
    PChar(S1),                                 // PCNZWCH lpString1
    -1,                                        // int     cchCount1
    PChar(S2),                                 // PCNZWCH lpString2
    -1) = CSTR_EQUAL;                          // int     cchCount2
end;

function IsDirInPath(DirName: string; const PathType: TPathType;
  out FindType: TPathFindType): LSTATUS;
var
  PathString: string;
  PathElements: TStringArray;
  I: Integer;
begin
  FindType := PathFindTypeNotFound;
  if not IsPathElementValid(DirName) then
  begin
    result := ERROR_INVALID_PARAMETER;
    exit;
  end;
  result := GetPathString(PathType, PathString);
  if result <> ERROR_SUCCESS then
    exit;
  GetPathElements(PathString, PathElements);
  if Length(PathElements) = 0 then
  begin
    result := ERROR_PATH_NOT_FOUND;
    exit;
  end;
  DirName := StandardizePathElement(DirName);
  for I := 0 to Length(PathElements) - 1 do
  begin
    if SameText(DirName, StandardizePathElement(PathElements[I])) then
    begin
      FindType := PathFindTypeUnexpanded;
      exit;
    end;
  end;
  // Not found yet; try expanding environment strings
  DirName := ExpandEnvStrings(DirName);
  PathString := ExpandEnvStrings(PathString);
  GetPathElements(PathString, PathElements);
  for I := 0 to Length(PathElements) - 1 do
  begin
    if SameText(DirName, StandardizePathElement(PathElements[I])) then
    begin
      FindType := PathFindTypeExpanded;
      exit;
    end;
  end;
  result := ERROR_PATH_NOT_FOUND;
end;

function AddDirToPath(DirName: string; const PathType: TPathType;
  const PathAddType: TPathAddType): LSTATUS;
var
  FindType: TPathFindType;
  PathString: string;
begin
  result := IsDirInPath(DirName, PathType, FindType);
  if result = ERROR_SUCCESS then
  begin
    result := ERROR_ALREADY_EXISTS;
    exit;
  end;
  if not ((result = ERROR_FILE_NOT_FOUND) or (result = ERROR_PATH_NOT_FOUND)) then
    exit;
  result := GetPathString(PathType, PathString);
  if not ((result = ERROR_SUCCESS) or (result = ERROR_FILE_NOT_FOUND)) then
    exit;
  DirName := StandardizePathElement(DirName);
  // Must add quotes when adding path element containing delimiter
  if Pos(WINDOWS_PATH_DELIMITER, DirName) > 0 then
    DirName := '"' + DirName + '"';
  if (result = ERROR_FILE_NOT_FOUND) or (PathString = '') then
    PathString := DirName
  else
  begin
    if PathAddType = PathAddTypeEnd then
    begin
      if PathString[Length(PathString)] <> WINDOWS_PATH_DELIMITER then
        PathString := PathString + WINDOWS_PATH_DELIMITER + DirName
      else
        PathString := PathString + DirName;
    end
    else  // Add to beginning
    begin
      if PathString[1] <> WINDOWS_PATH_DELIMITER then
        PathString := DirName + WINDOWS_PATH_DELIMITER + PathString
      else
        PathString := DirName + PathString;
    end;
  end;
  result := SetPathString(PathType, PathString);
end;

function CountPathElements(DirName: string; var PathElements: TStringArray): Integer;
var
  I: Integer;
begin
  result := 0;
  if Length(PathElements) > 0 then
  begin
    DirName := StandardizePathElement(DirName);
    for I := 0 to Length(PathElements) - 1 do
      if SameText(DirName, StandardizePathElement(PathElements[I])) then
        Inc(result);
  end;
end;

function RemoveDirFromPath(DirName: string; const PathType: TPathType): LSTATUS;
var
  FindType: TPathFindType;
  PathString: string;
  PathElementsIn, PathElementsOut: TStringArray;
  I, J: Integer;
begin
  result := IsDirInPath(DirName, PathType, FindType);
  if result <> ERROR_SUCCESS then
    exit;
  // Only check unexpanded path
  if FindType <> PathFindTypeUnexpanded then
  begin
    result := ERROR_PATH_NOT_FOUND;
    exit;
  end;
  result := GetPathString(PathType, PathString);
  if result <> ERROR_SUCCESS then
    exit;
  if PathString = '' then
  begin
    result := ERROR_PATH_NOT_FOUND;
    exit;
  end;
  GetPathElements(PathString, PathElementsIn);
  PathString := '';  // Value to set in registry
  if Length(PathElementsIn) > 1 then
  begin
    DirName := StandardizePathElement(DirName);
    // Output array length is length of original array less the number
    // of times DirName appears in input array
    SetLength(PathElementsOut, Length(PathElementsIn) - CountPathElements(DirName, PathElementsIn));
    I := 0;
    for J := 0 to Length(PathElementsIn) - 1 do
    begin
      if not SameText(DirName, StandardizePathElement(PathElementsIn[J])) then
      begin
        // Must add quotes when adding path element containing delimiter
        if Pos(WINDOWS_PATH_DELIMITER, PathElementsIn[J]) > 0 then
          PathElementsOut[I] := '"' + PathElementsIn[J] + '"'
        else
          PathElementsOut[I] := PathElementsIn[J];
        Inc(I);
      end;
    end;
    // If Length(PathElementsOut) = 0, PathString stays empty
    if Length(PathElementsOut) > 0 then
    begin
      PathString := PathElementsOut[0];
      for I := 1 to Length(PathElementsOut) - 1 do
        PathString := PathString + WINDOWS_PATH_DELIMITER + PathElementsOut[I];
    end;
  end;
  result := SetPathString(PathType, PathString);
end;

begin
end.
