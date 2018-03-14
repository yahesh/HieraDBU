unit DBLockU;

// Please, don't delete this comment. \\
(*
  Copyright Owner: Yahe
  Copyright Year : 2007-2018

  Unit   : DBLockU (platform independant)
  Version: 0.1a1

  Contact E-Mail: hello@yahe.sh
*)
// Please, don't delete this comment. \\

(*
  Description:

  This unit contains the core database engine.
*)

(*
  Change Log:

  [Version 0.1a] (20.09.2007: initial release)
  - initial release
*)

interface

uses
  SysUtils,
  Classes;

type
  TDataBaseLock = class;

  TDataBaseLock = class(TObject)
  private
  protected
  public
    function CreateLock(const AFileName : String; const ALockID : LongInt) : Boolean;
    function IsOwnLock(const AFileName : String; const ALockID : LongInt) : Boolean;

    procedure RemoveLock(const AFileName : String; const ALockID : LongInt);
  published
  end;

const
  CDataBaseLockTag = 'DBL';

implementation

{ TDataBaseLock }

function TDataBaseLock.CreateLock(const AFileName : String; const ALockID : LongInt) : Boolean;
var
  LFileStream : TFileStream;
begin
  Result := (IsOwnLock(AFileName, ALockID) and FileExists(AFileName));
  if not(Result) then
  begin
    if not(FileExists(AFileName)) then
    begin
      LFileStream := TFileStream.Create(AFileName, fmCreate or fmShareDenyWrite);
      try
        LFileStream.Position := 0;
        LFileStream.Write(CDataBaseLockTag[1], Length(CDataBaseLockTag));
        LFileStream.Write(ALockID, SizeOf(ALockID));

        Result := true;
      finally
        LFileStream.Free;
      end;
    end;
  end;
end;

function TDataBaseLock.IsOwnLock(const AFileName : String; const ALockID : LongInt) : Boolean;
var
  LFileStream : TFileStream;
  LHandle     : LongInt;
  LTag        : String;
begin
  Result := not(FileExists(AFileName));
  if not(Result) then
  begin
    LFileStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      LFileStream.Position := 0;
      SetLength(LTag, Length(CDataBaseLockTag));
      LFileStream.Read(LTag[1], Length(LTag));

      if (LTag = CDataBaseLockTag) then
      begin
        LFileStream.Read(LHandle, SizeOf(LHandle));

        Result := (LHandle = ALockID);
      end;
    finally
      LFileStream.Free;
    end;
  end;
end;

procedure TDataBaseLock.RemoveLock(const AFileName : String; const ALockID : LongInt);
begin
  if (IsOwnLock(AFileName, ALockID) and FileExists(AFileName)) then
    DeleteFile(AFileName);
end;

end.
 
