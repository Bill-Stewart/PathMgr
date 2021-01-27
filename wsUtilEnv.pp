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
  wsUtilEnv;

interface

// Expands environment variable references (e.g., %varname%) in the named
// string and returns the resulting string with expanded references
function ExpandEnvStrings(const Name: unicodestring): unicodestring;

// Gets the value of the named environment variable; returns an empty string
// if the variable doesn't exist
function GetEnvVar(const Name: unicodestring): unicodestring;

implementation

uses
  windows;

function ExpandEnvStrings(const Name: unicodestring): unicodestring;
  var
    NumChars, BufSize: DWORD;
    pBuffer: pwidechar;
  begin
  result := '';
  // Get number of characters needed for buffer
  NumChars := ExpandEnvironmentStringsW(pwidechar(Name),  // LPCWSTR lpSrc
                                        nil,              // LPWSTR  lpDst
                                        0);               // DWORD   nSize
  if NumChars > 0 then
    begin
    BufSize := NumChars * SizeOf(widechar);
    GetMem(pBuffer, BufSize);
    if ExpandEnvironmentStringsW(pwidechar(Name),    // LPCWSTR lpSrc
                                 pBuffer,            // LPWSTR  lpDst
                                 NumChars) > 0 then  // DWORD   nSize
      result := pBuffer;
    FreeMem(pBuffer, BufSize);
    end;
  end;

function GetEnvVar(const Name: unicodestring): unicodestring;
  var
    NumChars, BufSize: DWORD;
    pBuffer: pwidechar;
  begin
  result := '';
  // Get number of characters needed for buffer
  NumChars := GetEnvironmentVariableW(pwidechar(Name),  // LPCWSTR lpName
                                      nil,              // LPWSTR  lpBuffer
                                      0);               // DWORD   nSize
  if NumChars > 0 then
    begin
    BufSize := NumChars * SizeOf(widechar);
    GetMem(pBuffer, BufSize);
    if GetEnvironmentVariableW(pwidechar(Name),    // LPCWSTR lpName
                               pBuffer,            // LPWSTR  lpBuffer
                               NumChars) > 0 then  // DWORD   nSize
      result := pBuffer;
    FreeMem(pBuffer, BufSize);
    end;
  end;

begin
end.
