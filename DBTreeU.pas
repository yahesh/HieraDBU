unit DBTreeU;

// Please, don't delete this comment. \\
(*
  Copyright Owner: Yahe
  Copyright Year : 2007-2018

  Unit   : DBTreeU (platform independant)
  Version: 0.1a3

  Contact E-Mail: hello@yahe.sh
*)
// Please, don't delete this comment. \\

(*
  Description:

  This unit contains classes for managing the index hierarchy tree.
*)

(*
  Change Log:

  [Version 0.1a1] (17.09.2007: initial release)
  - initial release

  [Version 0.1a2] (17.09.2007: small modifications)
  - deleting and saving has improved a bit

  [Version 0.1a3] (20.09.2007: improvements)
  - Insert() introduced
  - Remove() introduced
  - Equilibrate() now works in-place
  - Remove() works correctly now
*)

interface

uses
  SysUtils,
  Classes;

type
  THierarchyTree = class;

  TTraverseObject = class;

  TTreeItem     = class;
  TTreeItemList = class;

  TTraverseStyle = (tsIterative, tsRecursive);

  THierarchyTree = class(TObject)
  private
  protected
    FRoot          : TTreeItem;
    FTraverseStyle : TTraverseStyle;

    procedure InorderIterative(const ATraverse : TTraverseObject);
    procedure PreorderIterative(const ATraverse : TTraverseObject);
    procedure PostorderIterative(const ATraverse : TTraverseObject);

    procedure InorderRecursive(const ATraverse : TTraverseObject);
    procedure PreorderRecursive(const ATraverse : TTraverseObject);
    procedure PostorderRecursive(const ATraverse : TTraverseObject);
  public
    constructor Create;

    destructor Destroy; override;

    property Root          : TTreeItem      read FRoot;
    property TraverseStyle : TTraverseStyle read FTraverseStyle write FTraverseStyle;

    procedure Equilibrate(const AEqulibrateLowerHierarchies : Boolean);

    function Insert(const ATreeItem : TTreeItem) : Boolean;
    function InsertItem(const APrimaryKey : LongWord; const AFileID : LongWord; const APositionID : LongWord) : TTreeItem;

    function Remove(const APrimaryKey : LongWord) : TTreeItem;
    procedure RemoveItem(const APrimaryKey : LongWord);

    function LoadFromFile(const AFileName : String; const ALoadLowerHierarchies : Boolean) : LongWord;
    procedure SaveToFile(const AFileName : String; const ASaveLowerHierarchies : Boolean);

    function SearchItem(const APrimaryKey : LongWord) : TTreeItem;
    function SearchParent(const APrimaryKey : LongWord) : TTreeItem;

    procedure Clear;
    procedure ClearList;

    procedure Inorder(const ATraverse : TTraverseObject);
    procedure Preorder(const ATraverse : TTraverseObject);
    procedure Postorder(const ATraverse : TTraverseObject);
  published
  end;

  TTraverseObject = class(TObject)
  private
  protected
  public
    procedure OnTraverse(const ATreeItem : TTreeItem; var AAbort : Boolean); virtual;
  published
  end;

  TTreeItem = class(TObject)
  private
  protected
    FLeft   : TTreeItem;
    FMiddle : THierarchyTree;
    FRight  : TTreeItem;

    FPrimaryKey : LongWord;

    FFileID     : LongWord; //!! No FileID
    FPositionID : LongWord;
  public
    constructor Create(const APrimaryKey : LongWord; const AFileID : LongWord; const APositionID : LongWord; const ATraverseStyle : TTraverseStyle); overload;

    destructor Destroy; override;

    property Left   : TTreeItem      read FLeft   write FLeft;
    property Middle : THierarchyTree read FMiddle {write FMiddle};
    property Right  : TTreeItem      read FRight  write FRight;

    property PrimaryKey : LongWord read FPrimaryKey write FPrimaryKey;

    property FileID     : LongWord read FFileID     write FFileID; //!! No FileID
    property PositionID : LongWord read FPositionID write FPositionID;

    procedure Assign(const ATreeItem : TTreeItem);
  published
  end;

  TTreeItemList = class(TList)
  private
  protected
  public
    destructor Destroy; override;
  published
  end;

const
  CDataBaseTreeTag = 'DBT';

implementation

type
  TDeleteTraverse = class(TTraverseObject)
  private
  protected
  public
    procedure OnTraverse(const ATreeItem : TTreeItem; var AAbort : Boolean); override;
  published
  end;

  TEquilibrateTraverse = class(TTraverseObject)
  private
  protected
    FEquilibrateLower : Boolean;
    FList             : TTreeItemList;
  public
    constructor Create(const AEquilibrateLower : Boolean); overload;

    property EquilibrateLower : Boolean read FEquilibrateLower write FEquilibrateLower;

    procedure OnTraverse(const ATreeItem : TTreeItem; var AAbort : Boolean); override;

    procedure Initialize(const AList : TTreeItemList);
  published
  end;

  TSaveTraverse = class(TTraverseObject)
  private
  protected
    FCount      : LongWord;
    FFileName   : String;
    FFileStream : TFileStream;
    FSaveLower  : Boolean;
  public
    constructor Create(const ASaveLower : Boolean); overload;

    destructor Destroy; override;

    property SaveLower : Boolean read FSaveLower write FSaveLower;

    procedure OnTraverse(const ATreeItem : TTreeItem; var AAbort : Boolean); override;

    procedure Initialize(const AFileName : String);
    procedure Finalize;
  published
  end;

{ TTreeItem }

procedure TTreeItem.Assign(const ATreeItem : TTreeItem);
begin
  if (ATreeItem <> nil) then
  begin
    FLeft   := ATreeItem.Left;
    FMiddle := ATreeItem.Middle;
    FRight  := ATreeItem.Right;

    FPrimaryKey := ATreeItem.PrimaryKey;
    FFileID     := ATreeItem.FileID; //!! No FileID
    FPositionID := ATreeItem.PositionID;
  end
  else
    raise Exception.Create('Tree Item Does Not Exist');
end;

constructor TTreeItem.Create(const APrimaryKey : LongWord; const AFileID : LongWord; const APositionID : LongWord; const ATraverseStyle : TTraverseStyle);
begin
  inherited Create;

  FPrimaryKey := APrimaryKey;
  FFileID     := AFileID; //!! No FileID
  FPositionID := APositionID;

  FMiddle := THierarchyTree.Create;
  FMiddle.TraverseStyle := ATraverseStyle;
end;

destructor TTreeItem.Destroy;
begin
  if (FMiddle <> nil) then
  begin
    FMiddle.Free;
    FMiddle := nil;
  end;

  inherited Destroy;
end;

{ THierarchyTree }

procedure THierarchyTree.Clear;
begin
  FRoot := nil;
end;

procedure THierarchyTree.ClearList;
var
  LDeleteTraverse : TDeleteTraverse;
begin
  LDeleteTraverse := TDeleteTraverse.Create;
  if (LDeleteTraverse <> nil) then
  begin
    try
      Postorder(LDeleteTraverse);

      Clear;
    finally
      LDeleteTraverse.Free;
    end;
  end
  else
    raise Exception.Create('DeleteTraverse Could Not Be Created');
end;

constructor THierarchyTree.Create;
begin
  inherited Create;

  FRoot          := nil;
  FTraverseStyle := tsRecursive;
end;

destructor THierarchyTree.Destroy;
begin
  ClearList;

  inherited Destroy;
end;

procedure THierarchyTree.Equilibrate(const AEqulibrateLowerHierarchies : Boolean);
var
  LHierarchyTree       : THierarchyTree;
  LIndex               : LongInt;
  LItem                : TTreeItem;
  LList                : TTreeItemList;
  LEquilibrateTraverse : TEquilibrateTraverse;
  LStepLength          : LongInt;
begin
  if (FRoot <> nil) then
  begin
    LList := TTreeItemList.Create;
    if (LList <> nil) then
    begin
      try
        LEquilibrateTraverse := TEquilibrateTraverse.Create(AEqulibrateLowerHierarchies);
        if (LEquilibrateTraverse <> nil) then
        begin
          try
            LEquilibrateTraverse.Initialize(LList);
            Inorder(LEquilibrateTraverse);
          finally
            LEquilibrateTraverse.Free;
          end;
        end
        else
          raise Exception.Create('EquilibrateTraverse Could Not Be Created');

        LHierarchyTree := THierarchyTree.Create;
        if (LHierarchyTree <> nil) then
        begin
          try
            LStepLength := Succ(LList.Count div 2);
            while (LStepLength > 0) do
            begin
              for LIndex := 1 to (LList.Count div LStepLength) do
              begin
                LItem := TTreeItem(LList.Items[Pred(LStepLength * LIndex)]);
                if (LItem <> nil) then
                begin
                  if (LHierarchyTree.SearchItem(LItem.PrimaryKey) = nil) then
                  begin
                    if not(LHierarchyTree.Insert(LItem)) then
                      raise Exception.Create('Tree Item Could Not Be Equilibrated');
                  end;
                end;
              end;

              LStepLength := (LStepLength div 2);
            end;

            FRoot := LHierarchyTree.Root;
          finally
            LHierarchyTree.Clear; // important!
            LHIerarchyTree.Free;
          end;
        end
        else
          raise Exception.Create('Hierarchy Tree Could Not Be Created');
      finally
        LList.Clear;
        LList.Free;
      end;
    end
    else
      raise Exception.Create('List Could Not Be Created');
  end;
end;

procedure THierarchyTree.Inorder(const ATraverse: TTraverseObject);
begin
  if (FTraverseStyle = tsIterative) then
    InorderIterative(ATraverse)
  else
    InorderRecursive(ATraverse);
end;

procedure THierarchyTree.InorderIterative(const ATraverse: TTraverseObject);
var
  LAbort : Boolean;
  LItem  : TTreeItem;
  LList  : TList;
begin
  if (ATraverse <> nil) then
  begin
    LList := TList.Create;
    if (LList <> nil) then
    begin
      try
        LAbort := false;
        LItem  := FRoot;
        repeat
          while (LItem <> nil) do
          begin
            LList.Add(LItem);
            LItem := LItem.Left;
          end;

          if (LList.Count > 0) then
          begin
            LItem := LList.Items[Pred(LList.Count)];
            LList.Delete(Pred(LList.Count));
            if (LItem <> nil) then
            begin
              ATraverse.OnTraverse(LItem, LAbort);
              if LAbort then
                Break;

              LItem := LItem.Right;
            end;
          end;
        until ((LList.Count <= 0) and (LItem = nil));
      finally
        LList.Free;
      end;
    end
    else
      raise Exception.Create('List Could Not Be Created');
  end;
end;

procedure THierarchyTree.InorderRecursive(const ATraverse : TTraverseObject);
  function DoInorder(const AItem : TTreeItem; const ATraverse : TTraverseObject) : Boolean;
  begin
    Result := false;

    if (AItem <> nil) then
    begin
      Result := DoInorder(AItem.Left, ATraverse);
      if not(Result) then
      begin
        ATraverse.OnTraverse(AItem, Result);
        if not(Result) then
          Result := DoInorder(AItem.Right, ATraverse);
      end;
    end;
  end;
begin
  if (ATraverse <> nil) then
    DoInorder(FRoot, ATraverse);
end;

function THierarchyTree.InsertItem(const APrimaryKey : LongWord; const AFileID : LongWord; const APositionID : LongWord) : TTreeItem;
begin
  Result := TTreeItem.Create(APrimaryKey, AFileID, APositionID, FTraverseStyle);
  if (Result <> nil) then
  begin
    if not(Insert(Result)) then
    begin
      Result.Free;
      Result := nil;
    end;
  end
  else
    raise Exception.Create('Tree Item Could Not Be Created');
end;

function THierarchyTree.Insert(const ATreeItem: TTreeItem): Boolean;
var
  LCurrent : TTreeItem;
begin
  Result := false;

  if (ATreeItem <> nil) then
  begin
    ATreeItem.Left  := nil;
    ATreeItem.Right := nil;

    Result := (FRoot = nil);
    if not(Result) then
    begin
      LCurrent := FRoot;
      while not(Result) do
      begin
        if (ATreeItem.PrimaryKey < LCurrent.PrimaryKey) then
        begin
          Result := (LCurrent.Left = nil);
          if Result then
            LCurrent.Left := ATreeItem
          else
            LCurrent := LCurrent.Left;
        end
        else
        begin
          if (ATreeItem.PrimaryKey > LCurrent.PrimaryKey) then
          begin
            Result := (LCurrent.Right = nil);
            if Result then
              LCurrent.Right := ATreeItem
            else
              LCurrent := LCurrent.Right;
          end
          else
            raise Exception.Create('Primary Key Already Exists');
        end;
      end;
    end
    else
      FRoot := ATreeItem;
  end;
end;

function THierarchyTree.LoadFromFile(const AFileName: String; const ALoadLowerHierarchies: Boolean): LongWord;
var
  LCount      : LongWord;
  LFile       : TFileStream;
  LFileID     : LongWord;
  LFullRecord : Boolean;
  LItem       : TTreeItem;
  LPositionID : LongWord;
  LPrimaryKey : LongWord;
  LTag        : String;
begin
  ClearList;

  LCount := 0;
  if FileExists(AFileName) then
  begin
    LFile := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      if (LFile <> nil) then
      begin
        LFile.Position := 0;

        SetLength(LTag, Length(CDataBaseTreeTag));
        LFile.Read(LTag[1], Length(LTag));
        if (LTag = CDataBaseTreeTag) then
        begin
          LFullRecord := true;
          while ((LFile.Position < LFile.Size) and LFullRecord) do
          begin
            LFullRecord := false;

            if ((LFile.Position + SizeOf(LPrimaryKey)) < LFile.Size) then
            begin
              LFile.Read(LPrimaryKey, SizeOf(LPrimaryKey));
              if ((LFile.Position + SizeOf(LFileID)) < LFile.Size) then
              begin
                LFile.Read(LFileID, SizeOf(LFileID));
                if ((LFile.Position + SizeOf(LPositionID)) <= LFile.Size) then
                begin
                  LFile.Read(LPositionID, SizeOf(LPositionID));

                  LItem := InsertItem(LPrimaryKey, LFileID, LPositionID);
                  if (ALoadLowerHierarchies and FileExists(ChangeFileExt(AFileName, '') + '.' + IntToStr(LCount) + '.' + CDataBaseTreeTag)) then
                    LItem.Middle.LoadFromFile(ChangeFileExt(AFileName, '') + '.' + IntToStr(LCount) + '.' + CDataBaseTreeTag, ALoadLowerHierarchies);
                  Inc(LCount);

                  LFullRecord := true;
                end;
              end;
            end;
          end;

          if not(LFullRecord) then
            raise Exception.Create('Corrupted Tree');
        end
        else
          raise Exception.Create('File Tag does not match');
      end
      else
        raise Exception.Create('Tree File Could Not Be Opened');
    finally
      LFile.Free;
    end;
  end
  else
    raise Exception.Create('Tree File Does Not Exist');

  Result := LCount;
end;

procedure THierarchyTree.Postorder(const ATraverse: TTraverseObject);
begin
  if (FTraverseStyle = tsIterative) then
    PostorderIterative(ATraverse)
  else
    PostorderRecursive(ATraverse);
end;

procedure THierarchyTree.PostorderIterative(const ATraverse: TTraverseObject);
var
  LAbort : Boolean;
  LItem  : TTreeItem;
  LListA : TList;
  LListB : TList;
begin
  if (ATraverse <> nil) then
  begin
    LListA := TList.Create;
    if (LListA <> nil) then
    begin
      try
        LListB := TList.Create;
        if (LListB <> nil) then
        begin
          try
            LAbort := false;
            LItem  := FRoot;
            repeat
              while (LItem <> nil) do
              begin
                LListA.Add(LItem);
                LItem := LItem.Left;
              end;

              if (LListA.Count > 0) then
              begin
                LItem := LListA.Items[Pred(LListA.Count)];
                if (LItem <> nil) then
                begin
                  if (((LItem.Left = nil) or (LListB.IndexOf(LItem.Left) >= 0)) and
                      ((LItem.Right = nil) or (LListB.IndexOf(LItem.Right) >= 0))) then
                  begin
                    ATraverse.OnTraverse(LItem, LAbort);
                    if LAbort then
                      Break;

                    LListA.Delete(Pred(LListA.Count));
                    LListB.Add(LItem);
                    LItem := nil;
                  end;
                end;

                if (LItem <> nil) then
                begin
                  LItem := LItem.Right;
                  if ((LItem <> nil) and (LListB.IndexOf(LItem) >= 0)) then
                    LItem := nil;
                end;
              end;
            until ((LListA.Count <= 0) and (LItem = nil));
          finally
            LListB.Free;
          end;
        end
        else
          raise Exception.Create('List Could Not Be Created');
      finally
        LListA.Free;
      end;
    end
    else
      raise Exception.Create('List Could Not Be Created');
  end;
end;

procedure THierarchyTree.PostorderRecursive(const ATraverse: TTraverseObject);
  function DoPostorder(const AItem : TTreeItem; const ATraverse : TTraverseObject) : Boolean;
  begin
    Result := false;

    if (AItem <> nil) then
    begin
      Result := DoPostorder(AItem.Left, ATraverse);
      if not(Result) then
      begin
        Result := DoPostorder(AItem.Right, ATraverse);
        if not(Result) then
          ATraverse.OnTraverse(AItem, Result);
      end;
    end;
  end;
begin
  if (ATraverse <> nil) then
    DoPostorder(FRoot, ATraverse);
end;

procedure THierarchyTree.Preorder(const ATraverse: TTraverseObject);
begin
  if (FTraverseStyle = tsIterative) then
    PreorderIterative(ATraverse)
  else
    PreorderRecursive(ATraverse);
end;

procedure THierarchyTree.PreorderIterative(const ATraverse: TTraverseObject);
var
  LAbort : Boolean;
  LItem  : TTreeItem;
  LList  : TList;
begin
  if (ATraverse <> nil) then
  begin
    LList := TList.Create;
    if (LList <> nil) then
    begin
      try
        LAbort := false;
        LItem  := FRoot;
        repeat
          while (LItem <> nil) do
          begin
            ATraverse.OnTraverse(LItem, LAbort);
            if LAbort then
              Break;

            LList.Add(LItem);
            LItem := LItem.Left;
          end;
          if LAbort then
            Break;

          if (LList.Count > 0) then
          begin
            LItem := LList.Items[Pred(LList.Count)];
            LList.Delete(Pred(LList.Count));
            if (LItem <> nil) then
              LItem := LItem.Right;
          end;
        until ((LList.Count <= 0) and (LItem = nil));
      finally
        LList.Free;
      end;
    end
    else
      raise Exception.Create('List Could Not Be Created');
  end;
end;

procedure THierarchyTree.PreorderRecursive(const ATraverse: TTraverseObject);
  function DoPreorder(const AItem : TTreeItem; const ATraverse : TTraverseObject) : Boolean;
  begin
    Result := false;

    if (AItem <> nil) then
    begin
      ATraverse.OnTraverse(AItem, Result);
      if not(Result) then
      begin
        Result := DoPreorder(AItem.Left, ATraverse);
        if not(Result) then
          Result := DoPreorder(AItem.Right, ATraverse);
      end;
    end;
  end;
begin
  if (ATraverse <> nil) then
    DoPreorder(FRoot, ATraverse);
end;

function THierarchyTree.Remove(const APrimaryKey: LongWord): TTreeItem;
var
  LParent    : TTreeItem;
  LSuccessor : TTreeItem;
begin
  Result := SearchItem(APrimaryKey);
  if (Result <> nil) then
  begin
    if (Result.Right <> nil) then
    begin
      LSuccessor := Result.Right;
      while (LSuccessor.Left <> nil) do
        LSuccessor := LSuccessor.Left;
    end
    else
      LSuccessor := Result.Left;

    if (LSuccessor = nil) then
    begin
      LParent := SearchParent(APrimaryKey);
      if (LParent <> nil) then
      begin
        if (LParent.Left = Result) then
          LParent.Left := nil
        else
          LParent.Right := nil;
      end
      else
      begin
        if (Result = FRoot) then
          FRoot := nil;
      end;
    end
    else
    begin
      if (LSuccessor <> Result.Left) then
      begin
        LParent := SearchParent(LSuccessor.PrimaryKey);
        if (LParent <> nil) then
        begin
          if (LParent <> Result) then
          begin
            LParent.Left := LSuccessor.Right;

            LSuccessor.Right := Result.Right;
          end;

          LSuccessor.Left := Result.Left;
        end;
      end;

      LParent := SearchParent(APrimaryKey);
      if (LParent <> nil) then
      begin
        if (Result = LParent.Left) then
          LParent.Left := LSuccessor
        else
          LParent.Right := LSuccessor;
      end
      else
        FRoot := LSuccessor;
    end;

    Result.Left  := nil;
    Result.Right := nil;
  end
  else
    raise Exception.Create('Tree Item Does Not Exist');
end;

procedure THierarchyTree.RemoveItem(const APrimaryKey: LongWord);
var
  LItem : TTreeItem;
begin
  LItem := Remove(APrimaryKey);
  if (LItem <> nil) then
    LItem.Free;
end;

procedure THierarchyTree.SaveToFile(const AFileName: String; const ASaveLowerHierarchies: Boolean);
var
  LSaveTraverse : TSaveTraverse;
begin
  if (FRoot <> nil) then
  begin
    LSaveTraverse := TSaveTraverse.Create(ASaveLowerHierarchies);
    if (LSaveTraverse <> nil) then
    begin
      try
        LSaveTraverse.Initialize(AFileName);
        try
          Preorder(LSaveTraverse);
        finally
          LSaveTraverse.Finalize;
        end;
      finally
        LSaveTraverse.Free;
      end;
    end
    else
      raise Exception.Create('SaveTraverse Could Not Be Created');
  end;
end;

function THierarchyTree.SearchItem(const APrimaryKey: LongWord): TTreeItem;
var
  LDone : Boolean;
  LItem : TTreeItem;
begin
  Result := nil;

  LItem := FRoot;
  LDone := (LItem = nil);
  while not(LDone) do
  begin
    LDone := (APrimaryKey = LItem.PrimaryKey);
    if LDone then
      Result := LItem
    else
    begin
      if (APrimaryKey < LItem.PrimaryKey) then
      begin
        LDone := (LItem.Left = nil);
        if not(LDone) then
          LItem := LItem.Left;
      end
      else
      begin
        LDone := (LItem.Right = nil);
        if not(LDone) then
          LItem := LItem.Right;
      end;
    end;
  end;
end;

function THierarchyTree.SearchParent(const APrimaryKey: LongWord): TTreeItem;
var
  LDone   : Boolean;
  LItem   : TTreeItem;
  LParent : TTreeItem;
begin
  Result := nil;

  LItem   := FRoot;
  LDone   := (LItem = nil);
  LParent := nil;
  while not(LDone) do
  begin
    LDone := (APrimaryKey = LItem.PrimaryKey);
    if LDone then
      Result := LParent
    else
    begin
      if (APrimaryKey < LItem.PrimaryKey) then
      begin
        LDone := (LItem.Left = nil);
        if not(LDone) then
        begin
          LParent := LItem;
          LItem   := LItem.Left;
        end;
      end
      else
      begin
        LDone := (LItem.Right = nil);
        if not(LDone) then
        begin
          LParent := LItem;
          LItem   := LItem.Right;
        end;
      end;
    end;
  end;
end;

{ TTraverseObject }

procedure TTraverseObject.OnTraverse(const ATreeItem : TTreeItem; var AAbort : Boolean);
begin
// virtual dummy
end;

{ TSaveTraverse }

constructor TSaveTraverse.Create(const ASaveLower: Boolean);
begin
  inherited Create;

  FSaveLower := ASaveLower;
end;

destructor TSaveTraverse.Destroy;
begin
  Finalize;

  inherited Destroy;
end;

procedure TSaveTraverse.Finalize;
begin
  if (FFileStream <> nil) then
  begin
    FFileStream.Free;
    FFileStream := nil;
  end;
  FFileName := '';
end;

procedure TSaveTraverse.Initialize(const AFileName : String);
begin
  if (FFileStream = nil) then
  begin
    FCount    := 0;
    FFileName := AFileName;

    if FileExists(FFileName) then
      DeleteFile(FFileName);

    FFileStream := TFileStream.Create(FFileName, fmCreate or fmShareDenyWrite);
    if (FFileStream <> nil) then
      FFileStream.Write(CDataBaseTreeTag[1], Length(CDataBaseTreeTag))
    else
      raise Exception.Create('Tree File Could Not Be Created');
  end
  else
    raise Exception.Create('Tree File Already Opened');
end;

// should be optimized by first saving the Middle-Elements and writing them  to
// a file when the current tree is done - otherwise a stack overflow is easier
// to be caused
procedure TSaveTraverse.OnTraverse(const ATreeItem : TTreeItem; var AAbort : Boolean);
begin
  inherited;

  if (FFileStream <> nil) then
  begin
    FFileStream.Write(ATreeItem.PrimaryKey, SizeOf(ATreeItem.PrimaryKey));
    FFileStream.Write(ATreeItem.FileID,     SizeOf(ATreeItem.FileID)); //!! No FileID
    FFileStream.Write(ATreeItem.PositionID, SizeOf(ATreeItem.PositionID));

    if (FSaveLower and (ATreeItem.Middle <> nil)) then
      ATreeItem.Middle.SaveToFile(ChangeFileExt(FFileName, '') + '.' + IntToStr(FCount) + '.' + CDataBaseTreeTag, FSaveLower);

    Inc(FCount);
  end;
end;

{ TDeleteTraverse }

// should be optimized by first saving the Middle-Elements and clearing them when
// the current tree is done - otherwise a stack overflow is easier to be caused
procedure TDeleteTraverse.OnTraverse(const ATreeItem: TTreeItem; var AAbort: Boolean);
begin
  inherited;

  ATreeItem.Free;
end;

{ TEquilibrateTraverse }

constructor TEquilibrateTraverse.Create(const AEquilibrateLower: Boolean);
begin
  inherited Create;

  FEquilibrateLower := AEquilibrateLower;
end;

procedure TEquilibrateTraverse.Initialize(const AList : TTreeItemList);
begin
  FList := AList;
end;

procedure TEquilibrateTraverse.OnTraverse(const ATreeItem: TTreeItem; var AAbort: Boolean);
begin
  inherited;

  if (FList <> nil) then
  begin
    if FEquilibrateLower then
      ATreeItem.Middle.Equilibrate(FEquilibrateLower);

    FList.Add(ATreeItem);
  end;
end;

{ TTreeItemList }

destructor TTreeItemList.Destroy;
begin
  Clear;

  inherited Destroy;
end;

end.
