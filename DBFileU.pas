unit DBFileU;

// Please, don't delete this comment. \\
(*
  Copyright Owner: Yahe
  Copyright Year : 2007-2018

  Unit   : DBFileU (platform independant)
  Version: 0.1a1

  Contact E-Mail: hello@yahe.sh
*)
// Please, don't delete this comment. \\

(*
  Description:

  This unit contains the management of the database data files.
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
  DBDataU;

type
  TFileItem     = class;
  TFileItemList = class;

  TFileItem = class(TObject)
  private
  protected
    FDataAccess : TDataAccess;
    FFileName   : String;

    procedure SetFileName(const AValue : String);
  public
    constructor Create(const AFileName : String);

    destructor Destroy; override;

    property DataAccess : TDataAccess read FDataAccess;
    property FileName   : String      read FFileName write SetFileName;
  published
  end;

  TFileItemList = class(TList)
  private
  protected
  public
    destructor Destroy; override;

    function AddItem(const AFileName : String) : LongInt;

    procedure LoadFromFile(const AFileName : String);
    procedure SaveToFile(const AFileName : String);

    procedure ClearList;
  published
  end;

const
  CDataBaseFilesTag = 'DBF';

implementation

{ TFileItem }

constructor TFileItem.Create(const AFileName : String);
begin
  inherited Create;

  FFileName := AFileName;

  FDataAccess := TDataAccess.Create;
  if (FDataAccess <> nil) then
  begin
    try
      FDataAccess.OpenFile(FFileName, false);
    except
      FDataAccess.Free;
      FDataAccess := nil;
    end;
  end
  else
    raise Exception.Create('DataAccess Could Not Be Created');
end;

destructor TFileItem.Destroy;
begin
  if (FDataAccess <> nil) then
  begin
    FDataAccess.Free;
    FDataAccess := nil;
  end;

  inherited Destroy;
end;

procedure TFileItem.SetFileName(const AValue: String);
begin
  if (FDataAccess <> nil) then
  begin
    FDataAccess.CloseFile;
    FDataAccess.Free;
    FDataAccess := nil;
  end;

  FFileName := AValue;

  FDataAccess := TDataAccess.Create;
  if (FDataAccess <> nil) then
  begin
    try
      FDataAccess.OpenFile(FFileName, true)
    except
      FDataAccess.Free;
      FDataAccess := nil;
    end;
  end
  else
    raise Exception.Create('DataAccess Could Not Be Created');
end;

{ TFileItemList }

function TFileItemList.AddItem(const AFileName : String) : LongInt;
begin
  Result := Add(TFileItem.Create(AFileName));
end;

procedure TFileItemList.ClearList;
var
  LIndex : LongInt;
  LItem  : TFileItem;
begin
  for LIndex := Pred(Count) downto 0 do
  begin
    LItem := TFileItem(Items[LIndex]);
    if (LItem <> nil) then
      LItem.Free;
  end;

  Clear;
end;

destructor TFileItemList.Destroy;
begin
  ClearList;

  inherited Destroy;
end;

procedure TFileItemList.LoadFromFile(const AFileName: String);
var
  LFile       : TFileStream;
  LFileName   : String;
  LFullRecord : Boolean;
  LSize       : Word;
  LTag        : String;
begin
  ClearList;

  if FileExists(AFileName) then
  begin
    LFile := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    if (LFile <> nil) then
    begin
      try
        LFile.Position := 0;

        SetLength(LTag, Length(CDataBaseFilesTag));
        LFile.Read(LTag[1], Length(LTag));
        if (LTag = CDataBaseFilesTag) then
        begin
          LFullRecord := true;
          while ((LFile.Position < LFile.Size) and LFullRecord) do
          begin
            LFile.Read(LSize, SizeOf(LSize));

            LFullRecord := (LSize = 0);
            if not(LFullRecord) then
            begin
              if ((LFile.Position + LSize) <= LFile.Size) then
              begin
                SetLength(LFileName, LSize);
                LFile.Read(LFileName[1], LSize);

                LFullRecord := (AddItem(LFileName) >= 0);
              end
              else
                LFile.Position := LFile.Size;
            end;
          end;

          if not(LFullRecord) then
            raise Exception.Create('Corrupted File');
        end
        else
          raise Exception.Create('File Tag does not match');
      finally
        LFile.Free;
      end;
    end
    else
      raise Exception.Create('File Could Not Be Opened');
  end
  else
    raise Exception.Create('File Does Not Exist');
end;

procedure TFileItemList.SaveToFile(const AFileName: String);
var
  LFile  : TFileStream;
  LIndex : LongInt;
  LItem  : TFileItem;
  LSize  : Word;
begin
  if FileExists(AFileName) then
    LFile := TFileStream.Create(AFileName, fmOpenWrite or fmShareDenyWrite)
  else
    LFile := TFileStream.Create(AFileName, fmCreate or fmShareDenyWrite);

  if (LFile <> nil) then
  begin
    try
      LFile.Position := 0;
      LFile.Write(CDataBaseFilesTag[1], Length(CDataBaseFilesTag));

      for LIndex := 0 to Pred(Count) do
      begin
        LItem := TFileItem(Items[LIndex]);
        if (LItem <> nil) then
        begin
          LSize := Length(LItem.FileName);
          LFile.Write(LSize, SizeOf(LSize));

          LFile.Write(LItem.FileName[1], Length(LItem.FileName));
        end;
      end;

      LFile.Size := LFile.Position;
    finally
      LFile.Free;
    end;
  end
  else
    raise Exception.Create('File Could Not Be Opened');
end;

end.
