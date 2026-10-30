program RedeFraternaServer;

{$mode Delphi}{$H+}
{$codepage UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, IniFiles,
  Horse,
  ZConnection,
  twapi.Types, twapi.Controller.PoolConn, twapi.Auth,
  RedeFraterna.Database.Schema,
  RedeFraterna.Database.Seeds,
  RedeFraterna.Middlewares,
  RedeFraterna.Controllers;

procedure EnsureDefaultConfFile;
var
  LConfFile: string;
  LIni: TIniFile;
  LSqliteDll: string;
begin
  LConfFile := ChangeFileExt(ParamStr(0), '.conf');
  LIni := TIniFile.Create(LConfFile);
  try
    if not FileExists(LConfFile) then
    begin
      LSqliteDll := ExtractFilePath(ParamStr(0)) + 'sqlite3.dll';
      if not FileExists(LSqliteDll) then
        LSqliteDll := 'D:\Desenv\lazarus\EXE\sqlite3.dll';
      if not FileExists(LSqliteDll) then
        LSqliteDll := 'sqlite3.dll';

      LIni.WriteString(SECT_DB_NAME, 'Protocol', 'sqlite');
      LIni.WriteInteger(SECT_DB_NAME, 'Port', 5432);
      LIni.WriteString(SECT_DB_NAME, 'Host', 'localhost');
      LIni.WriteString(SECT_DB_NAME, 'DataBase', 'masterdb.db');
      LIni.WriteString(SECT_DB_NAME, 'User', '');
      LIni.WriteString(SECT_DB_NAME, 'Paswd', '');
      LIni.WriteString(SECT_DB_NAME, 'Lib', LSqliteDll);

      LIni.WriteInteger(SECT_BASE_NAME, 'ServerPort', 9095);
      LIni.WriteBool(SECT_BASE_NAME, 'Debug', True);
      LIni.WriteString('Entidade', 'NomeMantenedora', 'UME - Cachoeira do Sul');
      LIni.WriteString('Entidade', 'SiglaMantenedora', 'UME');
      LIni.WriteString('Entidade', 'CidadeMantenedora', 'Cachoeira do Sul');
      LIni.WriteString('Entidade', 'UFMantenedora', 'RS');
      LIni.UpdateFile;
    end;

    GConfigEnv.ServerPort := LIni.ReadInteger(SECT_BASE_NAME, 'ServerPort', 9095);
    GConfigEnv.Debug := LIni.ReadBool(SECT_BASE_NAME, 'Debug', True);
    if GConfigEnv.JWTSecret = '' then;
  finally
    LIni.Free;
  end;
end;

procedure InitDatabaseOnStartup;
var
  LConn, LTenantConn: TZConnection;
  LTenantDB: string;
begin
  LConn := TZeosConnectionPool.GetInstance.Acquire('');
  try
    TRedeFraternaSchema.EnsureMasterSchema(LConn);
    if SameText(LConn.Protocol, 'sqlite') then
      LTenantDB := 'redefraterna_db.db'
    else
      LTenantDB := 'redefraterna_db';
  finally
    TZeosConnectionPool.GetInstance.Release(LConn);
  end;

  // Já inicializa também o schema do banco operacional padrão no startup
  LTenantConn := TZeosConnectionPool.GetInstance.Acquire(LTenantDB);
  try
    TRedeFraternaSchema.EnsureTenantSchema(LTenantConn);
  finally
    TZeosConnectionPool.GetInstance.Release(LTenantConn);
  end;
end;

begin
  SetCurrentDir(ExtractFilePath(ParamStr(0)));

  SetMultiByteConversionCodePage(CP_UTF8);
  SetMultiByteRTLFileSystemCodePage(CP_UTF8);

  EnsureDefaultConfFile;
  InitDatabaseOnStartup;

  RegisterRedeFraternaMiddlewares;
  TRedeFraternaControllers.RegisterAllRoutes;

  WriteLn('==================================================================');
  WriteLn('  Rede Fraterna - Uniao Municipal Espirita (UME)');
  WriteLn('  Servidor Web ativo em: http://localhost:' + IntToStr(GConfigEnv.ServerPort));
  WriteLn('  Perfis iniciais:');
  WriteLn('    - Administrador:       admin    / admin123');
  WriteLn('    - Operador do Sistema: operador / 123456');
  WriteLn('    - Operador da Familia: familia  / 123456');
  WriteLn('==================================================================');

  try
    THorse.Listen(GConfigEnv.ServerPort);
  finally
    TRedeFraternaControllers.FinalizeControllers;
  end;
end.
