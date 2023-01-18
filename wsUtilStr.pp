{ Copyright (C) 2021-2023 by Bill Stewart (bstewart at iname.com)

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

unit wsUtilStr;

interface

uses
  Windows;

type
  TArrayOfString = array of UnicodeString;

// Returns true if the specified directory name is a valid name to use in
// the Path
function IsValidPath(const Path: UnicodeString): Boolean;

// Apppends S to Dest using delimiter
procedure JoinString(var Dest: UnicodeString; const S, Delim: UnicodeString);

// Normalizes the specified path: Removes redundant '\' in middle and end
// of path; if the path specifies a drive letter and ':' only, returns the
// drive letter and ':' with trailing '\'
function NormalizePath(Path: UnicodeString): UnicodeString;

// Returns true if the two strings are the same; not case-sensitive
function SameText(const S1, S2: UnicodeString): Boolean;

// Splits S into the Dest array using Delim as a delimiter
procedure StrSplit(S, Delim: UnicodeString; var Dest: TArrayOfString);

// Returns true if the string contains one or more non-whitespace characters
function StrHasNonWhitespace(const S: UnicodeString): Boolean;

// Converts the specified string to a number and returns the result; if the
// conversion fails, returns Def
function StrToIntDef(const S: UnicodeString; const Def: LongInt): LongInt;

// Converts the specified string to a Unicode string and returns the result
function StringToUnicodeString(const S: string; const CodePage: UINT): UnicodeString;

implementation

function StrHasNonWhitespace(const S: UnicodeString): Boolean;
const
  Whitespace: set of Char = [#9, #32];
var
  I: LongInt;
begin
  result := false;
  for I := 1 to Length(S) do
    if not (S[I] in Whitespace) then
    begin
      result := true;
      break;
    end;
end;

// See MSDN topic titled "Naming Files, Paths, and Namespaces" - currently at
// https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file
// The goal here is to identify whether a directory name we're specifying to
// add to (or remove from) the Path is valid, so (for example) ';' is not
// a valid character because Path is ';'-delimited
function IsValidPath(const Path: UnicodeString): Boolean;
const
  InvalidChars: set of Char = [#0..#31, '<', '>', ';', '"', '/', '|', '?', '*'];
  InvalidEndOfNameChars: set of Char = [#9, #32, '.'];
var
  I: LongInt;
begin
  result := StrHasNonWhitespace(Path);
  if result then
    for I := 1 to Length(Path) do
    begin
      result := not (Path[I] in InvalidChars);
      if not result then
        break;
    end;
  if result then
    result := not (Path[Length(Path)] in InvalidEndOfNameChars);
end;

procedure JoinString(var Dest: UnicodeString; const S, Delim: UnicodeString);
begin
  if Dest = '' then
    Dest := S
  else
    Dest := Dest + Delim + S;
end;

function SameText(const S1, S2: UnicodeString): Boolean;
const
  CSTR_EQUAL = 2;
var
  CompareFlags: LongInt;
begin
  CompareFlags := LINGUISTIC_IGNORECASE;
  result := CompareStringW(GetThreadLocale(),  // LCID    Local
    CompareFlags,                              // DWORD   dwCmpFlags
    PWideChar(S1),                             // PCNZWCH lpString1
    -1,                                        // int     cchCount1
    PWideChar(S2),                             // PCNZWCH lpString2
    -1) = CSTR_EQUAL;                          // int     cchCount2
end;

// Returns the position of SubString within S starting at the specified
// offset; returns 0 if SubString is not found within S
function PosEx(const SubString, S: UnicodeString; Offset: LongInt): LongInt;
var
  SubLen, MaxLen, I: LongInt;
  FirstChar: WideChar;
  pFirstChar: PWideChar;
begin
  result := 0;
  SubLen := Length(SubString);
  if (SubLen > 0) and (Offset > 0) and (Offset <= Length(S)) then
  begin
    MaxLen := Length(S) - SubLen;
    FirstChar := SubString[1];
    I := IndexWord(S[Offset], Length(S) - Offset + 1, Word(FirstChar));
    while (I >= 0) and ((Offset + I - 1) <= MaxLen) do
    begin
      pFirstChar := @S[Offset + I];
      if CompareWord(SubString[1], pFirstChar^, SubLen) = 0 then
        exit(Offset + I);
      Offset := Offset + I + 1;
      I := IndexWord(S[Offset], Length(S) - Offset + 1, Word(FirstChar));
    end;
  end;
end;

// Returns the number of times SubString appears in S
function CountSubstring(const SubString, S: UnicodeString): LongInt;
var
  P: LongInt;
begin
  result := 0;
  P := PosEx(SubString, S, 1);
  while P <> 0 do
  begin
    Inc(result);
    P := PosEx(SubString, S, P + Length(SubString));
  end;
end;

procedure StrSplit(S, Delim: UnicodeString; var Dest: TArrayOfString);
var
  I, P: LongInt;
begin
  I := CountSubstring(Delim, S);
  // If no delimiters, then Dest is a single-element array
  if I = 0 then
  begin
    SetLength(Dest, 1);
    Dest[0] := S;
    exit();
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

function NormalizePath(Path: UnicodeString): UnicodeString;
var
  Parts: TArrayOfString;
  Prefix: UnicodeString;
  I: LongInt;
begin
  result := Path;
  StrSplit(Path, '\', Parts);
  // No delimiters
  if Length(Parts) < 2 then
    exit();
  Prefix := '';
  // Preserve leading '\\' or '\'
  if Pos('\\', Path) = 1 then
    Prefix := '\\'
  else if Path[1] = '\' then
    Prefix := '\';
  Path := '';
  for I := 0 to Length(Parts) - 1 do
  begin
    if Length(Parts[I]) > 0 then
      JoinString(Path, Parts[I], '\');
  end;
  // If path is drive letter and ':' only, add trailing '\'
  if (Length(Path) = 2) and (Path[2] = ':') then
    Path := Path + '\';
  result := Prefix + Path;
end;

function StrToIntDef(const S: UnicodeString; const Def: LongInt): LongInt;
var
  Code: Word;
begin
  Val(S, result, Code);
  if Code > 0 then
    result := Def;
end;

function StringToUnicodeString(const S: string; const CodePage: UINT): UnicodeString;
var
  NumChars, BufSize: DWORD;
  pBuffer: PWideChar;
begin
  result := '';
  // Get number of characters needed for buffer
  NumChars := MultiByteToWideChar(CodePage,  // UINT   CodePage
    0,                                       // DWORD  dwFlags
    PChar(S),                                // LPCCH  lpMultiByteStr
    -1,                                      // int    cbMultiByte
    nil,                                     // LPWSTR lpWideCharStr
    0);                                      // int    cchWideChar
  if NumChars > 0 then
  begin
    BufSize := NumChars * SizeOf(WideChar);
    GetMem(pBuffer, BufSize);
    if MultiByteToWideChar(CP_OEMCP,  // UINT   CodePage
      0,                              // DWORD  dwFlags
      PChar(S),                       // LPCCH  lpMultiByteStr
      -1,                             // int    cbMultiByte
      pBuffer,                        // LPWSTR lpWideCharStr
      NumChars) > 0 then              // int    cchWideChar
      result := pBuffer;
    FreeMem(pBuffer, BufSize);
  end;
end;

function UnicodeStringToString(const S: UnicodeString; const CodePage: UINT): string;
var
  NumChars, BufSize: DWORD;
  pBuffer: PChar;
begin
  result := '';
  // Get number of characters needed for buffer
  NumChars := WideCharToMultiByte(CodePage,  // UINT   CodePage
    0,                                       // DWORD  dwFlags
    PWideChar(S),                            // LPCWCH lpWideCharStr
    -1,                                      // int    cchWideChar
    nil,                                     // LPSTR  lpMultiByteStr
    0,                                       // int    cbMultiByte
    nil,                                     // LPCCH  lpDefaultChar
    nil);                                    // LPBOOL lpUsedDefaultChar
  if NumChars > 0 then
  begin
    BufSize := NumChars * SizeOf(Char);
    GetMem(pBuffer, BufSize);
    if WideCharToMultiByte(CP_OEMCP,  // UINT   CodePage
      0,                              // DWORD  dwFlags
      PWideChar(S),                   // LPCWCH lpWideCharStr
      -1,                             // int    cchWideChar
      pBuffer,                        // LPSTR  lpMultiByteStr
      NumChars,                       // int    cbMultiByte
      nil,                            // LPCCH  lpDefaultChar
      nil) > 0 then                   // LPBOOL lpUsedDefaultChar
      result := pBuffer;
    FreeMem(pBuffer, BufSize);
  end;
end;

begin
end.
