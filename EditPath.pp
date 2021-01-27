{ Copyright (C) 2004-2021 by Bill Stewart (bstewart at iname.com)

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
{$R *.res}
{$APPTYPE CONSOLE}

program
  EditPath;

uses
  getopts,
  windows,
  wsUtilMsg,
  wsPathMgr;

type
  TCommandLine = object
    ErrorCode: word;
    ErrorMessage: unicodestring;
    ArgHelp: boolean;                  // --help/-h
    ArgQuiet: boolean;                 // --quiet/-q
    ArgAddToPath: unicodestring;       // --add/-a
    ArgAddToBeginning: boolean;        // --beginning/-b
    ArgList: boolean;                  // --list/-l
    ArgRemoveFromPath: unicodestring;  // --remove/-r
    ArgPathSystem: boolean;            // --system/-s
    ArgTest: unicodestring;            // --test/-t
    ArgPathUser: boolean;              // --user/-u
    ArgExpand: boolean;                // --expand/-x
    function CountSetBits(N: DWORD): DWORD;
    procedure Parse();
    end;

var
  CommandLine: TCommandLine;
  PathType: TPathType;
  PathAddType: TPathAddType;
  PathFindType: TPathFindType;
  OutputStr: unicodestring;

procedure Usage();
  const
    NEWLINE: unicodestring = #13 + #10;
  var
    UsageText: unicodestring;
  begin
  UsageText := 'EditPath 4.0 - Copyright (C) 2004-2021 by Bill Stewart (bstewart at iname.com)' + NEWLINE
    + NEWLINE
    + 'This is free software and comes with ABSOLUTELY NO WARRANTY.' + NEWLINE
    + NEWLINE
    + 'Usage: EditPath [<options>] <type> <action>' + NEWLINE
    + NEWLINE
    + 'You must specify one of each parameter from <type> and <action> (see below).' + NEWLINE
    + 'Other <options> are optional.' + NEWLINE
    + NEWLINE
    + '<type>    Abbreviation  Description' + NEWLINE
    + '-------------------------------------------------' + NEWLINE
    + '--system  -s            Specifies the system Path' + NEWLINE
    + '--user    -u            Specifies the user Path' + NEWLINE
    + NEWLINE
    + '<action>            Abbreviation  Description' + NEWLINE
    + '-------------------------------------------------------------------' + NEWLINE
    + '--list              -l            Lists directories in Path' + NEWLINE
    + '--test "dirname"    -t "dirname"  Tests if directory exists in Path' + NEWLINE
    + '--add "dirname"     -a "dirname"  Adds directory to Path' + NEWLINE
    + '--remove "dirname"  -r "dirname"  Removes directory from Path' + NEWLINE
    + NEWLINE
    + '<options>    Abbreviation  Description' + NEWLINE
    + '----------------------------------------------------------------------' + NEWLINE
    + '--quiet      -q            Suppresses result messages' + NEWLINE
    + '--expand     -x            Expands environment variables (--list only)' + NEWLINE
    + '--beginning  -b            Adds to beginning of Path (--add only)' + NEWLINE
    + NEWLINE
    + 'Anything on the command line after --test, --add, or --remove is' + NEWLINE
    + 'considered to be the argument for the parameter. To avoid ambiguity,' + NEWLINE
    + 'specify the <action> parameter last on the command line.' + NEWLINE
    + NEWLINE
    + 'Typical exit codes when not using --test (-t):' + NEWLINE
    + '0 - No errors' + NEWLINE
    + '2 - The Path value is not present in the registry' + NEWLINE
    + '3 - The specified directory does not exist in the Path' + NEWLINE
    + '5 - Access is denied' + NEWLINE
    + '87 - Incorrect parameter(s)' + NEWLINE
    + '183 - The specified directory already exists in the Path' + NEWLINE
    + NEWLINE
    + 'Typical exit codes when using --test (-t):' + NEWLINE
    + '1 - The specified directory exists in the unexpanded Path' + NEWLINE
    + '2 - The specified directory exists in the expanded Path' + NEWLINE
    + '3 - The specified directory does not exist in the Path';
  WriteLn(UsageText);
  end;

function TCommandLine.CountSetBits(N: DWORD): DWORD;
  var
    Count: DWORD = 0;
  begin
  // Counts the number of bits set in N
  while N <> 0 do
    begin
    Count := Count + (N and 1);
    N := N shr 1;
    end;
  result := Count;
  end;

procedure TCommandLine.Parse();
  const
    REQ_ARGS_ACTION_NONE     = 0;
    REQ_ARGS_ACTION_ADD      = 1;
    REQ_ARGS_ACTION_LIST     = 2;
    REQ_ARGS_ACTION_REMOVE   = 4;
    REQ_ARGS_ACTION_TEST     = 8;
    REQ_ARGS_PATHTYPE_NONE   = 0;
    REQ_ARGS_PATHTYPE_SYSTEM = 1;
    REQ_ARGS_PATHTYPE_USER   = 2;
  var
    LongOpts: array[1..11] of TOption;
    Opt: char;
    I: longint;
    ReqArgsAction, ReqArgsPathType: DWORD;
  begin
  // Set up array of options; requires final option with empty name;
  // set Value member to specify short option match for GetLongOps
  with LongOpts[1] do
    begin
    Name    := 'add';
    Has_arg := Required_Argument;
    Flag    := nil;
    Value   := 'a';
    end;
  with LongOpts[2] do
    begin
    Name    := 'beginning';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := 'b';
    end;
  with LongOpts[3] do
    begin
    Name    := 'help';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := 'h';
    end;
  with LongOpts[4] do
    begin
    Name    := 'list';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := 'l';
    end;
  with LongOpts[5] do
    begin
    Name    := 'quiet';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := 'q';
    end;
  with LongOpts[6] do
    begin
    Name    := 'remove';
    Has_arg := Required_Argument;
    Flag    := nil;
    Value   := 'r';
    end;
  with LongOpts[7] do
    begin
    Name    := 'system';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := 's';
    end;
  with LongOpts[8] do
    begin
    Name    := 'test';
    Has_arg := Required_Argument;
    Flag    := nil;
    Value   := 't';
    end;
  with LongOpts[9] do
    begin
    Name    := 'user';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := 'u';
    end;
  with LongOpts[10] do
    begin
    Name    := 'expand';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := 'x';
    end;
  with LongOpts[11] do
    begin
    Name    := '';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := #0;
    end;
  // Initialize defaults
  ErrorCode := 0;
  ErrorMessage := '';
  ArgAddToPath := '';          // --add/-a
  ArgAddToBeginning := false;  // --beginning/-b
  ArgHelp := false;            // --help/-h
  ArgList := false;            // --list/-l
  ArgQuiet :=  false;          // --quiet/-q
  ArgRemoveFromPath := '';     // --remove/-r
  ArgPathSystem := false;      // --system/-s
  ArgTest := '';               // --test/-t
  ArgPathUser := false;        // --user/-u
  ArgExpand := false;          // --expand/-x
  ReqArgsAction := REQ_ARGS_ACTION_NONE;
  ReqArgsPathType := REQ_ARGS_PATHTYPE_NONE;
  OptErr := false;  // no error outputs from getopts
  repeat
    Opt := GetLongOpts('a:bhlqr:st:ux', @LongOpts, I);
    case Opt of
      'a':
        begin
        ReqArgsAction := ReqArgsAction or REQ_ARGS_ACTION_ADD;
        ArgAddToPath := unicodestring(OptArg);
        end;
      'b': ArgAddToBeginning := true;
      'h': ArgHelp := true;
      'l':
        begin
        ReqArgsAction := ReqArgsAction or REQ_ARGS_ACTION_LIST;
        ArgList := true;
        end;
      'q': ArgQuiet := true;
      'r':
        begin
        ReqArgsAction := ReqArgsAction or REQ_ARGS_ACTION_REMOVE;
        ArgRemoveFromPath := unicodestring(OptArg);
        end;
      's':
        begin
        ReqArgsPathType := ReqArgsPathType or REQ_ARGS_PATHTYPE_SYSTEM;
        ArgPathSystem := true;
        end;
      't':
        begin
        ReqArgsAction := ReqArgsAction or REQ_ARGS_ACTION_TEST;
        ArgTest := unicodestring(OptArg);
        end;
      'u':
        begin
        ReqArgsPathType := ReqArgsPathType or REQ_ARGS_PATHTYPE_USER;
        ArgPathUser := true;
        end;
      'x': ArgExpand := true;
      '?':
        begin
        ErrorCode := ERROR_INVALID_PARAMETER;
        ErrorMessage := 'Incorrect parameter(s). Use --help (-h) for usage.';
        end;
      end; //case Opt
  until Opt = EndOfOptions;
  if ErrorCode = 0 then
    begin
    if (ReqArgsAction = REQ_ARGS_ACTION_NONE) or (ReqArgsPathType = REQ_ARGS_PATHTYPE_NONE) then
      begin
      ErrorCode := ERROR_INVALID_PARAMETER;
      ErrorMessage := 'Required parameter(s) missing. Specify --help (-h) for usage.';
      end
    else if (CountSetBits(ReqArgsAction) > 1) or (CountSetBits(ReqArgsPathType) > 1) then
      begin
      ErrorCode := ERROR_INVALID_PARAMETER;
      ErrorMessage := 'Mutually exclusive parameter(s) specified. Specify --help (-h) for usage.';
      end;
    end;
  end;

function TranslateErrorCode(const Code: DWORD): unicodestring;
  begin
  case Code of
    ERROR_FILE_NOT_FOUND:
      result := 'The Path value is not present in the registry. (2)';
    ERROR_PATH_NOT_FOUND:
      result := 'The specified directory does not exist in the Path. (3)';
    ERROR_ALREADY_EXISTS:
      result := 'The specified directory already exists in the Path. (183)';
    else
      result := GetWindowsMessage(Code, true);
    end; //case
  end;

procedure WriteOutput(const S: unicodestring);
  begin
  if not CommandLine.ArgQuiet then
    if ExitCode <> 0 then WriteLn(ErrOutput, S) else WriteLn(S);
  end;

begin
  // Parse the command line using getopts
  CommandLine.Parse();

  // --help/-h or /?
  if CommandLine.ArgHelp or (ParamStr(1) = '/?') then
    begin
    Usage();
    exit();
    end;

  ExitCode := CommandLine.ErrorCode;
  if ExitCode <> 0 then
    begin
    WriteLn(CommandLine.ErrorMessage);
    exit();
    end;

  PathType := UserPath;
  if CommandLine.ArgPathSystem then
    PathType := SystemPath
  else if CommandLine.ArgPathUser then
    PathType := UserPath;

  if CommandLine.ArgAddToPath <> '' then
    begin
    if CommandLine.ArgAddToBeginning then
      PathAddType := AppendPathToDir
    else
      PathAddType := AppendDirToPath;
    ExitCode := wsAddDirToPath(CommandLine.ArgAddToPath, PathType, PathAddType);
    WriteOutput(TranslateErrorCode(ExitCode));
    end
  else if CommandLine.ArgList then
    begin
    ExitCode := wsGetPath(PathType, CommandLine.ArgExpand, OutputStr);
    if (ExitCode = 0) and (OutputStr <> '') then
      WriteLn(OutputStr)
    else if ExitCode <> 0 then
      WriteOutput(TranslateErrorCode(ExitCode));
    end
  else if CommandLine.ArgRemoveFromPath <> '' then
    begin
    ExitCode := wsRemoveDirFromPath(CommandLine.ArgRemoveFromPath, PathType);
    WriteOutput(TranslateErrorCode(ExitCode));
    end
  else if CommandLine.ArgTest <> '' then
    begin
    OutputStr := '';
    ExitCode := wsIsDirInPath(CommandLine.ArgTest, PathType, PathFindType);
    if ExitCode = 0 then
      begin
      case PathFindType of
        FoundInUnexpandedPath:
          begin
          ExitCode := DWORD(FoundInUnexpandedPath);
          OutputStr := 'The specified directory exists in the unexpanded Path. (1)';
          end;
        FoundInExpandedPath:
          begin
          ExitCode := DWORD(FoundInExpandedPath);
          OutputStr := 'The specified directory exists in the expanded Path. (2)';
          end;
        end; //case
      end;
    if OutputStr <> '' then
      WriteOutput(OutputStr)
    else
      WriteOutput(TranslateErrorCode(ExitCode));
    end;

end.
