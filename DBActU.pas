unit DBActU;

// Please, don't delete this comment. \\
(*
  Copyright Owner: Yahe
  Copyright Year : 2007-2018

  Unit   : DBActU (platform independant)
  Version: 0.1a1

  Contact E-Mail: hello@yahe.sh
*)
// Please, don't delete this comment. \\

(*
  Description:

  This unit contains the representation of a database command.
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
  TAssignmentItem     = class;
  TAssignmentItemList = class;

  TEquationItem     = class;
  TEquationItemList = class;
  TEquationList     = class;

  TActionData = class;

  TEquationType = (etEqual, etLike, etGreater, etGreaterEqual, etSmaller, etSmallerEqual);
  TValueType    = (vtNumber, vtText);

  TAssignmentItem = class(TObject)
  private
  protected
    FIdentifierName : String;
    FValue          : String;
    FValueType      : TValueType;
  public
    constructor Create(const AIdentifierName : String; const AValue : String; const AValueType : TValueType); overload;

    property IdentifierName : String     read FIdentifierName write FIdentifierName;
    property Value          : String     read FValue          write FValue;
    property ValueType      : TValueType read FValueType      write FValueType;
  published
  end;

  TAssignmentItemList = class(TList)
  private
  protected
  public
    destructor Destroy; override;

    function AddItem(const AIdentifierName : String; const AValue : String; const AValueType : TValueType) : LongInt;

    procedure ClearList;
  published
  end;

  TEquationItem = class(TObject)
  private
  protected
    FCheckCase       : Boolean;
    FEquationType    : TEquationType;
    FIdentifierLevel : String;
    FIdentifierName  : String;
    FNegate          : Boolean;
    FValue           : String;
    FValueType       : TValueType;
  public
    constructor Create(const ACheckCase : Boolean; const AEquationType : TEquationType; const AIdentifierLevel : String; const AIdentifierName : String; const ANegative : Boolean; const AValue : String; const AValueType : TValueType); overload;

    property CheckCase       : Boolean       read FCheckCase       write FCheckCase;
    property EquationType    : TEquationType read FEquationType    write FEquationType;
    property IdentifierLevel : String        read FIdentifierLevel write FIdentifierLevel;
    property IdentifierName  : String        read FIdentifierName  write FIdentifierName;
    property Negate          : Boolean       read FNegate          write FNegate;
    property Value           : String        read FValue           write FValue;
    property ValueType       : TValueType    read FValueType       write FValueType;
  published
  end;

  TEquationItemList = class(TList)
  private
  protected
  public
    destructor Destroy; override;

    function AddItem(const ACheckCase : Boolean; const AEquationType : TEquationType; const AIdentifierLevel : String; const AIdentifierName : String; const ANegative : Boolean; const AValue : String; const AValueType : TValueType) : LongInt;

    function GetLevel(ALevel : String; ACurrentLevel : String) : TEquationItemList;

    procedure ClearList;
  published
  end;

  TEquationList = class(TList)
  private
  protected
  public
    destructor Destroy; override;

    procedure ClearList;
  published
  end;

  TActionData = class(TObject)
  private
  protected
    FAssignments       : TAssignmentItemList;
    FIdentifierName    : String;
    FInAll             : Boolean;
    FInEquations       : TEquationList;
    FInNoDuplicates    : Boolean;
    FWhereAll          : Boolean;
    FWhereEquations    : TEquationList;
    FWhereNoDuplicates : Boolean;
  public
    constructor Create;

    destructor Destroy; override;

    property Assignments       : TAssignmentItemList read FAssignments;
    property IdentifierName    : String              read FIdentifierName    write FIdentifierName;
    property InAll             : Boolean             read FInAll             write FInAll;
    property InEquations       : TEquationList       read FInEquations;
    property InNoDuplicates    : Boolean             read FInNoDuplicates    write FInNoDuplicates;
    property WhereAll          : Boolean             read FWhereAll          write FWhereAll;
    property WhereEquations    : TEquationList       read FWhereEquations;
    property WhereNoDuplicates : Boolean             read FWhereNoDuplicates write FWhereNoDuplicates;
  published
  end;

implementation

{ TEquationItemList }

function TEquationItemList.AddItem(const ACheckCase : Boolean; const AEquationType : TEquationType; const AIdentifierLevel : String; const AIdentifierName : String; const ANegative : Boolean; const AValue : String; const AValueType : TValueType) : LongInt;
begin
  Result := Add(TEquationItem.Create(ACheckCase, AEquationType, AIdentifierLevel, AIdentifierName, ANegative, AValue, AValueType));
end;

procedure TEquationItemList.ClearList;
var
  LIndex : LongInt;
  LItem  : TEquationItem;
begin
  for LIndex := Pred(Count) downto 0 do
  begin
    LItem := TEquationItem(Items[LIndex]);
    if (LItem <> nil) then
      LItem.Free;
  end;

  Clear;
end;

destructor TEquationItemList.Destroy;
begin
  ClearList;

  inherited Destroy;
end;

function TEquationItemList.GetLevel(ALevel : String; ACurrentLevel : String) : TEquationItemList;
var
  LIndex : LongInt;
  LItem  : TEquationItem;
begin
  Result := nil;

  ACurrentLevel := AnsiLowerCase(Trim(ACurrentLevel));
  ALevel        := AnsiLowerCase(Trim(ALevel));

  for LIndex := 0 to Pred(Count) do
  begin
    LItem := TEquationItem(Items[LIndex]);
    if (LItem <> nil) then
    begin
      if ((ACurrentLevel = AnsiLowerCase(Trim(LItem.IdentifierLevel))) or
          (AnsiLowerCase(Trim(LItem.IdentifierLevel)) = '') and (ACurrentLevel = ALevel)) then
      begin
        if (Result = nil) then
          Result := TEquationItemList.Create;

        Result.Add(LItem);
      end;
    end;
  end;
end;

{ TEquationList }

procedure TEquationList.ClearList;
var
  LIndex : LongInt;
  LItem  : TEquationItemList;
begin
  for LIndex := Pred(Count) downto 0 do
  begin
    LItem := TEquationItemList(Items[LIndex]);
    if (LItem <> nil) then
      LItem.Free;
  end;

  Clear;
end;

destructor TEquationList.Destroy;
begin
  ClearList;

  inherited Destroy;
end;

{ TAssignmentItemList }

function TAssignmentItemList.AddItem(const AIdentifierName : String; const AValue : String; const AValueType : TValueType) : LongInt;
begin
  Result := Add(TAssignmentItem.Create(AIdentifierName, AValue, AValueType));
end;

procedure TAssignmentItemList.ClearList;
var
  LIndex : LongInt;
  LItem  : TAssignmentItem;
begin
  for LIndex := Pred(Count) downto 0 do
  begin
    LItem := TAssignmentItem(Items[LIndex]);
    if (LItem <> nil) then
      LItem.Free;
  end;

  Clear;
end;

destructor TAssignmentItemList.Destroy;
begin
  ClearList;

  inherited Destroy;
end;


{ TActionData }

constructor TActionData.Create;
begin
  inherited Create;

  FAssignments    := TAssignmentItemList.Create;
  FInEquations    := TEquationList.Create;
  FWhereEquations := TEquationList.Create;
end;

destructor TActionData.Destroy;
begin
  if (FAssignments <> nil) then
  begin
    FAssignments.Free;
    FAssignments := nil;
  end;
  if (FInEquations <> nil) then
  begin
    FInEquations.Free;
    FInEquations := nil;
  end;
  if (FWhereEquations <> nil) then
  begin
    FWhereEquations.Free;
    FWhereEquations := nil;
  end;

  inherited Destroy;
end;

{ TEquationItem }

constructor TEquationItem.Create(const ACheckCase : Boolean; const AEquationType : TEquationType; const AIdentifierLevel : String; const AIdentifierName : String; const ANegative : Boolean; const AValue : String; const AValueType : TValueType);
begin
  inherited Create;

  FCheckCase       := ACheckCase;
  FEquationType    := AEquationType;
  FIdentifierLevel := AIdentifierLevel;
  FIdentifierName  := AIdentifierName;
  FNegate          := ANegative;
  FValue           := AValue;
  FValueType       := AValueType;
end;

{ TAssignmentItem }

constructor TAssignmentItem.Create(const AIdentifierName : String; const AValue : String; const AValueType : TValueType);
begin
  inherited Create;

  FIdentifierName := AIdentifierName;
  FValue          := AValue;
  FValueType      := AValueType;
end;

end.
