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
{$R *.res}

library
  PathMgr;

uses
  windows,
  wsPathMgr;

procedure CopyString(const Source: unicodestring; Dest: pwidechar);
  var
    NumChars: DWORD;
  begin
  NumChars := Length(Source);
  Move(Source[1], Dest^, NumChars * SizeOf(widechar));
  Dest[NumChars] := #0;
  end;

function AddDirToPath(const DirName: pwidechar; const PathType, AddType: DWORD): DWORD; stdcall;
  begin
  if (PathType > 1) or (AddType > 1) then exit(ERROR_INVALID_PARAMETER);
  result := wsAddDirToPath(DirName, TPathType(PathType), TPathAddType(AddType));
  end;

function GetPath(const PathType, Expand: DWORD; Buffer: pwidechar; const NumChars: DWORD): DWORD; stdcall;
  var
    Path: unicodestring;
  begin
  result := 0;
  if PathType > 1 then exit();
  if wsGetPath(TPathType(PathType), Expand <> 0, Path) = 0 then
    begin
    if (Length(Path) > 0) and Assigned(Buffer) and (NumChars >= Length(Path)) then
      CopyString(Path, Buffer);
    result := Length(Path);
    end;
  end;

function IsDirInPath(const DirName: pwidechar; const PathType: DWORD; FindType: PDWORD): DWORD; stdcall;
  var
    PathFindType: TPathFindType;
  begin
  if PathType > 1 then exit(ERROR_INVALID_PARAMETER);
  result := wsIsDirInPath(DirName, TPathType(PathType), PathFindType);
  FindType^ := DWORD(PathFindType);
  end;

function RemoveDirFromPath(const DirName: pwidechar; const PathType: DWORD): DWORD; stdcall;
  begin
  if PathType > 1 then exit(ERROR_INVALID_PARAMETER);
  result := wsRemoveDirFromPath(DirName, TPathType(PathType));
  end;

exports
  AddDirToPath,
  GetPath,
  IsDirInPath,
  RemoveDirFromPath;

end.
