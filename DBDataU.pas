unit DBDataU;

// Please, don't delete this comment. \\
(*
  Copyright Owner: Yahe
  Copyright Year : 2007-2018

  Unit   : DBDataU (platform independant)
  Version: 0.1a1

  Contact E-Mail: hello@yahe.sh
*)
// Please, don't delete this comment. \\

(*
  Description:

  This unit contains access to the data in a database data file.
*)

(*
  Change Log:

  [Version 0.1a1] (17.09.2007: initial release)
  - initial release
*)

interface

uses
  SysUtils,
  Classes,
  DBStrucU,
  DBRecU;

type
  TDataAccess = class;

  TDataAccess = class(TObject)
  private
  protected
    FFile   : TFileStream;
    FOpened : Boolean;
  public
    constructor Create;

    destructor Destroy; override;

    function LoadAsRaw(const AID : LongWord; const AStructure : TStructureItemList) : String;
    function LoadAsRecord(const AID : LongWord; const AStructure : TStructureItemList) : TRecordItem;

    function Locate(const AID : LongWord; const AStructure : TStructureItemList; const AAllowBehindLastID : Boolean) : Boolean;
    function RecordCount(const AStructure : TStructureItemList) : LongWord;

    procedure CloseFile;
    procedure OpenFile(const AFileName : String; const AReopen : Boolean);

    procedure SaveAsRaw(const AID : LongWord; const AStructure : TStructureItemList; const AData : String);
    procedure SaveAsRecord(const AID : LongWord; const AStructure : TStructureItemList; const AData : TRecordItem);
  published
  end;

const
  CDataBaseDataTag = 'DBD';

implementation

{ TDataAccess }

procedure TDataAccess.CloseFile;
begin
  if FOpened then
  begin
    if (FFile <> nil) then
    begin
      FFile.Free;
      FFile := nil;
    end;

    FOpened := false;
  end;
end;

constructor TDataAccess.Create;
begin
  inherited Create;

  FOpened := false;
end;

destructor TDataAccess.Destroy;
begin
  if FOpened then
    CloseFile;

  inherited Destroy;
end;

function TDataAccess.LoadAsRaw(const AID : LongWord; const AStructure : TStructureItemList) : String;
begin
  Result := '';

  if FOpened then
  begin
    if Locate(AID, AStructure, false) then
    begin
      SetLength(Result, (AStructure.Size + SizeOf(Byte)));
      FFile.Read(Result[1], Length(Result));
    end
    else
      raise Exception.Create('Data Do Not Exist');
  end
  else
    raise Exception.Create('No File Open');
end;

function TDataAccess.LoadAsRecord(const AID : LongWord; const AStructure : TStructureItemList) : TRecordItem;
begin
  Result := TRecordItem.Create;
  if (Result <> nil) then
  begin
    Result.Initialize(AStructure);
    Result.ParseData(LoadAsRaw(AID, AStructure));
  end
  else
    raise Exception.Create('Record Object Could Not Be Created');
end;

function TDataAccess.Locate(const AID : LongWord; const AStructure : TStructureItemList; const AAllowBehindLastID : Boolean) : Boolean;
var
  LRecordCount : LongWord;
begin
  if FOpened then
  begin
    LRecordCount := RecordCount(AStructure);
    if AAllowBehindLastID then
      Result := (LRecordCount >= AID)
    else
      Result := (LRecordCount > AID);

    if Result then
//      this line would remove the only existant compiler warning message:
//      FFile.Position := Length(CDataBaseDataTag) + (AID * Int64(AStructure.Size + SizeOf(Byte)))
      FFile.Position := Length(CDataBaseDataTag) + (AID * (AStructure.Size + SizeOf(Byte)))
    else
      raise Exception.Create('ID Does Not Exist');
  end
  else
    raise Exception.Create('No File Open');
end;

procedure TDataAccess.OpenFile(const AFileName: String; const AReopen : Boolean);
var
  LExists : Boolean;
  LTag    : String;
begin
  if (not(FOpened) or AReopen) then
  begin
    if FOpened then
      CloseFile;

    LExists := FileExists(AFileName);
    if LExists then
      FFile := TFileStream.Create(AFileName, fmOpenReadWrite or fmShareDenyWrite)
    else
      FFile := TFileStream.Create(AFileName, fmCreate or fmShareDenyWrite);

    if (FFile <> nil) then
    begin
      if not(LExists) then
      begin
        FFile.Position := 0;
        FFile.Write(CDataBaseDataTag[1], Length(CDataBaseDataTag));
      end;

      FFile.Position := 0;

      SetLength(LTag, Length(CDataBaseDataTag));
      FFile.Read(LTag[1], Length(LTag));
      FOpened := (LTag = CDataBaseDataTag);
      if not(FOpened) then
      begin
        FOpened := true;
        try
          CloseFile;
        finally
          FOpened := false;
        end;

        raise Exception.Create('File Tag does not match');
      end;
    end
    else
      raise Exception.Create('Data File Could Not Be Opened');
  end
  else
    raise Exception.Create('File Already Open');
end;

function TDataAccess.RecordCount(const AStructure : TStructureItemList) : LongWord;
begin
  if FOpened then
    Result := (FFile.Size - Length(CDataBaseDataTag)) div (AStructure.Size + SizeOf(Byte))
  else
    raise Exception.Create('No File Open');
end;

procedure TDataAccess.SaveAsRaw(const AID : LongWord; const AStructure : TStructureItemList; const AData : String);
begin
  if FOpened then
  begin
    if Locate(AID, AStructure, true) then
      FFile.Write(AData[1], Length(AData))
    else
      raise Exception.Create('Data Do Not Exist');
  end
  else
    raise Exception.Create('No File Open');
end;

procedure TDataAccess.SaveAsRecord(const AID : LongWord; const AStructure : TStructureItemList; const AData : TRecordItem);
begin
  if (AData <> nil) then
    SaveAsRaw(AID, AStructure, AData.Data)
  else
    raise Exception.Create('Record Object Does Not Exist');
end;

end.
