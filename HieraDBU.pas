unit HieraDBU;

// Please, don't delete this comment. \\
(*
  Copyright Owner: Yahe
  Copyright Year : 2007-2018

  Unit   : HieraDBU (platform independant)
  Version: 0.1a3

  Contact E-Mail: hello@yahe.sh
*)
// Please, don't delete this comment. \\

(*
  Description:

  This unit contains the interface to the TDataBaseEngine class.
*)

(*
  Change Log:

  [Version 0.1a] (17.09.2007: initial release)
  - initial release

  [Version 0.1a2] (18.09.2007: minor bugfix)
  - bound check in Next() method was incorrect 

  [Version 0.1a3] (18.09.2007: improvements)
  - exception escalation increased
  - property DataBase now only returns if DataBase is opened
*)

interface

uses
  SysUtils,
  DBStrucU,
  DBRecU,
  DBLangU,
  DBEngU,
  DBActU;

type
  THierarchicalDataBase = class;

  THierarchicalDataBase = class(TObject)
  private
  protected
    FAutoClearResults : Boolean;
    FCurrent          : LongInt;
    FEngine           : TDataBaseEngine;
    FLevel            : String;
    FParser           : TLanguageParser;
    FResults          : TRecordItemList;

    function GetDataBase : String;
    function GetDirectory : String;
    procedure SetDirectory(const AValue : String);

    function GetIsOpen : Boolean;

    function GetLevelCount : LongInt;
    function GetLevelName(const AIndex : LongInt) : String;

    function GetColumnCount(const ALevel : String) : LongInt;
    function GetColumnName(const ALevel : String; const AIndex : LongInt) : String;
    function GetColumnSize(const ALevel : String; const AIndex : LongInt) : Byte;
    function GetColumnType(const ALevel : String; const AIndex : LongInt) : TItemTypeEnum;

    function GetCount : LongInt;
    function GetIndex : LongInt;
    function GetCurrent : TRecordItem;
    function GetFirst : Boolean;
    function GetLast : Boolean;
    function GetNext : Boolean;
    function GetPrevious : Boolean;
    function GetResult(const AIndex : LongInt) : TRecordItem;
  public
    constructor Create;                            overload;
    constructor Create(const ADirectory : String); overload;

    destructor Destroy; override;

    property AutoClearResults : Boolean read FAutoClearResults write FAutoClearResults;

    property DataBase  : String  read GetDataBase;
    property Directory : String  read GetDirectory write SetDirectory;
    property IsOpen    : Boolean read GetIsOpen;

    property LevelCount                        : LongInt read GetLevelCount;
    property LevelName[const AIndex : LongInt] : String  read GetLevelName;

    property ColumnCount[const ALevel : String]                        : LongInt       read GetColumnCount;
    property ColumnName[const ALevel : String; const AIndex : LongInt] : String        read GetColumnName;
    property ColumnSize[const ALevel : String; const AIndex : LongInt] : Byte          read GetColumnSize;
    property ColumnType[const ALevel : String; const AIndex : LongInt] : TItemTypeEnum read GetColumnType;

    property Count                          : LongInt     read GetCount;
    property Index                          : LongInt     read GetIndex;
    property Current                        : TRecordItem read GetCurrent;
    property CurrentLevel                   : String      read FLevel;
    property First                          : Boolean     read GetFirst;
    property Last                           : Boolean     read GetLast;
    property Next                           : Boolean     read GetNext;
    property Previous                       : Boolean     read GetPrevious;
    property Result[const AIndex : LongInt] : TRecordItem read GetResult;

    function Execute(const ACommand : String) : Boolean;

    procedure ClearResults;
  published
  end;

implementation

{ THierarchicalDataBase }

constructor THierarchicalDataBase.Create;
begin
  inherited Create;

  FAutoClearResults := true;
  FCurrent          := - 1;
  FEngine           := TDataBaseEngine.Create;
  FLevel            := '';
  FParser           := TLanguageParser.Create;
  FResults          := nil;
end;

constructor THierarchicalDataBase.Create(const ADirectory : String);
begin
  Create;

  FEngine.Directory := ADirectory;
end;

destructor THierarchicalDataBase.Destroy;
begin
  if (FEngine <> nil) then
  begin
    FEngine.Free;
    FEngine := nil;
  end;
  if (FParser <> nil) then
  begin
    FParser.Free;
    FParser := nil;
  end;
  if (FResults <> nil) then
  begin
    FResults.Free;
    FResults := nil;
  end;

  inherited Destroy;
end;

function THierarchicalDataBase.GetDataBase : String;
begin
  Result := '';

  if FEngine.Opened then
    Result := FEngine.DataBaseName;
end;

function THierarchicalDataBase.GetDirectory : String;
begin
  Result := FEngine.Directory;
end;

procedure THierarchicalDataBase.SetDirectory(const AValue : String);
begin
  if not(FEngine.Opened) then
    FEngine.Directory := AValue;
end;

function THierarchicalDataBase.GetLevelCount : LongInt;
begin
  Result := - 1;

  if (FEngine.Opened) then
    Result := FEngine.Structure.Count;
end;

function THierarchicalDataBase.GetLevelName(const AIndex : LongInt) : String;
var
  LItem : TStructureItemList;
begin
  Result := '';

  if (FEngine.Opened) then
  begin
    if ((AIndex >= 0) and (FEngine.Structure.Count > AIndex)) then
    begin
      LItem := TStructureItemList(FEngine.Structure.Items[AIndex]);
      if (LItem <> nil) then
        Result := LItem.Name;
    end;
  end;
end;

function THierarchicalDataBase.GetColumnCount(const ALevel : String) : LongInt;
var
  LItem : TStructureItemList;
begin
  Result := - 1;

  if (FEngine.Opened) then
  begin
    LItem := FEngine.Structure.SearchItem(ALevel);
    if (LItem <> nil) then
      Result := LItem.Count;
  end;
end;

function THierarchicalDataBase.GetColumnName(const ALevel : String; const AIndex : LongInt) : String;
var
  LItemA : TStructureItemList;
  LItemB : TStructureItem;
begin
  Result := '';

  if (FEngine.Opened) then
  begin
    LItemA := FEngine.Structure.SearchItem(ALevel);
    if (LItemA <> nil) then
    begin
      if ((AIndex >= 0) and (LItemA.Count > AIndex)) then
      begin
        LItemB := TStructureItem(LItemA.Items[AIndex]);
        if (LItemB <> nil) then
          Result := LItemB.ItemName;
      end;
    end;
  end;
end;

function THierarchicalDataBase.GetColumnSize(const ALevel : String; const AIndex : LongInt) : Byte;
var
  LItemA : TStructureItemList;
  LItemB : TStructureItem;
begin
  Result := 0;

  if (FEngine.Opened) then
  begin
    LItemA := FEngine.Structure.SearchItem(ALevel);
    if (LItemA <> nil) then
    begin
      if ((AIndex >= 0) and (LItemA.Count > AIndex)) then
      begin
        LItemB := TStructureItem(LItemA.Items[AIndex]);
        if (LItemB <> nil) then
          Result := LItemB.ItemSize;
      end;
    end;
  end;
end;

function THierarchicalDataBase.GetColumnType(const ALevel : String; const AIndex : LongInt) : TItemTypeEnum;
var
  LItemA : TStructureItemList;
  LItemB : TStructureItem;
begin
  Result := iteRaw;

  if (FEngine.Opened) then
  begin
    LItemA := FEngine.Structure.SearchItem(ALevel);
    if (LItemA <> nil) then
    begin
      if ((AIndex >= 0) and (LItemA.Count > AIndex)) then
      begin
        LItemB := TStructureItem(LItemA.Items[AIndex]);
        if (LItemB <> nil) then
          Result := LItemB.ItemType;
      end;
    end;
  end;
end;

function THierarchicalDataBase.GetCount : LongInt;
begin
  Result := - 1;

  if ((FEngine.Opened) and (FResults <> nil)) then
    Result := FResults.Count;
end;

function THierarchicalDataBase.GetCurrent : TRecordItem;
begin
  Result := nil;

  if ((FEngine.Opened) and (FResults <> nil)) then
  begin
    if ((FResults.Count > FCurrent) and (FCurrent >= 0)) then
      Result := TRecordItem(FResults.Items[FCurrent]);
  end;
end;

function THierarchicalDataBase.GetFirst : Boolean;
begin
  Result := false;

  if ((FEngine.Opened) and (FResults <> nil)) then
  begin
    if (FResults.Count > 0) then
    begin
      FCurrent := 0;

      Result := true;
    end;
  end;
end;

function THierarchicalDataBase.GetIndex : LongInt;
begin
  Result := - 1;

  if ((FEngine.Opened) and (FResults <> nil)) then
  begin
    if ((FResults.Count > FCurrent) and (FCurrent >= 0)) then
      Result := FCurrent;
  end;
end;

function THierarchicalDataBase.GetLast : Boolean;
begin
  Result := false;

  if ((FEngine.Opened) and (FResults <> nil)) then
  begin
    if (FResults.Count > 0) then
    begin
      FCurrent := Pred(FResults.Count);

      Result := true;
    end;
  end;
end;

function THierarchicalDataBase.GetNext : Boolean;
begin
  Result := false;

  if ((FEngine.Opened) and (FResults <> nil)) then
  begin
    if (FResults.Count > Succ(FCurrent)) and (FCurrent >= 0) then
    begin
      Inc(FCurrent);

      Result := true;
    end;
  end;
end;

function THierarchicalDataBase.GetPrevious : Boolean;
begin
  Result := false;

  if ((FEngine.Opened) and (FResults <> nil)) then
  begin
    if (FResults.Count > 0) and (FCurrent > 0) then
    begin
      Dec(FCurrent);

      Result := true;
    end;
  end;
end;

function THierarchicalDataBase.GetResult(const AIndex : LongInt) : TRecordItem;
begin
  Result := nil;

  if ((FEngine.Opened) and (FResults <> nil)) then
  begin
    if ((FResults.Count > AIndex) and (AIndex >= 0)) then
      Result := TRecordItem(FResults.Items[AIndex]);
  end;
end;

function THierarchicalDataBase.Execute(const ACommand : String) : Boolean;
var
  LAction      : TActionTypeEnum;
  LActionData  : TActionData;
  LAssignments : TAssignmentItemList;
  LEquations   : TEquationList;
  LHierarchy   : THierarchyList;
  LIndex       : LongInt;
  LRecords     : TRecordItemList;
  LValue       : String;
begin
  Result := false;

  if FAutoClearResults then
    ClearResults;

  if (Length(ACommand) > 0) then
  begin
    LAction := FParser.ParseAction(ACommand, LValue);

    if (LAction <> ateUnknown) then
    begin
      if (LAction in [ateGet, ateSet, ateInsert, ateRemove, ateReference]) then
      begin
        LActionData := TActionData.Create;
        // try // we will loose lots of exceptions otherwise
          LActionData.IdentifierName := FParser.ParseName(LValue, LValue);

          LAssignments := FParser.ParseASSIGN(LValue, LValue);
          if (LAssignments <> nil) then
          begin
            try
              for LIndex := 0 to Pred(LAssignments.Count) do
                LActionData.Assignments.Add(LAssignments.Items[LIndex]);
            finally
              LAssignments.Clear;
              LAssignments.Free;
            end;
          end;

          LActionData.WhereAll := FParser.ParseAllSign(LValue, LValue);
          if LActionData.WhereAll then
            LActionData.WhereNoDuplicates := not(FParser.ParseAllSign(LValue, LValue));

          LEquations := FParser.ParseWHERE(LValue, LValue);
          if (LEquations <> nil) then
          begin
            try
              for LIndex := 0 to Pred(LEquations.Count) do
                LActionData.WhereEquations.Add(LEquations.Items[LIndex]);
            finally
              LEquations.Clear;
              LEquations.Free;
            end;
          end;

          LActionData.InAll := FParser.ParseAllSign(LValue, LValue);
          if LActionData.InAll then
            LActionData.InNoDuplicates := not(FParser.ParseAllSign(LValue, LValue));

          LEquations := FParser.ParseIn(LValue, LValue);
          if (LEquations <> nil) then
          begin
            try
              for LIndex := 0 to Pred(LEquations.Count) do
                LActionData.InEquations.Add(LEquations.Items[LIndex]);
            finally
              LEquations.Clear;
              LEquations.Free;
            end;
          end;

          case LAction of
            ateGet :
            begin
              LRecords := FEngine.GetEntry(LActionData);

              if (FAutoClearResults or (FResults = nil)) then
              begin
                FLevel   := LActionData.IdentifierName;
                FResults := LRecords;
              end
              else
              begin
                if (AnsiLowerCase(Trim(LActionData.IdentifierName)) <> AnsiLowerCase(Trim(FLevel))) then
                  FLevel := '';

                 try
                   for LIndex := 0 to Pred(LRecords.Count) do
                     FResults.Add(LRecords.Items[LIndex]);
                 finally
                   LRecords.Clear;
                   LRecords.Free;
                 end;
              end;
            end;

            ateSet :
            begin
              FEngine.SetEntry(LActionData);
            end;

            ateInsert :
            begin
              FEngine.InsertEntry(LActionData);
            end;

            ateRemove :
            begin
              FEngine.RemoveEntry(LActionData);
            end;

            ateReference :
            begin
              FEngine.ReferenceEntry(LActionData);
            end;
          end;
        // finally // we will loose lots of exceptions otherwise
          LActionData.Free;
        // end; // we will loose lots of exceptions otherwise
      end
      else
      begin
        if (LAction in [ateCreate]) then
        begin
          FEngine.DataBaseName := FParser.ParseName(LValue, LValue);

          LHierarchy := FParser.ParseWITH(LValue, LValue);
          if (LHierarchy <> nil) then
            FEngine.CreateDataBase(LHierarchy);
        end
        else
        begin
          if (LAction in [ateOpen]) then
          begin
            FEngine.DataBaseName := FParser.ParseName(LValue, LValue);
            FEngine.OpenDataBase;

            Result := true;
          end
          else
          begin
            if (LAction in [ateClose, ateSave, ateOptimize]) then
            begin
              case LAction of
                ateClose    : FEngine.CloseDataBase;
                ateOptimize : FEngine.Equilibrate;
                ateSave     : FEngine.SaveData;
              end;

              Result := true;
            end;
          end;
        end;
      end;
    end;
  end;
end;

function THierarchicalDataBase.GetIsOpen: Boolean;
begin
  Result := FEngine.Opened;
end;

procedure THierarchicalDataBase.ClearResults;
begin
  FLevel := '';

  if (FResults <> nil) then
  begin
    FResults.Free;
    FResults := nil;
  end;
end;

end.
