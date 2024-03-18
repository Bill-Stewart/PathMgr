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

program PathMan;

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}
{$R *.res}

// wargcv and wgetopts: https://github.com/Bill-Stewart/wargcv
uses
  windows,
  wargcv,
  wgetopts,
  WindowsMessages,
  WindowsPath;

const
  PROGRAM_NAME = 'PathMan';
  PROGRAM_COPYRIGHT = 'Copyright (C) 2024 by Bill Stewart';

type
  // Must specify only one action param,
  TActionParamGroup = (
    ActionParamAdd,
    ActionParamHelp,
    ActionParamList,
    ActionParamRemove,
    ActionParamTest);
  TActionParamSet = set of TActionParamGroup;
  // ...and only one scope param
  TScopeParamGroup = (
    ScopeParamSystem,
    ScopeParamUser);
  TScopeParamSet = set of TScopeParamGroup;
  TCommandLine = object
    ActionParamSet: TActionParamSet;
    ScopeParamSet: TScopeParamSet;
    Error: DWORD;
    AddBeginning: Boolean;
    Expand: Boolean;
    Quiet: Boolean;
    DirName: string;
    procedure Parse();
  end;

function IntToStr(const I: Integer): string;
begin
  Str(I, result);
end;

function GetFileVersion(const FileName: string): string;
var
  VerInfoSize, Handle: DWORD;
  pBuffer: Pointer;
  pFileInfo: ^VS_FIXEDFILEINFO;
  Len: UINT;
begin
  result := '';
  VerInfoSize := GetFileVersionInfoSizeW(PChar(FileName),  // LPCWSTR lptstrFilename
    Handle);                                               // LPDWORD lpdwHandle
  if VerInfoSize > 0 then
  begin
    GetMem(pBuffer, VerInfoSize);
    if GetFileVersionInfoW(PChar(FileName),  // LPCWSTR lptstrFilename
      Handle,                                // DWORD   dwHandle
      VerInfoSize,                           // DWORD   dwLen
      pBuffer) then                          // LPVOID  lpData
    begin
      if VerQueryValueW(pBuffer,  // LPCVOID pBlock
        '\',                      // LPCWSTR lpSubBlock
        pFileInfo,                // LPVOID  *lplpBuffer
        Len) then                 // PUINT   puLen
      begin
        with pFileInfo^ do
        begin
          result := IntToStr(HiWord(dwFileVersionMS)) + '.' +
            IntToStr(LoWord(dwFileVersionMS)) + '.' +
            IntToStr(HiWord(dwFileVersionLS));
          // LoWord(dwFileVersionLS) intentionally omitted
        end;
      end;
    end;
    FreeMem(pBuffer);
  end;
end;

procedure Usage();
begin
  WriteLn(PROGRAM_NAME, ' ', GetFileVersion(ParamStr(0)), ' - ', PROGRAM_COPYRIGHT);
  WriteLn('This is free software and comes with ABSOLUTELY NO WARRANTY.');
  WriteLn();
  WriteLn('SYNOPSIS');
  WriteLn();
  WriteLn('Provides tools for management of the Path environment variable.');
  WriteLn();
  WriteLn('USAGE');
  WriteLn();
  WriteLn(PROGRAM_NAME, ' <scope> <action> <option> [<option> [...]]');
  WriteLn();
  WriteLn('<scope>   Abbrev.  Description');
  WriteLn('--------------------------------------------------');
  WriteLn('--system  -s       Specifies system Path');
  WriteLn('--user    -u       Specifies the current user Path');
  WriteLn();
  WriteLn('<action>            Abbrev.       Description');
  WriteLn('---------------------------------------------------------------');
  WriteLn('--list              -l            Lists directories in Path');
  WriteLn('--test "dirname"    -t "dirname"  Tests if directory is in Path');
  WriteLn('--add "dirname"     -a "dirname"  Adds directory to Path');
  WriteLn('--remove "dirname"  -r "dirname"  Removes directory from Path');
  WriteLn();
  WriteLn('<option>     Abbrev.  Description');
  WriteLn('-----------------------------------------------------------------');
  WriteLn('--expand     -x       Expands environment variables (--list only)');
  WriteLn('--beginning  -b       Adds to beginning of path (--add only)');
  WriteLn('--quiet      -q       Suppresses result and error messages');
  WriteLn();
  WriteLn('EXIT CODES');
  WriteLn();
  WriteLn('Typical exit codes when not using --test:');
  WriteLn('0 - No errors');
  WriteLn('2 - The Path value is missing from the registry');
  WriteLn('3 - The specified directory does not exist in the Path');
  WriteLn('5 - Access is denied');
  WriteLn('87 - Incorrect parameter(s)');
  WriteLn('183 - The specified directory already exists in the Path');
  WriteLn();
  WriteLn('Typical exit codes when using --test:');
  WriteLn('1 - The specified directory exists in the unexpanded Path');
  WriteLn('2 - The specified directory exists in the expanded Path');
  WriteLn('3 - The specified directory does not exist in the Path');
end;

procedure TCommandLine.Parse();
var
  Opts: array[1..11] of TOption;
  Opt: Char;
  I: Integer;
begin
  with Opts[1] do
  begin
    Name := 'add';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 'a';
  end;
  with Opts[2] do
  begin
    Name := 'beginning';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'b';
  end;
  with Opts[3] do
  begin
    Name := 'expand';
    Has_arg := No_Argument;
    Flag := nil;
    value := 'x';
  end;
  with Opts[4] do
  begin
    Name := 'help';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'h';
  end;
  with Opts[5] do
  begin
    Name := 'list';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'l';
  end;
  with Opts[6] do
  begin
    Name := 'quiet';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'q';
  end;
  with Opts[7] do
  begin
    Name := 'remove';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 'r';
  end;
  with Opts[8] do
  begin
    Name := 'system';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 's';
  end;
  with Opts[9] do
  begin
    Name := 'test';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 't';
  end;
  with Opts[10] do
  begin
    Name := 'user';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'u';
  end;
  with Opts[11] do
  begin
    Name := '';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  ActionParamSet := [];
  ScopeParamSet := [];
  Error := ERROR_SUCCESS;
  AddBeginning := false;
  Expand := false;
  Quiet := false;
  DirName := '';
  OptErr := false;
  repeat
    Opt := GetLongOpts('a:bxhlqr:st:u', @Opts[1], I);
    case Opt of
      'a':
      begin
        DirName := OptArg;
        Include(ActionParamSet, ActionParamAdd);
      end;
      'b': AddBeginning := true;
      'x': Expand := true;
      'h':
      begin
        Include(ActionParamSet, ActionParamHelp);
        break;
      end;
      'l': Include(ActionParamSet, ActionParamList);
      'q': Quiet := true;
      'r':
      begin
        DirName := OptArg;
        Include(ActionParamSet, ActionParamRemove);
      end;
      's': Include(ScopeParamSet, ScopeParamSystem);
      't':
      begin
        DirName := OptArg;
        Include(ActionParamSet, ActionParamTest);
      end;
      'u': Include(ScopeParamSet, ScopeParamUser);
      '?':
      begin
        Error := ERROR_INVALID_PARAMETER;
        break;
      end;
    end;
  until Opt = EndOfOptions;
  if Error <> ERROR_SUCCESS then
    exit;
  // Must specify only one action param and only one scope param
  if (PopCnt(DWORD(ActionParamSet)) <> 1) or (PopCnt(DWORD(ScopeParamSet)) <> 1) then
    Error := ERROR_INVALID_PARAMETER;
end;

var
  RC: DWORD;
  CmdLine: TCommandLine;
  PathType: TPathType;
  Path: string;
  FindType: TPathFindType;
  AddType: TPathAddType;

begin
  RC := ERROR_SUCCESS;

  CmdLine.Parse();

  if (ParamCount = 0) or (ActionParamHelp in CmdLine.ActionParamSet) then
  begin
    Usage();
    exit;
  end;

  if CmdLine.Error <> ERROR_SUCCESS then
  begin
    RC := CmdLine.Error;
    if not CmdLine.Quiet then
      WriteLn(GetWindowsMessage(RC, true));
    ExitCode := Integer(RC);
    exit;
  end;

  if ScopeParamSystem in CmdLine.ScopeParamSet then
    PathType := PathTypeSystem
  else
    PathType := PathTypeUser;

  if ActionParamList in CmdLine.ActionParamSet then
  begin
    RC := GetPath(PathType, CmdLine.Expand, Path);
    if RC = ERROR_SUCCESS then
    begin
      if Path <> '' then
        WriteLn(Path);
    end
    else
      WriteLn(GetWindowsMessage(RC, true));
  end;

  if ActionParamTest in CmdLine.ActionParamSet then
  begin
    RC := IsDirInPath(CmdLine.DirName, PathType, FindType);
    if RC = ERROR_SUCCESS then
    begin
      case FindType of
        PathFindTypeUnexpanded:
        begin
          RC := 1;
          if not CmdLine.Quiet then
            WriteLn('The specified directory exists in the unexpanded Path. (1)');
        end;
        PathFindTypeExpanded:
        begin
          RC := 2;
          if not CmdLine.Quiet then
            WriteLn('The specified directory exists in the expanded Path. (2)');
        end;
      end;
    end
    else  // RC <> ERROR_SUCCESS
    begin
      if not CmdLine.Quiet then
      begin
        if (RC = ERROR_PATH_NOT_FOUND) and (FindType = PathFindTypeNotFound) then
          WriteLn('The specified directory was not found in the Path. (3)')
        else
          WriteLn(GetWindowsMessage(RC, true));
      end;
    end;
  end;

  if ActionParamAdd in CmdLine.ActionParamSet then
  begin
    if CmdLine.AddBeginning then
      AddType := PathAddTypeBeginning
    else
      AddType := PathAddTypeEnd;
    RC := AddDirToPath(CmdLine.DirName, PathType, AddType);
    if not CmdLine.Quiet then
      WriteLn(GetWindowsMessage(RC, true));
  end;

  if ActionParamRemove in CmdLine.ActionParamSet then
  begin
    RC := RemoveDirFromPath(CmdLine.DirName, PathType);
    if not CmdLine.Quiet then
      WriteLn(GetWindowsMessage(RC, true));
  end;

  ExitCode := Integer(RC);
end.
