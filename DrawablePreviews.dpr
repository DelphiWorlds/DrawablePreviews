program DrawablePreviews;

uses
  System.StartUpCopy,
  FMX.Forms,
  DP.View.Main in 'Views\DP.View.Main.pas' {MainView};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainView, MainView);
  Application.Run;
end.
