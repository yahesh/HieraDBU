unit DBRecU;

// Please, don't delete this comment. \\
(*
  Copyright Owner: Yahe
  Copyright Year : 2007-2018

  Unit   : DBRecU (platform independant)
  Version: 0.1a1

  Contact E-Mail: hello@yahe.sh
*)
// Please, don't delete this comment. \\

(*
  Description:

  This unit contains access to the fields of a dataset.
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
  DBStrucU;

type
  TRecordDataItem = class;
  TRecordItem     = class;
  TRecordItemList = class;

  TRecordDataItem = class(TObject)
  private
  protected
    FData      : String;
    FStructure : TStructureItem;

    function GetItemName : String;
    function GetItemPrimary : Boolean;
    function GetItemSize : Byte;
    function GetItemType : TItemTypeEnum;

    function GetByte : Byte;
    function GetFloat : Extended;
    function GetIntSigned : LongInt;
    function GetIntUnsigned : LongWord;
    function GetRaw : String;
    function GetString : String;

    function GetInterpreted : String;

    procedure SetByte(const AValue : Byte);
    procedure SetFloat(const AValue : Extended);
    procedure SetIntSigned(const AValue : LongInt);
    procedure SetIntUnsigned(const AValue : LongWord);
    procedure SetRaw(const AValue : String);
    procedure SetString(const AValue : String);

    procedure SetInterpreted(const AValue : String);
  public
    constructor Create(const AStructure : TStructureItem);

    property AsByte        : Byte     read GetByte        write SetByte;
    property AsFloat       : Extended read GetFloat       write SetFloat;
    property AsIntSigned   : LongInt  read GetIntSigned   write SetIntSigned;
    property AsIntUnsigned : LongWord read GetIntUnsigned write SetIntUnsigned;
    property AsRaw         : String   read GetRaw         write SetRaw;
    property AsString      : String   read GetString      write SetString;

    property Interpreted : String read GetInterpreted write SetInterpreted;

    property ItemName    : String        read GetItemName;
    property ItemPrimary : Boolean       read GetItemPrimary;
    property ItemSize    : Byte          read GetItemSize;
    property ItemType    : TItemTypeEnum read GetItemType;
  published
  end;

  TRecordItem = class(TList)
  private
  protected
    FLevel          : String;
    FReferenceCount : Byte;

    function GetData : String;
    function GetDatum(const AItemName : String) : TRecordDataItem;
    function GetPrimaryKey(const ACheckCase : Boolean) : LongWord;
    function GetSize : LongWord;
  public
    destructor Destroy; override;

    property ReferenceCount : Byte read FReferenceCount write FReferenceCount;

    property Data                                   : String          read GetData;
    property Datum[const AItemName : String]        : TRecordDataItem read GetDatum;
    property Level                                  : String          read FLevel;
    property PrimaryKey[const ACheckCase : Boolean] : LongWord        read GetPrimaryKey;
    property Size                                   : LongWord        read GetSize;

    procedure ClearList;
    procedure Initialize(const AStructure : TStructureItemList);
    procedure ParseData(const AData : String);
  published
  end;

  TRecordItemList = class(TList)
  private
  protected
  public
    destructor Destroy; override;

    procedure ClearList;
  published
  end;

implementation

{ TRecordDataItem }

constructor TRecordDataItem.Create(const AStructure: TStructureItem);
begin
  inherited Create;

  if (AStructure <> nil) then
  begin
    FStructure := AStructure;

    SetLength(FData, ItemSize);
  end
  else
    raise Exception.Create('Structure Object Does Not Exist');
end;

function TRecordDataItem.GetByte: Byte;
var
  LSize : Byte;
begin
  LSize := SizeOf(Result);
  if (Length(FData) < LSize) then
    LSize := Length(FData);

  FillChar(Result, SizeOf(Result), 0);
  Move(FData[1], Result, LSize);
end;

function TRecordDataItem.GetFloat: Extended;
var
  LSize : Byte;
begin
  LSize := SizeOf(Result);
  if (Length(FData) < LSize) then
    LSize := Length(FData);

  FillChar(Result, SizeOf(Result), 0);
  Move(FData[1], Result, LSize);
end;

function TRecordDataItem.GetInterpreted: String;
begin
  Result := '';

  case ItemType of
    iteRaw         : Result := AsRaw;
    iteIntSigned   : Result := IntToStr(AsIntSigned);
    iteIntUnsigned : Result := IntToStr(AsIntUnsigned);
    iteByte        : Result := IntToStr(AsByte);
    iteFloat       : Result := FloatToStr(AsFloat);
    iteString      : Result := AsString;
  end;
end;

function TRecordDataItem.GetIntSigned: LongInt;
var
  LSize : Byte;
begin
  LSize := SizeOf(Result);
  if (Length(FData) < LSize) then
    LSize := Length(FData);

  FillChar(Result, SizeOf(Result), 0);
  Move(FData[1], Result, LSize);
end;

function TRecordDataItem.GetIntUnsigned: LongWord;
var
  LSize : Byte;
begin
  LSize := SizeOf(Result);
  if (Length(FData) < LSize) then
    LSize := Length(FData);

  FillChar(Result, SizeOf(Result), 0);
  Move(FData[1], Result, LSize);
end;

function TRecordDataItem.GetItemName: String;
begin
  if (FStructure <> nil) then
    Result := FStructure.ItemName
  else
    raise Exception.Create('Structure Object Does Not Exist');
end;

function TRecordDataItem.GetItemPrimary: Boolean;
begin
  if (FStructure <> nil) then
    Result := FStructure.ItemPrimary
  else
    raise Exception.Create('Structure Object Does Not Exist');
end;

function TRecordDataItem.GetItemSize: Byte;
begin
  if (FStructure <> nil) then
    Result := FStructure.ItemSize
  else
    raise Exception.Create('Structure Object Does Not Exist');
end;

function TRecordDataItem.GetItemType: TItemTypeEnum;
begin
  if (FStructure <> nil) then
    Result := FStructure.ItemType
  else
    raise Exception.Create('Structure Object Does Not Exist');
end;

function TRecordDataItem.GetRaw: String;
var
  LSize : Byte;
begin
  LSize := ItemSize;
  if (Length(FData) < LSize) then
    LSize := Length(FData);

  SetLength(Result, ItemSize);
  FillChar(Result[1], Length(Result), 0);
  Move(FData[1], Result[1], LSize);
end;

function TRecordDataItem.GetString: String;
var
  LCount : LongInt;
  LIndex : LongInt;
  LTemp  : String;
begin
  LCount := 0;
  LTemp  := GetRaw;

  SetLength(Result, Length(LTemp));
  for LIndex := 1 to Length(LTemp) do
  begin
    if (LTemp[LIndex] <> #0) then
    begin
      Inc(LCount);
      Result[LCount] := LTemp[LIndex];
    end
    else
      Break;
  end;
  SetLength(Result, LCount);
end;

procedure TRecordDataItem.SetByte(const AValue: Byte);
var
  LSize : Byte;
begin
  LSize := SizeOf(AValue);
  if (Length(FData) < LSize) then
    LSize := Length(FData);

  FillChar(FData[1], Length(FData), 0);
  Move(AValue, FData[1], LSize);
end;

procedure TRecordDataItem.SetFloat(const AValue: Extended);
var
  LSize : Byte;
begin
  LSize := SizeOf(AValue);
  if (Length(FData) < LSize) then
    LSize := Length(FData);

  FillChar(FData[1], Length(FData), 0);
  Move(AValue, FData[1], LSize);
end;

procedure TRecordDataItem.SetInterpreted(const AValue: String);
begin
  case ItemType of
    iteRaw         : AsRaw         := AValue;
    iteIntSigned   : AsIntSigned   := StrToInt(AValue);
    iteIntUnsigned : AsIntUnsigned := StrToInt(AValue);
    iteByte        : AsByte        := StrToInt(AValue);
    iteFloat       : AsFloat       := StrToFloat(AValue);
    iteString      : AsString      := AValue;
  end;
end;

procedure TRecordDataItem.SetIntSigned(const AValue: Integer);
var
  LSize : Byte;
begin
  LSize := SizeOf(AValue);
  if (Length(FData) < LSize) then
    LSize := Length(FData);

  FillChar(FData[1], Length(FData), 0);
  Move(AValue, FData[1], LSize);
end;

procedure TRecordDataItem.SetIntUnsigned(const AValue: LongWord);
var
  LSize : Byte;
begin
  LSize := SizeOf(AValue);
  if (Length(FData) < LSize) then
    LSize := Length(FData);

  FillChar(FData[1], Length(FData), 0);
  Move(AValue, FData[1], LSize);
end;

procedure TRecordDataItem.SetRaw(const AValue: String);
var
  LSize : Byte;
begin
  LSize := Length(AValue);
  if (Length(FData) < LSize) then
    LSize := Length(FData);

  FillChar(FData[1], Length(FData), 0);
  Move(AValue[1], FData[1], LSize);
end;

procedure TRecordDataItem.SetString(const AValue: String);
begin
  SetRaw(AValue);
end;

{ TRecordItem }

procedure TRecordItem.ClearList;
var
  LIndex : LongInt;
  LItem  : TRecordDataItem;
begin
  for LIndex := Pred(Count) downto 0 do
  begin
    LItem := TRecordDataItem(Items[LIndex]);
    if (LItem <> nil) then
      LItem.Free;
  end;

  Clear;
end;

destructor TRecordItem.Destroy;
begin
  ClearList;

  inherited Destroy;
end;

function TRecordItem.GetData : String;
var
  LIndex : LongInt;
  LItem  : TRecordDataItem;
begin
  Result := Char(FReferenceCount);

  for LIndex := 0 to Pred(Count) do
  begin
    LItem := TRecordDataItem(Items[LIndex]);
    if (LItem <> nil) then
      Result := Result + LItem.AsRaw;
  end;
end;

function TRecordItem.GetDatum(const AItemName : String) : TRecordDataItem;
var
  LIndex : LongInt;
  LItem  : TRecordDataItem;
begin
  Result := nil;

  for LIndex := 0 to Pred(Count) do
  begin
    LItem := TRecordDataItem(Items[LIndex]);
    if (LItem <> nil) then
    begin
      if (AnsiLowerCase(LItem.ItemName) = AnsiLowerCase(AItemName)) then
      begin
        Result := LItem;

        Break;
      end;
    end;
  end;

  if (Result = nil) then
    raise Exception.Create('Field Does Not Exist');
end;

// bases on simple One-At-A-Time hashing algorithms
// needs to be improved to be used in proper system 
function TRecordItem.GetPrimaryKey(const ACheckCase : Boolean) : LongWord;
var
  LIndex : LongInt;
  LItem  : TRecordDataItem;
  LTemp  : String;
begin
  LTemp := '';
  for LIndex := 0 to Pred(Count) do
  begin
    LItem := TRecordDataItem(Items[LIndex]);
    if (LItem <> nil) then
    begin
      if LItem.ItemPrimary then
      begin
        if ((LItem.ItemType = iteString) and not(ACheckCase)) then
          LTemp := LTemp + UpperCase(LItem.AsRaw)
        else
          LTemp := LTemp + LItem.AsRaw;
      end;
    end;
  end;

  Result := 0;
  for LIndex := 1 to Length(LTemp) do
  begin
    Result := Result + Ord(LTemp[LIndex]);
    Result := Result + (Result shl 20);
    Result := Result xor (Result shr 12);
  end;
  Result := Result + (Result shl 6);
  Result := Result xor (Result shr 22);
  Result := Result + (Result shl 30);
end;

function TRecordItem.GetSize: LongWord;
var
  LIndex : LongInt;
  LItem  : TRecordDataItem;
begin
  Result := 0;

  Result := Result + SizeOf(FReferenceCount);

  for LIndex := 0 to Pred(Count) do
  begin
    LItem := TRecordDataItem(Items[LIndex]);
    if (LItem <> nil) then
      Result := Result + LItem.ItemSize;
  end;
end;

procedure TRecordItem.Initialize(const AStructure : TStructureItemList);
var
  LData     : TRecordDataItem;
  LIndex    : LongInt;
  LItem     : TStructureItem;
begin
  ClearList;

  if (AStructure <> nil) then
  begin
    FLevel := AStructure.Name;

    for LIndex := 0 to Pred(AStructure.Count) do
    begin
      LItem := TStructureItem(AStructure.Items[LIndex]);
      if (LItem <> nil) then
      begin
        LData := TRecordDataItem.Create(LItem);
        if (LData <> nil) then
          Add(LData)
        else
          raise Exception.Create('Data Object Could Not Be Created');
      end;
    end;
  end
  else
    raise Exception.Create('Structure Does Not Exist');
end;

procedure TRecordItem.ParseData(const AData : String);
var
  LData     : TRecordDataItem;
  LIndex    : LongInt;
  LPosition : LongInt;
begin
  if (Count > 0) then
  begin
    if (Length(AData) > 0) then
    begin
      LPosition := 0;

      FReferenceCount := Ord(AData[1]);
      LPosition := LPosition + SizeOf(FReferenceCount);

      for LIndex := 0 to Pred(Count) do
      begin
        LData := TRecordDataItem(Items[LIndex]);
        if (LData <> nil) then
        begin
          if (Length(AData) >= (LPosition + LData.ItemSize)) then
          begin
            LData.AsRaw := Copy(AData, Succ(LPosition), LData.ItemSize);

            LPosition := LPosition + LData.ItemSize;
          end
          else
            raise Exception.Create('Data Size Not Matching Structure Size');
        end;
      end;
    end
    else
      raise Exception.Create('Illegal Record Data');
  end
  else
    raise Exception.Create('Record Not Initialized');
end;

{ TRecordItemList }

procedure TRecordItemList.ClearList;
var
  LIndex : LongInt;
  LItem  : TRecordItem;
begin
  for LIndex := Pred(Count) downto 0 do
  begin
    LItem := TRecordItem(Items[LIndex]);
    if (LItem <> nil) then
      LItem.Free;
  end;

  Clear;
end;

destructor TRecordItemList.Destroy;
begin
  ClearList;

  inherited Destroy;
end;

end.
