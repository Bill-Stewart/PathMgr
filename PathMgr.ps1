# Copyright (C) 2021 by Bill Stewart (bstewart at iname.com)
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU Lesser General Public License as published by the Free
# Software Foundation; either version 3 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program. If not, see https://www.gnu.org/licenses/.

#requires -version 2

# Demo script for functions in PathMgr.dll

# Prerequisites:
# * 64-bit PathMgr.dll in x64 directory
# * 32-bit PathMgr.dll in x86 directory

[CmdletBinding(DefaultParameterSetName = "List")]
param(
  [Parameter(ParameterSetName = "List",Position = 0)]
  [Parameter(ParameterSetName = "Test",Position = 0)]
  [Parameter(ParameterSetName = "Add",Position = 0)]
  [Parameter(ParameterSetName = "Remove",Position = 0)]
  [ValidateSet("System","User")]
  [String]
  $PathType,

  [Parameter(ParameterSetName = "List")]
  [Switch]
  $List,

  [Parameter(ParameterSetName = "Test",Position = 1)]
  [String]
  $Test,

  [Parameter(ParameterSetName = "Add",Position = 1)]
  [String]
  $Add,

  [Parameter(ParameterSetName = "Remove",Position = 1)]
  [String]
  $Remove,

  [Parameter(ParameterSetName = "List")]
  [Switch]
  $ExpandVars,

  [Parameter(ParameterSetName = "Add")]
  [Switch]
  $Beginning
)

function Get-Platform {
  if ( [IntPtr]::Size -eq 8 ) {
    "x64"
  }
  else {
    "x86"
  }
}

$APIDefs = @"
[DllImport("{0}\\PathMgr.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint AddDirToPath(
  string DirName,
  uint   PathType,
  uint   AddType
);

[DllImport("{0}\\PathMgr.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint GetPath(
  uint          PathType,
  uint          Expand,
  StringBuilder Path,
  uint          NumChars
);

[DllImport("{0}\\PathMgr.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint IsDirInPath(
  string   DirName,
  uint     PathType,
  out uint FindType
);

[DllImport("{0}\\PathMgr.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint RemoveDirFromPath(
  string DirName,
  uint   PathType
);
"@ -f (Get-Platform)

$PathMgr = Add-Type -Name PathMgr `
  -MemberDefinition $APIDefs `
  -Namespace "D2DB052B379F4E9CB1163446F95246E6" `
  -UsingNamespace "System.Text" `
  -PassThru `
  -ErrorAction Stop

function GetSystemOrUser {
  param(
    [String]
    [ValidateSet("System","User")]
    $pathType
  )
  if ( $pathType -eq "System" ) { 0 } else { 1 }
}

function GetPath {
  param(
    [String]
    [ValidateSet("System","User")]
    $pathType,

    [Switch]
    $expandVars
  )
  $result = ""
  $intPathType = GetSystemOrUser $pathType
  if ( $expandVars ) { $intExpandVars = 1 } else { $intExpandVars = 0 }
  # Create a StringBuilder with 0 capacity initially
  $stringBuilder = New-Object Text.StringBuilder(0)
  # Invoke DLL function with 0 for last parameter to get length
  $numChars = $PathMgr::GetPath($intPathType,$intExpandVars,$stringBuilder,0)
  if ( $numChars -gt 0 ) {
    # Specify length of string and call function again
    $stringBuilder.Capacity = $numChars
    if ( $PathMgr::GetPath($intPathType,$intExpandVars,$stringBuilder,$numChars) -gt 0 ) {
      $result = $stringBuilder.ToString()
    }
  }
  if ( $result -ne "" ) {
    $result -split [Environment]::NewLine
  }
}

function IsDirInPath {
  param(
    [String]
    [ValidateSet("System","User")]
    $pathType,

    [String]
    $dirName
  )
  $result = 0
  $intPathType = GetSystemOrUser $pathType
  $findType = $null
  $result = $PathMgr::IsDirInPath($dirName,$intPathType,[Ref] $findType)
  if ( $result -eq 0 ) {
    $result = $findType
  }
  $result
}

function AddDirToPath {
  param(
    [String]
    [ValidateSet("System","User")]
    $pathType,

    [String]
    $dirName,

    [Switch]
    $beginning
  )
  $intPathType = GetSystemOrUser $pathType
  if ( $beginning ) { $addType = 1 } else { $addType = 0 }
  $PathMgr::AddDirToPath($dirName,$intPathType,$addType)
}

function RemoveDirFromPath {
  param(
    [String]
    [ValidateSet("System","User")]
    $pathType,

    [String]
    $dirName
  )
  $intPathType = GetSystemOrUser $pathType
  $PathMgr::RemoveDirFromPath($dirName,$intPathType)
}

function GetMessageFromID {
  param(
    [UInt32]
    $messageID
  )
  $stdOut = & "$env:SystemRoot\System32\net.exe" helpmsg $messageID | Out-String -Width ([Int32]::MaxValue)
  "{0} - {1}" -f $messageID,($stdOut -replace [Environment]::NewLine,"")
}

$ExitCode = 0
switch ( $PSCmdlet.ParameterSetName ) {
  "List" {
    GetPath $PathType -ExpandVars:$ExpandVars
  }
  "Test" {
    $ExitCode = IsDirInPath $PathType $Test
    switch ( $ExitCode ) {
      1 { "1 - Directory '$Test' found in unexpanded $PathType Path" }
      2 { "2 - Directory '$Test' found in expanded $PathType Path" }
      3 { "3 - Directory '$Test' not found in $PathType Path" }
    }
  }
  "Add" {
    $ExitCode = AddDirToPath $PathType $Add -Beginning:$Beginning
    GetMessageFromId $ExitCode
  }
  "Remove" {
    $ExitCode = RemoveDirFromPath $PathType $Remove
    GetMessageFromId $ExitCode
  }
}
exit $ExitCode
