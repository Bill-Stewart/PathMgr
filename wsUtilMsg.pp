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
  wsUtilMsg;

interface

uses
  windows;

// For the specified string, replaces '%1' ('%2', etc.) in the string with the
// values from the Args array; if the Args array contains an insufficient
// number of elements, the message string is returned unmodified
function FormatMessageInsertArgs(const Msg: unicodestring; const Args: array of unicodestring): unicodestring;

// For the following functions, the parameters are as follows:
//
// MessageId - the Windows message number [e.g., from GetLastError() function]
//
// AddId - if true, appends the error number (in decimal) to the end of the
// returned message
//
// Module - If specified, names a module that the FormatMessage() function
// should search for messages
//
// Args - If specified, provides an array of arguments that will be used to
// replace the '%1' ('%2', etc.) placeholders in the message string; if the
// Args array contains an insufficient number of elements, the message string
// is returned unmodified

function GetWindowsMessage(const MessageId: DWORD): unicodestring;

function GetWindowsMessage(const MessageId: DWORD; const AddId: boolean): unicodestring;

function GetWindowsMessage(const MessageId: DWORD; const Module: unicodestring): unicodestring;

function GetWindowsMessage(const MessageId: DWORD; const Module: unicodestring; const AddId: boolean): unicodestring;

function GetWindowsMessage(const MessageId: DWORD; const Args: array of unicodestring): unicodestring;

function GetWindowsMessage(const MessageId: DWORD; const AddId: boolean; const Args: array of unicodestring): unicodestring;

function GetWindowsMessage(const MessageId: DWORD; const Module: unicodestring; const Args: array of unicodestring): unicodestring;

function GetWindowsMessage(const MessageId: DWORD; const Module: unicodestring; const AddId: boolean; const Args: array of unicodestring): unicodestring;

implementation

function FormatMessageFromSystem(const MessageId: DWORD; const AddId: boolean = false; const Module: unicodestring = ''): unicodestring;
  var
    MsgFlags: DWORD;
    ModuleHandle: HMODULE;
    pBuffer: pwidechar;
    StrID: unicodestring;
  begin
  MsgFlags := FORMAT_MESSAGE_MAX_WIDTH_MASK or
    FORMAT_MESSAGE_ALLOCATE_BUFFER or
    FORMAT_MESSAGE_FROM_SYSTEM or
    FORMAT_MESSAGE_IGNORE_INSERTS;
  ModuleHandle := 0;
  if Module <> '' then
    begin
    ModuleHandle := LoadLibraryExW(pwidechar(Module),          // LPCWSTR lpLibFileName
                                   0,                          // HANDLE hFile
                                   LOAD_LIBRARY_AS_DATAFILE);  // DWORD  dwFlags
    if ModuleHandle <> 0 then
      MsgFlags := MsgFlags or FORMAT_MESSAGE_FROM_HMODULE;
    end;
  if FormatMessageW(MsgFlags,                                   // DWORD   dwFlags
                    pointer(ModuleHandle),                      // LPCVOID lpSource
                    MessageId,                                  // DWORD   dwMessageId
                    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),  // DWORD   dwLanguageId
                    @pBuffer,                                   // LPWSTR  lpBuffer
                    0,                                          // DWORD   nSize
                    nil) > 0 then                               // va_list Arguments
    begin
    result := pwidechar(pBuffer);
    LocalFree(HLOCAL(pBuffer));
    if result[Length(result)] = ' ' then
      SetLength(result, Length(result) - 1);
    end
  else
    result := 'Unknown error';
  if ModuleHandle <> 0 then
    FreeLibrary(ModuleHandle);
  if AddId then
    begin
    Str(MessageId, StrID);
    result := result + ' (' + StrID + ')';
    end;
  end;

function FormatMessageInsertArgs(const Msg: unicodestring; const Args: array of unicodestring): unicodestring;
  var
    ArgArray: array of DWORD_PTR;
    I, MsgFlags: DWORD;
    pBuffer: pwidechar;
  begin
  result := Msg;
  if High(Args) > -1 then
    begin
    SetLength(ArgArray, High(Args) + 1);
    for I := Low(Args) to High(Args) do
      ArgArray[I] := DWORD_PTR(pwidechar(Args[I]));
    MsgFlags := FORMAT_MESSAGE_ALLOCATE_BUFFER or
      FORMAT_MESSAGE_FROM_STRING or
      FORMAT_MESSAGE_ARGUMENT_ARRAY;
    try
      if FormatMessageW(MsgFlags,               // DWORD   dwFlags
                        pwidechar(Msg),         // LPCVOID lpSource
                        0,                      // DWORD   dwMessageId
                        0,                      // DWORD   dwLanguageId
                        @pBuffer,               // LWTSTR  lpBuffer
                        0,                      // DWORD   nSize
                        @ArgArray[0]) > 0 then  // va_list Arguments
        begin
        result := pwidechar(pBuffer);
        LocalFree(HLOCAL(pBuffer));
        end;
    except
    end; //try
    end;
  end;

function GetWindowsMessage(const MessageId: DWORD): unicodestring;
  begin
  result := FormatMessageFromSystem(MessageId);
  end;

function GetWindowsMessage(const MessageId: DWORD; const AddId: boolean): unicodestring;
  begin
  result := FormatMessageFromSystem(MessageId, AddId);
  end;

function GetWindowsMessage(const MessageId: DWORD; const Module: unicodestring): unicodestring;
  begin
  result := FormatMessageFromSystem(MessageId, false, Module);
  end;

function GetWindowsMessage(const MessageId: DWORD; const Module: unicodestring; const AddId: boolean): unicodestring;
  begin
  result := FormatMessageFromSystem(MessageId, AddId, Module);
  end;

function GetWindowsMessage(const MessageId: DWORD; const Args: array of unicodestring): unicodestring;
  var
    Msg: unicodestring;
  begin
  Msg := FormatMessageFromSystem(MessageId);
  result := FormatMessageInsertArgs(Msg, Args);
  end;

function GetWindowsMessage(const MessageId: DWORD; const AddId: boolean; const Args: array of unicodestring): unicodestring;
  var
    Msg: unicodestring;
  begin
  Msg := FormatMessageFromSystem(MessageId, AddId);
  result := FormatMessageInsertArgs(Msg, Args);
  end;

function GetWindowsMessage(const MessageId: DWORD; const Module: unicodestring; const Args: array of unicodestring): unicodestring;
  var
    Msg: unicodestring;
  begin
  Msg := FormatMessageFromSystem(MessageId, false, Module);
  result := FormatMessageInsertArgs(Msg, Args);
  end;

function GetWindowsMessage(const MessageId: DWORD; const Module: unicodestring; const AddId: boolean; const Args: array of unicodestring): unicodestring;
  var
    Msg: unicodestring;
  begin
  Msg := FormatMessageFromSystem(MessageId, AddId, Module);
  result := FormatMessageInsertArgs(Msg, Args);
  end;

begin
end.
