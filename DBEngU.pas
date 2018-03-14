unit DBEngU;

// Please, don't delete this comment. \\
(*
  Copyright Owner: Yahe
  Copyright Year : 2007-2018

  Unit   : DBEngU (platform independant)
  Version: 0.1a4

  Contact E-Mail: hello@yahe.sh
*)
// Please, don't delete this comment. \\

(*
  Description:

  This unit contains the core database engine.
*)

(*
  Change Log:

  [Version 0.1a] (17.09.2007: initial release)
  - initial release

  [Version 0.1a2] (19.09.2007: minor improvements)
  - References are recognized as duplicates as well
  - Index search only triggers on exact requests

  [Version 0.1a3] (20.09.2007: improvements)
  - SetPrimaryKeys() does not change handles anymore
  - SetEntry() sets primary keys correctly now
  - FindRecords() now correctly recognizes result entries
  - locking moved to seperate class TDataBaseLock

  [Version 0.1a4] (01.10.2007: Delphi-specific correction)
  - HashedDateTime() implemented to generate instance specific ID
*)

interface

// define if you only want to have one file for each hierarchy level
{$DEFINE UseMinimalFiles}

uses
  SysUtils,
  Classes,
  DBTreeU,
  DBStrucU,
  DBRecU,
  DBLockU,
  DBFileU,
  DBDataU,
  DBActU;

type
  TDataBaseEngine = class;

  TLongWordArray = array of LongWord;

  TDataBaseEngine = class(TObject)
  private
  protected
    FDataBaseName : String;
    FDirectory    : String;
    FOpened       : Boolean;

    FFileItemList   : TFileItemList;
    FHierarchyList  : THierarchyList;
    FHierarchyTree  : THierarchyTree;
    FLockHandle     : LongInt;
    FLocking        : TDataBaseLock;

    function HashedDateTime : LongInt;

    function GetFileName(const AExtension : String) : String;
    function GetFolderName : String;

    procedure SetDataBaseName(const AValue : String);
    procedure SetDirectory(const AValue : String);

    function FindRecords(const ATree : THierarchyTree; const AStartLevel : LongInt; const AAll : Boolean; const ANoDuplicates : Boolean; AIdentifierName : String; const AEquations : TEquationList; const ALevelBefore : Boolean) : TTreeItemList;
    function GetRecord(const ARecordPath : TLongWordArray) : TRecordItem;

    procedure SetPrimaryKeys(const AIdentifierName : String; const AFileID : LongWord; const APositionID : LongWord; const APrimaryKeyOld : LongWord; const APrimaryKeyNew : LongWord);
    procedure SetRecordData(const ARecordItem : TRecordItem; const AAction : TActionData);
  public
    constructor Create; overload;
    constructor Create(const ADirectory : String; const ADataBaseName: String); overload;

    destructor Destroy; override;

    property DataBaseName : String         read FDataBaseName  write SetDataBaseName;
    property Directory    : String         read FDirectory     write SetDirectory;
    property Opened       : Boolean        read FOpened;
    property Structure    : THierarchyList read FHierarchyList;

    procedure CreateDataBase(const AHierarchyList : THierarchyList);
    procedure CloseDataBase;
    procedure OpenDataBase;

    function GetEntry(const AAction : TActionData) : TRecordItemList;
    procedure SetEntry(const AAction : TActionData);

    procedure InsertEntry(const AAction : TActionData);
    procedure RemoveEntry(const AAction : TActionData);

    procedure ReferenceEntry(const AAction : TActionData);

    procedure Equilibrate;

    procedure SaveData;

    procedure SaveFileList;
    procedure SaveStructure;
    procedure SaveTree;
  published
  end;

implementation

type
  TEnlistTraverse = class(TTraverseObject)
  private
  protected
    FEquations : TEquationItemList;
    FFiles     : TFileItemList;
    FList      : TTreeItemList;
    FStructure : TStructureItemList;
  public
    procedure OnTraverse(const ATreeItem : TTreeItem; var AAbort : Boolean); override;

    function IsEqual(const ARecordItem : TRecordItem; const AEquations : TEquationItemList) : Boolean;

    procedure Initialize(const AList : TTreeItemList; const AFiles : TFileItemList; const AStructure : TStructureItemList; const AEquations : TEquationItemList);
  published
  end;

  TFindItem = class(TObject)
  private
  protected
    FDeletable : Boolean;
    FItem      : TTreeItem;
    FParent    : LongInt;
    FPrevious  : Boolean;
    FResult    : Boolean;
  public
    constructor Create(const ADeletable : Boolean; const AItem : TTreeItem; const AParent : LongInt; const APrevious : Boolean; const AResult : Boolean); overload;

    property Deletable : Boolean   read FDeletable write FDeletable;
    property Item      : TTreeItem read FItem      write FItem;
    property Parent    : LongInt   read FParent    write FParent;
    property Previous  : Boolean   read FPrevious  write FPrevious;
    property Result    : Boolean   read FResult    write FResult;
  published
  end;

  TFindList = class(TList)
  private
  protected
  public
    destructor Destroy; override;

    function AddItem(const ADeletable : Boolean; const AItem : TTreeItem; const AParent : LongInt; const APrevious : Boolean; const AResult : Boolean) : LongInt;

    procedure ClearList;
  published
  end;

const
{$IFDEF MSWINDOWS}
  CPathDivider = '\';
{$ELSE MSWINDOWS}
  CPathDivider = '/';
{$ENDIF MSWINDOWS}

{ TDataBaseEngine }

procedure TDataBaseEngine.CloseDataBase;
begin
  if FOpened then
  begin
    SaveData;

    FFileItemList.Free;
    FFileItemList := nil;
    FHierarchyList.Free;
    FHierarchyList := nil;
    FHierarchyTree.Free;
    FHierarchyTree := nil;

    FLocking.RemoveLock(GetFileName(CDataBaseLockTag), FLockHandle);

    FOpened := false;
  end;
end;

constructor TDataBaseEngine.Create;
begin
  inherited Create;

  FOpened := false;

  FFileItemList   := nil;
  FHierarchyList  := nil;
  FHierarchyTree  := nil;

  FLockHandle := Integer(Self) + HashedDateTime;
  FLocking    := TDataBaseLock.Create;
end;

destructor TDataBaseEngine.Destroy;
begin
  if FOpened then
    CloseDataBase;

  FLocking.Free;
  FLocking := nil;

  inherited Destroy;
end;

function TDataBaseEngine.GetFileName(const AExtension : String) : String;
begin
  Result := GetFolderName + FDataBaseName + '.' + AExtension;
end;

function TDataBaseEngine.GetFolderName : String;
begin
  Result := FDirectory;
  if (Length(Result) > 0) then
  begin
    if (Result[Length(Result)] <> CPathDivider) then
      Result := Result + CPathDivider;
  end;
  Result := Result + FDataBaseName + CPathDivider;
end;

function TDataBaseEngine.GetRecord(const ARecordPath : TLongWordArray) : TRecordItem;
var
  LDataAccess    : TDataAccess;
  LFileItem      : TFileItem;
  LHierarchyTree : THierarchyTree;
  LItem          : TTreeItem;
  LIndex         : LongInt;
begin
  Result := nil;

  if FOpened then
  begin
    LHierarchyTree := FHierarchyTree;
    for LIndex := 0 to Pred(Length(ARecordPath)) do
    begin
      if (LHierarchyTree <> nil) then
      begin
        LItem := LHierarchyTree.SearchItem(ARecordPath[LIndex]);
        if (LItem <> nil) then
        begin
          if (LIndex = Pred(Length(ARecordPath))) then
          begin
            LFileItem := TFileItem(FFileItemList.Items[LItem.FileID]); //!! No FileID
            if (LFileItem <> nil) then
            begin
              LDataAccess := LFileItem.DataAccess;
              if (LDataAccess <> nil) then
                Result := LDataAccess.LoadAsRecord(LItem.PositionID, FHierarchyList.Items[LIndex]);
            end;
          end
          else
            LHierarchyTree := LItem.Middle;
        end
        else
          Break;
      end
      else
        Break;
    end;
  end;
end;

function TDataBaseEngine.GetEntry(const AAction : TActionData) : TRecordItemList;
var
  LFileItem          : TFileItem;
  LIndex             : LongInt;
  LItem              : TTreeItem;
  LStructureItemList : TStructureItemList;
  LTreeList          : TTreeItemList;
begin
  Result := nil;

  if (FOpened and (AAction <> nil)) then
  begin
    LStructureItemList := FHierarchyList.SearchItem(AAction.IdentifierName);
    if (LStructureItemList <> nil) then
    begin
      LTreeList := FindRecords(FHierarchyTree, 0, AAction.WhereAll, AAction.WhereNoDuplicates, AAction.IdentifierName, AAction.WhereEquations, false);
      if (LTreeList <> nil) then
      begin
        try
          for LIndex := 0 to Pred(LTreeList.Count) do
          begin
            LItem := TTreeItem(LTreeList.Items[LIndex]);
            if (LItem <> nil) then
            begin
              LFileItem := TFileItem(FFileItemList.Items[LItem.FileID]); //!! No FileID
              if (LFileItem <> nil) then
              begin
                if (Result = nil) then
                  Result := TRecordItemList.Create;

                Result.Add(LFileItem.DataAccess.LoadAsRecord(LItem.PositionID, LStructureItemList));
              end
              else
                raise Exception.Create('File Could Not Be Accessed');
            end;
          end;
        finally
          LTreeList.Clear;
          LTreeList.Free;
        end;
      end;
    end;
  end
  else
    raise Exception.Create('DataBase Not Open or ActionData Empty');
end;

procedure TDataBaseEngine.InsertEntry(const AAction : TActionData);
var
  LFileID            : LongInt;
  LFileItem          : TFileItem;
  LIndex             : LongInt;
  LItem              : TTreeItem;
  LRecordItem        : TRecordItem;
  LStructureItemList : TStructureItemList;
  LTreeList          : TTreeItemList;
begin
  if (FOpened and (AAction <> nil)) then
  begin
    LStructureItemList := FHierarchyList.SearchItem(AAction.IdentifierName);
    if (LStructureItemList <> nil) then
    begin
      LRecordItem := TRecordItem.Create;
      try
        SetRecordData(LRecordItem, AAction);
        LRecordItem.ReferenceCount := 1;

        LTreeList := FindRecords(FHierarchyTree, 0, AAction.WhereAll, AAction.WhereNoDuplicates, AAction.IdentifierName, AAction.WhereEquations, true);
        if (LTreeList <> nil) then
        begin
          try
            for LIndex := 0 to Pred(LTreeList.Count) do
            begin
              LItem := TTreeItem(LTreeList.Items[LIndex]);
              if (LItem <> nil) then
              begin
{$IFDEF UseMinimalFiles}
                LFileID := FHierarchyList.SearchIndex(AAction.IdentifierName);
                while (FFileItemList.Count <= LFileID) do
                  FFileItemList.AddItem(GetFileName(IntToStr(FFileItemList.Count) + '.' + CDataBaseDataTag));
{$ELSE UseMinimalFiles}
                if (LItem.Middle.Root <> nil) then
                  LFileID := LItem.Middle.Root.FileID
                else
                  LFileID := FFileItemList.AddItem(GetFileName(IntToStr(FFileItemList.Count) + '.' + CDataBaseDataTag));
{$ENDIF UseMinimalFiles}

                LFileItem := TFileItem(FFileItemList.Items[LFileID]);
                if (LFileItem <> nil) then
                begin
                  LItem.Middle.InsertItem(LRecordItem.PrimaryKey[false], LFileID, LFileItem.DataAccess.RecordCount(LStructureItemList));
                  LFileItem.DataAccess.SaveAsRecord(LFileItem.DataAccess.RecordCount(LStructureItemList), LStructureItemList, LRecordItem);
                end
                else
                  raise Exception.Create('File Could Not Be Accessed');
              end;
            end;
          finally
            LTreeList.Clear;
            LTreeList.Free;
          end;
        end
        else
        begin
          if (FHierarchyList.SearchIndex(AAction.IdentifierName) = 0) then
          begin
{$IFDEF UseMinimalFiles}
            LFileID := 0;
            while (FFileItemList.Count <= LFileID) do
              FFileItemList.AddItem(GetFileName(IntToStr(FFileItemList.Count) + '.' + CDataBaseDataTag));
{$ELSE UseMinimalFiles}
            if (FHierarchyTree.Root <> nil) then
              LFileID := FHierarchyTree.Root.FileID
            else
              LFileID := FFileItemList.AddItem(GetFileName(IntToStr(FFileItemList.Count) + '.' + CDataBaseDataTag));
{$ENDIF UseMinimalFiles}

            LFileItem := TFileItem(FFileItemList.Items[LFileID]);
            if (LFileItem <> nil) then
            begin
              FHierarchyTree.InsertItem(LRecordItem.PrimaryKey[false], LFileID, LFileItem.DataAccess.RecordCount(LStructureItemList));
              LFileItem.DataAccess.SaveAsRecord(LFileItem.DataAccess.RecordCount(LStructureItemList), LStructureItemList, LRecordItem);
            end
            else
              raise Exception.Create('File Could Not Be Accessed');
          end;
        end;
      finally
        LRecordItem.Free;
      end;
    end;
  end
  else
    raise Exception.Create('DataBase Not Open or ActionData Empty');
end;

procedure TDataBaseEngine.OpenDataBase;
begin
  if not(FOpened) then
  begin
    if ForceDirectories(GetFolderName) then
    begin
      if FLocking.IsOwnLock(GetFileName(CDataBaseLockTag), FLockHandle) then
      begin
        if FLocking.CreateLock(GetFileName(CDataBaseLockTag), FLockHandle) then
        begin
          FFileItemList := TFileItemList.Create;
          if FileExists(GetFileName(CDataBaseFilesTag)) then
            FFileItemList.LoadFromFile(GetFileName(CDataBaseFilesTag));

          FHierarchyList := THierarchyList.Create;
          if FileExists(GetFileName(CDataBaseStructureTag)) then
            FHierarchyList.LoadFromFile(GetFileName(CDataBaseStructureTag));

          FHierarchyTree := THierarchyTree.Create;
          if FileExists(GetFileName(CDataBaseTreeTag)) then
            FHierarchyTree.LoadFromFile(GetFileName(CDataBaseTreeTag), true);
          FHierarchyTree.TraverseStyle := tsIterative;

          FOpened := true;
        end
        else
          raise Exception.Create('Lock-File Could Not Be Created');
      end
      else
        raise Exception.Create('DataBase Locked By Other Device - No MultiUser-Support');
    end;
  end
  else
    raise Exception.Create('DataBase Already Open');
end;

procedure TDataBaseEngine.RemoveEntry(const AAction : TActionData);
var
  LFileItem          : TFileItem;
  LIndexA            : LongInt;
  LIndexB            : LongInt;
  LItemA             : TTreeItem;
  LItemB             : TTreeItem;
  LItemTreeList      : TTreeItemList;
  LRecordItem        : TRecordItem;
  LStructureIndex    : LongInt;
  LStructureItemList : TStructureItemList;
  LTreeList          : TTreeItemList;
begin
  if (FOpened and (AAction <> nil)) then
  begin
    LStructureItemList := FHierarchyList.SearchItem(AAction.IdentifierName);
    if (LStructureItemList <> nil) then
    begin
      LTreeList := FindRecords(FHierarchyTree, 0, AAction.WhereAll, AAction.WhereNoDuplicates, AAction.IdentifierName, AAction.WhereEquations, true);
      if (LTreeList <> nil) then
      begin
        try
          LStructureIndex := FHierarchyList.SearchIndex(AAction.IdentifierName);
          if (LStructureIndex >= 0) then
          begin
            for LIndexA := 0 to Pred(LTreeList.Count) do
            begin
              LItemA := TTreeItem(LTreeList.Items[LIndexA]);
              if (LItemA <> nil) then
              begin
                LItemTreeList := FindRecords(LItemA.Middle, LStructureIndex, AAction.WhereAll, AAction.WhereNoDuplicates, AAction.IdentifierName, AAction.WhereEquations, false);
                if (LItemTreeList <> nil) then
                begin
                  try
                    for LIndexB := 0 to Pred(LItemTreeList.Count) do
                    begin
                      LItemB := TTreeItem(LItemTreeList.Items[LIndexB]);
                      if (LItemB <> nil) then
                      begin
                        LFileItem := TFileItem(FFileItemList.Items[LItemB.FileID]); //!! No FileID
                        if (LFileItem <> nil) then
                        begin
                          LRecordItem := LFileItem.DataAccess.LoadAsRecord(LItemB.PositionID, LStructureItemList);
                          try
                            if (LRecordItem.ReferenceCount > Low(LRecordItem.ReferenceCount)) then
                              LRecordItem.ReferenceCount := Pred(LRecordItem.ReferenceCount);
                            LFileItem.DataAccess.SaveAsRecord(LItemB.PositionID, LStructureItemList, LRecordItem);

                            LItemA.Middle.RemoveItem(LRecordItem.PrimaryKey[false]);
                          finally
                            LRecordItem.Free;
                          end;
                        end
                        else
                          raise Exception.Create('File Could Not Be Accessed');
                      end;
                    end;
                  finally
                    LItemTreeList.Free;
                  end;
                end;
              end;
            end;
          end;
        finally
          LTreeList.Clear;
          LTreeList.Free;
        end;
      end
      else
      begin
        if (FHierarchyList.SearchIndex(AAction.IdentifierName) = 0) then
        begin
          LItemTreeList := FindRecords(FHierarchyTree, 0, AAction.WhereAll, AAction.WhereNoDuplicates, AAction.IdentifierName, AAction.WhereEquations, false);
          if (LItemTreeList <> nil) then
          begin
            try
              for LIndexA := 0 to Pred(LItemTreeList.Count) do
              begin
                LItemA := TTreeItem(LItemTreeList.Items[LIndexA]);
                if (LItemA <> nil) then
                begin
                  LFileItem := TFileItem(FFileItemList.Items[LItemA.FileID]); //!! No FileID
                  if (LFileItem <> nil) then
                  begin
                    LRecordItem := LFileItem.DataAccess.LoadAsRecord(LItemA.PositionID, LStructureItemList);
                    try
                      if (LRecordItem.ReferenceCount > Low(LRecordItem.ReferenceCount)) then
                        LRecordItem.ReferenceCount := Pred(LRecordItem.ReferenceCount);
                      LFileItem.DataAccess.SaveAsRecord(LItemA.PositionID, LStructureItemList, LRecordItem);

                      FHierarchyTree.RemoveItem(LRecordItem.PrimaryKey[false]);
                    finally
                      LRecordItem.Free;
                    end;
                  end
                  else
                    raise Exception.Create('File Could Not Be Accessed');
                end;
              end;
            finally
              LItemTreeList.Free;
            end;
          end;
        end;
      end;
    end;
  end
  else
    raise Exception.Create('DataBase Not Open or ActionData Empty');
end;

procedure TDataBaseEngine.SaveData;
begin
  SaveFileList;
  SaveStructure;
  SaveTree;
end;

procedure TDataBaseEngine.SaveFileList;
begin
  if FOpened then
    FFileItemList.SaveToFile(GetFileName(CDataBaseFilesTag));
end;

procedure TDataBaseEngine.SaveStructure;
begin
  if FOpened then
    FHierarchyList.SaveToFile(GetFileName(CDataBaseStructureTag));
end;

procedure TDataBaseEngine.SaveTree;
begin
  if FOpened then
    FHierarchyTree.SaveToFile(GetFileName(CDataBaseTreeTag), true);
end;

procedure TDataBaseEngine.SetEntry(const AAction : TActionData);
var
  LFileItem          : TFileItem;
  LIndex             : LongInt;
  LItem              : TTreeItem;
  LPrimaryKey        : LongWord;
  LRecordItem        : TRecordItem;
  LStructureItemList : TStructureItemList;
  LTreeList          : TTreeItemList;
begin
  if (FOpened and (AAction <> nil)) then
  begin
    LStructureItemList := FHierarchyList.SearchItem(AAction.IdentifierName);
    if (LStructureItemList <> nil) then
    begin
      LTreeList := FindRecords(FHierarchyTree, 0, AAction.WhereAll, AAction.WhereNoDuplicates, AAction.IdentifierName, AAction.WhereEquations, false);
      if (LTreeList <> nil) then
      begin
        try
          for LIndex := 0 to Pred(LTreeList.Count) do
          begin
            LItem := TTreeItem(LTreeList.Items[LIndex]);
            if (LItem <> nil) then
            begin
              LFileItem := TFileItem(FFileItemList.Items[LItem.FileID]); //!! No FileID
              if (LFileItem <> nil) then
              begin
                LRecordItem := LFileItem.DataAccess.LoadAsRecord(LItem.PositionID, LStructureItemList);
                try
                  LPrimaryKey := LRecordItem.PrimaryKey[false];

                  SetRecordData(LRecordItem, AAction);
                  if (LRecordItem.PrimaryKey[false] <> LPrimaryKey) then
                    SetPrimaryKeys(AAction.IdentifierName, LItem.FileID, LItem.PositionID, LPrimaryKey, LRecordItem.PrimaryKey[false]); //!! No FileID

                  LFileItem.DataAccess.SaveAsRecord(LItem.PositionID, LStructureItemList, LRecordItem);
                finally
                  LRecordItem.Free;
                end;
              end
              else
                raise Exception.Create('File Could Not Be Accessed');
            end;
          end;
        finally
          LTreeList.Clear;
          LTreeList.Free;
        end;
      end;
    end;
  end
  else
    raise Exception.Create('DataBase Not Open or ActionData Empty');
end;

procedure TDataBaseEngine.CreateDataBase(const AHierarchyList : THierarchyList);
var
  LDone  : Boolean;
  LIndex : LongInt;
  LItem  : TStructureItemList;
begin
  if (AHierarchyList <> nil) then
  begin
    if not(FOpened) then
    begin
      LDone := false;
      for LIndex := Pred(AHierarchyList.Count) downto 0 do
      begin
        LDone := false;

        LItem := TStructureItemList(AHierarchyList.Items[LIndex]);
        if (LItem <> nil) then
        begin
          LDone := (LItem.PrimaryCount > 0);
          if not(LDone) then
            Break;
        end
        else
          AHierarchyList.Delete(LIndex);
      end;

      if LDone then
      begin
        if not(DirectoryExists(GetFolderName)) then
        begin
          if ForceDirectories(GetFolderName) then
          begin
            try
              FFileItemList  := TFileItemList.Create;
              FHierarchyList := AHierarchyList;
              FHierarchyTree := THierarchyTree.Create;

              FOpened := true;
            finally
              CloseDataBase;
            end;
          end;
        end
        else
          raise Exception.Create('DataBase Already Exists');
      end
      else
        raise Exception.Create('DataBase Already Open');
    end
    else
      raise Exception.Create('Every Hierarchy Level Needs A Primary Key Entry');
  end
  else
    raise Exception.Create('Hierarchy Does Not Exist');
end;

procedure TDataBaseEngine.SetDataBaseName(const AValue : String);
begin
  if not(FOpened) then
    FDataBaseName := AValue
  else
    raise Exception.Create('DataBase Already Open.');
end;

procedure TDataBaseEngine.SetDirectory(const AValue: String);
begin
  if not(FOpened) then
    FDirectory := AValue
  else
    raise Exception.Create('DataBase Already Open.');
end;

constructor TDataBaseEngine.Create(const ADirectory: String; const ADataBaseName: String);
begin
  Create;

  FDataBaseName := ADataBaseName;
  FDirectory    := ADirectory;
end;

procedure TDataBaseEngine.Equilibrate;
begin
  if FOpened then
    FHierarchyTree.Equilibrate(true);
end;

procedure TDataBaseEngine.SetRecordData(const ARecordItem : TRecordItem; const AAction : TActionData);
var
  LAssignmentItem : TAssignmentItem;
  LIndex          : LongInt;
  LRecordDataItem : TRecordDataItem;
begin
  if ((ARecordItem <> nil) and (AAction <> nil)) then
  begin
    if (AAction.Assignments <> nil) then
    begin
      ARecordItem.Initialize(FHierarchyList.SearchItem(AAction.IdentifierName));
      for LIndex := 0 to Pred(AAction.Assignments.Count) do
      begin
        LAssignmentItem := TAssignmentItem(AAction.Assignments.Items[LIndex]);
        if (LAssignmentItem <> nil) then
        begin
          LRecordDataItem := ARecordItem.Datum[LAssignmentItem.IdentifierName];
          if (LRecordDataItem <> nil) then
          begin
            case LAssignmentItem.ValueType of
              vtNumber :
              begin
                if (LRecordDataItem.ItemType in [iteFloat, iteIntSigned, iteIntUnsigned]) then
                  LRecordDataItem.Interpreted := LAssignmentItem.Value
                else
                  LRecordDataItem.AsIntSigned := StrToInt(LAssignmentItem.Value);
              end;

              vtText :
              begin
                if (LRecordDataItem.ItemType in [iteRaw, iteString]) then
                  LRecordDataItem.Interpreted := LAssignmentItem.Value
                else
                  LRecordDataItem.AsRaw := LAssignmentItem.Value;
              end;
            end;
          end;
        end;
      end;
    end;
  end;
end;

function TDataBaseEngine.FindRecords(const ATree : THierarchyTree; const AStartLevel : LongInt; const AAll : Boolean; const ANoDuplicates : Boolean; AIdentifierName : String; const AEquations : TEquationList; const ALevelBefore : Boolean) : TTreeItemList;
  function FindPrimaryKey(const ATree : THierarchyTree; const AFileList : TFileItemList; const AStructure : TStructureItemList; const AEquations : TEquationItemList) : TTreeItem;
  var
    LActionData     : TActionData;
    LEnlistTraverse : TEnlistTraverse;
    LEquation       : TEquationItem;
    LFileItem       : TFileItem;
    LIndex          : LongInt;
    LItem           : TEquationItem;
    LPrimaryCount   : LongInt;
    LPrimaryIndex   : LongInt;
    LRecordItem     : TRecordItem;
    LTreeItem       : TTreeItem;
  begin
    Result := nil;

    if ((ATree <> nil) and (AFileList <> nil) and (AStructure <> nil) and (AEquations <> nil)) then
    begin
      LPrimaryCount := AStructure.PrimaryCount;
      if (LPrimaryCount <= AEquations.Count) then
      begin
        LPrimaryIndex := 0;
        for LIndex := 0 to Pred(AEquations.Count) do
        begin
          LItem := TEquationItem(AEquations[LIndex]);
          if (LItem <> nil) then
          begin
            if AStructure.IsPrimary(LItem.IdentifierName) then
            begin
              if ((LItem.EquationType = etEqual) and not(LItem.CheckCase)) then
              begin
                Inc(LPrimaryIndex);

                if (LPrimaryIndex >= LPrimaryCount) then
                  Break;
              end;
            end;
          end;
        end;

        if (LPrimaryIndex >= LPrimaryCount) then
        begin
          LTreeItem := nil; // needed for correct functionality

          LActionData := TActionData.Create;
          try
            LActionData.IdentifierName := AStructure.Name;
            LActionData.Assignments.ClearList;
            for LIndex := 0 to Pred(AEquations.Count) do
            begin
              LEquation := TEquationItem(AEquations.Items[LIndex]);
              if (LEquation <> nil) then
                LActionData.Assignments.AddItem(LEquation.IdentifierName, LEquation.Value, LEquation.ValueType)
            end;

            LRecordItem := TRecordItem.Create;
            try
              SetRecordData(LRecordItem, LActionData);

              LTreeItem := ATree.SearchItem(LRecordItem.PrimaryKey[false]);
            finally
              LRecordItem.Free;
            end;
          finally
            LActionData.Free;
          end;

          if (LTreeItem <> nil) then
          begin
            LFileItem := TFileItem(AFileList.Items[LTreeItem.FileID]); //!! No FileID
            if (LFileItem <> nil) then
            begin
              LRecordItem := LFileItem.DataAccess.LoadAsRecord(LTreeItem.PositionID, AStructure);
              if (LRecordItem <> nil) then
              begin
                try
                  LEnlistTraverse := TEnlistTraverse.Create;
                  try
                    if LEnlistTraverse.IsEqual(LRecordItem, AEquations) then
                      Result := LTreeItem;
                  finally
                    LEnlistTraverse.Free;
                  end;
                finally
                  LRecordItem.Free;
                end;
              end;
            end;
          end;
        end;
      end;
    end;
  end;

var
  LDeepest        : LongInt;
  LEnlistTraverse : TEnlistTraverse;
  LEquationItem   : TEquationItem;
  LEquations      : TEquationItemList;
  LFindItemA      : TFindItem;
  LFindItemB      : TFindItem;
  LIndexA         : LongInt;
  LIndexB         : LongInt;
  LIndexC         : LongInt;
  LIndexD         : LongInt;
  LLevel          : LongInt;
  LNext           : LongInt;
  LStructureList  : TStructureItemList;
  LTree           : THierarchyTree;
  LTreeItemA      : TTreeItem;
  LTreeItemB      : TTreeItem;
  LTreeList       : TTreeItemList;
  LWorkEquations  : TEquationItemList;
  LWorkList       : TFindList;
begin
  Result := TTreeItemList.Create;
  Result.Clear;

  if ((AEquations <> nil) and (ATree <> nil)) then
  begin
    AIdentifierName := AnsiLowerCase(Trim(AIdentifierName));

    LEnlistTraverse := TEnlistTraverse.Create;
    try
      if (AEquations <> nil) and (AEquations.Count > 0) then
      begin
        LTreeList := TTreeItemList.Create;
        try
          LWorkList := TFindList.Create;
          try
            for LIndexA := 0 to Pred(AEquations.Count) do
            begin
              LTree := ATree;

              LEquations := TEquationItemList(AEquations[LIndexA]);
              if (LEquations <> nil) then
              begin
                LLevel := FHierarchyList.SearchIndex(AIdentifierName);
                if ALevelBefore then
                  Dec(LLevel);

                LDeepest := LLevel;
                for LIndexB := 0 to Pred(LEquations.Count) do
                begin
                  LEquationItem := TEquationItem(LEquations.Items[LIndexB]);
                  if (LEquationItem <> nil) then
                  begin
                    if (Length(Trim(LEquationItem.IdentifierLevel)) > 0) then
                    begin
                      LNext := FHierarchyList.SearchIndex(LEquationItem.IdentifierLevel);
                      if (LNext > LDeepest) then
                        LDeepest := LNext;
                    end;
                  end;
                end;

                if (LDeepest >= AStartLevel) then
                begin
                  LWorkList.ClearList;

                  LStructureList := TStructureItemList(FHierarchyList.Items[AStartLevel]);
                  if (LStructureList <> nil) then
                  begin
                    LWorkEquations := LEquations.GetLevel(AIdentifierName, LStructureList.Name);
                    try
                      LTreeList.Clear;

                      LTreeItemA := FindPrimaryKey(LTree, FFileItemList, LStructureList, LWorkEquations);
                      if (LTreeItemA <> nil) then
                        LTreeList.Add(LTreeItemA)
                      else
                      begin
                        LEnlistTraverse.Initialize(LTreeList, FFileItemList, LStructureList, LWorkEquations);
                        LTree.Preorder(LEnlistTraverse);
                      end;

                      LWorkList.ClearList;
                      for LIndexB := 0 to Pred(LTreeList.Count) do
                        LWorkList.AddItem(false, LTreeList.Items[LIndexB], LIndexB, false, (LLevel = AStartLevel));
                    finally
                      if (LWorkEquations <> nil) then
                      begin
                        LWorkEquations.Clear;
                        LWorkEquations.Free;
                      end;
                    end;
                  end;

                  for LIndexB := Succ(AStartLevel) to LDeepest do
                  begin
                    LStructureList := TStructureItemList(FHierarchyList.Items[LIndexB]);
                    if (LStructureList <> nil) then
                    begin
                      LWorkEquations := LEquations.GetLevel(AIdentifierName, LStructureList.Name);
                      try
                        for LIndexC := 0 to Pred(LWorkList.Count) do
                        begin
                          if not(TFindItem(LWorkList.Items[LIndexC]).Previous) then
                          begin
                            LTree := TFindItem(LWorkList.Items[LIndexC]).Item.Middle;
                            if (LTree <> nil) then
                            begin
                              LTreeList.Clear;

                              LTreeItemA := FindPrimaryKey(LTree, FFileItemList, LStructureList, LWorkEquations);
                              if (LTreeItemA <> nil) then
                                LTreeList.Add(LTreeItemA)
                              else
                              begin
                                LEnlistTraverse.Initialize(LTreeList, FFileItemList, LStructureList, LWorkEquations);
                                LTree.Preorder(LEnlistTraverse);
                              end;

                              if (LTreeList.Count > 0) then
                              begin
                                for LIndexD := 0 to Pred(LTreeList.Count) do
                                begin
                                  if (LTreeList.Items[LIndexD] <> nil) then
                                    LWorkList.AddItem(false, LTreeList.Items[LIndexD], TFindItem(LWorkList.Items[LIndexC]).Parent, false, (LIndexB = LLevel));
                                end;
                              end;
                              TFindItem(LWorkList.Items[LIndexC]).Previous := true;
                            end;
                          end;
                          TFindItem(LWorkList.Items[LIndexC]).Deletable := true;
                        end;

                        for LIndexC := Pred(LWorkList.Count) downto 0 do
                        begin
                          LFindItemA := TFindItem(LWorkList.Items[LIndexC]);
                          if (LFindItemA <> nil) then
                          begin
                            if (LIndexB >= LLevel) then
                            begin
                              if ((LFindItemA.Parent >= 0) and (LFindItemA.Parent < LWorkList.Count)) then
                              begin
                                LFindItemB := TFindItem(LWorkList.Items[LFindItemA.Parent]);
                                if (LFindItemB <> nil) then
                                begin
                                  if LFindItemB.Result then
                                  begin
                                    if not(LFindItemA.Deletable) then
                                      LFindItemB.Deletable := false;
                                  end;
                                end;
                              end;
                            end;

                            if LFindItemA.Deletable then
                            begin
                              LFindItemA.Free;
                              LWorkList.Delete(LIndexC);
                            end;
                          end;
                        end;
                      finally
                        if (LWorkEquations <> nil) then
                        begin
                          LWorkEquations.Clear;
                          LWorkEquations.Free;
                        end;
                      end;
                    end;
                  end;

                  if (LWorkList.Count > 0) then
                  begin
                    for LIndexB := 0 to Pred(LWorkList.Count) do
                    begin
                      LFindItemA := TFindItem(LWorkList.Items[LIndexB]);
                      if (LFindItemA <> nil) then
                      begin
                        if LFindItemA.Result then
                        begin
                          Result.Add(LFindItemA.Item);

                          if not(AAll) then
                            Break;
                        end;
                      end;
                    end;

                    if ((Result.Count > 0) and not(AAll)) then
                      Break;
                  end;
                end;
              end;
            end;
          finally
            LWorkList.Free;
          end;
        finally
          LTreeList.Clear;
          LTreeList.Free;
        end;
      end
      else
      begin
        LTree := ATree;

        LLevel := FHierarchyList.SearchIndex(AIdentifierName);
        if ALevelBefore then
          Dec(LLevel);

        if (LLevel >= AStartLevel) then
        begin
          LStructureList := FHierarchyList.Items[AStartLevel];
          if (LStructureList <> nil) then
          begin
            LEnlistTraverse.Initialize(Result, FFileItemList, LStructureList, nil);
            LTree.Preorder(LEnlistTraverse);
          end;

          for LIndexA := Succ(AStartLevel) to LLevel do
          begin
            LStructureList := FHierarchyList.Items[LIndexA];
            if (LStructureList <> nil) then
            begin
              for LIndexB := Pred(Result.Count) downto 0 do
              begin
                LTree := TTreeItem(Result.Items[LIndexB]).Middle;
                if (LTree <> nil) then
                begin
                  LEnlistTraverse.Initialize(Result, FFileItemList, LStructureList, nil);
                  LTree.Preorder(LEnlistTraverse);
                end;

                Result.Delete(LIndexB);
              end;
            end;
          end;

          if not(AAll) then
          begin
            if (Result.Count > 1) then
            begin
              for LIndexA := Pred(Result.Count) downto 1 do
                Result.Delete(LIndexA);
            end;
          end;
        end;
      end;
    finally
      LEnlistTraverse.Free;
    end;
  end;

  if (Result.Count > 0) then
  begin
    if ANoDuplicates then
    begin
      LIndexA := 0;
      while (LIndexA < Result.Count) do
      begin
        LTreeItemA := TTreeItem(Result.Items[LIndexA]);
        if (LTreeItemA <> nil) then
        begin
          LIndexB := Pred(Result.Count);
          while (LIndexB > LIndexA) do
          begin
            LTreeItemB := TTreeItem(Result.Items[LIndexB]);
            if (LTreeItemB <> nil) then
            begin
              if ((LTreeItemA.FileID = LTreeItemB.FileID) and //!! No FileID
                  (LTreeItemA.PositionID = LTreeItemB.PositionID)) then
                Result.Delete(LIndexB);
            end
            else
              Result.Delete(LIndexB);

            Dec(LIndexB);
          end;
        end;

        Inc(LIndexA);
      end;
    end;
  end
  else
  begin
    Result.Free;
    Result := nil;
  end;
end;

procedure TDataBaseEngine.ReferenceEntry(const AAction: TActionData);
var
  LFileItem          : TFileItem;
  LIndexA            : LongInt;
  LIndexB            : LongInt;
  LItemA             : TTreeItem;
  LItemB             : TTreeItem;
  LItemTreeList      : TTreeItemList;
  LRecordItem        : TRecordItem;
  LStructureItemList : TStructureItemList;
  LTreeList          : TTreeItemList;
begin
  if (FOpened and (AAction <> nil)) then
  begin
    LStructureItemList := FHierarchyList.SearchItem(AAction.IdentifierName);
    if (LStructureItemList <> nil) then
    begin
      if (FHierarchyList.SearchIndex(AAction.IdentifierName) > 0) then
      begin
        LTreeList := FindRecords(FHierarchyTree, 0, AAction.WhereAll, AAction.WhereNoDuplicates, AAction.IdentifierName, AAction.WhereEquations, false);
        if (LTreeList <> nil) then
        begin
          try
            for LIndexA := 0 to Pred(LTreeList.Count) do
            begin
              LItemA := TTreeItem(LTreeList.Items[LIndexA]);
              if (LItemA <> nil) then
              begin
                LFileItem := TFileItem(FFileItemList.Items[LItemA.FileID]); //!! No FileID
                if (LFileItem <> nil) then
                begin
                  LRecordItem := LFileItem.DataAccess.LoadAsRecord(LItemA.PositionID, LStructureItemList);
                  try
                    LItemTreeList := FindRecords(FHierarchyTree, 0, AAction.InAll, AAction.InNoDuplicates, AAction.IdentifierName, AAction.InEquations, true);
                    if (LItemTreeList <> nil) then
                    begin
                      try
                        for LIndexB := 0 to Pred(LItemTreeList.Count) do
                        begin
                          LItemB := TTreeItem(LItemTreeList.Items[LIndexB]);
                          if (LItemB <> nil) then
                          begin
                            if (LRecordItem.ReferenceCount < High(LRecordItem.ReferenceCount)) then
                            begin
                              LItemB.Middle.InsertItem(LRecordItem.PrimaryKey[false], LItemA.FileID, LItemA.PositionID); //!! No FileID

                              LRecordItem.ReferenceCount := Succ(LRecordItem.ReferenceCount);
                              LFileItem.DataAccess.SaveAsRecord(LItemA.PositionID, LStructureItemList, LRecordItem);
                            end
                            else
                              raise Exception.Create('Too Many References Exist For DataSet');
                          end;
                        end;
                      finally
                        LItemTreeList.Free;
                      end;
                    end;
                  finally
                    LRecordItem.Free;
                  end;
                end
                else
                  raise Exception.Create('File Could Not Be Accessed');
              end;
            end;
          finally
            LTreeList.Clear;
            LTreeList.Free;
          end;
        end;
      end;
    end;
  end
  else
    raise Exception.Create('DataBase Not Open or ActionData Empty');
end;

procedure TDataBaseEngine.SetPrimaryKeys(const AIdentifierName : String; const AFileID : LongWord; const APositionID : LongWord; const APrimaryKeyOld : LongWord; const APrimaryKeyNew : LongWord);
var
  LIndex      : LongInt;
  LItem       : TTreeItem;
  LRemoveItem : TTreeItem;
  LTreeItem   : TTreeItem;
  LTreeList   : TTreeItemList;
begin
  LTreeList := FindRecords(FHierarchyTree, 0, true, false, AIdentifierName, nil, true);
  if (LTreeList <> nil) then
  begin
    try
      for LIndex := 0 to Pred(LTreeList.Count) do
      begin
        LItem := TTreeItem(LTreeList.Items[LIndex]);
        if (LItem <> nil) then
        begin
          LTreeItem := LItem.Middle.SearchItem(APrimaryKeyOld);
          if (LTreeItem <> nil) then
          begin
            if ((LTreeItem.FileID = AFileID) and (LTreeItem.PositionID = APositionID)) then //!! No FileID
            begin
              LRemoveItem := LItem.Middle.Remove(APrimaryKeyOld);
              if (LRemoveItem <> nil) then
              begin
                LRemoveItem.PrimaryKey := APrimaryKeyNew;

                LItem.Middle.Insert(LRemoveItem);
              end;
            end;
          end;
        end;
      end;
    finally
      LTreeList.Free;
    end;
  end
  else
  begin
    if (FHierarchyList.SearchIndex(AIdentifierName) = 0) then
    begin
      LTreeItem := FHierarchyTree.SearchItem(APrimaryKeyOld);
      if (LTreeItem <> nil) then
      begin
        if ((LTreeItem.FileID = AFileID) and (LTreeItem.PositionID = APositionID)) then //!! No FileID
        begin
          LRemoveItem := FHierarchyTree.Remove(APrimaryKeyOld);
          if (LRemoveItem <> nil) then
          begin
            LRemoveItem.PrimaryKey := APrimaryKeyNew;

            FHierarchyTree.Insert(LRemoveItem);
          end;
        end;
      end;
    end;
  end;
end;

function TDataBaseEngine.HashedDateTime : LongInt;
var
  LDay     : Word;
  LHour    : Word;
  LMinute  : Word;
  LMonth   : Word;
  LMSecond : Word;
  LSecond  : Word;
  LYear    : Word;
begin
  DecodeDate(Now, LYear, LMonth, LDay);
  DecodeTime(Now, LHour, LMinute, LSecond, LMSecond);

  Result := LYear + LMonth + LDay + LHour + LMinute + LSecond + LMSecond;
end;

{ TEnlistTraverse }

procedure TEnlistTraverse.Initialize(const AList : TTreeItemList; const AFiles : TFileItemList; const AStructure : TStructureItemList; const AEquations : TEquationItemList);
begin
  FEquations := AEquations;
  FFiles     := AFiles;
  FList      := AList;
  FStructure := AStructure;
end;

function TEnlistTraverse.IsEqual(const ARecordItem : TRecordItem; const AEquations : TEquationItemList) : Boolean;
var
  LIndex      : LongInt;
  LItem       : TEquationItem;
  LRecordData : TRecordDataItem;
begin
  Result := false;

  if (ARecordItem <> nil) then
  begin
    Result := (AEquations = nil);
    if not(Result) then
      Result := (AEquations.Count <= 0);
    if not(Result) then
    begin
      for LIndex := 0 to Pred(AEquations.Count) do
      begin
        LItem := TEquationItem(AEquations[LIndex]);
        if (LItem <> nil) then
        begin
          LRecordData := ARecordItem.Datum[LItem.IdentifierName];
          if (LRecordData <> nil) then
          begin
            case LItem.EquationType of
              etEqual :
              begin
                case LItem.ValueType of
                  vtNumber :
                  begin
                    Result := (StrToFloat(LItem.Value) = StrToFloat(LRecordData.Interpreted));
                  end;

                  vtText :
                  begin
                    if LItem.CheckCase then
                      Result := (LItem.Value = LRecordData.Interpreted)
                    else
                      Result := (AnsiLowerCase(LItem.Value) = AnsiLowerCase(LRecordData.Interpreted));
                  end;
                end;
              end;

              etLike :
              begin
                case LItem.ValueType of
                  vtNumber :
                  begin
                    Result := (Pos(LItem.Value, LRecordData.Interpreted) > 0);
                  end;

                  vtText :
                  begin
                    if LItem.CheckCase then
                      Result := (Pos(LItem.Value, LRecordData.Interpreted) > 0)
                    else
                      Result := (Pos(AnsiLowerCase(LItem.Value), AnsiLowerCase(LRecordData.Interpreted)) > 0);
                  end;
                end;
              end;

              etGreater :
              begin
                case LItem.ValueType of
                  vtNumber :
                  begin
                    Result := (StrToFloat(LItem.Value) > StrToFloat(LRecordData.Interpreted));
                  end;

                  vtText :
                  begin
                    if LItem.CheckCase then
                      Result := (LItem.Value > LRecordData.Interpreted)
                    else
                      Result := (AnsiLowerCase(LItem.Value) > AnsiLowerCase(LRecordData.Interpreted));
                  end;
                end;
              end;

              etGreaterEqual :
              begin
                case LItem.ValueType of
                  vtNumber :
                  begin
                    Result := (StrToFloat(LItem.Value) >= StrToFloat(LRecordData.Interpreted));
                  end;

                  vtText :
                  begin
                    if LItem.CheckCase then
                      Result := (LItem.Value >= LRecordData.Interpreted)
                    else
                      Result := (AnsiLowerCase(LItem.Value) >= AnsiLowerCase(LRecordData.Interpreted));
                  end;
                end;
              end;

              etSmaller :
              begin
                case LItem.ValueType of
                  vtNumber :
                  begin
                    Result := (StrToFloat(LItem.Value) < StrToFloat(LRecordData.Interpreted));
                  end;

                  vtText :
                  begin
                    if LItem.CheckCase then
                      Result := (LItem.Value < LRecordData.Interpreted)
                    else
                      Result := (AnsiLowerCase(LItem.Value) < AnsiLowerCase(LRecordData.Interpreted));
                  end;
                end;
              end;

              etSmallerEqual :
              begin
                case LItem.ValueType of
                  vtNumber :
                  begin
                    Result := (StrToFloat(LItem.Value) <= StrToFloat(LRecordData.Interpreted));
                  end;

                  vtText :
                  begin
                    if LItem.CheckCase then
                      Result := (LItem.Value <= LRecordData.Interpreted)
                    else
                      Result := (AnsiLowerCase(LItem.Value) <= AnsiLowerCase(LRecordData.Interpreted));
                  end;
                end;
              end;
            end;
          end;

          if LItem.Negate then
            Result := not(Result);
          if not(Result) then
            Break;
        end;
      end;
    end;
  end;
end;

procedure TEnlistTraverse.OnTraverse(const ATreeItem : TTreeItem; var AAbort : Boolean);
var
  LDone       : Boolean;
  LRecordItem : TRecordItem;
begin
  inherited;

  if (FList <> nil) then
  begin
    LDone := (FEquations = nil);
    if not(LDone) then
      LDone := (FEquations.Count <= 0);
    if (not(LDone) and (FFiles <> nil) and (FStructure <> nil)) then
    begin
      LRecordItem := TFileItem(FFiles[ATreeItem.FileID]).DataAccess.LoadAsRecord(ATreeItem.PositionID, FStructure); //!! No FileID
      if (LRecordItem <> nil) then
      begin
        try
          LDone := IsEqual(LRecordItem, FEquations);
        finally
          LRecordItem.Free;
        end;
      end;
    end;

    if LDone then
      FList.Add(ATreeItem);
  end;
end;

{ TFindItem }

constructor TFindItem.Create(const ADeletable: Boolean; const AItem: TTreeItem; const AParent: Integer; const APrevious : Boolean; const AResult : Boolean);
begin
  inherited Create;

  FDeletable := ADeletable;
  FItem      := AItem;
  FParent    := AParent;
  FPrevious  := APrevious;
  FResult    := AResult;
end;

{ TFindList }

function TFindList.AddItem(const ADeletable: Boolean; const AItem: TTreeItem; const AParent: Integer; const APrevious : Boolean; const AResult : Boolean): LongInt;
begin
  Result := Add(TFindItem.Create(ADeletable, AItem, AParent, APrevious, AResult));
end;

procedure TFindList.ClearList;
var
  LIndex : LongInt;
  LItem  : TFindItem;
begin
  for LIndex := Pred(Count) downto 0 do
  begin
    LItem := TFindItem(Items[LIndex]);
    if (LItem <> nil) then
      LItem.Free;
  end;

  Clear;
end;

destructor TFindList.Destroy;
begin
  ClearList;

  inherited Destroy;
end;

end.
