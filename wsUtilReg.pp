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
  wsUtilReg;

interface

uses
  windows;

const
  HKEY_CURRENT_USER_64 = $80000101;
  HKEY_CURRENT_USER_32 = $80000201;
  HKEY_LOCAL_MACHINE_64 = $80000102;
  HKEY_LOCAL_MACHINE_32 = $80000202;

// Returns the ValueName value from the specified key and subkey into
// ResultStr; returns 0 for success or non-zero for failure
function RegQueryStringValue(RootKey: HKEY;
                             const SubKeyName, ValueName: unicodestring;
                             var ResultStr: unicodestring): DWORD;

// Writes the specified REG_EXPAND_SZ-type regsitry value; returns 0 for
// success or non-zero for failure
function RegWriteExpandStringValue(RootKey: HKEY;
                                   const SubKey, ValueName, Data: unicodestring): DWORD;

implementation

// Updates RootKey and AccessFlags appropriately if using _32 or _64 RootKey
procedure InitRegKeyAndFlags(var RootKey: HKEY; var AccessFlags: REGSAM);
  begin
  if (RootKey and KEY_WOW64_32KEY) <> 0 then
    begin
    RootKey := RootKey and (not KEY_WOW64_32KEY);
    AccessFlags := AccessFlags or KEY_WOW64_32KEY;
    end
  else if (RootKey and KEY_WOW64_64KEY) <> 0 then
    begin
    RootKey := RootKey and (not KEY_WOW64_64KEY);
    AccessFlags := AccessFlags or KEY_WOW64_64KEY;
    end;
  end;

function RegKeyExists(RootKey: HKEY;
                      const SubKeyName: unicodestring): boolean;
  var
    AccessFlags: REGSAM;
    hkHandle: HANDLE;
  begin
  AccessFlags := KEY_READ;
  InitRegKeyAndFlags(RootKey, AccessFlags);
  result := RegOpenKeyExW(RootKey,                // HKEY    hKey
                          pwidechar(SubKeyName),  // LPCWSTR lpSubKey
                          0,                      // DWORD   ulOptions
                          AccessFlags,            // REGSAM  samDesired
                          hkHandle) = 0;          // PHKEY   phkResult
  if result then
    RegCloseKey(hkHandle);
  end;

function RegQueryStringValue(RootKey: HKEY;
                             const SubKeyName, ValueName: unicodestring;
                             var ResultStr: unicodestring): DWORD;
  var
    AccessFlags: REGSAM;
    hkHandle: HKEY;
    ValueType, ValueSize: DWORD;
    pData: pointer;
  begin
  AccessFlags := KEY_READ;
  InitRegKeyAndFlags(RootKey, AccessFlags);
  result := RegOpenKeyExW(RootKey,                // HKEY    hKey
                          pwidechar(SubKeyName),  // LPCWSTR lpSubKey
                          0,                      // DWORD   ulOptions
                          AccessFlags,            // REGSAM  samDesired
                          hkHandle);              // PHKEY   phkResult
  if result = 0 then
    begin
    // First call: Get value size
    result := RegQueryValueExW(hkHandle,              // HKEY    hKey
                               pwidechar(ValueName),  // LPCWSTR lpValueName
                               nil,                   // LPDWORD lpReserved
                               @ValueType,            // LPDWORD lpType
                               nil,                   // LPBYTE  lpData
                               @ValueSize);           // LPDWORD lpcbData
    if result = 0 then
      begin
      // Must be REG_SZ or REG_EXPAND_SZ
      if (ValueType = REG_SZ) or (ValueType = REG_EXPAND_SZ) then
        begin
        GetMem(pData, ValueSize);
        // Second call: Get value data
        result := RegQueryValueExW(hkHandle,              // HKEY    hKey
                                   pwidechar(ValueName),  // LPCWSTR lpValueName
                                   nil,                   // LPDWORD lpReserved
                                   @ValueType,            // LPDWORD lpType
                                   pData,                 // LPBYTE  lpData
                                   @ValueSize);           // LPDWORD lpcbData
        if result = 0 then
          ResultStr := pwidechar(pData);
        FreeMem(pData, ValueSize);
        end
      else
        result := ERROR_INVALID_DATA;
      end;
    RegCloseKey(hkHandle);
    end;
  end;

function RegWriteExpandStringValue(RootKey: HKEY;
                                   const SubKey, ValueName, Data: unicodestring): DWORD;
  var
    AccessFlags: REGSAM;
    hkHandle: HKEY;
    BufSize: DWORD;
  begin
  AccessFlags := KEY_ALL_ACCESS;
  InitRegKeyAndFlags(RootKey, AccessFlags);
  result := RegOpenKeyExW(RootKey,            // HKEY    hKey
                          pwidechar(SubKey),  // LPCWSTR lpSubKey
                          0,                  // DWORD   ulOptions
                          AccessFlags,        // REGSAM  samDesired
                          hkHandle);          // PHKEY   phkResult
  if result = 0 then
    begin
    // Account for length of string + terminating null
    BufSize := Length(Data) * SizeOf(widechar) + SizeOf(widechar);
    result := RegSetValueExW(hkHandle,              // HKEY       hKey
                             pwideChar(ValueName),  // LPCWSTR    lpValueName
                             0,                     // DWORD      Reserved
                             REG_EXPAND_SZ,         // DWORD      dwType
                             pwidechar(Data),       // const BYTE *lpData
                             BufSize);              // DWORD      cbData
    RegCloseKey(hkHandle);
    end;
  end;

begin
end.
