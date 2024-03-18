{ Copyright (C) 2021-2024 by Bill Stewart (bstewart at iname.com)

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
{$MODESWITCH UNICODESTRINGS}
{$R *.res}

library PathMgr;

uses
  Windows,
  WindowsPath;

procedure CopyString(const Source: string; Dest: PChar);
var
  NumChars: DWORD;
begin
  NumChars := Length(Source);
  Move(Source[1], Dest^, NumChars * SizeOf(Char));
  Dest[NumChars] := #0;
end;

function GetPath(PathType, Expand: DWORD; Buffer: PChar; NumChars: DWORD): DWORD; stdcall;
var
  Path: string;
begin
  if PathType > 1 then
    PathType := 1;
  if WindowsPath.GetPath(TPathType(PathType), Expand <> 0, Path) = ERROR_SUCCESS then
  begin
    result := Length(Path);
    if (result > 0) and (result <= NumChars) and Assigned(Buffer) then
      CopyString(Path, Buffer);
  end
  else
    result := 0;
end;

function IsDirInPath(DirName: PChar; PathType: DWORD; FindType: PDWORD): DWORD; stdcall;
var
  PathFindType: TPathFindType;
begin
  if PathType > 1 then
    PathType := 1;
  result := WindowsPath.IsDirInPath(string(DirName), TPathType(PathType), PathFindType);
  FindType^ := DWORD(PathFindType);
end;

function AddDirToPath(DirName: PChar; PathType, AddType: DWORD): DWORD; stdcall;
begin
  if PathType > 1 then
    PathType := 1;
  if AddType > 1 then
    AddType := 1;
  result := WindowsPath.AddDirToPath(string(DirName), TPathType(PathType), TPathAddType(AddType));
end;

function RemoveDirFromPath(DirName: PChar; PathType: DWORD): DWORD; stdcall;
begin
  if PathType > 1 then
    PathType := 1;
  result := WindowsPath.RemoveDirFromPath(string(DirName), TPathType(PathType));
end;

exports
  AddDirToPath,
  GetPath,
  IsDirInPath,
  RemoveDirFromPath;

end.
