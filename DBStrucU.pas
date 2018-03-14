unit DBStrucU;

// Please, don't delete this comment. \\
(*
  Copyright Owner: Yahe
  Copyright Year : 2007-2018

  Unit   : DBStrucU (platform independant)
  Version: 0.1a1

  Contact E-Mail: hello@yahe.sh
*)
// Please, don't delete this comment. \\

(*
  Description:

  This unit contains management of the database structure.
*)

(*
  Change Log:

  [Version 0.1a1] (17.09.2007: initial release)
  - initial release
*)

interface

{
  DataBase-Structure (*.dbs) looks as follows:

  DBS[#0][size of name:1][name:size of name][primary:1][type:1][size of type:1][...][size of name:1][name:size of name][primary:1][type:1][size of type:1][#0][...]
}

uses
  SysUtils,
  Classes;

type
  TItemTypeEnum = (iteRaw, iteIntSigned, iteIntUnsigned, iteByte, iteFloat, iteString);

  THierarchyList = class;

  TStructureItem     = class;
  TStructureItemList = class;

  THierarchyList = class(TList)
  private
  protected
  public
    destructor Destroy; override;

    function AddItem(const AName : String) : LongInt;

    function SearchIndex(const AName : String) : LongInt;
    function SearchItem(const AName : String) : TStructureItemList;

    procedure LoadFromFile(const AFileName : String);
    procedure SaveToFile(const AFileName : String);

    procedure ClearList;
  published
  end;

  TStructureItem = class(TObject)
  private
  protected
    FItemName    : ShortString;
    FItemPrimary : Boolean;
    FItemSize    : Byte;
    FItemType    : TItemTypeEnum;

    function GetItemSize : Byte;
  public
    constructor Create(const AItemName : ShortString; const AItemPrimary : Boolean; const AItemType : TItemTypeEnum; const AItemSize : Byte); overload;

    property ItemName    : ShortString   read FItemName    write FItemName;
    property ItemPrimary : Boolean       read FItemPrimary write FItemPrimary;
    property ItemSize    : Byte          read GetItemSize  write FItemSize;
    property ItemType    : TItemTypeEnum read FItemType    write FItemType;
  published
  end;

  TStructureItemList = class(TList)
  private
  protected
    FName : String;

    function GetPrimaryCount : LongInt;
    function GetSize : LongWord;
  public
    constructor Create(const AName : String);

    destructor Destroy; override;

    property Name : String read FName write FName;

    property PrimaryCount : LongInt  read GetPrimaryCount;
    property Size         : LongWord read GetSize;

    function AddItem : LongInt; overload;
    function AddItem(const AItemName : ShortString; const AItemPrimary : Boolean; const AItemType : TItemTypeEnum; const AItemSize : Byte) : LongInt; overload;

    function IsPrimary(const AName : String) : Boolean;
    function SearchIndex(const AName : String) : LongInt;
    function SearchItem(const AName : String) : TStructureItem;

    procedure ClearList;
  published
  end;

const
  CDataBaseStructureTag = 'DBS';

implementation

{ TStructureItem }

constructor TStructureItem.Create(const AItemName : ShortString; const AItemPrimary : Boolean; const AItemType : TItemTypeEnum; const AItemSize : Byte);
begin
  inherited Create;

  FItemName    := AItemName;
  FItemPrimary := AItemPrimary;
  FItemSize    := AItemSize;
  FItemType    := AItemType;
end;

function TStructureItem.GetItemSize : Byte;
begin
  case FItemType of
    iteIntSigned   : Result := SizeOf(LongInt);
    iteIntUnsigned : Result := SizeOf(LongWord);
    iteByte        : Result := SizeOf(Byte);
    iteFloat       : Result := SizeOf(Extended);
  else
    Result := FItemSize;
  end;
end;

{ TStructureItemList }

function TStructureItemList.AddItem : LongInt;
begin
  Result := Add(TStructureItem.Create);
end;

function TStructureItemList.AddItem(const AItemName : ShortString; const AItemPrimary : Boolean; const AItemType : TItemTypeEnum; const AItemSize : Byte) : LongInt;
begin
  Result := Add(TStructureItem.Create(AItemName, AItemPrimary, AItemType, AItemSize));
end;

procedure TStructureItemList.ClearList;
var
  LIndex : LongInt;
  LItem  : TStructureItem;
begin
  for LIndex := Pred(Count) downto 0 do
  begin
    LItem := TStructureItem(Items[LIndex]);
    if (LItem <> nil) then
      LItem.Free;
  end;

  Clear;
end;

constructor TStructureItemList.Create(const AName: String);
begin
  inherited Create;

  FName := AName;
end;

destructor TStructureItemList.Destroy;
begin
  ClearList;

  inherited Destroy;
end;

function TStructureItemList.GetPrimaryCount : LongInt;
var
  LIndex : LongInt;
  LItem  : TStructureItem;
begin
  Result := 0;

  for LIndex := 0 to Pred(Count) do
  begin
    LItem := TStructureItem(Items[LIndex]);
    if (LItem <> nil) then
    begin
      if LItem.ItemPrimary then
        Inc(Result);
    end;
  end;
end;

function TStructureItemList.GetSize: LongWord;
var
  LIndex : LongInt;
  LItem  : TStructureItem;
begin
  Result := 0;

  for LIndex := 0 to Pred(Count) do
  begin
    LItem := TStructureItem(Items[LIndex]);
    if (LItem <> nil) then
      Result := Result + LItem.ItemSize;
  end;
end;

function TStructureItemList.IsPrimary(const AName: String) : Boolean;
begin
  Result := SearchItem(AName).ItemPrimary;
end;

function TStructureItemList.SearchIndex(const AName: String): LongInt;
var
  LIndex : LongInt;
  LItem  : TStructureItem;
begin
  Result := - 1;

  for LIndex := 0 to Pred(Count) do
  begin
    LItem := TStructureItem(Items[LIndex]);
    if (LItem <> nil) then
    begin
      if (AnsiLowerCase(LItem.ItemName) = AnsiLowerCase(AName)) then
      begin
        Result := LIndex;

        Break;
      end;
    end;
  end;

  if (Result < 0) then
    raise Exception.Create('Field Does Not Exist');
end;

function TStructureItemList.SearchItem(const AName: String): TStructureItem;
var
  LIndex : LongInt;
begin
  Result := nil;

  LIndex := SearchIndex(AName);
  if (LIndex >= 0) then
    Result := Items[LIndex];
end;

{ THierarchyList }

function THierarchyList.AddItem(const AName : String) : LongInt;
begin
  Result := Add(TStructureItemList.Create(AName));
end;

procedure THierarchyList.ClearList;
var
  LIndex : LongInt;
  LItem  : TStructureItemList;
begin
  for LIndex := Pred(Count) downto 0 do
  begin
    LItem := TStructureItemList(Items[LIndex]);
    if (LItem <> nil) then
      LItem.Free;
  end;

  Clear;
end;

destructor THierarchyList.Destroy;
begin
  ClearList;

  inherited Destroy;
end;

procedure THierarchyList.LoadFromFile(const AFileName : String);
var
  LFile       : TFileStream;
  LFullRecord : Boolean;
  LList       : TStructureItemList;
  LName       : String;
  LPrimary    : Boolean;
  LSize       : Byte;
  LTag        : String;
  LType       : TItemTypeEnum;
begin
  ClearList;

  if FileExists(AFileName) then
  begin
    LFile := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    if (LFile <> nil) then
    begin
      try
        LFile.Position := 0;

        SetLength(LTag, Length(CDataBaseStructureTag));
        LFile.Read(LTag[1], Length(LTag));
        if (LTag = CDataBaseStructureTag) then
        begin
          LList := nil;

          LFullRecord := true;
          while ((LFile.Position < LFile.Size) and LFullRecord) do
          begin
            LFile.Read(LSize, SizeOf(LSize));

            LFullRecord := (LSize = 0);
            if LFullRecord then
            begin
              if (LFile.Position < LFile.Size) then
              begin
                LFile.Read(LSize, SizeOf(LSize));
                if (LSize > 0) then
                begin
                  if ((LFile.Position + LSize) < LFile.Size) then
                  begin
                    SetLength(LName, LSize);
                    LFile.Read(LName[1], Length(LName));

                    LList := TStructureItemList.Create(LName);
                    Add(LList);
                  end;
                end;
              end;
            end
            else
            begin
              if (LList <> nil) then
              begin
                if ((LFile.Position + LSize) < LFile.Size) then
                begin
                  SetLength(LName, LSize);
                  LFile.Read(LName[1], LSize);
                  if (LFile.Position < LFile.Size) then
                  begin
                    LFile.Read(LPrimary, SizeOf(LPrimary));
                    if (LFile.Position < LFile.Size) then
                    begin
                      LFile.Read(LType, SizeOf(LType));
                      if (LFile.Position < LFile.Size) then
                      begin
                        LFile.Read(LSize, SizeOf(LSize));

                        LFullRecord := (LList.AddItem(LName, LPrimary, LType, LSize) >= 0);
                      end;
                    end;
                  end;
                end
                else
                  LFile.Position := LFile.Size;
              end
              else
                raise Exception.Create('Hierarchy Structure Not Created');
            end;
          end;

          if not(LFullRecord) then
            raise Exception.Create('Corrupted Structure');
        end
        else
          raise Exception.Create('File Tag does not match');
      finally
        LFile.Free;
      end;
    end
    else
      raise Exception.Create('Structure File Could Not Be Opened');
  end
  else
    raise Exception.Create('Structure File Does Not Exist');
end;

procedure THierarchyList.SaveToFile(const AFileName : String);
var
  LFile   : TFileStream;
  LIndexA : LongInt;
  LIndexB : LongInt;
  LItem   : TStructureItem;
  LList   : TStructureItemList;
  LSize   : Byte;
begin
  if FileExists(AFileName) then
    LFile := TFileStream.Create(AFileName, fmOpenWrite or fmShareDenyWrite)
  else
    LFile := TFileStream.Create(AFileName, fmCreate or fmShareDenyWrite);

  if (LFile <> nil) then
  begin
    try
      LFile.Position := 0;
      LFile.Write(CDataBaseStructureTag[1], Length(CDataBaseStructureTag));

      for LIndexA := 0 to Pred(Count) do
      begin
        LSize := 0;
        LFile.Write(LSize, SizeOf(LSize));

        LList := TStructureItemList(Items[LIndexA]);
        if (LList <> nil) then
        begin
          LSize := Length(LList.Name);
          LFile.Write(LSize, SizeOf(LSize));

          LFile.Write(LList.Name[1], Length(LList.Name));

          for LIndexB := 0 to Pred(LList.Count) do
          begin
            LItem := TStructureItem(LList.Items[LIndexB]);
            if (LItem <> nil) then
            begin
              LSize := Length(LItem.ItemName);
              LFile.Write(LSize, SizeOf(LSize));

              LFile.Write(LItem.ItemName[1], Length(LItem.ItemName));
              LFile.Write(LItem.ItemPrimary, SizeOf(LItem.ItemPrimary));
              LFile.Write(LItem.ItemType,    SizeOf(LItem.ItemType));

              LSize := LItem.ItemSize;
              LFile.Write(LSize, SizeOf(LSize));
            end;
          end;
        end;
      end;

      LFile.Size := LFile.Position;
    finally
      LFile.Free;
    end;
  end
  else
    raise Exception.Create('Structure File Could Not Be Opened');
end;

function THierarchyList.SearchIndex(const AName: String): LongInt;
var
  LIndex : LongInt;
  LItem  : TStructureItemList;
begin
  Result := - 1;

  for LIndex := 0 to Pred(Count) do
  begin
    LItem := TStructureItemList(Items[LIndex]);
    if (LItem <> nil) then
    begin
      if (AnsiLowerCase(LItem.Name) = AnsiLowerCase(AName)) then
      begin
        Result := LIndex;

        Break;
      end;
    end;
  end;

  if (Result < 0) then
    raise Exception.Create('Hierarchy Level Does Not Exist');
end;

function THierarchyList.SearchItem(const AName : String) : TStructureItemList;
var
  LIndex : LongInt;
begin
  Result := nil;

  LIndex := SearchIndex(AName);
  if (LIndex >= 0) then
    Result := Items[LIndex];
end;

end.
