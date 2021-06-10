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

unit wsUtilArch;

interface

uses
  Windows;

// Returns true if the current OS is 64-bit or false otherwise
function IsWin64(): Boolean;

// Returns true if the current process is WoW64 (i.e., 32-bit running on a
// 64-bit OS), or false otherwise
function IsProcessWoW64(): Boolean;

implementation

function IsProcessor64Bit(): Boolean;
const
  PROCESSOR_ARCHITECTURE_INTEL   = 0;
  PROCESSOR_ARCHITECTURE_ARM     = 5;
  PROCESSOR_ARCHITECTURE_IA64    = 6;
  PROCESSOR_ARCHITECTURE_AMD64   = 9;
  PROCESSOR_ARCHITECTURE_ARM64   = 12;
  PROCESSOR_ARCHITECTURE_UNKNOWN = $FFFF;
type
  TGetNativeSystemInfo = procedure(var lpSystemInfo: SYSTEM_INFO); stdcall;
var
  Kernel32: HMODULE;
  GetNativeSystemInfo: TGetNativeSystemInfo;
  SystemInfo: SYSTEM_INFO;
begin
  result := false;
  Kernel32 := GetModuleHandle('kernel32');  // LPCSTR lpModuleName
  GetNativeSystemInfo := TGetNativeSystemInfo(GetProcAddress(Kernel32, 'GetNativeSystemInfo'));
  if Assigned(GetNativeSystemInfo) then
  begin
    GetNativeSystemInfo(SystemInfo);  // LPSYSTEM_INFO lpSystemInfo
    with SystemInfo do
      result := (wProcessorArchitecture = PROCESSOR_ARCHITECTURE_IA64) or
        (wProcessorArchitecture = PROCESSOR_ARCHITECTURE_AMD64) or
        (wProcessorArchitecture = PROCESSOR_ARCHITECTURE_ARM64);
  end;
end;

function IsProcessWoW64(): Boolean;
type
  TIsWow64Process = function(hProcess: HANDLE; var Wow64Process: BOOL): BOOL; stdcall;
var
  Kernel32: HMODULE;
  IsWow64Process: TIsWow64Process;
  ProcessHandle: HANDLE;
  IsWoW64: BOOL;
begin
  result := false;
  Kernel32 := GetModuleHandle('kernel32');  // LPCSTR lpModuleName
  IsWow64Process := TIsWow64Process(GetProcAddress(Kernel32, 'IsWow64Process'));
  if Assigned(IsWow64Process) then
  begin
    ProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION,  // DWORD dwDesiredAccess
      true,                                                  // BOOL  bInheritHandle
      GetCurrentProcessId());                                // DWORD dwProcessId
    if ProcessHandle <> 0 then
    begin
      if IsWow64Process(ProcessHandle,  // HANDLE hProcess
        IsWoW64) then                   // PBOOL  Wow64Process
        result := IsWoW64;
      CloseHandle(ProcessHandle);  // HANDLE hObject
    end;
  end;
end;

function IsWin64(): Boolean;
begin
{$IFDEF WIN64}
  // compiled on x64
  result := true;
{$ELSE}
  // true if processor is 64-bit and current process is WoW64
  result := IsProcessor64Bit() and IsProcessWoW64();
{$ENDIF}
end;

begin
end.
