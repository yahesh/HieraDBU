unit DBLangU;

// Please, don't delete this comment. \\
(*
  Copyright Owner: Yahe
  Copyright Year : 2007-2018

  Unit   : HieraDBU (platform independant)
  Version: 0.1a2

  Contact E-Mail: hello@yahe.sh
*)
// Please, don't delete this comment. \\

(*
  Description:

  This unit contains the language parser that is used
  by THierarchicalDataBase.Execute().
*)

(*
  Change Log:

  [Version 0.1a1] (17.09.2007: initial release)
  - initial release

  [Version 0.1a2] (19.09.2007: major bugfix)
  - IN statement is recognized now
*)

interface

uses
  SysUtils,
  DBStrucU,
  DBActU;

type
  TLanguageParser = class;

  TActionTypeEnum = (ateUnknown, ateCreate, ateOpen, ateClose, ateSave, ateOptimize, ateGet, ateSet, ateInsert, ateRemove, ateReference);
  TCharSet        = set of Char;

  TLanguageParser = class(TObject)
  private
  protected
    function ParseWord(const ACommand : String; const ACharSet : TCharSet; const AIgnoreSet : TCharSet; var AReturn : String) : String;

    function ParseAssignment(const ACommand : String; var AReturn : String) : TAssignmentItem;
    function ParseAssignments(const ACommand : String; var AReturn : String) : TAssignmentItemList;

    function ParseDefinitionItem(const ACommand : String; var AReturn : String) : TStructureItemList;
    function ParseDefinitionList(const ACommand : String; var AReturn : String) : THierarchyList;
    function ParseAS(const AName : String; const ACommand : String; var AReturn : String) : TStructureItemList;
    function ParseDefinition(const ACommand : String; var AReturn : String) : TStructureItem;
    function ParseDefinitions(const AName : String; const ACommand : String; var AReturn : String) : TStructureItemList;

    function ParseANDEquations(const ACommand : String; var AReturn : String) : TEquationItemList;
    function ParseOREquations(const ACommand : String; var AReturn : String) : TEquationList;
    function ParseEquation(const ACommand : String; var AReturn : String) : TEquationItem;
  public
    function ParseASSIGN(const ACommand : String; var AReturn : String) : TAssignmentItemList;
    function ParseIN(const ACommand : String; var AReturn : String) : TEquationList;
    function ParseWHERE(const ACommand : String; var AReturn : String) : TEquationList;
    function ParseWITH(const ACommand : String; var AReturn : String) : THierarchyList;

    function ParseAllSign(const ACommand : String; var AReturn : String) : Boolean;
    function ParseAction(const ACommand : String; var AReturn : String) : TActionTypeEnum;
    function ParseName(const ACommand : String; var AReturn : String) : String;
  published
  end;

implementation

{ TLanguageParser }

function TLanguageParser.ParseAction(const ACommand : String; var AReturn : String) : TActionTypeEnum;
const
  CActions : array [1..10] of String = ('CREATE', 'OPEN', 'CLOSE', 'SAVE', 'OPTIMIZE', 'GET', 'SET', 'INSERT', 'REMOVE', 'REFERENCE');

  CCharSet   = ['A', 'C', 'E'..'G', 'I', 'L'..'P', 'R'..'T', 'V', 'Z'];
  CIgnoreSet = [' '];
var
  LIndex : LongInt;
  LTemp  : String;
begin
  Result := ateUnknown;

  LTemp := AnsiUpperCase(ParseWord(ACommand, CCharSet, CIgnoreSet, AReturn));
  for LIndex := Low(CActions) to High(CActions) do
  begin
    if (LTemp = CActions[LIndex]) then
    begin
      Result := TActionTypeEnum(LIndex);

      Break;
    end;
  end;
end;

function TLanguageParser.ParseAllSign(const ACommand: String; var AReturn: String): Boolean;
const
  CCharSet = ['*'];
  CIgnore  = [' '];
var
  LAllCount : LongInt;
  LChar     : Char;
  LDone     : Boolean;
  LIndex    : LongInt;
begin
//  Result := false;
  AReturn := Trim(ACommand);

  LAllCount := 0;
  LDone     := false;
  for LIndex := 1 to Length(AReturn) do
  begin
    Inc(LAllCount);

    LChar := UpCase(AReturn[LIndex]);
    LDone := (LChar in CCharSet);
    if not(LDone) then
    begin
      if not(LChar in CIgnore) then
      begin
        Dec(LAllCount);
        Break;
      end;
    end
    else
      Break;
  end;

  Result := LDone;
  if Result then
    Delete(AReturn, 1, LAllCount);
end;

function TLanguageParser.ParseANDEquations(const ACommand : String; var AReturn : String) : TEquationItemList;
const
  CBegin     = ['('];
  CDivider   = ['&'];
  CEscape    = ['/'];
  CIgnore    = [' '];
  CSeperator = [')'];
  CText      = ['"'];
var
  LAllCount   : LongInt;
  LChar       : Char;
  LCount      : LongInt;
  LEscapeNext : Boolean;
  LHasStarted : Boolean;
  LIndex      : LongInt;
  LInText     : Boolean;
  LItem       : TEquationItem;
  LTemp       : String;
begin
  Result := nil;
  AReturn := Trim(ACommand);

  LAllCount   := 0;
  LCount      := 0;
  LEscapeNext := false;
  LHasStarted := false;
  LInText     := false;
  SetLength(LTemp, Length(AReturn));
  for LIndex := 1 to Length(AReturn) do
  begin
    Inc(LAllCount);

    if LHasStarted then
    begin
      LChar := UpCase(AReturn[LIndex]);
      if (((LChar in CSeperator) or (LChar in CDivider)) and not(LInText)) then
      begin
        SetLength(LTemp, LCount);
        LCount := 0;

        if (Length(Trim(LTemp)) > 0) then
        begin
          LItem := ParseEquation(LTemp, LTemp);
          if (LItem <> nil) then
          begin
            if (Result = nil) then
              Result := TEquationItemList.Create;

            Result.Add(LItem);
          end;
        end;

        SetLength(LTemp, Length(AReturn) - LAllCount);

        if (LChar in CSeperator) then
          Break;
      end
      else
      begin
        if LInText then
          LChar := AReturn[LIndex];

        Inc(LCount);
        LTemp[LCount] := LChar;

        if LInText then
        begin
          LInText := (not(LChar in CText) or LEscapeNext);
          if LEscapeNext then
            LEscapeNext := false
          else
            LEscapeNext := (LChar in CEscape);
        end
        else
          LInText := (LChar in CText);
      end;
    end
    else
    begin
      LChar := UpCase(AReturn[LIndex]);
      LHasStarted := (LChar in CBegin);
      if not(LHasStarted) then
      begin
        if not(LChar in CIgnore) then
          Break;
      end;
    end;
  end;
  SetLength(LTemp, LCount);
  Delete(AReturn, 1, LAllCount);

  if (Length(LTemp) > 0) then
    raise Exception.Create('ANDEquation Not Compliant To Syntax');
end;

function TLanguageParser.ParseAS(const AName : String; const ACommand: String; var AReturn: String): TStructureItemList;
const
  CWord = 'AS';

  CCharSet   = ['A', 'S'];
  CIgnoreSet = [' '];
var
  LTemp : String;
begin
  Result := nil;

  LTemp := ParseWord(ACommand, CCharSet, CIgnoreSet, AReturn);
  if (AnsiUpperCase(LTemp) = CWord) then
    Result := ParseDefinitions(AName, AReturn, AReturn);
end;

function TLanguageParser.ParseASSIGN(const ACommand: String; var AReturn: String): TAssignmentItemList;
const
  CWord = 'ASSIGN';

  CCharSet   = ['A', 'G', 'I', 'N', 'S'];
  CIgnoreSet = [' '];
var
  LTemp : String;
begin
  Result := nil;

  LTemp := ParseWord(ACommand, CCharSet, CIgnoreSet, AReturn);
  if (AnsiUpperCase(LTemp) = CWord) then
    Result := ParseAssignments(AReturn, AReturn);
end;

function TLanguageParser.ParseAssignment(const ACommand: String; var AReturn: String): TAssignmentItem;
type
  TProgressEnum = (peIdentifier, peAssignment, peValue, peIsCorrect);
const
  CCharSet    = ['A'..'Z', '0'..'9'];
  CAssignment = [':'];
  CEscape     = ['/'];
  CNumberSet  = ['0'..'9'];
  CComma      = [',', '.'];
  CIgnore     = [' '];
  CSeperator  = [';', ']'];
  CText       = ['"'];
var
  LAllCount   : LongInt;
  LChar       : Char;
  LCount      : LongInt;
  LDone       : Boolean;
  LEscapeNext : Boolean;
  LIdentifier : String;
  LIndex      : LongInt;
  LIsText     : Boolean;
  LHasPoint   : Boolean;
  LHasStarted : Boolean;
  LProgress   : TProgressEnum;
  LTemp       : String;
  LValue      : String;
begin
//  Result := nil;
  AReturn := Trim(ACommand);

  LIdentifier := '';
  LIsText     := false;
  LValue      := '';

  LAllCount   := 0;
  LCount      := 0;
  LDone       := false;
  LEscapeNext := false;
  LHasPoint   := false;
  LHasStarted := false;
  LProgress   := peIdentifier;
  SetLength(LTemp, Length(AReturn));
  for LIndex := 1 to Length(AReturn) do
  begin
    Inc(LAllCount);

    case LProgress of
      peIdentifier :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if LHasStarted then
        begin
          if (LChar in CCharSet) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;
          end
          else
          begin
            SetLength(LTemp, LCount);
            LCount      := 0;
            LIdentifier := LTemp;
            SetLength(LTemp, Length(AReturn) - LAllCount);

            LHasStarted := false;

            if (LChar in CAssignment) then
              LProgress := peValue
            else
            begin
              if (LChar in CIgnore) then
                LProgress := peAssignment
              else
                Break;
            end;
          end;
        end
        else
        begin
          if (LChar in CCharSet) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;

            LHasStarted := true;
          end
          else
          begin
            if not(LChar in CIgnore) then
              Break;
          end;
        end;
      end;

      peAssignment :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if (LChar in CAssignment) then
        begin
          LHasStarted := false;
          LProgress   := peValue;
        end
        else
        begin
          if not(LChar in CIgnore) then
            Break;
        end;
      end;

      peValue :
      begin
        if LHasStarted then
        begin
          if LIsText then
          begin
            LChar := AReturn[LIndex];
            if ((not(LChar in CText) and not(LChar in CEscape)) or LEscapeNext) then
            begin
              Inc(LCount);
              LTemp[LCount] := LChar;

              LEscapeNext := false;
            end
            else
            begin
              LEscapeNext := (LChar in CEscape);
              if not(LEscapeNext) then
              begin
                SetLength(LTemp, LCount);
                LCount := 0;
                LValue := LTemp;
                SetLength(LTemp, Length(AReturn) - LAllCount);

                LHasStarted := false;
                LProgress   := peIsCorrect;

                LDone := true;
              end;
            end;
          end
          else
          begin
            LChar := UpCase(AReturn[LIndex]);
            if ((LChar in CNumberSet) or (LChar in CComma)) then
            begin
              if not((LChar in CComma) and LHasPoint) then
              begin
                Inc(LCount);
                LTemp[LCount] := LChar;

                if not(LHasPoint) then
                  LHasPoint := (LChar in CComma);
              end
              else
                Break;
            end
            else
            begin
              if (LChar in CIgnore) then
              begin
                SetLength(LTemp, LCount);
                LCount := 0;
                LValue := LTemp;
                SetLength(LTemp, Length(AReturn) - LAllCount);

                LHasStarted := false;
                LProgress   := peIsCorrect;

                LDone := true;
              end
              else
              begin
                if (LChar in CSeperator) then
                begin
                  SetLength(LTemp, LCount);
                  LValue := LTemp;
                  SetLength(LTemp, Length(AReturn) - LAllCount);
                  LCount := 0;

                  LDone := true;
                  Break;
                end
                else
                  Break;
              end;
            end;
          end;
        end
        else
        begin
          LChar := UpCase(AReturn[LIndex]);
          if ((LChar in CNumberSet) or (LChar in CComma)) then
          begin
            LIsText := false;

            Inc(LCount);
            LTemp[LCount] := LChar;

            LHasPoint   := (LChar in CComma);
            LHasStarted := true;
          end
          else
          begin
            if (LChar in CText) then
            begin
              LIsText := true;

              LHasStarted := true;
            end
            else
            begin
              if not(LChar in CIgnore) then
                Break;
            end;
          end;
        end;
      end;

      peIsCorrect :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if (LChar in CSeperator) then
          Break
        else
        begin
          if not(LChar in CIgnore) then
          begin
            LDone := false;
            Break;
          end;
        end;
      end;
    end;
  end;
  SetLength(LTemp, LCount);
  Delete(AReturn, 1, LAllCount);

  if (Length(LTemp) > 0) then
  begin
    LDone := ((LProgress = peValue) and not(LIsText));
    if LDone then
      LValue := LTemp;
  end;

  if LDone then
  begin
    Result := TAssignmentItem.Create;
    try
      Result.IdentifierName := LIdentifier;

      if LIsText then
        Result.ValueType := vtText
      else
        Result.ValueType := vtNumber;

      Result.Value := LValue;

    except
      Result.Free;
      Result := nil;
    end;
  end
  else
    raise Exception.Create('Assignment Not Compliant To Syntax');
end;

function TLanguageParser.ParseAssignments(const ACommand : String; var AReturn : String) : TAssignmentItemList;
const
  CBegin     = ['['];
  CDivider   = [';'];
  CEscape    = ['/'];
  CIgnore    = [' '];
  CSeperator = [']'];
  CText      = ['"'];
var
  LAllCount   : LongInt;
  LChar       : Char;
  LCount      : LongInt;
  LEscapeNext : Boolean;
  LHasStarted : Boolean;
  LIndex      : LongInt;
  LInText     : Boolean;
  LItem       : TAssignmentItem;
  LTemp       : String;
begin
  Result := nil;
  AReturn := Trim(ACommand);

  LAllCount   := 0;
  LCount      := 0;
  LEscapeNext := false;
  LHasStarted := false;
  LInText     := false;
  SetLength(LTemp, Length(AReturn));
  for LIndex := 1 to Length(AReturn) do
  begin
    Inc(LAllCount);

    if LHasStarted then
    begin
      LChar := AReturn[LIndex];
      if (((LChar in CSeperator) or (LChar in CDivider)) and not(LInText)) then
      begin
        SetLength(LTemp, LCount);
        LCount := 0;

        if (Length(Trim(LTemp)) > 0) then
        begin
          LItem := ParseAssignment(LTemp, LTemp);
          if (LItem <> nil) then
          begin
            if (Result = nil) then
              Result := TAssignmentItemList.Create;

            Result.Add(LItem);
          end;
        end;

        SetLength(LTemp, Length(AReturn) - LAllCount);

        if (LChar in CSeperator) then
          Break;
      end
      else
      begin
        if not(LInText) then
          LChar := UpCase(LChar);

        Inc(LCount);
        LTemp[LCount] := LChar;

        if LInText then
        begin
          LInText := (not(LChar in CText) or LEscapeNext);
          if LEscapeNext then
            LEscapeNext := false
          else
            LEscapeNext := (LChar in CEscape);
        end
        else
          LInText := (LChar in CText);
      end;
    end
    else
    begin
      LChar := UpCase(AReturn[LIndex]);
      LHasStarted := (LChar in CBegin);
      if not(LHasStarted) then
      begin
        if not(LChar in CIgnore) then
          Break;
      end;
    end;
  end;
  SetLength(LTemp, LCount);
  Delete(AReturn, 1, LAllCount);

  if (Length(LTemp) > 0) then
    raise Exception.Create('Assignments Not Compliant To Syntax');
end;

function TLanguageParser.ParseDefinition(const ACommand: String; var AReturn: String): TStructureItem;
type
  TProgressEnum = (pePrimary, peIdentifier, peDefine, peType, peOpenBracket, peSize, peCloseBracket, peIsCorrect);
const
  CTypes : array [0..5] of String = ('RAW', 'INTSIGNED', 'INTUNSIGNED', 'BYTE', 'FLOAT', 'STRING');

  CCharacterSet = ['A'..'Z'];
  CCharSet      = ['A'..'Z', '0'..'9'];
  CCloseBracket = [')'];
  CDefine       = [':'];
  CNumberSet    = ['0'..'9'];
  CIgnore       = [' '];
  COpenBracket  = ['('];
  CPrimary      = ['$'];
  CSeperator    = [';', '}'];
var
  LAllCount   : LongInt;
  LChar       : Char;
  LCount      : LongInt;
  LDone       : Boolean;
  LIdentifier : String;
  LIndex      : LongInt;
  LHasStarted : Boolean;
  LPrimary    : Boolean;
  LProgress   : TProgressEnum;
  LSize       : String;
  LTemp       : String;
  LType       : String;
begin
//  Result := nil;
  AReturn := Trim(ACommand);

  LIdentifier := '';
  LPrimary    := false;
  LSize       := '';
  LType       := '';

  LAllCount   := 0;
  LCount      := 0;
  LDone       := false;
  LHasStarted := false;
  LProgress   := pePrimary;
  SetLength(LTemp, Length(AReturn));
  for LIndex := 1 to Length(AReturn) do
  begin
    Inc(LAllCount);

    case LProgress of
      pePrimary :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if (LChar in CPrimary) then
        begin
          LPrimary := true;

          LHasStarted := false;
          LProgress   := peIdentifier;
        end
        else
        begin
          if (LChar in CCharSet) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;

            LHasStarted := true;
            LProgress   := peIdentifier;
          end
          else
          begin
            if not(LChar in CIgnore) then
              Break;
          end;
        end;
      end;

      peIdentifier :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if LHasStarted then
        begin
          if (LChar in CCharSet) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;
          end
          else
          begin
            SetLength(LTemp, LCount);
            LCount      := 0;
            LIdentifier := LTemp;
            SetLength(LTemp, Length(AReturn) - LAllCount);

            if (LChar in CDefine) then
            begin
              LHasStarted := false;
              LProgress   := peType;
            end
            else
            begin
              if (LChar in CIgnore) then
              begin
                LHasStarted := false;
                LProgress   := peDefine;
              end
              else
                Break;
            end;
          end;
        end
        else
        begin
          if (LChar in CCharSet) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;

            LHasStarted := true;
          end
          else
          begin
            if not(LChar in CIgnore) then
              Break;
          end;
        end;
      end;

      peDefine :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if (LChar in CDefine) then
        begin
          LHasStarted := false;
          LProgress   := peType;
        end
        else
        begin
          if not(LChar in CIgnore) then
            Break;
        end;
      end;

      peType :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if LHasStarted then
        begin
          if (LChar in CCharacterSet) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;
          end
          else
          begin
            SetLength(LTemp, LCount);
            LCount := 0;
            LType  := LTemp;
            SetLength(LTemp, Length(AReturn) - LAllCount);

            if (LChar in CSeperator) then
            begin
              LDone := true;
              Break;
            end
            else
            begin
              if (LChar in COpenBracket) then
              begin
                LHasStarted := false;
                LProgress   := peSize;
              end
              else
              begin
                if (LChar in CIgnore) then
                begin
                  LHasStarted := false;
                  LProgress   := peOpenBracket;
                end
                else
                  Break;
              end;
            end;
          end;
        end
        else
        begin
          if (LChar in CCharacterSet) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;

            LHasStarted := true;
          end
          else
          begin
            if not(LChar in CIgnore) then
              Break;
          end;
        end;
      end;

      peOpenBracket :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if (LChar in COpenBracket) then
        begin
          LHasStarted := false;
          LProgress   := peSize;
        end
        else
        begin
          if (LChar in CSeperator) then
          begin
            LDone := true;
            Break;
          end
          else
          begin
            if not(LChar in CIgnore) then
              Break;
          end;
        end;
      end;

      peSize :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if LHasStarted then
        begin
          if (LChar in CNumberSet) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;
          end
          else
          begin
            SetLength(LTemp, LCount);
            LCount := 0;
            LSize  := LTemp;
            SetLength(LTemp, Length(AReturn) - LAllCount);

            if (LChar in CCloseBracket) then
            begin
              LHasStarted := false;
              LProgress   := peIsCorrect;

              LDone := true;
            end
            else
            begin
              if (LChar in CIgnore) then
              begin
                LHasStarted := false;
                LProgress   := peCloseBracket;
              end
              else
                Break;
            end;
          end;
        end
        else
        begin
          if (LChar in CNumberSet) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;

            LHasStarted := true;
          end
          else
          begin
            if not(LChar in CIgnore) then
              Break;
          end;
        end;
      end;

      peCloseBracket :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if (LChar in CCloseBracket) then
        begin
          LHasStarted := false;
          LProgress   := peIsCorrect;

          LDone := true;
        end
        else
        begin
          if not(LChar in CIgnore) then
            Break;
        end;
      end;

      peIsCorrect :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if (LChar in CSeperator) then
          Break
        else
        begin
          if not(LChar in CIgnore) then
          begin
            LDone := false;
            Break;
          end;
        end;
      end;
    end;
  end;
  SetLength(LTemp, LCount);
  Delete(AReturn, 1, LAllCount);

  if (Length(LTemp) > 0) then
  begin
    LDone := (LProgress = peType);
    if LDone then
      LType := LTemp;
  end;

  if LDone then
  begin
    Result := TStructureItem.Create;
    try
      for LIndex := Low(CTypes) to High(CTypes) do
      begin
        LDone := (CTypes[LIndex] = LType);
        if LDone then
        begin
          Result.ItemType := TItemTypeEnum(LIndex);

          Break;
        end;
      end;

      if LDone then
      begin
        Result.ItemName    := LIdentifier;
        Result.ItemPrimary := LPrimary;

        if (Length(Trim(LSize)) > 0) then
          Result.ItemSize := StrToInt(LSize)
        else
          Result.ItemSize := 0;
      end;

      if not(LDone) then
      begin
        Result.Free;
        Result := nil;
      end;
    except
      Result.Free;
      Result := nil;
    end;
  end
  else
    raise Exception.Create('Definition Not Compliant To Syntax');
end;

function TLanguageParser.ParseDefinitionItem(const ACommand: String; var AReturn: String): TStructureItemList;
var
  LName : String;
begin
  Result := nil;

  LName := Trim(ParseName(ACommand, AReturn));
  if (Length(LName) > 0) then
    Result := ParseAS(LName, AReturn, AReturn);
end;

function TLanguageParser.ParseDefinitionList(const ACommand: String; var AReturn: String): THierarchyList;
const
  CDivider = [','];
var
  LAllCount : LongInt;
  LChar     : Char;
  LCount    : LongInt;
  LIndex    : LongInt;
  LItem     : TStructureItemList;
  LTemp     : String;
begin
  Result := nil;
  AReturn := Trim(ACommand);

  LAllCount   := 0;
  LCount      := 0;
  SetLength(LTemp, Length(AReturn));
  for LIndex := 1 to Length(AReturn) do
  begin
    Inc(LAllCount);

    LChar := UpCase(AReturn[LIndex]);
    if (LChar in CDivider) then
    begin
      SetLength(LTemp, LCount);
      LCount := 0;

      LItem := ParseDefinitionItem(LTemp, LTemp);
      if (LItem <> nil) then
      begin
        if (Result = nil) then
          Result := THierarchyList.Create;

        Result.Add(LItem);
      end;

      SetLength(LTemp, Length(AReturn) - LAllCount);
    end
    else
    begin
      Inc(LCount);
      LTemp[LCount] := LChar;
    end;
  end;
  SetLength(LTemp, LCount);
  Delete(AReturn, 1, LAllCount);

  if (Length(LTemp) > 0) then
  begin
    LItem := ParseDefinitionItem(LTemp, LTemp);
    if (LItem <> nil) then
    begin
      if (Result = nil) then
        Result := THierarchyList.Create;

      Result.Add(LItem);
    end;
  end;
end;

function TLanguageParser.ParseDefinitions(const AName : String; const ACommand: String; var AReturn: String): TStructureItemList;
const
  CBegin     = ['{'];
  CDivider   = [';'];
  CIgnore    = [' '];
  CSeperator = ['}'];
var
  LAllCount   : LongInt;
  LChar       : Char;
  LCount      : LongInt;
  LHasStarted : Boolean;
  LIndex      : LongInt;
  LItem       : TStructureItem;
  LTemp       : String;
begin
  Result := nil;
  AReturn := Trim(ACommand);

  LAllCount   := 0;
  LCount      := 0;
  LHasStarted := false;
  SetLength(LTemp, Length(AReturn));
  for LIndex := 1 to Length(AReturn) do
  begin
    Inc(LAllCount);

    LChar := UpCase(AReturn[LIndex]);
    if LHasStarted then
    begin
      if ((LChar in CSeperator) or (LChar in CDivider)) then
      begin
        SetLength(LTemp, LCount);
        LCount := 0;

        if (Length(Trim(LTemp)) > 0) then
        begin
          LItem := ParseDefinition(LTemp, LTemp);
          if (LItem <> nil) then
          begin
            if (Result = nil) then
              Result := TStructureItemList.Create(aName);

            Result.Add(LItem);
          end;
        end;

        SetLength(LTemp, Length(AReturn) - LAllCount);

        if (LChar in CSeperator) then
          Break;
      end
      else
      begin
        Inc(LCount);
        LTemp[LCount] := LChar;
      end;
    end
    else
    begin
      LHasStarted := (LChar in CBegin);
      if not(LHasStarted) then
      begin
        if not(LChar in CIgnore) then
          Break;
      end;
    end;
  end;
  SetLength(LTemp, LCount);
  Delete(AReturn, 1, LAllCount);

  if (Length(LTemp) > 0) then
    raise Exception.Create('Definitions Not Compliant To Syntax');
end;

function TLanguageParser.ParseEquation(const ACommand : String; var AReturn : String): TEquationItem;
type
  TProgressEnum = (peNot, peIdentifier, peCheckCase, peEquation, peValue, peIsCorrect);
const
  CEquations : array [0..5] of String = ('=', '~', '>', '>=', '<', '<=');

  CPointChar = '.';

  CCharSet       = ['A'..'Z', '0'..'9'];
  CEquationBegin = ['=', '~', '>', '<'];
  CEquationEnd   = ['='];
  CEscape        = ['/'];
  CNumberSet     = ['0'..'9'];
  CCheckCase     = ['#'];
  CComma         = [',', '.'];
  CIgnore        = [' '];
  CNegate        = ['!'];
  CPoint         = ['.'];
  CSeperator     = ['&', ')'];
  CText          = ['"'];
var
  LAllCount   : LongInt;
  LChar       : Char;
  LCheckCase  : Boolean;
  LCount      : LongInt;
  LDone       : Boolean;
  LEquation   : String;
  LEscapeNext : Boolean;
  LIdentifier : String;
  LIndex      : LongInt;
  LIsText     : Boolean;
  LHasPoint   : Boolean;
  LHasStarted : Boolean;
  LNegate     : Boolean;
  LProgress   : TProgressEnum;
  LTemp       : String;
  LValue      : String;
begin
//  Result := nil;
  AReturn := Trim(ACommand);

  LCheckCase  := false;
  LEquation   := '';
  LIdentifier := '';
  LIsText     := false;
  LNegate     := false;
  LValue      := '';

  LAllCount   := 0;
  LCount      := 0;
  LDone       := false;
  LEscapeNext := false;
  LHasPoint   := false;
  LHasStarted := false;
  LProgress   := peNot;
  SetLength(LTemp, Length(AReturn));
  for LIndex := 1 to Length(AReturn) do
  begin
    Inc(LAllCount);

    case LProgress of
      peNot :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if (LChar in CNegate) then
        begin
          LNegate := true;

          LHasPoint   := false;
          LHasStarted := false;
          LProgress   := peIdentifier;
        end
        else
        begin
          if (LChar in CCharSet) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;

            LHasPoint   := false;
            LHasStarted := true;
            LProgress   := peIdentifier;
          end
          else
          begin
            if not(LChar in CIgnore) then
              Break;
          end;
        end;
      end;

      peIdentifier :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if LHasStarted then
        begin
          if ((LChar in CCharSet) or (LChar in CPoint)) then
          begin
            if not((LChar in CPoint) and LHasPoint) then
            begin
              Inc(LCount);
              LTemp[LCount] := LChar;

              if not(LHasPoint) then
                LHasPoint := (LChar in CPoint);
            end
            else
              Break;
          end
          else
          begin
            SetLength(LTemp, LCount);
            LCount      := 0;
            LIdentifier := LTemp;
            SetLength(LTemp, Length(AReturn) - LAllCount);

            if (LChar in CCheckCase) then
            begin
              LCheckCase := true;

              LHasStarted := false;
              LProgress   := peEquation;
            end
            else
            begin
              if (LChar in CEquationBegin) then
              begin
                Inc(LCount);
                LTemp[LCount] := LChar;

                LHasStarted := true;
                LProgress   := peEquation;
              end
              else
              begin
                if (LChar in CIgnore) then
                begin
                  LHasStarted := false;
                  LProgress   := peCheckCase;
                end
                else
                  Break;
              end;
            end;
          end;
        end
        else
        begin
          if (LChar in CCharSet) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;

            LHasStarted := true;
          end
          else
          begin
            if not(LChar in CIgnore) then
              Break;
          end;
        end;
      end;

      peCheckCase :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if (LChar in CCheckCase) then
        begin
          LCheckCase := true;

          LHasStarted := false;
          LProgress   := peEquation;
        end
        else
        begin
          if (LChar in CEquationBegin) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;

            LHasStarted := true;
            LProgress   := peEquation;
          end
          else
          begin
            if not(LChar in CIgnore) then
              Break;
          end;
        end;
      end;

      peEquation :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if LHasStarted then
        begin
          if (LChar in CEquationEnd) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;
          end;

          SetLength(LTemp, LCount);
          LCount    := 0;
          LEquation := LTemp;
          SetLength(LTemp, Length(AReturn) - LAllCount);

          if (LChar in CEquationEnd) then
          begin
            LHasStarted := false;
            LProgress   := peValue;
          end
          else
          begin
            if (LChar in CNumberSet) then
            begin
              LIsText := false;

              Inc(LCount);
              LTemp[LCount] := LChar;

              LHasPoint   := false;
              LHasStarted := true;
              LProgress   := peValue;
            end
            else
            begin
              if (LChar in CText) then
              begin
                LIsText := true;

                LHasStarted := true;
                LProgress   := peValue;
              end
              else
              begin
                if (LChar in CIgnore) then
                begin
                  LHasStarted := false;
                  LProgress   := peValue;
                end
                else
                  Break;
              end;
            end;
          end;
        end
        else
        begin
          if (LChar in CEquationBegin) then
          begin
            Inc(LCount);
            LTemp[LCount] := LChar;

            LHasStarted := true;
          end
          else
          begin
            if not(LChar in CIgnore) then
              Break;
          end;
        end;
      end;

      peValue :
      begin
        if LHasStarted then
        begin
          if LIsText then
          begin
            LChar := AReturn[LIndex];
            if ((not(LChar in CText) and not(LChar in CEscape)) or LEscapeNext) then
            begin
              Inc(LCount);
              LTemp[LCount] := LChar;

              LEscapeNext := false;
            end
            else
            begin
              LEscapeNext := (LChar in CEscape);
              if not(LEscapeNext) then
              begin
                SetLength(LTemp, LCount);
                LCount := 0;
                LValue := LTemp;
                SetLength(LTemp, Length(AReturn) - LAllCount);

                LHasStarted := false;
                LProgress   := peIsCorrect;

                LDone := true;
              end;
            end;
          end
          else
          begin
            LChar := UpCase(AReturn[LIndex]);
            if ((LChar in CNumberSet) or (LChar in CComma)) then
            begin
              if not((LChar in CComma) and LHasPoint) then
              begin
                Inc(LCount);
                LTemp[LCount] := LChar;

                if not(LHasPoint) then
                  LHasPoint := (LChar in CComma);
              end
              else
                Break;
            end
            else
            begin
              if (LChar in CIgnore) then
              begin
                SetLength(LTemp, LCount);
                LCount := 0;
                LValue := LTemp;
                SetLength(LTemp, Length(AReturn) - LAllCount);

                LHasStarted := false;
                LProgress   := peIsCorrect;

                LDone := true;
              end
              else
              begin
                if (LChar in CSeperator) then
                begin
                  SetLength(LTemp, LCount);
                  LValue := LTemp;
                  SetLength(LTemp, Length(AReturn) - LAllCount);
                  LCount := 0;

                  LDone := true;
                  Break;
                end
                else
                  Break;
              end;
            end;
          end;
        end
        else
        begin
          LChar := UpCase(AReturn[LIndex]);
          if ((LChar in CNumberSet) or (LChar in CComma)) then
          begin
            LIsText := false;

            Inc(LCount);
            LTemp[LCount] := LChar;

            LHasPoint   := (LChar in CComma);
            LHasStarted := true;
          end
          else
          begin
            if (LChar in CText) then
            begin
              LIsText := true;

              LHasStarted := true;
            end
            else
            begin
              if not(LChar in CIgnore) then
                Break;
            end;
          end;
        end;
      end;

      peIsCorrect :
      begin
        LChar := UpCase(AReturn[LIndex]);
        if (LChar in CSeperator) then
          Break
        else
        begin
          if not(LChar in CIgnore) then
          begin
            LDone := false;
            Break;
          end;
        end;
      end;
    end;
  end;
  SetLength(LTemp, LCount);
  Delete(AReturn, 1, LAllCount);

  if (Length(LTemp) > 0) then
  begin
    LDone := ((LProgress = peValue) and not(LIsText));
    if LDone then
      LValue := LTemp;
  end;

  if LDone then
  begin
    Result := TEquationItem.Create;
    try
      for LIndex := Low(CEquations) to High(CEquations) do
      begin
        LDone := (CEquations[LIndex] = LEquation);
        if LDone then
        begin
          Result.EquationType := TEquationType(LIndex);

          Break;
        end;
      end;

      if LDone then
      begin
        if (Pos(CPointChar, LIdentifier) > 0) then
        begin
          Result.IdentifierLevel := Copy(LIdentifier, 1, Pred(Pos(CPointChar, LIdentifier)));
          Delete(LIdentifier, 1, Pos(CPointChar, LIdentifier));
        end;
        Result.IdentifierName := LIdentifier;

        LDone := (Length(Result.IdentifierName) > 0);
        if LDone then
        begin
          Result.CheckCase := LCheckCase;
          Result.Negate    := LNegate;

          if LIsText then
            Result.ValueType := vtText
          else
            Result.ValueType := vtNumber;

          Result.Value := LValue;
        end;
      end;

      if not(LDone) then
      begin
        Result.Free;
        Result := nil;
      end;
    except
      Result.Free;
      Result := nil;
    end;
  end
  else
    raise Exception.Create('Equation Not Compliant To Syntax');
end;

function TLanguageParser.ParseIN(const ACommand : String; var AReturn : String) : TEquationList;
const
  CWord = 'IN';

  CCharSet   = ['I', 'N'];
  CIgnoreSet = [' '];
var
  LTemp : String;
begin
  Result := nil;

  LTemp := ParseWord(ACommand, CCharSet, CIgnoreSet, AReturn);
  if (AnsiUpperCase(LTemp) = CWord) then
    Result := ParseOREquations(AReturn, AReturn);
end;

function TLanguageParser.ParseName(const ACommand : String; var AReturn : String) : String;
const
  CCharSet   = ['A'..'Z', '0'..'9'];
  CIgnoreSet = [' '];
begin
  Result := ParseWord(ACommand, CCharSet, CIgnoreSet, AReturn);
end;

function TLanguageParser.ParseOREquations(const ACommand : String; var AReturn : String) : TEquationList;
const
  CClose     = [')'];
  CDivider   = ['|'];
  CEscape    = ['/'];
  CIgnore    = [' '];
  COpen      = ['('];
  CSeperator = ['I'];
  CText      = ['"'];
var
  LAllCount   : LongInt;
  LChar       : Char;
  LCount      : LongInt;
  LEscapeNext : Boolean;
  LInBracket  : Boolean;
  LIndex      : LongInt;
  LInText     : Boolean;
  LItem       : TEquationItemList;
  LTemp       : String;
begin
  Result := nil;
  AReturn := Trim(ACommand);

  LAllCount   := 0;
  LCount      := 0;
  LEscapeNext := false;
  LInBracket  := false;
  LInText     := false;
  SetLength(LTemp, Length(AReturn));
  for LIndex := 1 to Length(AReturn) do
  begin
    Inc(LAllCount);

    LChar := UpCase(AReturn[LIndex]);
    if ((((LChar in CSeperator) and not(LInBracket)) or (LChar in CDivider)) and not(LInText)) then
    begin
      SetLength(LTemp, LCount);
      LCount := 0;

      LItem := ParseANDEquations(LTemp, LTemp);
      if (LItem <> nil) then
      begin
        if (Result = nil) then
          Result := TEquationList.Create;

        Result.Add(LItem);
      end;

      SetLength(LTemp, Length(AReturn) - LAllCount);

      if (LChar in CSeperator) then
      begin
        Dec(LAllCount);
        Break;
      end;
    end
    else
    begin
      if LInText then
        LChar := AReturn[LIndex];

      Inc(LCount);
      LTemp[LCount] := LChar;

      if LInText then
      begin
        LInText := (not(LChar in CText) or LEscapeNext);
        if LEscapeNext then
          LEscapeNext := false
        else
          LEscapeNext := (LChar in CEscape);
      end
      else
        LInText := (LChar in CText);

      if LInBracket then
        LInBracket := not(LChar in CClose)
      else
        LInBracket := (LChar in COpen);
    end;
  end;
  SetLength(LTemp, LCount);
  Delete(AReturn, 1, LAllCount);

  if (Length(LTemp) > 0) then
  begin
    LItem := ParseANDEquations(LTemp, LTemp);
    if (LItem <> nil) then
    begin
      if (Result = nil) then
        Result := TEquationList.Create;

      Result.Add(LItem);
    end;
  end;
end;

function TLanguageParser.ParseWHERE(const ACommand: String; var AReturn: String): TEquationList;
const
  CWord = 'WHERE';

  CCharSet   = ['E', 'H', 'R', 'W'];
  CIgnoreSet = [' '];
var
  LTemp : String;
begin
  Result := nil;

  LTemp := ParseWord(ACommand, CCharSet, CIgnoreSet, AReturn);
  if (AnsiUpperCase(LTemp) = CWord) then
    Result := ParseOREquations(AReturn, AReturn);
end;

function TLanguageParser.ParseWITH(const ACommand: String; var AReturn: String): THierarchyList;
const
  CWord = 'WITH';

  CCharSet   = ['H', 'I', 'T', 'W'];
  CIgnoreSet = [' '];
var
  LTemp : String;
begin
  Result := nil;

  LTemp := ParseWord(ACommand, CCharSet, CIgnoreSet, AReturn);
  if (AnsiUpperCase(LTemp) = CWord) then
    Result := ParseDefinitionList(AReturn, AReturn);
end;

function TLanguageParser.ParseWord(const ACommand: String; const ACharSet : TCharSet; const AIgnoreSet : TCharSet; var AReturn: String): String;
var
  LAllCount   : LongInt;
  LChar       : Char;
  LCount      : LongInt;
  LDone       : Boolean;
  LHasStarted : Boolean;
  LIndex      : LongInt;
  LTemp       : String;
begin
  Result := '';
  AReturn := Trim(ACommand);

  LAllCount   := 0;
  LCount      := 0;
  LDone       := false;
  LHasStarted := false;
  SetLength(LTemp, Length(AReturn));
  for LIndex := 1 to Length(AReturn) do
  begin
    Inc(LAllCount);

    LChar := UpCase(AReturn[LIndex]);
    if LHasStarted then
    begin
      if (LChar in ACharSet) then
      begin
        Inc(LCount);
        LTemp[LCount] := LChar;

        LDone := true;
      end
      else
      begin
        Dec(LAllCount);

        Break;
      end;
    end
    else
    begin
      if (LChar in ACharSet) then
      begin
        Inc(LCount);
        LTemp[LCount] := LChar;

        LDone       := true;
        LHasStarted := true;
      end
      else
      begin
        if not(LChar in AIgnoreSet) then
        begin
          Dec(LAllCount);

          Break;
        end;
      end;
    end;
  end;
  SetLength(LTemp, LCount);
  Delete(AReturn, 1, LAllCount);

  if LDone then
    Result := LTemp;
end;

end.
