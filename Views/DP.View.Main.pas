unit DP.View.Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.ListView.Types, FMX.ListView.Appearances, FMX.ListView.Adapters.Base,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.ListView;

type
  TMainView = class(TForm)
    ListView: TListView;
    procedure FormActivate(Sender: TObject);
    procedure ListViewResized(Sender: TObject);
  private
    FHasShown: Boolean;
    procedure LoadDrawables;
  public
    { Public declarations }
  end;

var
  MainView: TMainView;

implementation

{$R *.fmx}

uses
  System.IOUtils,
  Androidapi.JNI.GraphicsContentViewText, Androidapi.Helpers, Androidapi.JNI.JavaTypes,
  FMX.Surfaces, FMX.Helpers.Android,
  SimpleLog.Log;

type
  TBitmapHelper = class helper for TBitmap
  public
    function FromJBitmap(const AJBitmap: JBitmap): Boolean;
  end;

  TListViewHelper = class helper for TListView
  private
    function ItemWidth: Single;
    function GetObjectAbsoluteX(const AObject: TCommonObjectAppearance): Single;
    procedure InternalStretchObject(const AObject: TCommonObjectAppearance; const AStretchTo: Single);
  public
    function FindAppearanceObject(const AName: string; var AObject: TCommonObjectAppearance): Boolean;
    procedure StretchObject(const AName: string; const AToName: string = '');
  end;

  TAndroidDrawableListViewItem = class(TListViewItem)
  private
    function GetDescription: TListItemText;
    function GetImage: TListItemImage;
    function GetTitle: TListItemText;
  protected
    function GetListItemImage(const AItemName: string; const AOwnsBitmap: Boolean = True): TListItemImage;
  public
    property Description: TListItemText read GetDescription;
    property Image: TListItemImage read GetImage;
    property Title: TListItemText read GetTitle;
  end;

function GetResourceID(const AResourceName, AResourceType: string; const APackageName: string = ''): Integer; overload;
var
  LContext: JContext;
  LPackageName: JString;
begin
  LContext := TAndroidHelper.Context;
  if APackageName.IsEmpty then
    LPackageName := LContext.getPackageName
  else
    LPackageName := StringToJString(APackageName);
  Result := LContext.getResources.getIdentifier(StringToJString(AResourceName), StringToJString(AResourceType), LPackageName);
end;

function GetAndroidResourceID(const AResourceName, AResourceType: string): Integer;
begin
  Result := GetResourceID(AResourceName, AResourceType, 'android');
end;

function GetDrawableBitmap(const AResourceId: Integer): JBitmap;
var
  LDrawable: JDrawable;
  LCanvas: JCanvas;
begin
  LDrawable := TAndroidHelper.Context.getDrawable(AResourceId);
  if LDrawable <> nil then
  begin
    if (LDrawable.getIntrinsicWidth <= 0) or (LDrawable.getIntrinsicHeight <= 0) then
      Result := TJBitmap.JavaClass.createBitmap(96, 96, TJBitmap_Config.JavaClass.ARGB_8888)
    else
      Result := TJBitmap.JavaClass.createBitmap(LDrawable.getIntrinsicWidth, LDrawable.getIntrinsicHeight, TJBitmap_Config.JavaClass.ARGB_8888);
    LCanvas := TJCanvas.JavaClass.init(Result);
    LDrawable.setBounds(0, 0, LCanvas.getWidth, LCanvas.getHeight);
    LDrawable.draw(LCanvas);
  end;
end;

function FindAndroidDrawableBitmap(const AResourceName: string; out ABitmap: JBitmap): Boolean;
var
  LResId: Integer;
begin
  Result := False;
  LResId := GetAndroidResourceID(AResourceName, 'drawable');
  if LResId <> 0 then
  begin
    ABitmap := GetDrawableBitmap(LResId);
    Result := True;
  end;
end;

{ TBitmapHelper }

function TBitmapHelper.FromJBitmap(const AJBitmap: JBitmap): Boolean;
var
  LSurface: TBitmapSurface;
begin
  LSurface := TBitmapSurface.Create;
  try
    Result := JBitmapToSurface(AJBitmap, LSurface);
    if Result  then
      Assign(LSurface);
  finally
    LSurface.Free;
  end;
end;

{ TListViewHelper }

function TListViewHelper.FindAppearanceObject(const AName: string; var AObject: TCommonObjectAppearance): Boolean;
var
  LObject: TCommonObjectAppearance;
begin
  Result := False;
  for LObject in ItemAppearanceObjects.ItemObjects.Objects do
  begin
    if LObject.Name.Equals(AName) then
    begin
      AObject := LObject;
      Result := True;
      Break;
    end;
  end;
end;

function TListViewHelper.GetObjectAbsoluteX(const AObject: TCommonObjectAppearance): Single;
begin
  case AObject.Align of
    TListItemAlign.Leading:
      Result := AObject.PlaceOffset.X;
    TListItemAlign.Center:
      Result := (ItemWidth / 2) - (AObject.Width / 2) + AObject.PlaceOffset.X;
    TListItemAlign.Trailing:
      Result := ItemWidth + AObject.PlaceOffset.X - AObject.Width;
  else
    Result := AObject.PlaceOffset.X;
  end;
end;

function TListViewHelper.ItemWidth: Single;
begin
  Result := Width - 10; // TODO: Need to determine item width properly
end;

procedure TListViewHelper.InternalStretchObject(const AObject: TCommonObjectAppearance; const AStretchTo: Single);
begin
  case AObject.Align of
    TListItemAlign.Leading:
      AObject.Width := AStretchTo - AObject.PlaceOffset.X - 10;
    // Implement the others when needed
  end;
end;

procedure TListViewHelper.StretchObject(const AName: string; const AToName: string = '');
var
  LObject, LToObject: TCommonObjectAppearance;
  LStretchTo: Single;
begin
  if FindAppearanceObject(AName, LObject) and (AToName.IsEmpty or FindAppearanceObject(AToName, LToObject)) then
  begin
    if LToObject <> nil then
      LStretchTo := GetObjectAbsoluteX(LToObject)
    else
      LStretchTo := ItemWidth;
    InternalStretchObject(LObject, LStretchTo);
  end;
end;

{ TAndroidDrawableListViewItem }

function TAndroidDrawableListViewItem.GetListItemImage(const AItemName: string; const AOwnsBitmap: Boolean = True): TListItemImage;
begin
  Result := Objects.FindObjectT<TListItemImage>(AItemName);
  if AOwnsBitmap and (Result.Bitmap = nil) then
    Result.Bitmap := TBitmap.Create;
  Result.OwnsBitmap := AOwnsBitmap;
end;

function TAndroidDrawableListViewItem.GetDescription: TListItemText;
begin
  Result := Objects.FindObjectT<TListItemText>('Description');
end;

function TAndroidDrawableListViewItem.GetImage: TListItemImage;
begin
  Result := GetListItemImage('Image');
end;

function TAndroidDrawableListViewItem.GetTitle: TListItemText;
begin
  Result := Objects.FindObjectT<TListItemText>('Title');
end;

{ TMainView }

procedure TMainView.FormActivate(Sender: TObject);
begin
  if not FHasShown then
    LoadDrawables;
  FHasShown := True;
end;

procedure TMainView.ListViewResized(Sender: TObject);
begin
  ListView.StretchObject('Title', 'Image');
end;

procedure TMainView.LoadDrawables;
var
  LFileName, LResourceName: string;
  LItem: TAndroidDrawableListViewItem;
  LBitmap: JBitmap;
begin
  LFileName := TPath.Combine(TPath.GetDocumentsPath, 'drawables.txt');
  if TFile.Exists(LFileName) then
  begin
    for LResourceName in TFile.ReadAllLines(LFileName) do
    begin
      if FindAndroidDrawableBitmap(LResourceName, LBitmap) then
      begin
        LItem := TAndroidDrawableListViewItem(ListView.Items.Add);
        LItem.Title.Font.Size := 14;
        LItem.Title.Text := LResourceName;
        LItem.Image.Bitmap.FromJBitmap(LBitmap);
      end;
    end;
  end;
end;

end.
