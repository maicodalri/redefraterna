{*******************************************************************************
  RedeFraterna.Controllers - Controladores REST, Auditoria de Famílias e Login
  Projeto: Rede Fraterna - Sistema de Controle da União Municipal Espírita (UME)

  Descrição:
    Gerencia todas as rotas REST do sistema Rede Fraterna utilizando
    TTWApiController (twapi.Controller) para CRUDs automáticos e rotas
    especializadas para consultas enriquecidas e gravação automática de Log de
    Alterações da Família (tabela familia_logs).
*******************************************************************************}
unit RedeFraterna.Controllers;

{$mode Delphi}{$H+}
{$codepage UTF8}

interface

uses
  Classes, SysUtils, StrUtils, IniFiles, DB, fpjson, jsonparser, sha1,
  Horse, Horse.Commons, ZConnection, ZDataset, DataSet.Serialize,
  twapi.Types, twapi.SQLBuilder, twapi.Controller, twapi.Controller.PoolConn,
  twapi.Auth, twapi.TextFileLog, RedeFraterna.Database.Schema;

type
  TCurrentRequestUser = record
    UserId: Integer;
    Username: string;
    UserType: string;
    CentroId: Integer;
    IsAdmin: Boolean;
  end;

  { TRedeFraternaControllers }
  TRedeFraternaControllers = class
  private
    class var FCtrlUsuarios: TTWApiController;
    class var FCtrlCentros: TTWApiController;
    class var FCtrlTrabalhadores: TTWApiController;
    class var FCtrlAgenda: TTWApiController;
    class var FCtrlFamilias: TTWApiController;
    class var FCtrlIntegrantes: TTWApiController;
    class var FCtrlAuxilios: TTWApiController;
    class var FCtrlLogs: TTWApiController;
    class var FCtrlNoticias: TTWApiController;

    // Helpers de banco, escopo por Centro Espírita e auditoria
    class function GetNextIdIfPostgres(AConn: TZConnection): Int64;
    class function ResolveTenantDBName(const ATenantAlias: string): string;
    class function ObterConfiguracaoEntidadeJSON(AConn: TZConnection): TJSONObject;
    class function ObterNomeCentro(AConn: TZConnection; ACentroId: Integer): string;
    class function ObterCentroIdDoRegistro(AConn: TZConnection; const ATable: string; AId: Integer): Integer;
    class function ObterCentroIdDaFamilia(AConn: TZConnection; AFamiliaId: Integer): Integer;
    class function ObterRegistroJSON(AConn: TZConnection; const ATable: string; AId: Integer): TJSONObject;
    class function NormalizarCPF(const ACPF: string): string;
    class function ValidarCPFUnicoNoSistema(AConn: TZConnection; const ACPF: string;
      ACheckResponsavel: Boolean; AIgnorarFamiliaId, AIgnorarIntegranteId: Integer;
      out AErrorMessage: string): Boolean;
    class procedure GravarLogFamilia(AConn: TZConnection; AFamiliaId, ACentroId, AUsuarioId: Integer;
      const AUsuarioNome, AAcao, AEntidade: string; AEntidadeId: Integer;
      const AResumo, ADadosAnteriores, ADadosNovos: string);

    // Hooks de Usuários
    class procedure UsuariosBeforeCreate(Sender: TTWApiController; AJSONObject: TJSONObject;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure UsuariosBeforeUpdate(Sender: TTWApiController; const AId: string;
      AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);

    // Hooks de Centros Espíritas
    class procedure CentrosBeforeCreate(Sender: TTWApiController; AJSONObject: TJSONObject;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure CentrosBeforeUpdate(Sender: TTWApiController; const AId: string;
      AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure CentrosBeforeDelete(Sender: TTWApiController; const AId: string;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);

    // Hooks de Trabalhadores
    class procedure TrabalhadoresBeforeCreate(Sender: TTWApiController; AJSONObject: TJSONObject;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure TrabalhadoresBeforeUpdate(Sender: TTWApiController; const AId: string;
      AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure TrabalhadoresBeforeDelete(Sender: TTWApiController; const AId: string;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);

    // Hooks de Agenda Semanal
    class procedure AgendaBeforeCreate(Sender: TTWApiController; AJSONObject: TJSONObject;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure AgendaBeforeUpdate(Sender: TTWApiController; const AId: string;
      AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure AgendaBeforeDelete(Sender: TTWApiController; const AId: string;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);

    // Hooks de Famílias (com geração automática de log de alterações)
    class procedure FamiliasBeforeCreate(Sender: TTWApiController; AJSONObject: TJSONObject;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure FamiliasAfterCreate(Sender: TTWApiController; AJSONObject: TJSONObject;
      var DBConn: TZConnection);
    class procedure FamiliasBeforeUpdate(Sender: TTWApiController; const AId: string;
      AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure FamiliasBeforeDelete(Sender: TTWApiController; const AId: string;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);

    // Hooks de Integrantes da Família (com geração automática de log na família)
    class procedure IntegrantesBeforeCreate(Sender: TTWApiController; AJSONObject: TJSONObject;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure IntegrantesAfterCreate(Sender: TTWApiController; AJSONObject: TJSONObject;
      var DBConn: TZConnection);
    class procedure IntegrantesBeforeUpdate(Sender: TTWApiController; const AId: string;
      AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure IntegrantesBeforeDelete(Sender: TTWApiController; const AId: string;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);

    // Hooks de Histórico de Auxílios (com geração automática de log na família)
    class procedure AuxiliosBeforeCreate(Sender: TTWApiController; AJSONObject: TJSONObject;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure AuxiliosAfterCreate(Sender: TTWApiController; AJSONObject: TJSONObject;
      var DBConn: TZConnection);
    class procedure AuxiliosBeforeUpdate(Sender: TTWApiController; const AId: string;
      AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure AuxiliosBeforeDelete(Sender: TTWApiController; const AId: string;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);

    // Hooks de Notícias
    class procedure NoticiasBeforeCreate(Sender: TTWApiController; AJSONObject: TJSONObject;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure NoticiasBeforeUpdate(Sender: TTWApiController; const AId: string;
      AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
    class procedure NoticiasBeforeDelete(Sender: TTWApiController; const AId: string;
      var AAllow: Boolean; var AErrorMessage: string; var DBConn: TZConnection);
  public
    class function OnAuthenticate(const AUser: string; const APass: string;
      const ATenantAlias: string; const AIdSistem: Integer;
      out ADataBase: string; out AUserId: Integer; out AErrorMsg: string;
      out ATipoUser: string; out ALogoBase64: string): Boolean;

    // Endpoints customizados para visões consolidadas e relatórios rápidos
    class procedure HandleGetMeuPerfil(Req: THorseRequest; Res: THorseResponse); static;
    class procedure HandleGetConfiguracoes(Req: THorseRequest; Res: THorseResponse); static;
    class procedure HandlePutConfiguracoes(Req: THorseRequest; Res: THorseResponse); static;
    class procedure HandlePostAlterarMinhaSenha(Req: THorseRequest; Res: THorseResponse); static;
    class procedure HandleGetResumoDashboard(Req: THorseRequest; Res: THorseResponse); static;
    class procedure HandleGetFamiliasDetalhadas(Req: THorseRequest; Res: THorseResponse); static;
    class procedure HandleGetFamiliaCompleta(Req: THorseRequest; Res: THorseResponse); static;
    class procedure HandleGetEntidadePublica(Req: THorseRequest; Res: THorseResponse); static;
    class procedure HandleGetAgendaPublicaCentro(Req: THorseRequest; Res: THorseResponse); static;
    class procedure HandleGetNoticiasPublicas(Req: THorseRequest; Res: THorseResponse); static;

    class procedure RegisterAllRoutes;
    class procedure FinalizeControllers;
  end;

implementation

uses
  DataSet.Serialize.Config;

threadvar
  GCurrentUser: TCurrentRequestUser;

procedure HorseCentroAccessMiddleware(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
var
  LPath, LSubId: string;
  LTokenData: TTokenData;
  LConn: TZConnection;
  LQry: TZQuery;
begin
  GCurrentUser := Default(TCurrentRequestUser);

  LPath := LowerCase(Trim(Req.RawWebRequest.PathInfo));
  if SameText(Req.RawWebRequest.Method, 'OPTIONS') or
     SameText(LPath, '/api/login') or
     (not SameText(Copy(LPath, 1, 5), '/api/')) then
  begin
    Next();
    Exit;
  end;

  LTokenData := ValidateToken(GetTokenByReq(Req));
  if not LTokenData.IsValid then
  begin
    Next();
    Exit;
  end;

  GCurrentUser.UserId := LTokenData.UserId;
  GCurrentUser.Username := LTokenData.Username;
  GCurrentUser.UserType := UpperCase(Trim(LTokenData.UserType));
  GCurrentUser.CentroId := 0;
  GCurrentUser.IsAdmin := (GCurrentUser.UserType = 'A');

  LConn := TZeosConnectionPool.GetInstance.Acquire(LTokenData.Database);
  try
    LQry := TZQuery.Create(nil);
    try
      LQry.Connection := LConn;
      LQry.SQL.Text :=
        'SELECT id, login, tipo, COALESCE(centro_id, 0) AS centro_id, ativo ' +
        'FROM usuarios WHERE id = :id';
      LQry.ParamByName('id').AsInteger := LTokenData.UserId;
      LQry.Open;
      if not LQry.IsEmpty then
      begin
        if not SameText(LQry.FieldByName('ativo').AsString, 'S') then
        begin
          Res.Status(403).Send('{"error": "Seu usuário está inativo no sistema."}').ContentType(CONTENT_TYPE_JSON);
          raise EHorseCallbackInterrupted.Create;
        end;
        GCurrentUser.Username := Trim(LQry.FieldByName('login').AsString);
        GCurrentUser.UserType := UpperCase(Trim(LQry.FieldByName('tipo').AsString));
        GCurrentUser.CentroId := LQry.FieldByName('centro_id').AsInteger;
        GCurrentUser.IsAdmin := (GCurrentUser.UserType = 'A');
      end;
    finally
      LQry.Free;
    end;
  finally
    TZeosConnectionPool.GetInstance.Release(LConn);
  end;

  if not GCurrentUser.IsAdmin then
  begin
    // Qualquer usuário não-Administrador deve estar obrigatoriamente vinculado a um Centro Espírita
    if GCurrentUser.CentroId <= 0 then
    begin
      Res.Status(403).Send('{"error": "Seu usuário não possui um Centro Espírita vinculado. Solicite ao Administrador da UME a vinculação do seu cadastro."}').ContentType(CONTENT_TYPE_JSON);
      raise EHorseCallbackInterrupted.Create;
    end;

    // Bloqueia acesso de não-administradores ao cadastro de usuários
    if (LPath = '/api/usuarios') or (Pos('/api/usuarios/', LPath) = 1) then
    begin
      Res.Status(403).Send('{"error": "Acesso restrito ao Administrador da UME."}').ContentType(CONTENT_TYPE_JSON);
      raise EHorseCallbackInterrupted.Create;
    end;

    // Bloqueia consulta direta a outro Centro Espírita (GET /api/centros/:id)
    if SameText(Req.RawWebRequest.Method, 'GET') and (Pos('/api/centros/', LPath) = 1) then
    begin
      LSubId := Copy(LPath, Length('/api/centros/') + 1, MaxInt);
      if StrToIntDef(LSubId, 0) <> GCurrentUser.CentroId then
      begin
        Res.Status(403).Send('{"error": "Acesso negado: você só tem acesso às informações do seu próprio Centro Espírita."}').ContentType(CONTENT_TYPE_JSON);
        raise EHorseCallbackInterrupted.Create;
      end;
    end;
  end;

  Next();
end;

function GetJSONIntDef(AObj: TJSONObject; const AKey: string; ADefault: Integer = 0): Integer;
var
  LNode: TJSONData;
begin
  Result := ADefault;
  if not Assigned(AObj) then Exit;
  LNode := AObj.Find(AKey);
  if (not Assigned(LNode)) or (LNode.JSONType = jtNull) then Exit;
  case LNode.JSONType of
    jtNumber: Result := LNode.AsInteger;
    jtString: Result := StrToIntDef(Trim(LNode.AsString), ADefault);
  end;
end;

function GetJSONStrDef(AObj: TJSONObject; const AKey: string; const ADefault: string = ''): string;
var
  LNode: TJSONData;
begin
  Result := ADefault;
  if not Assigned(AObj) then Exit;
  LNode := AObj.Find(AKey);
  if (not Assigned(LNode)) or (LNode.JSONType = jtNull) then Exit;
  Result := Trim(LNode.AsString);
end;

{ TRedeFraternaControllers }

class function TRedeFraternaControllers.GetNextIdIfPostgres(AConn: TZConnection): Int64;
var
  LQry: TZQuery;
begin
  Result := 0;
  if not SameText(AConn.Protocol, 'sqlite') then
  begin
    LQry := TZQuery.Create(nil);
    try
      LQry.Connection := AConn;
      LQry.SQL.Text := 'SELECT nextval(''seq_global_id'')';
      LQry.Open;
      Result := LQry.Fields[0].AsLargeInt;
    finally
      LQry.Free;
    end;
  end;
end;

class function TRedeFraternaControllers.ResolveTenantDBName(const ATenantAlias: string): string;
var
  LMasterConn, LTmpl: TZConnection;
  LQryMaster: TZQuery;
  LMasterDB, LAlias, LTenantDB: string;
begin
  LAlias := Trim(ATenantAlias);
  if LAlias = '' then
    LAlias := 'redefraterna';

  LTmpl := TZeosConnectionPool.GetTampleteConnection;
  if SameText(LTmpl.Protocol, 'sqlite') then
    LMasterDB := ExtractFileName(LTmpl.Database)
  else
    LMasterDB := LTmpl.Database;
  if Trim(LMasterDB) = '' then
    LMasterDB := 'masterdb.db';

  LTenantDB := '';
  LMasterConn := TZeosConnectionPool.GetInstance.Acquire(LMasterDB);
  try
    TRedeFraternaSchema.EnsureMasterSchema(LMasterConn);
    LQryMaster := TZQuery.Create(nil);
    try
      LQryMaster.Connection := LMasterConn;
      LQryMaster.SQL.Text :=
        'SELECT tenant_dbname FROM tb_sistema ' +
        'WHERE UPPER(tenant_alias) = UPPER(:alias) AND sistema = 1';
      LQryMaster.ParamByName('alias').AsString := LAlias;
      LQryMaster.Open;
      if not LQryMaster.IsEmpty then
        LTenantDB := Trim(LQryMaster.FieldByName('tenant_dbname').AsString);
    finally
      LQryMaster.Free;
    end;
  finally
    TZeosConnectionPool.GetInstance.Release(LMasterConn);
  end;

  if LTenantDB = '' then
  begin
    if SameText(LTmpl.Protocol, 'sqlite') then
      Result := 'redefraterna_db.db'
    else
      Result := 'redefraterna_db';
  end
  else if SameText(LTmpl.Protocol, 'sqlite') then
    Result := ExtractFileName(LTenantDB)
  else
    Result := LTenantDB;
end;

class function TRedeFraternaControllers.ObterConfiguracaoEntidadeJSON(AConn: TZConnection): TJSONObject;
var
  LQry: TZQuery;
begin
  Result := TJSONObject.Create;
  LQry := TZQuery.Create(nil);
  try
    LQry.Connection := AConn;
    LQry.SQL.Text := 'SELECT * FROM configuracoes ORDER BY id ASC LIMIT 1';
    LQry.Open;
    if LQry.IsEmpty then
    begin
      Result.Add('id', 1);
      Result.Add('nome_mantenedora', 'UME - Cachoeira do Sul');
      Result.Add('sigla_mantenedora', 'UME');
      Result.Add('subtitulo_sistema', 'Gestão Integrada de Centros Espíritas e Assistência Social');
      Result.Add('cnpj_mantenedora', '');
      Result.Add('cidade_mantenedora', 'Cachoeira do Sul');
      Result.Add('uf_mantenedora', 'RS');
      Result.Add('telefone_mantenedora', '');
      Result.Add('email_mantenedora', '');
      Result.Add('endereco_mantenedora', '');
    end
    else
    begin
      Result.Free;
      Result := LQry.ToJSONObject;
      if Trim(GetJSONStrDef(Result, 'nome_mantenedora', '')) = '' then
        Result.Strings['nome_mantenedora'] := 'UME - Cachoeira do Sul';
      if Trim(GetJSONStrDef(Result, 'sigla_mantenedora', '')) = '' then
        Result.Strings['sigla_mantenedora'] := 'UME';
    end;
  finally
    LQry.Free;
  end;
end;

class function TRedeFraternaControllers.ObterNomeCentro(AConn: TZConnection; ACentroId: Integer): string;
var
  LQry: TZQuery;
begin
  Result := 'Não informado';
  if ACentroId <= 0 then Exit;
  LQry := TZQuery.Create(nil);
  try
    LQry.Connection := AConn;
    LQry.SQL.Text := 'SELECT nome FROM centros_espiritas WHERE id = :id';
    LQry.ParamByName('id').AsInteger := ACentroId;
    LQry.Open;
    if not LQry.IsEmpty then
      Result := LQry.FieldByName('nome').AsString;
  finally
    LQry.Free;
  end;
end;

class function TRedeFraternaControllers.ObterCentroIdDoRegistro(AConn: TZConnection; const ATable: string; AId: Integer): Integer;
var
  LQry: TZQuery;
begin
  Result := 0;
  if AId <= 0 then Exit;
  LQry := TZQuery.Create(nil);
  try
    LQry.Connection := AConn;
    LQry.SQL.Text := Format('SELECT COALESCE(centro_id, 0) AS centro_id FROM %s WHERE id = :id', [ATable]);
    LQry.ParamByName('id').AsInteger := AId;
    LQry.Open;
    if not LQry.IsEmpty then
      Result := LQry.FieldByName('centro_id').AsInteger;
  finally
    LQry.Free;
  end;
end;

class function TRedeFraternaControllers.ObterCentroIdDaFamilia(AConn: TZConnection; AFamiliaId: Integer): Integer;
begin
  Result := ObterCentroIdDoRegistro(AConn, 'familias', AFamiliaId);
end;

class function TRedeFraternaControllers.ObterRegistroJSON(AConn: TZConnection; const ATable: string; AId: Integer): TJSONObject;
var
  LQry: TZQuery;
begin
  Result := nil;
  if AId <= 0 then Exit;
  LQry := TZQuery.Create(nil);
  try
    LQry.Connection := AConn;
    LQry.SQL.Text := Format('SELECT * FROM %s WHERE id = :id', [ATable]);
    LQry.ParamByName('id').AsInteger := AId;
    LQry.Open;
    if not LQry.IsEmpty then
      Result := LQry.ToJSONObject;
  finally
    LQry.Free;
  end;
end;

class function TRedeFraternaControllers.NormalizarCPF(const ACPF: string): string;
var
  I: Integer;
  LDigits: string;
begin
  LDigits := '';
  for I := 1 to Length(ACPF) do
    if ACPF[I] in ['0'..'9'] then
      LDigits := LDigits + ACPF[I];

  if LDigits = '' then
    Result := ''
  else if Length(LDigits) = 11 then
    Result := Format('%s.%s.%s-%s', [
      Copy(LDigits, 1, 3),
      Copy(LDigits, 4, 3),
      Copy(LDigits, 7, 3),
      Copy(LDigits, 10, 2)
    ])
  else
    Result := Trim(ACPF);
end;

class function TRedeFraternaControllers.ValidarCPFUnicoNoSistema(AConn: TZConnection;
  const ACPF: string; ACheckResponsavel: Boolean; AIgnorarFamiliaId, AIgnorarIntegranteId: Integer;
  out AErrorMessage: string): Boolean;
var
  LQry: TZQuery;
  LCPFNorm, LDigits: string;
  I: Integer;
begin
  Result := True;
  AErrorMessage := '';
  LCPFNorm := NormalizarCPF(ACPF);
  if LCPFNorm = '' then Exit;

  LDigits := '';
  for I := 1 to Length(LCPFNorm) do
    if LCPFNorm[I] in ['0'..'9'] then
      LDigits := LDigits + LCPFNorm[I];

  if Length(LDigits) <> 11 then
  begin
    Result := False;
    AErrorMessage := Format('O CPF informado (%s) é inválido. Informe os 11 dígitos do CPF.', [ACPF]);
    Exit;
  end;

  LQry := TZQuery.Create(nil);
  try
    LQry.Connection := AConn;

    // 1. Verifica se o CPF já consta como Responsável de alguma outra família
    LQry.SQL.Text :=
      'SELECT f.id, f.nome_referencia, COALESCE(c.nome, ''Centro não informado'') AS centro_nome ' +
      'FROM familias f ' +
      'LEFT JOIN centros_espiritas c ON c.id = f.centro_id ' +
      'WHERE f.id <> :ign_fam_id ' +
      '  AND (f.cpf_responsavel = :cpf_norm ' +
      '       OR REPLACE(REPLACE(COALESCE(f.cpf_responsavel, ''''), ''.'', ''''), ''-'', '''') = :cpf_dig)';
    LQry.ParamByName('ign_fam_id').AsInteger := AIgnorarFamiliaId;
    LQry.ParamByName('cpf_norm').AsString := LCPFNorm;
    LQry.ParamByName('cpf_dig').AsString := LDigits;
    LQry.Open;
    if not LQry.IsEmpty then
    begin
      Result := False;
      AErrorMessage := Format(
        'CPF já cadastrado! O CPF %s já consta como Responsável da família ''%s'', vinculada ao ''%s''. Uma família não pode ser cadastrada em mais de um centro espírita.',
        [LCPFNorm, LQry.FieldByName('nome_referencia').AsString, LQry.FieldByName('centro_nome').AsString]
      );
      Exit;
    end;
    LQry.Close;

    // 2. Verifica se o CPF já consta na tabela de integrantes (familia_integrantes)
    if ACheckResponsavel then
    begin
      // Se estamos validando o CPF do responsável da família, ele não pode ser integrante de OUTRA família
      LQry.SQL.Text :=
        'SELECT fi.id, fi.nome AS integrante_nome, f.nome_referencia, COALESCE(c.nome, ''Centro não informado'') AS centro_nome ' +
        'FROM familia_integrantes fi ' +
        'JOIN familias f ON f.id = fi.familia_id ' +
        'LEFT JOIN centros_espiritas c ON c.id = f.centro_id ' +
        'WHERE fi.familia_id <> :ign_fam_id ' +
        '  AND (fi.cpf = :cpf_norm ' +
        '       OR REPLACE(REPLACE(COALESCE(fi.cpf, ''''), ''.'', ''''), ''-'', '''') = :cpf_dig)';
      LQry.ParamByName('ign_fam_id').AsInteger := AIgnorarFamiliaId;
      LQry.ParamByName('cpf_norm').AsString := LCPFNorm;
      LQry.ParamByName('cpf_dig').AsString := LDigits;
    end
    else
    begin
      // Se estamos validando um integrante, o CPF é único em toda a tabela familia_integrantes
      LQry.SQL.Text :=
        'SELECT fi.id, fi.nome AS integrante_nome, f.nome_referencia, COALESCE(c.nome, ''Centro não informado'') AS centro_nome ' +
        'FROM familia_integrantes fi ' +
        'JOIN familias f ON f.id = fi.familia_id ' +
        'LEFT JOIN centros_espiritas c ON c.id = f.centro_id ' +
        'WHERE fi.id <> :ign_int_id ' +
        '  AND (fi.cpf = :cpf_norm ' +
        '       OR REPLACE(REPLACE(COALESCE(fi.cpf, ''''), ''.'', ''''), ''-'', '''') = :cpf_dig)';
      LQry.ParamByName('ign_int_id').AsInteger := AIgnorarIntegranteId;
      LQry.ParamByName('cpf_norm').AsString := LCPFNorm;
      LQry.ParamByName('cpf_dig').AsString := LDigits;
    end;

    LQry.Open;
    if not LQry.IsEmpty then
    begin
      Result := False;
      AErrorMessage := Format(
        'CPF já cadastrado! O CPF %s pertence ao integrante ''%s'' da família ''%s'', vinculada ao ''%s''. Uma família/pessoa não pode ser cadastrada em mais de um centro espírita.',
        [LCPFNorm, LQry.FieldByName('integrante_nome').AsString, LQry.FieldByName('nome_referencia').AsString, LQry.FieldByName('centro_nome').AsString]
      );
      Exit;
    end;
  finally
    LQry.Free;
  end;
end;

class procedure TRedeFraternaControllers.GravarLogFamilia(AConn: TZConnection;
  AFamiliaId, ACentroId, AUsuarioId: Integer; const AUsuarioNome, AAcao, AEntidade: string;
  AEntidadeId: Integer; const AResumo, ADadosAnteriores, ADadosNovos: string);
var
  LQry: TZQuery;
  LNextId: Int64;
  LUserId: Integer;
  LUserNome: string;
begin
  if (AConn = nil) or (not AConn.Connected) or (AFamiliaId <= 0) then Exit;

  LUserId := AUsuarioId;
  if (LUserId <= 0) and (GCurrentUser.UserId > 0) then
    LUserId := GCurrentUser.UserId;

  LUserNome := Trim(AUsuarioNome);
  if ((LUserNome = '') or SameText(LUserNome, 'Operador')) and (GCurrentUser.Username <> '') then
    LUserNome := GCurrentUser.Username;
  if LUserNome = '' then
    LUserNome := 'Sistema';

  LQry := TZQuery.Create(nil);
  try
    LQry.Connection := AConn;
    LNextId := GetNextIdIfPostgres(AConn);
    if LNextId > 0 then
    begin
      LQry.SQL.Text :=
        'INSERT INTO familia_logs (id, familia_id, centro_id, usuario_id, usuario_nome, acao, entidade, entidade_id, resumo_alteracao, dados_anteriores, dados_novos) ' +
        'VALUES (:id, :fam_id, :cen_id, :usr_id, :usr_nome, :acao, :ent, :ent_id, :resumo, :ant, :nov)';
      LQry.ParamByName('id').AsLargeInt := LNextId;
    end
    else
    begin
      LQry.SQL.Text :=
        'INSERT INTO familia_logs (familia_id, centro_id, usuario_id, usuario_nome, acao, entidade, entidade_id, resumo_alteracao, dados_anteriores, dados_novos) ' +
        'VALUES (:fam_id, :cen_id, :usr_id, :usr_nome, :acao, :ent, :ent_id, :resumo, :ant, :nov)';
    end;

    LQry.ParamByName('fam_id').AsInteger := AFamiliaId;
    if ACentroId > 0 then
      LQry.ParamByName('cen_id').AsInteger := ACentroId
    else
      LQry.ParamByName('cen_id').Clear;

    if LUserId > 0 then
      LQry.ParamByName('usr_id').AsInteger := LUserId
    else
      LQry.ParamByName('usr_id').Clear;

    LQry.ParamByName('usr_nome').AsString := LUserNome;
    LQry.ParamByName('acao').AsString := AAcao;
    LQry.ParamByName('ent').AsString := AEntidade;
    if AEntidadeId > 0 then
      LQry.ParamByName('ent_id').AsInteger := AEntidadeId
    else
      LQry.ParamByName('ent_id').Clear;

    LQry.ParamByName('resumo').AsString := AResumo;
    LQry.ParamByName('ant').AsString := ADadosAnteriores;
    LQry.ParamByName('nov').AsString := ADadosNovos;
    LQry.ExecSQL;
  except
    on E: Exception do
      WriteLog('Erro ao gravar log de família: ' + E.Message, ltErro);
  end;
  LQry.Free;
end;

{ Hooks de Usuários }

class procedure TRedeFraternaControllers.UsuariosBeforeCreate(Sender: TTWApiController;
  AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LSenha, LLogin, LTipo: string;
  LCentroId: Integer;
  LQry: TZQuery;
begin
  AAllow := True;
  if not GCurrentUser.IsAdmin then
  begin
    AAllow := False;
    AErrorMessage := 'Apenas o Administrador da UME pode cadastrar usuários.';
    Exit;
  end;

  LLogin := GetJSONStrDef(AJSONObject, 'login', '');
  if LLogin = '' then
  begin
    AAllow := False;
    AErrorMessage := 'O campo login é obrigatório.';
    Exit;
  end;

  // Verifica duplicidade de login
  LQry := TZQuery.Create(nil);
  try
    LQry.Connection := DBConn;
    LQry.SQL.Text := 'SELECT id FROM usuarios WHERE LOWER(login) = LOWER(:login)';
    LQry.ParamByName('login').AsString := LLogin;
    LQry.Open;
    if not LQry.IsEmpty then
    begin
      AAllow := False;
      AErrorMessage := 'Já existe um usuário cadastrado com este login.';
      Exit;
    end;
  finally
    LQry.Free;
  end;

  LTipo := UpperCase(GetJSONStrDef(AJSONObject, 'tipo', 'F'));
  if not ((LTipo = 'A') or (LTipo = 'O') or (LTipo = 'F')) then
    LTipo := 'F';
  AJSONObject.Strings['tipo'] := LTipo;

  LCentroId := GetJSONIntDef(AJSONObject, 'centro_id', 0);
  if LTipo <> 'A' then
  begin
    if LCentroId <= 0 then
    begin
      AAllow := False;
      AErrorMessage := 'Usuários que não são Administradores devem estar obrigatoriamente vinculados a um Centro Espírita.';
      Exit;
    end;
    AJSONObject.Integers['centro_id'] := LCentroId;
  end
  else
  begin
    if AJSONObject.Find('centro_id') <> nil then
      AJSONObject.Delete('centro_id');
  end;

  if AJSONObject.Find('senha') <> nil then
  begin
    LSenha := Trim(AJSONObject.Get('senha', ''));
    AJSONObject.Delete('senha');
    if LSenha <> '' then
      AJSONObject.Strings['senha_hash'] := SHA1Print(SHA1String(LSenha));
  end;

  if (AJSONObject.Find('senha_hash') = nil) or (Trim(AJSONObject.Get('senha_hash', '')) = '') then
    AJSONObject.Strings['senha_hash'] := SHA1Print(SHA1String('123456'));

  if AJSONObject.Find('ativo') = nil then
    AJSONObject.Strings['ativo'] := 'S';
end;

class procedure TRedeFraternaControllers.UsuariosBeforeUpdate(Sender: TTWApiController;
  const AId: string; AJSONObject: TJSONObject; var AAllow: Boolean;
  var AErrorMessage: string; var DBConn: TZConnection);
var
  LSenha, LTipo: string;
  LCentroId: Integer;
  LOldObj: TJSONObject;
begin
  AAllow := True;
  if not GCurrentUser.IsAdmin then
  begin
    AAllow := False;
    AErrorMessage := 'Apenas o Administrador da UME pode alterar o cadastro de usuários.';
    Exit;
  end;

  LOldObj := ObterRegistroJSON(DBConn, 'usuarios', StrToIntDef(AId, 0));
  try
    LTipo := UpperCase(GetJSONStrDef(AJSONObject, 'tipo', GetJSONStrDef(LOldObj, 'tipo', 'F')));
    if not ((LTipo = 'A') or (LTipo = 'O') or (LTipo = 'F')) then
      LTipo := 'F';
    AJSONObject.Strings['tipo'] := LTipo;

    LCentroId := GetJSONIntDef(AJSONObject, 'centro_id', GetJSONIntDef(LOldObj, 'centro_id', 0));
    if LTipo <> 'A' then
    begin
      if LCentroId <= 0 then
      begin
        AAllow := False;
        AErrorMessage := 'Usuários que não são Administradores devem estar obrigatoriamente vinculados a um Centro Espírita.';
        Exit;
      end;
      AJSONObject.Integers['centro_id'] := LCentroId;
    end
    else
    begin
      if AJSONObject.Find('centro_id') <> nil then
        AJSONObject.Delete('centro_id');
      AJSONObject.Add('centro_id', TJSONNull.Create);
    end;
  finally
    LOldObj.Free;
  end;

  if AJSONObject.Find('senha') <> nil then
  begin
    LSenha := Trim(AJSONObject.Get('senha', ''));
    AJSONObject.Delete('senha');
    if LSenha <> '' then
      AJSONObject.Strings['senha_hash'] := SHA1Print(SHA1String(LSenha));
  end;
end;

{ Hooks de Centros Espíritas }

class procedure TRedeFraternaControllers.CentrosBeforeCreate(Sender: TTWApiController;
  AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
begin
  AAllow := True;
  if not GCurrentUser.IsAdmin then
  begin
    AAllow := False;
    AErrorMessage := 'Acesso negado: apenas o Administrador da UME pode cadastrar novos Centros Espíritas.';
    Exit;
  end;
end;

class procedure TRedeFraternaControllers.CentrosBeforeUpdate(Sender: TTWApiController;
  const AId: string; AJSONObject: TJSONObject; var AAllow: Boolean;
  var AErrorMessage: string; var DBConn: TZConnection);
begin
  AAllow := True;
  if not GCurrentUser.IsAdmin then
  begin
    if GCurrentUser.UserType <> 'O' then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: seu perfil não possui permissão para alterar os dados cadastrais do Centro Espírita.';
      Exit;
    end;
    if StrToIntDef(AId, 0) <> GCurrentUser.CentroId then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: você só pode editar os dados do seu próprio Centro Espírita.';
      Exit;
    end;
  end;
end;

class procedure TRedeFraternaControllers.CentrosBeforeDelete(Sender: TTWApiController;
  const AId: string; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LQry: TZQuery;
begin
  AAllow := True;
  if not GCurrentUser.IsAdmin then
  begin
    AAllow := False;
    AErrorMessage := 'Acesso negado: apenas o Administrador da UME pode excluir Centros Espíritas.';
    Exit;
  end;

  LQry := TZQuery.Create(nil);
  try
    LQry.Connection := DBConn;
    LQry.SQL.Text := 'SELECT COUNT(*) FROM familias WHERE centro_id = :id AND ativo = ''S''';
    LQry.ParamByName('id').AsInteger := StrToIntDef(AId, 0);
    LQry.Open;
    if LQry.Fields[0].AsInteger > 0 then
    begin
      AAllow := False;
      AErrorMessage := 'Não é possível excluir este Centro Espírita pois existem famílias ativas vinculadas a ele.';
      Exit;
    end;
  finally
    LQry.Free;
  end;
end;

{ Hooks de Trabalhadores dos Centros Espíritas }

class procedure TRedeFraternaControllers.TrabalhadoresBeforeCreate(Sender: TTWApiController;
  AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LCentroId: Integer;
begin
  AAllow := True;
  if GCurrentUser.UserType = 'F' then
  begin
    AAllow := False;
    AErrorMessage := 'Acesso negado: Operadores da Família não possuem permissão para cadastrar trabalhadores.';
    Exit;
  end;

  LCentroId := GetJSONIntDef(AJSONObject, 'centro_id', 0);
  if not GCurrentUser.IsAdmin then
  begin
    if (LCentroId > 0) and (LCentroId <> GCurrentUser.CentroId) then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: você só pode cadastrar trabalhadores no seu próprio Centro Espírita.';
      Exit;
    end;
    LCentroId := GCurrentUser.CentroId;
    AJSONObject.Integers['centro_id'] := LCentroId;
  end;

  if LCentroId <= 0 then
  begin
    AAllow := False;
    AErrorMessage := 'Informe o Centro Espírita ao qual o trabalhador pertence.';
    Exit;
  end;

  if AJSONObject.Find('ativo') = nil then
    AJSONObject.Strings['ativo'] := 'S';
end;

class procedure TRedeFraternaControllers.TrabalhadoresBeforeUpdate(Sender: TTWApiController;
  const AId: string; AJSONObject: TJSONObject; var AAllow: Boolean;
  var AErrorMessage: string; var DBConn: TZConnection);
var
  LOldCentroId, LNewCentroId: Integer;
begin
  AAllow := True;
  if GCurrentUser.UserType = 'F' then
  begin
    AAllow := False;
    AErrorMessage := 'Acesso negado: Operadores da Família não possuem permissão para editar trabalhadores.';
    Exit;
  end;

  if not GCurrentUser.IsAdmin then
  begin
    LOldCentroId := ObterCentroIdDoRegistro(DBConn, 'trabalhadores', StrToIntDef(AId, 0));
    if LOldCentroId <> GCurrentUser.CentroId then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: este trabalhador pertence a outro Centro Espírita.';
      Exit;
    end;
    LNewCentroId := GetJSONIntDef(AJSONObject, 'centro_id', LOldCentroId);
    if LNewCentroId <> GCurrentUser.CentroId then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: você não pode transferir trabalhadores para outro Centro Espírita.';
      Exit;
    end;
    AJSONObject.Integers['centro_id'] := GCurrentUser.CentroId;
  end;
end;

class procedure TRedeFraternaControllers.TrabalhadoresBeforeDelete(Sender: TTWApiController;
  const AId: string; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LOldCentroId: Integer;
begin
  AAllow := True;
  if GCurrentUser.UserType = 'F' then
  begin
    AAllow := False;
    AErrorMessage := 'Acesso negado: Operadores da Família não possuem permissão para excluir trabalhadores.';
    Exit;
  end;

  if not GCurrentUser.IsAdmin then
  begin
    LOldCentroId := ObterCentroIdDoRegistro(DBConn, 'trabalhadores', StrToIntDef(AId, 0));
    if LOldCentroId <> GCurrentUser.CentroId then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: este trabalhador pertence a outro Centro Espírita.';
      Exit;
    end;
  end;
end;

{ Hooks de Agenda Semanal dos Centros Espíritas }

class procedure TRedeFraternaControllers.AgendaBeforeCreate(Sender: TTWApiController;
  AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LCentroId: Integer;
begin
  AAllow := True;
  if GCurrentUser.UserType = 'F' then
  begin
    AAllow := False;
    AErrorMessage := 'Acesso negado: Operadores da Família não possuem permissão para alterar a agenda semanal.';
    Exit;
  end;

  LCentroId := GetJSONIntDef(AJSONObject, 'centro_id', 0);
  if not GCurrentUser.IsAdmin then
  begin
    if (LCentroId > 0) and (LCentroId <> GCurrentUser.CentroId) then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: você só pode cadastrar atividades na agenda semanal do seu próprio Centro Espírita.';
      Exit;
    end;
    LCentroId := GCurrentUser.CentroId;
    AJSONObject.Integers['centro_id'] := LCentroId;
  end;

  if LCentroId <= 0 then
  begin
    AAllow := False;
    AErrorMessage := 'Informe o Centro Espírita da atividade na agenda semanal.';
    Exit;
  end;

  if AJSONObject.Find('ativo') = nil then
    AJSONObject.Strings['ativo'] := 'S';
end;

class procedure TRedeFraternaControllers.AgendaBeforeUpdate(Sender: TTWApiController;
  const AId: string; AJSONObject: TJSONObject; var AAllow: Boolean;
  var AErrorMessage: string; var DBConn: TZConnection);
var
  LOldCentroId, LNewCentroId: Integer;
begin
  AAllow := True;
  if GCurrentUser.UserType = 'F' then
  begin
    AAllow := False;
    AErrorMessage := 'Acesso negado: Operadores da Família não possuem permissão para alterar a agenda semanal.';
    Exit;
  end;

  if not GCurrentUser.IsAdmin then
  begin
    LOldCentroId := ObterCentroIdDoRegistro(DBConn, 'agenda_centro', StrToIntDef(AId, 0));
    if LOldCentroId <> GCurrentUser.CentroId then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: esta atividade da agenda pertence a outro Centro Espírita.';
      Exit;
    end;
    LNewCentroId := GetJSONIntDef(AJSONObject, 'centro_id', LOldCentroId);
    if LNewCentroId <> GCurrentUser.CentroId then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: você só pode gerenciar a agenda semanal do seu próprio Centro Espírita.';
      Exit;
    end;
    AJSONObject.Integers['centro_id'] := GCurrentUser.CentroId;
  end;
end;

class procedure TRedeFraternaControllers.AgendaBeforeDelete(Sender: TTWApiController;
  const AId: string; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LOldCentroId: Integer;
begin
  AAllow := True;
  if GCurrentUser.UserType = 'F' then
  begin
    AAllow := False;
    AErrorMessage := 'Acesso negado: Operadores da Família não possuem permissão para alterar a agenda semanal.';
    Exit;
  end;

  if not GCurrentUser.IsAdmin then
  begin
    LOldCentroId := ObterCentroIdDoRegistro(DBConn, 'agenda_centro', StrToIntDef(AId, 0));
    if LOldCentroId <> GCurrentUser.CentroId then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: esta atividade da agenda pertence a outro Centro Espírita.';
      Exit;
    end;
  end;
end;

{ Hooks de Famílias com Auditoria Completa }

class procedure TRedeFraternaControllers.FamiliasBeforeCreate(Sender: TTWApiController;
  AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LCentroId: Integer;
  LNomeRef, LCPFResp: string;
begin
  AAllow := True;
  LNomeRef := GetJSONStrDef(AJSONObject, 'nome_referencia', '');
  LCentroId := GetJSONIntDef(AJSONObject, 'centro_id', 0);
  LCPFResp := NormalizarCPF(GetJSONStrDef(AJSONObject, 'cpf_responsavel', ''));

  if LNomeRef = '' then
  begin
    AAllow := False;
    AErrorMessage := 'Informe o nome de referência da família.';
    Exit;
  end;

  if not GCurrentUser.IsAdmin then
  begin
    if (LCentroId > 0) and (LCentroId <> GCurrentUser.CentroId) then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: você só pode cadastrar famílias vinculadas ao seu próprio Centro Espírita.';
      Exit;
    end;
    LCentroId := GCurrentUser.CentroId;
    AJSONObject.Integers['centro_id'] := LCentroId;
  end;

  if LCentroId <= 0 then
  begin
    AAllow := False;
    AErrorMessage := 'A família deve estar obrigatoriamente vinculada a um Centro Espírita.';
    Exit;
  end;

  if LCPFResp = '' then
  begin
    AAllow := False;
    AErrorMessage := 'Informe o CPF do responsável pela família para evitar duplicidade entre Centros Espíritas.';
    Exit;
  end;

  if not ValidarCPFUnicoNoSistema(DBConn, LCPFResp, True, 0, 0, AErrorMessage) then
  begin
    AAllow := False;
    Exit;
  end;

  AJSONObject.Strings['cpf_responsavel'] := LCPFResp;

  if AJSONObject.Find('ativo') = nil then
    AJSONObject.Strings['ativo'] := 'S';
  if AJSONObject.Find('situacao') = nil then
    AJSONObject.Strings['situacao'] := 'ATIVA';
end;

class procedure TRedeFraternaControllers.FamiliasAfterCreate(Sender: TTWApiController;
  AJSONObject: TJSONObject; var DBConn: TZConnection);
var
  LFamId, LCentroId: Integer;
  LNomeRef, LCPFResp, LNomeCentro, LResumo: string;
begin
  LFamId := GetJSONIntDef(AJSONObject, 'id', 0);
  LCentroId := GetJSONIntDef(AJSONObject, 'centro_id', 0);
  LNomeRef := GetJSONStrDef(AJSONObject, 'nome_referencia', '');
  LCPFResp := GetJSONStrDef(AJSONObject, 'cpf_responsavel', '');
  LNomeCentro := ObterNomeCentro(DBConn, LCentroId);

  LResumo := Format('Família "%s" (CPF Resp: %s) cadastrada e vinculada ao centro "%s".',
    [LNomeRef, IfThen(LCPFResp <> '', LCPFResp, 'N/I'), LNomeCentro]);
  GravarLogFamilia(DBConn, LFamId, LCentroId, 0, 'Operador', 'CRIACAO', 'FAMILIA',
    LFamId, LResumo, '', AJSONObject.AsJSON);
end;

class procedure TRedeFraternaControllers.FamiliasBeforeUpdate(Sender: TTWApiController;
  const AId: string; AJSONObject: TJSONObject; var AAllow: Boolean;
  var AErrorMessage: string; var DBConn: TZConnection);
var
  LFamId, LOldCentroId, LNewCentroId: Integer;
  LOldObj: TJSONObject;
  LDiffList: TStringList;
  LResumo, LUsuarioLog: string;
  LOldNome, LNewNome, LOldCPF, LNewCPF, LOldEnd, LNewEnd, LOldSit, LNewSit, LOldObs, LNewObs, LOldTel, LNewTel: string;
begin
  AAllow := True;
  LFamId := StrToIntDef(AId, 0);
  if LFamId <= 0 then Exit;

  // Permite que o front-end envie opcionalmente _usuario_log para enriquecer a auditoria
  LUsuarioLog := GetJSONStrDef(AJSONObject, '_usuario_log', 'Operador');
  if AJSONObject.Find('_usuario_log') <> nil then
    AJSONObject.Delete('_usuario_log');

  LOldObj := ObterRegistroJSON(DBConn, 'familias', LFamId);
  if not Assigned(LOldObj) then Exit;

  LDiffList := TStringList.Create;
  try
    LOldCentroId := GetJSONIntDef(LOldObj, 'centro_id', 0);
    LNewCentroId := GetJSONIntDef(AJSONObject, 'centro_id', LOldCentroId);

    if not GCurrentUser.IsAdmin then
    begin
      if LOldCentroId <> GCurrentUser.CentroId then
      begin
        AAllow := False;
        AErrorMessage := 'Acesso negado: esta família está vinculada a outro Centro Espírita.';
        Exit;
      end;
      if (LNewCentroId > 0) and (LNewCentroId <> GCurrentUser.CentroId) then
      begin
        AAllow := False;
        AErrorMessage := 'Acesso negado: apenas o Administrador da UME pode transferir uma família para outro Centro Espírita.';
        Exit;
      end;
      LNewCentroId := GCurrentUser.CentroId;
      AJSONObject.Integers['centro_id'] := LNewCentroId;
    end;

    if AJSONObject.Find('cpf_responsavel') <> nil then
    begin
      LNewCPF := NormalizarCPF(GetJSONStrDef(AJSONObject, 'cpf_responsavel', ''));
      if LNewCPF = '' then
      begin
        AAllow := False;
        AErrorMessage := 'O CPF do responsável pela família é obrigatório.';
        Exit;
      end;
      if not ValidarCPFUnicoNoSistema(DBConn, LNewCPF, True, LFamId, 0, AErrorMessage) then
      begin
        AAllow := False;
        Exit;
      end;
      AJSONObject.Strings['cpf_responsavel'] := LNewCPF;
    end;

    if (LNewCentroId > 0) and (LNewCentroId <> LOldCentroId) then
      LDiffList.Add(Format('Vínculo de Centro Espírita alterado de "%s" para "%s"',
        [ObterNomeCentro(DBConn, LOldCentroId), ObterNomeCentro(DBConn, LNewCentroId)]));

    LOldNome := GetJSONStrDef(LOldObj, 'nome_referencia', '');
    LNewNome := GetJSONStrDef(AJSONObject, 'nome_referencia', LOldNome);
    if LNewNome <> LOldNome then
      LDiffList.Add(Format('Nome de referência alterado de "%s" para "%s"', [LOldNome, LNewNome]));

    LOldCPF := GetJSONStrDef(LOldObj, 'cpf_responsavel', '');
    LNewCPF := GetJSONStrDef(AJSONObject, 'cpf_responsavel', LOldCPF);
    if LNewCPF <> LOldCPF then
      LDiffList.Add(Format('CPF do Responsável alterado de "%s" para "%s"', [LOldCPF, LNewCPF]));

    LOldTel := GetJSONStrDef(LOldObj, 'telefone', '');
    LNewTel := GetJSONStrDef(AJSONObject, 'telefone', LOldTel);
    if LNewTel <> LOldTel then
      LDiffList.Add(Format('Telefone alterado de "%s" para "%s"', [LOldTel, LNewTel]));

    LOldEnd := Trim(GetJSONStrDef(LOldObj, 'logradouro', '') + ', ' + GetJSONStrDef(LOldObj, 'numero', '') + ' - ' + GetJSONStrDef(LOldObj, 'bairro', ''));
    LNewEnd := Trim(GetJSONStrDef(AJSONObject, 'logradouro', GetJSONStrDef(LOldObj, 'logradouro', '')) + ', ' +
                    GetJSONStrDef(AJSONObject, 'numero', GetJSONStrDef(LOldObj, 'numero', '')) + ' - ' +
                    GetJSONStrDef(AJSONObject, 'bairro', GetJSONStrDef(LOldObj, 'bairro', '')));
    if LNewEnd <> LOldEnd then
      LDiffList.Add(Format('Endereço atualizado (%s)', [LNewEnd]));

    LOldSit := GetJSONStrDef(LOldObj, 'situacao', 'ATIVA');
    LNewSit := GetJSONStrDef(AJSONObject, 'situacao', LOldSit);
    if LNewSit <> LOldSit then
      LDiffList.Add(Format('Situação alterada de "%s" para "%s"', [LOldSit, LNewSit]));

    LOldObs := GetJSONStrDef(LOldObj, 'observacoes', '');
    LNewObs := GetJSONStrDef(AJSONObject, 'observacoes', LOldObs);
    if LNewObs <> LOldObs then
      LDiffList.Add('Observações da família atualizadas');

    if LDiffList.Count = 0 then
      LResumo := 'Atualização cadastral dos dados da família "' + LNewNome + '".'
    else
      LResumo := StringReplace(Trim(LDiffList.Text), sLineBreak, ' | ', [rfReplaceAll]);

    if (LNewCentroId > 0) and (LNewCentroId <> LOldCentroId) then
      GravarLogFamilia(DBConn, LFamId, LNewCentroId, 0, LUsuarioLog, 'VINCULO_CENTRO', 'FAMILIA',
        LFamId, LResumo, LOldObj.AsJSON, AJSONObject.AsJSON)
    else
      GravarLogFamilia(DBConn, LFamId, LNewCentroId, 0, LUsuarioLog, 'ALTERACAO', 'FAMILIA',
        LFamId, LResumo, LOldObj.AsJSON, AJSONObject.AsJSON);
  finally
    LDiffList.Free;
    LOldObj.Free;
  end;
end;

class procedure TRedeFraternaControllers.FamiliasBeforeDelete(Sender: TTWApiController;
  const AId: string; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LFamId, LCentroId: Integer;
  LOldObj: TJSONObject;
  LNomeRef: string;
begin
  AAllow := True;
  if GCurrentUser.UserType = 'F' then
  begin
    AAllow := False;
    AErrorMessage := 'Acesso negado: Operadores da Família não possuem permissão para excluir famílias.';
    Exit;
  end;

  LFamId := StrToIntDef(AId, 0);
  LOldObj := ObterRegistroJSON(DBConn, 'familias', LFamId);
  if Assigned(LOldObj) then
  try
    LCentroId := GetJSONIntDef(LOldObj, 'centro_id', 0);
    if (not GCurrentUser.IsAdmin) and (LCentroId <> GCurrentUser.CentroId) then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: esta família está vinculada a outro Centro Espírita.';
      Exit;
    end;
    LNomeRef := GetJSONStrDef(LOldObj, 'nome_referencia', '');
    GravarLogFamilia(DBConn, LFamId, LCentroId, 0, 'Operador', 'EXCLUSAO', 'FAMILIA',
      LFamId, Format('Família "%s" inativada/excluída do sistema.', [LNomeRef]), LOldObj.AsJSON, '');
  finally
    LOldObj.Free;
  end;
end;

{ Hooks de Integrantes da Família com Auditoria na Família }

class procedure TRedeFraternaControllers.IntegrantesBeforeCreate(Sender: TTWApiController;
  AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LFamId, LFamCentroId: Integer;
  LCPF: string;
begin
  AAllow := True;
  LFamId := GetJSONIntDef(AJSONObject, 'familia_id', 0);
  if LFamId <= 0 then
  begin
    AAllow := False;
    AErrorMessage := 'O integrante deve estar vinculado a uma família.';
    Exit;
  end;

  if not GCurrentUser.IsAdmin then
  begin
    LFamCentroId := ObterCentroIdDaFamilia(DBConn, LFamId);
    if LFamCentroId <> GCurrentUser.CentroId then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: você só pode adicionar integrantes em famílias do seu próprio Centro Espírita.';
      Exit;
    end;
  end;

  if GetJSONStrDef(AJSONObject, 'nome', '') = '' then
  begin
    AAllow := False;
    AErrorMessage := 'Informe o nome do integrante da família.';
    Exit;
  end;

  LCPF := NormalizarCPF(GetJSONStrDef(AJSONObject, 'cpf', ''));
  if LCPF <> '' then
  begin
    if not ValidarCPFUnicoNoSistema(DBConn, LCPF, False, LFamId, 0, AErrorMessage) then
    begin
      AAllow := False;
      Exit;
    end;
    AJSONObject.Strings['cpf'] := LCPF;
  end
  else if AJSONObject.Find('cpf') <> nil then
    AJSONObject.Delete('cpf'); // Evita gravar string vazia ('') na coluna com índice UNIQUE

  if AJSONObject.Find('_usuario_log') <> nil then
    AJSONObject.Delete('_usuario_log');
  if AJSONObject.Find('ativo') = nil then
    AJSONObject.Strings['ativo'] := 'S';
end;

class procedure TRedeFraternaControllers.IntegrantesAfterCreate(Sender: TTWApiController;
  AJSONObject: TJSONObject; var DBConn: TZConnection);
var
  LIntId, LFamId: Integer;
  LNome, LPapel, LCPF, LResumo: string;
begin
  LIntId := GetJSONIntDef(AJSONObject, 'id', 0);
  LFamId := GetJSONIntDef(AJSONObject, 'familia_id', 0);
  LNome := GetJSONStrDef(AJSONObject, 'nome', '');
  LPapel := GetJSONStrDef(AJSONObject, 'papel_familia', '');
  LCPF := GetJSONStrDef(AJSONObject, 'cpf', '');

  LResumo := Format('Integrante adicionado: "%s" (Papel: %s%s)',
    [LNome, LPapel, IfThen(LCPF <> '', ', CPF: ' + LCPF, '')]);
  GravarLogFamilia(DBConn, LFamId, 0, 0, 'Operador', 'INTEGRANTE_ADD', 'INTEGRANTE',
    LIntId, LResumo, '', AJSONObject.AsJSON);
end;

class procedure TRedeFraternaControllers.IntegrantesBeforeUpdate(Sender: TTWApiController;
  const AId: string; AJSONObject: TJSONObject; var AAllow: Boolean;
  var AErrorMessage: string; var DBConn: TZConnection);
var
  LIntId, LFamId, LFamCentroId: Integer;
  LOldObj: TJSONObject;
  LNome, LPapel, LCPF, LUsuarioLog, LResumo: string;
begin
  AAllow := True;
  LIntId := StrToIntDef(AId, 0);
  LUsuarioLog := GetJSONStrDef(AJSONObject, '_usuario_log', 'Operador');
  if AJSONObject.Find('_usuario_log') <> nil then
    AJSONObject.Delete('_usuario_log');

  LOldObj := ObterRegistroJSON(DBConn, 'familia_integrantes', LIntId);
  if Assigned(LOldObj) then
  try
    LFamId := GetJSONIntDef(LOldObj, 'familia_id', GetJSONIntDef(AJSONObject, 'familia_id', 0));
    if not GCurrentUser.IsAdmin then
    begin
      LFamCentroId := ObterCentroIdDaFamilia(DBConn, LFamId);
      if LFamCentroId <> GCurrentUser.CentroId then
      begin
        AAllow := False;
        AErrorMessage := 'Acesso negado: este integrante pertence a uma família de outro Centro Espírita.';
        Exit;
      end;
    end;

    if AJSONObject.Find('cpf') <> nil then
    begin
      LCPF := NormalizarCPF(GetJSONStrDef(AJSONObject, 'cpf', ''));
      if LCPF <> '' then
      begin
        if not ValidarCPFUnicoNoSistema(DBConn, LCPF, False, LFamId, LIntId, AErrorMessage) then
        begin
          AAllow := False;
          Exit;
        end;
        AJSONObject.Strings['cpf'] := LCPF;
      end
      else
      begin
        AJSONObject.Delete('cpf');
        AJSONObject.Add('cpf', TJSONNull.Create);
      end;
    end;

    LNome := GetJSONStrDef(AJSONObject, 'nome', GetJSONStrDef(LOldObj, 'nome', ''));
    LPapel := GetJSONStrDef(AJSONObject, 'papel_familia', GetJSONStrDef(LOldObj, 'papel_familia', ''));
    LResumo := Format('Dados do integrante "%s" (%s) alterados.', [LNome, LPapel]);
    GravarLogFamilia(DBConn, LFamId, 0, 0, LUsuarioLog, 'INTEGRANTE_EDIT', 'INTEGRANTE',
      LIntId, LResumo, LOldObj.AsJSON, AJSONObject.AsJSON);
  finally
    LOldObj.Free;
  end;
end;

class procedure TRedeFraternaControllers.IntegrantesBeforeDelete(Sender: TTWApiController;
  const AId: string; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LIntId, LFamId, LFamCentroId: Integer;
  LOldObj: TJSONObject;
  LNome, LPapel: string;
begin
  AAllow := True;
  LIntId := StrToIntDef(AId, 0);
  LOldObj := ObterRegistroJSON(DBConn, 'familia_integrantes', LIntId);
  if Assigned(LOldObj) then
  try
    LFamId := GetJSONIntDef(LOldObj, 'familia_id', 0);
    if not GCurrentUser.IsAdmin then
    begin
      LFamCentroId := ObterCentroIdDaFamilia(DBConn, LFamId);
      if LFamCentroId <> GCurrentUser.CentroId then
      begin
        AAllow := False;
        AErrorMessage := 'Acesso negado: este integrante pertence a uma família de outro Centro Espírita.';
        Exit;
      end;
    end;
    LNome := GetJSONStrDef(LOldObj, 'nome', '');
    LPapel := GetJSONStrDef(LOldObj, 'papel_familia', '');
    GravarLogFamilia(DBConn, LFamId, 0, 0, 'Operador', 'INTEGRANTE_DEL', 'INTEGRANTE',
      LIntId, Format('Integrante removido da família: "%s" (%s).', [LNome, LPapel]),
      LOldObj.AsJSON, '');
  finally
    LOldObj.Free;
  end;
end;

{ Hooks de Histórico de Auxílios Prestados à Família }

class procedure TRedeFraternaControllers.AuxiliosBeforeCreate(Sender: TTWApiController;
  AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LFamId, LFamCentroId, LCentroId: Integer;
begin
  AAllow := True;
  LFamId := GetJSONIntDef(AJSONObject, 'familia_id', 0);
  if LFamId <= 0 then
  begin
    AAllow := False;
    AErrorMessage := 'Selecione a família que recebeu o auxílio.';
    Exit;
  end;

  if GetJSONStrDef(AJSONObject, 'descricao', '') = '' then
  begin
    AAllow := False;
    AErrorMessage := 'Descreva o auxílio prestado à família.';
    Exit;
  end;

  LFamCentroId := ObterCentroIdDaFamilia(DBConn, LFamId);
  if not GCurrentUser.IsAdmin then
  begin
    if LFamCentroId <> GCurrentUser.CentroId then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: você só pode registrar auxílios para famílias do seu próprio Centro Espírita.';
      Exit;
    end;
    AJSONObject.Integers['centro_id'] := GCurrentUser.CentroId;
  end
  else
  begin
    LCentroId := GetJSONIntDef(AJSONObject, 'centro_id', 0);
    if (LCentroId <= 0) and (LFamCentroId > 0) then
      AJSONObject.Integers['centro_id'] := LFamCentroId;
  end;

  if GetJSONStrDef(AJSONObject, 'data_auxilio', '') = '' then
    AJSONObject.Strings['data_auxilio'] := FormatDateTime('yyyy-mm-dd', Date);
end;

class procedure TRedeFraternaControllers.AuxiliosAfterCreate(Sender: TTWApiController;
  AJSONObject: TJSONObject; var DBConn: TZConnection);
var
  LAuxId, LFamId, LCentroId: Integer;
  LTipo, LDesc, LData, LResumo: string;
begin
  LAuxId := GetJSONIntDef(AJSONObject, 'id', 0);
  LFamId := GetJSONIntDef(AJSONObject, 'familia_id', 0);
  LCentroId := GetJSONIntDef(AJSONObject, 'centro_id', 0);
  LTipo := GetJSONStrDef(AJSONObject, 'tipo_auxilio', '');
  LDesc := GetJSONStrDef(AJSONObject, 'descricao', '');
  LData := GetJSONStrDef(AJSONObject, 'data_auxilio', '');

  LResumo := Format('Auxílio registrado [%s] em %s: %s', [LTipo, LData, LDesc]);
  GravarLogFamilia(DBConn, LFamId, LCentroId, 0,
    GetJSONStrDef(AJSONObject, 'usuario_nome', 'Operador'),
    'AUXILIO_REGISTRADO', 'AUXILIO', LAuxId, LResumo, '', AJSONObject.AsJSON);
end;

class procedure TRedeFraternaControllers.AuxiliosBeforeUpdate(Sender: TTWApiController;
  const AId: string; AJSONObject: TJSONObject; var AAllow: Boolean;
  var AErrorMessage: string; var DBConn: TZConnection);
var
  LAuxId, LFamId, LCentroId: Integer;
  LOldObj: TJSONObject;
begin
  AAllow := True;
  LAuxId := StrToIntDef(AId, 0);
  LOldObj := ObterRegistroJSON(DBConn, 'familia_auxilios', LAuxId);
  if Assigned(LOldObj) then
  try
    LFamId := GetJSONIntDef(LOldObj, 'familia_id', 0);
    LCentroId := GetJSONIntDef(LOldObj, 'centro_id', 0);
    if not GCurrentUser.IsAdmin then
    begin
      if LCentroId <> GCurrentUser.CentroId then
      begin
        AAllow := False;
        AErrorMessage := 'Acesso negado: este registro de auxílio pertence a outro Centro Espírita.';
        Exit;
      end;
      AJSONObject.Integers['centro_id'] := GCurrentUser.CentroId;
    end;
    GravarLogFamilia(DBConn, LFamId, LCentroId, 0, 'Operador', 'AUXILIO_EDITADO', 'AUXILIO',
      LAuxId, 'Registro de auxílio atualizado: ' + GetJSONStrDef(AJSONObject, 'descricao', GetJSONStrDef(LOldObj, 'descricao', '')),
      LOldObj.AsJSON, AJSONObject.AsJSON);
  finally
    LOldObj.Free;
  end;
end;

class procedure TRedeFraternaControllers.AuxiliosBeforeDelete(Sender: TTWApiController;
  const AId: string; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LAuxId, LFamId, LCentroId: Integer;
  LOldObj: TJSONObject;
begin
  AAllow := True;
  if GCurrentUser.UserType = 'F' then
  begin
    AAllow := False;
    AErrorMessage := 'Acesso negado: Operadores da Família não possuem permissão para excluir registros de auxílio.';
    Exit;
  end;

  LAuxId := StrToIntDef(AId, 0);
  LOldObj := ObterRegistroJSON(DBConn, 'familia_auxilios', LAuxId);
  if Assigned(LOldObj) then
  try
    LFamId := GetJSONIntDef(LOldObj, 'familia_id', 0);
    LCentroId := GetJSONIntDef(LOldObj, 'centro_id', 0);
    if (not GCurrentUser.IsAdmin) and (LCentroId <> GCurrentUser.CentroId) then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: este registro de auxílio pertence a outro Centro Espírita.';
      Exit;
    end;
    GravarLogFamilia(DBConn, LFamId, LCentroId, 0, 'Operador', 'AUXILIO_EXCLUIDO', 'AUXILIO',
      LAuxId, 'Registro de auxílio excluído: ' + GetJSONStrDef(LOldObj, 'descricao', ''),
      LOldObj.AsJSON, '');
  finally
    LOldObj.Free;
  end;
end;

{ Hooks de Notícias }

class procedure TRedeFraternaControllers.NoticiasBeforeCreate(Sender: TTWApiController;
  AJSONObject: TJSONObject; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LCentroId: Integer;
begin
  AAllow := True;
  if GCurrentUser.UserType = 'F' then
  begin
    AAllow := False;
    AErrorMessage := 'Acesso negado: Operadores da Família não possuem permissão para publicar notícias.';
    Exit;
  end;

  LCentroId := GetJSONIntDef(AJSONObject, 'centro_id', 0);
  if not GCurrentUser.IsAdmin then
  begin
    if (LCentroId > 0) and (LCentroId <> GCurrentUser.CentroId) then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: você só pode publicar notícias em nome do seu próprio Centro Espírita.';
      Exit;
    end;
    AJSONObject.Integers['centro_id'] := GCurrentUser.CentroId;
  end;

  if GetJSONStrDef(AJSONObject, 'titulo', '') = '' then
  begin
    AAllow := False;
    AErrorMessage := 'Informe o título da notícia.';
    Exit;
  end;

  if GetJSONStrDef(AJSONObject, 'conteudo', '') = '' then
  begin
    AAllow := False;
    AErrorMessage := 'Informe o conteúdo da notícia.';
    Exit;
  end;

  if GetJSONStrDef(AJSONObject, 'categoria', '') = '' then
    AJSONObject.Strings['categoria'] := 'COMUNICADO';

  if GetJSONStrDef(AJSONObject, 'destaque', '') = '' then
    AJSONObject.Strings['destaque'] := 'N';

  if GetJSONStrDef(AJSONObject, 'publicado', '') = '' then
    AJSONObject.Strings['publicado'] := 'S';

  if GetJSONStrDef(AJSONObject, 'data_publicacao', '') = '' then
    AJSONObject.Strings['data_publicacao'] := FormatDateTime('yyyy-mm-dd', Date);

  if AJSONObject.Find('ativo') = nil then
    AJSONObject.Strings['ativo'] := 'S';
end;

class procedure TRedeFraternaControllers.NoticiasBeforeUpdate(Sender: TTWApiController;
  const AId: string; AJSONObject: TJSONObject; var AAllow: Boolean;
  var AErrorMessage: string; var DBConn: TZConnection);
var
  LOldCentroId, LNewCentroId: Integer;
begin
  AAllow := True;
  if GCurrentUser.UserType = 'F' then
  begin
    AAllow := False;
    AErrorMessage := 'Acesso negado: Operadores da Família não possuem permissão para alterar notícias.';
    Exit;
  end;

  if not GCurrentUser.IsAdmin then
  begin
    LOldCentroId := ObterCentroIdDoRegistro(DBConn, 'noticias', StrToIntDef(AId, 0));
    if LOldCentroId <> GCurrentUser.CentroId then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: esta notícia pertence à UME ou a outro Centro Espírita.';
      Exit;
    end;
    LNewCentroId := GetJSONIntDef(AJSONObject, 'centro_id', LOldCentroId);
    if LNewCentroId <> GCurrentUser.CentroId then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: você só pode vincular notícias ao seu próprio Centro Espírita.';
      Exit;
    end;
    AJSONObject.Integers['centro_id'] := GCurrentUser.CentroId;
  end;
end;

class procedure TRedeFraternaControllers.NoticiasBeforeDelete(Sender: TTWApiController;
  const AId: string; var AAllow: Boolean; var AErrorMessage: string;
  var DBConn: TZConnection);
var
  LOldCentroId: Integer;
begin
  AAllow := True;
  if GCurrentUser.UserType = 'F' then
  begin
    AAllow := False;
    AErrorMessage := 'Acesso negado: Operadores da Família não possuem permissão para excluir notícias.';
    Exit;
  end;

  if not GCurrentUser.IsAdmin then
  begin
    LOldCentroId := ObterCentroIdDoRegistro(DBConn, 'noticias', StrToIntDef(AId, 0));
    if LOldCentroId <> GCurrentUser.CentroId then
    begin
      AAllow := False;
      AErrorMessage := 'Acesso negado: esta notícia pertence à UME ou a outro Centro Espírita.';
      Exit;
    end;
  end;
end;

{ Autenticação TWAPI }

class function TRedeFraternaControllers.OnAuthenticate(const AUser: string;
  const APass: string; const ATenantAlias: string; const AIdSistem: Integer;
  out ADataBase: string; out AUserId: Integer; out AErrorMsg: string;
  out ATipoUser: string; out ALogoBase64: string): Boolean;
var
  LMasterConn, LTenantConn: TZConnection;
  LQryMaster, LQryTenant: TZQuery;
  LSenhaHash, LMasterDB, LTenantDB: string;
  LTmpl: TZConnection;
begin
  Result := False;
  AUserId := 0;
  AErrorMsg := '';
  ATipoUser := 'F';
  ALogoBase64 := '';
  ADataBase := '';

  try
    LTmpl := TZeosConnectionPool.GetTampleteConnection;
    if SameText(LTmpl.Protocol, 'sqlite') then
      LMasterDB := ExtractFileName(LTmpl.Database)
    else
      LMasterDB := LTmpl.Database;

    if Trim(LMasterDB) = '' then
      LMasterDB := 'masterdb.db';

    LMasterConn := TZeosConnectionPool.GetInstance.Acquire(LMasterDB);
    try
      TRedeFraternaSchema.EnsureMasterSchema(LMasterConn);

      LQryMaster := TZQuery.Create(nil);
      try
        LQryMaster.Connection := LMasterConn;
        LQryMaster.SQL.Text :=
          'SELECT tenant_dbname, tenant_dt_limite FROM tb_sistema ' +
          'WHERE UPPER(tenant_alias) = UPPER(:alias) ' +
          '  AND sistema = :sistema ' +
          '  AND tenant_dt_limite >= :hoje';
        LQryMaster.ParamByName('alias').AsString := Trim(ATenantAlias);
        LQryMaster.ParamByName('sistema').AsInteger := AIdSistem;
        LQryMaster.ParamByName('hoje').AsString := FormatDateTime('yyyy-mm-dd', Date);
        LQryMaster.Open;

        if LQryMaster.IsEmpty then
        begin
          AErrorMsg := 'Unidade / Tenant não encontrado no MasterDB.';
          Exit(False);
        end;

        LTenantDB := Trim(LQryMaster.FieldByName('tenant_dbname').AsString);
        if LTenantDB = '' then
        begin
          AErrorMsg := 'Banco de dados do cliente não configurado.';
          Exit(False);
        end;
      finally
        LQryMaster.Free;
      end;
    finally
      TZeosConnectionPool.GetInstance.Release(LMasterConn);
    end;

    if SameText(LTmpl.Protocol, 'sqlite') then
      ADataBase := ExtractFileName(LTenantDB)
    else
      ADataBase := LTenantDB;

    LTenantConn := TZeosConnectionPool.GetInstance.Acquire(ADataBase);
    try
      TRedeFraternaSchema.EnsureTenantSchema(LTenantConn);

      LSenhaHash := SHA1Print(SHA1String(APass));

      LQryTenant := TZQuery.Create(nil);
      try
        LQryTenant.Connection := LTenantConn;
        LQryTenant.SQL.Text := SQLSelectFrom('usuarios', LTenantConn.Protocol)
          .Fields(['id', 'nome', 'senha_hash', 'tipo', 'ativo', 'centro_id'])
          .WhereEqualParam('login', 'login')
          .Build;
        LQryTenant.ParamByName('login').AsString := Trim(AUser);
        LQryTenant.Open;

        if LQryTenant.IsEmpty then
        begin
          AErrorMsg := 'Usuário não encontrado.';
          Exit(False);
        end;

        if not SameText(LQryTenant.FieldByName('ativo').AsString, 'S') then
        begin
          AErrorMsg := 'Usuário inativo no sistema.';
          Exit(False);
        end;

        if (not SameText(LQryTenant.FieldByName('senha_hash').AsString, LSenhaHash)) and
           (LQryTenant.FieldByName('senha_hash').AsString <> APass) then
        begin
          AErrorMsg := 'Senha incorreta.';
          Exit(False);
        end;

        AUserId := LQryTenant.FieldByName('id').AsInteger;
        ATipoUser := UpperCase(Trim(LQryTenant.FieldByName('tipo').AsString));
        if not ((ATipoUser = 'A') or (ATipoUser = 'O') or (ATipoUser = 'F')) then
          ATipoUser := 'F';

        if (ATipoUser <> 'A') and (LQryTenant.FieldByName('centro_id').AsInteger <= 0) then
        begin
          AErrorMsg := 'Este usuário não está vinculado a nenhum Centro Espírita. Solicite ao Administrador da UME a vinculação do seu cadastro.';
          Exit(False);
        end;

        Result := True;
      finally
        LQryTenant.Free;
      end;
    finally
      TZeosConnectionPool.GetInstance.Release(LTenantConn);
    end;
  except
    on E: Exception do
    begin
      AErrorMsg := 'Erro ao autenticar: ' + E.Message;
      Result := False;
    end;
  end;
end;

{ Endpoints Customizados }

class procedure TRedeFraternaControllers.HandleGetMeuPerfil(Req: THorseRequest; Res: THorseResponse);
var
  LTokenData: TTokenData;
  LConn: TZConnection;
  LQry: TZQuery;
  LResp: TJSONObject;
begin
  LTokenData := ValidateToken(GetTokenByReq(Req));
  if (not LTokenData.IsValid) or (LTokenData.UserId <= 0) then
  begin
    Res.Status(401).Send('{"error": "Sessão inválida ou expirada."}').ContentType(CONTENT_TYPE_JSON);
    Exit;
  end;

  LConn := TZeosConnectionPool.GetInstance.Acquire(LTokenData.Database);
  try
    LQry := TZQuery.Create(nil);
    try
      LQry.Connection := LConn;
      LQry.SQL.Text :=
        'SELECT u.id, u.login, u.nome, u.tipo, COALESCE(u.centro_id, 0) AS centro_id, ' +
        '       COALESCE(c.nome, '''') AS centro_nome, COALESCE(c.sigla, '''') AS centro_sigla ' +
        'FROM usuarios u ' +
        'LEFT JOIN centros_espiritas c ON c.id = u.centro_id ' +
        'WHERE u.id = :id';
      LQry.ParamByName('id').AsInteger := LTokenData.UserId;
      LQry.Open;

      if LQry.IsEmpty then
      begin
        Res.Status(404).Send('{"error": "Usuário não encontrado."}').ContentType(CONTENT_TYPE_JSON);
        Exit;
      end;

      LResp := LQry.ToJSONObject;
      try
        LResp.Add('entidade', ObterConfiguracaoEntidadeJSON(LConn));
        Res.Send(LResp.AsJSON).ContentType(CONTENT_TYPE_JSON);
      finally
        LResp.Free;
      end;
    finally
      LQry.Free;
    end;
  finally
    TZeosConnectionPool.GetInstance.Release(LConn);
  end;
end;

class procedure TRedeFraternaControllers.HandleGetConfiguracoes(Req: THorseRequest; Res: THorseResponse);
var
  LTokenData: TTokenData;
  LConn: TZConnection;
  LResp: TJSONObject;
begin
  LTokenData := ValidateToken(GetTokenByReq(Req));
  if not LTokenData.IsValid then
  begin
    Res.Status(401).Send('{"error": "Sessão inválida ou expirada."}').ContentType(CONTENT_TYPE_JSON);
    Exit;
  end;

  LConn := TZeosConnectionPool.GetInstance.Acquire(LTokenData.Database);
  try
    TRedeFraternaSchema.EnsureTenantSchema(LConn);
    LResp := ObterConfiguracaoEntidadeJSON(LConn);
    try
      Res.Send(LResp.AsJSON).ContentType(CONTENT_TYPE_JSON);
    finally
      LResp.Free;
    end;
  finally
    TZeosConnectionPool.GetInstance.Release(LConn);
  end;
end;

class procedure TRedeFraternaControllers.HandlePutConfiguracoes(Req: THorseRequest; Res: THorseResponse);
var
  LTokenData: TTokenData;
  LConn, LMasterConn, LTmpl: TZConnection;
  LQry: TZQuery;
  LBody, LResp: TJSONObject;
  LParser: TJSONParser;
  LNome, LSigla, LSubtitulo, LCNPJ, LCidade, LUF, LTelefone, LEmail, LEndereco, LConfFile, LMasterDB: string;
  LIni: TIniFile;
begin
  LTokenData := ValidateToken(GetTokenByReq(Req));
  if not LTokenData.IsValid then
  begin
    Res.Status(401).Send('{"error": "Sessão inválida ou expirada."}').ContentType(CONTENT_TYPE_JSON);
    Exit;
  end;

  if not GCurrentUser.IsAdmin then
  begin
    Res.Status(403).Send('{"error": "Acesso negado: apenas o Administrador pode alterar as configurações da Entidade Mantenedora."}').ContentType(CONTENT_TYPE_JSON);
    Exit;
  end;

  LBody := nil;
  try
    LParser := TJSONParser.Create(Req.Body);
    try
      LBody := LParser.Parse as TJSONObject;
    finally
      LParser.Free;
    end;
  except
    LBody := nil;
  end;

  if LBody = nil then
  begin
    Res.Status(400).Send('{"error": "JSON inválido."}').ContentType(CONTENT_TYPE_JSON);
    Exit;
  end;

  try
    LNome := Trim(GetJSONStrDef(LBody, 'nome_mantenedora', ''));
    LSigla := Trim(GetJSONStrDef(LBody, 'sigla_mantenedora', ''));
    LSubtitulo := Trim(GetJSONStrDef(LBody, 'subtitulo_sistema', 'Gestão Integrada de Centros Espíritas e Assistência Social'));
    LCNPJ := Trim(GetJSONStrDef(LBody, 'cnpj_mantenedora', ''));
    LCidade := Trim(GetJSONStrDef(LBody, 'cidade_mantenedora', ''));
    LUF := UpperCase(Trim(GetJSONStrDef(LBody, 'uf_mantenedora', '')));
    LTelefone := Trim(GetJSONStrDef(LBody, 'telefone_mantenedora', ''));
    LEmail := Trim(GetJSONStrDef(LBody, 'email_mantenedora', ''));
    LEndereco := Trim(GetJSONStrDef(LBody, 'endereco_mantenedora', ''));

    if LNome = '' then
    begin
      Res.Status(400).Send('{"error": "Informe o nome da Entidade Mantenedora (ex: UME - Cachoeira do Sul, AES - Santa Cruz)."}').ContentType(CONTENT_TYPE_JSON);
      Exit;
    end;

    if LSigla = '' then
      LSigla := 'UME';

    LConn := TZeosConnectionPool.GetInstance.Acquire(LTokenData.Database);
    try
      TRedeFraternaSchema.EnsureTenantSchema(LConn);
      LQry := TZQuery.Create(nil);
      try
        LQry.Connection := LConn;
        LQry.SQL.Text := 'SELECT COUNT(*) FROM configuracoes';
        LQry.Open;
        if LQry.Fields[0].AsInteger = 0 then
        begin
          LQry.Close;
          LQry.SQL.Text :=
            'INSERT INTO configuracoes (nome_mantenedora, sigla_mantenedora, subtitulo_sistema, ' +
            'cnpj_mantenedora, cidade_mantenedora, uf_mantenedora, telefone_mantenedora, email_mantenedora, endereco_mantenedora) ' +
            'VALUES (:nome, :sigla, :sub, :cnpj, :cidade, :uf, :fone, :email, :end)';
        end
        else
        begin
          LQry.Close;
          LQry.SQL.Text :=
            'UPDATE configuracoes SET ' +
            '  nome_mantenedora = :nome, ' +
            '  sigla_mantenedora = :sigla, ' +
            '  subtitulo_sistema = :sub, ' +
            '  cnpj_mantenedora = :cnpj, ' +
            '  cidade_mantenedora = :cidade, ' +
            '  uf_mantenedora = :uf, ' +
            '  telefone_mantenedora = :fone, ' +
            '  email_mantenedora = :email, ' +
            '  endereco_mantenedora = :end';
        end;
        LQry.ParamByName('nome').AsString := LNome;
        LQry.ParamByName('sigla').AsString := LSigla;
        LQry.ParamByName('sub').AsString := LSubtitulo;
        LQry.ParamByName('cnpj').AsString := LCNPJ;
        LQry.ParamByName('cidade').AsString := LCidade;
        LQry.ParamByName('uf').AsString := LUF;
        LQry.ParamByName('fone').AsString := LTelefone;
        LQry.ParamByName('email').AsString := LEmail;
        LQry.ParamByName('end').AsString := LEndereco;
        LQry.ExecSQL;
      finally
        LQry.Free;
      end;

      // Sincroniza também no arquivo .conf local para novos tenants/seeds
      try
        LConfFile := ChangeFileExt(ParamStr(0), '.conf');
        LIni := TIniFile.Create(LConfFile);
        try
          LIni.WriteString('Entidade', 'NomeMantenedora', LNome);
          LIni.WriteString('Entidade', 'SiglaMantenedora', LSigla);
          LIni.WriteString('Entidade', 'CidadeMantenedora', LCidade);
          LIni.WriteString('Entidade', 'UFMantenedora', LUF);
          LIni.UpdateFile;
        finally
          LIni.Free;
        end;
      except
      end;

      // Atualiza também o nome do tenant no MasterDB para manter consistência
      try
        LTmpl := TZeosConnectionPool.GetTampleteConnection;
        if SameText(LTmpl.Protocol, 'sqlite') then
          LMasterDB := ExtractFileName(LTmpl.Database)
        else
          LMasterDB := LTmpl.Database;
        if Trim(LMasterDB) = '' then
          LMasterDB := 'masterdb.db';

        LMasterConn := TZeosConnectionPool.GetInstance.Acquire(LMasterDB);
        try
          LQry := TZQuery.Create(nil);
          try
            LQry.Connection := LMasterConn;
            LQry.SQL.Text := 'UPDATE tb_sistema SET tenant_name = :nome WHERE tenant_dbname = :db';
            LQry.ParamByName('nome').AsString := Copy(LNome, 1, 60);
            LQry.ParamByName('db').AsString := LTokenData.Database;
            LQry.ExecSQL;
          finally
            LQry.Free;
          end;
        finally
          TZeosConnectionPool.GetInstance.Release(LMasterConn);
        end;
      except
      end;

      LResp := ObterConfiguracaoEntidadeJSON(LConn);
      try
        Res.Send(LResp.AsJSON).ContentType(CONTENT_TYPE_JSON);
      finally
        LResp.Free;
      end;
    finally
      TZeosConnectionPool.GetInstance.Release(LConn);
    end;
  finally
    LBody.Free;
  end;
end;

class procedure TRedeFraternaControllers.HandleGetEntidadePublica(Req: THorseRequest; Res: THorseResponse);
var
  LTenantConn: TZConnection;
  LTenantDB: string;
  LResp: TJSONObject;
begin
  LTenantDB := ResolveTenantDBName(Req.Query['tenant']);
  LTenantConn := TZeosConnectionPool.GetInstance.Acquire(LTenantDB);
  try
    TRedeFraternaSchema.EnsureTenantSchema(LTenantConn);
    LResp := ObterConfiguracaoEntidadeJSON(LTenantConn);
    try
      Res.Send(LResp.AsJSON).ContentType(CONTENT_TYPE_JSON);
    finally
      LResp.Free;
    end;
  finally
    TZeosConnectionPool.GetInstance.Release(LTenantConn);
  end;
end;

class procedure TRedeFraternaControllers.HandlePostAlterarMinhaSenha(Req: THorseRequest; Res: THorseResponse);
var
  LTokenData: TTokenData;
  LConn: TZConnection;
  LQry: TZQuery;
  LBody: TJSONObject;
  LParser: TJSONParser;
  LSenhaAtual, LNovaSenha, LConfirmaSenha, LHashAtual, LNovoHash: string;
begin
  LTokenData := ValidateToken(GetTokenByReq(Req));
  if (not LTokenData.IsValid) or (LTokenData.UserId <= 0) then
  begin
    Res.Status(401).Send('{"error": "Sessão inválida ou expirada."}').ContentType(CONTENT_TYPE_JSON);
    Exit;
  end;

  LBody := nil;
  try
    LParser := TJSONParser.Create(Req.Body);
    try
      LBody := LParser.Parse as TJSONObject;
    finally
      LParser.Free;
    end;
  except
    LBody := nil;
  end;

  if LBody = nil then
  begin
    Res.Status(400).Send('{"error": "JSON inválido."}').ContentType(CONTENT_TYPE_JSON);
    Exit;
  end;

  try
    LSenhaAtual := Trim(LBody.Get('senha_atual', ''));
    LNovaSenha := Trim(LBody.Get('nova_senha', ''));
    LConfirmaSenha := Trim(LBody.Get('confirma_senha', ''));

    if LSenhaAtual = '' then
    begin
      Res.Status(400).Send('{"error": "Informe a senha atual."}').ContentType(CONTENT_TYPE_JSON);
      Exit;
    end;
    if Length(LNovaSenha) < 4 then
    begin
      Res.Status(400).Send('{"error": "A nova senha deve ter pelo menos 4 caracteres."}').ContentType(CONTENT_TYPE_JSON);
      Exit;
    end;
    if LNovaSenha <> LConfirmaSenha then
    begin
      Res.Status(400).Send('{"error": "A confirmação da nova senha não confere."}').ContentType(CONTENT_TYPE_JSON);
      Exit;
    end;

    LConn := TZeosConnectionPool.GetInstance.Acquire(LTokenData.Database);
    try
      LQry := TZQuery.Create(nil);
      try
        LQry.Connection := LConn;
        LQry.SQL.Text := 'SELECT id, senha_hash FROM usuarios WHERE id = :id';
        LQry.ParamByName('id').AsInteger := LTokenData.UserId;
        LQry.Open;

        if LQry.IsEmpty then
        begin
          Res.Status(404).Send('{"error": "Usuário não encontrado."}').ContentType(CONTENT_TYPE_JSON);
          Exit;
        end;

        LHashAtual := SHA1Print(SHA1String(LSenhaAtual));
        if not SameText(Trim(LQry.FieldByName('senha_hash').AsString), LHashAtual) then
        begin
          Res.Status(400).Send('{"error": "A senha atual está incorreta."}').ContentType(CONTENT_TYPE_JSON);
          Exit;
        end;

        LNovoHash := SHA1Print(SHA1String(LNovaSenha));
        LQry.Close;
        LQry.SQL.Text := 'UPDATE usuarios SET senha_hash = :hash WHERE id = :id';
        LQry.ParamByName('hash').AsString := LNovoHash;
        LQry.ParamByName('id').AsInteger := LTokenData.UserId;
        LQry.ExecSQL;

        Res.Status(200).Send('{"success": true, "message": "Senha alterada com sucesso!"}').ContentType(CONTENT_TYPE_JSON);
      finally
        LQry.Free;
      end;
    finally
      TZeosConnectionPool.GetInstance.Release(LConn);
    end;
  finally
    LBody.Free;
  end;
end;

class procedure TRedeFraternaControllers.HandleGetResumoDashboard(Req: THorseRequest; Res: THorseResponse);
var
  LTokenData: TTokenData;
  LConn: TZConnection;
  LQry: TZQuery;
  LResp: TJSONObject;
  LCentroId: Integer;
  LIsAdmin: Boolean;
begin
  LTokenData := ValidateToken(GetTokenByReq(Req));
  LIsAdmin := GCurrentUser.IsAdmin;
  LCentroId := GCurrentUser.CentroId;

  LConn := TZeosConnectionPool.GetInstance.Acquire(LTokenData.Database);
  try
    LResp := TJSONObject.Create;
    LQry := TZQuery.Create(nil);
    try
      LQry.Connection := LConn;

      if LIsAdmin then
      begin
        LQry.SQL.Text := 'SELECT COUNT(*) FROM centros_espiritas WHERE ativo = ''S''';
        LQry.Open;
        LResp.Add('total_centros', LQry.Fields[0].AsInteger);
        LQry.Close;

        LQry.SQL.Text := 'SELECT COUNT(*) FROM trabalhadores WHERE ativo = ''S''';
        LQry.Open;
        LResp.Add('total_trabalhadores', LQry.Fields[0].AsInteger);
        LQry.Close;

        LQry.SQL.Text := 'SELECT COUNT(*) FROM agenda_centro WHERE ativo = ''S''';
        LQry.Open;
        LResp.Add('total_eventos_agenda', LQry.Fields[0].AsInteger);
        LQry.Close;

        LQry.SQL.Text := 'SELECT COUNT(*) FROM familias WHERE ativo = ''S''';
        LQry.Open;
        LResp.Add('total_familias', LQry.Fields[0].AsInteger);
        LQry.Close;

        LQry.SQL.Text := 'SELECT COUNT(*) FROM familia_integrantes WHERE ativo = ''S''';
        LQry.Open;
        LResp.Add('total_integrantes', LQry.Fields[0].AsInteger);
        LQry.Close;

        LQry.SQL.Text := 'SELECT COUNT(*) FROM familia_auxilios';
        LQry.Open;
        LResp.Add('total_auxilios', LQry.Fields[0].AsInteger);
        LQry.Close;

        LQry.SQL.Text := 'SELECT COUNT(*) FROM noticias WHERE ativo = ''S''';
        LQry.Open;
        LResp.Add('total_noticias', LQry.Fields[0].AsInteger);
        LQry.Close;
      end
      else
      begin
        LQry.SQL.Text := 'SELECT COUNT(*) FROM centros_espiritas WHERE ativo = ''S'' AND id = :cid';
        LQry.ParamByName('cid').AsInteger := LCentroId;
        LQry.Open;
        LResp.Add('total_centros', LQry.Fields[0].AsInteger);
        LQry.Close;

        LQry.SQL.Text := 'SELECT COUNT(*) FROM trabalhadores WHERE ativo = ''S'' AND centro_id = :cid';
        LQry.ParamByName('cid').AsInteger := LCentroId;
        LQry.Open;
        LResp.Add('total_trabalhadores', LQry.Fields[0].AsInteger);
        LQry.Close;

        LQry.SQL.Text := 'SELECT COUNT(*) FROM agenda_centro WHERE ativo = ''S'' AND centro_id = :cid';
        LQry.ParamByName('cid').AsInteger := LCentroId;
        LQry.Open;
        LResp.Add('total_eventos_agenda', LQry.Fields[0].AsInteger);
        LQry.Close;

        LQry.SQL.Text := 'SELECT COUNT(*) FROM familias WHERE ativo = ''S'' AND centro_id = :cid';
        LQry.ParamByName('cid').AsInteger := LCentroId;
        LQry.Open;
        LResp.Add('total_familias', LQry.Fields[0].AsInteger);
        LQry.Close;

        LQry.SQL.Text :=
          'SELECT COUNT(*) FROM familia_integrantes fi ' +
          'JOIN familias f ON f.id = fi.familia_id ' +
          'WHERE fi.ativo = ''S'' AND f.ativo = ''S'' AND f.centro_id = :cid';
        LQry.ParamByName('cid').AsInteger := LCentroId;
        LQry.Open;
        LResp.Add('total_integrantes', LQry.Fields[0].AsInteger);
        LQry.Close;

        LQry.SQL.Text := 'SELECT COUNT(*) FROM familia_auxilios WHERE centro_id = :cid';
        LQry.ParamByName('cid').AsInteger := LCentroId;
        LQry.Open;
        LResp.Add('total_auxilios', LQry.Fields[0].AsInteger);
        LQry.Close;

        LQry.SQL.Text := 'SELECT COUNT(*) FROM noticias WHERE ativo = ''S'' AND centro_id = :cid';
        LQry.ParamByName('cid').AsInteger := LCentroId;
        LQry.Open;
        LResp.Add('total_noticias', LQry.Fields[0].AsInteger);
        LQry.Close;
      end;

      Res.Send(LResp.AsJSON).ContentType(CONTENT_TYPE_JSON);
    finally
      LQry.Free;
      LResp.Free;
    end;
  finally
    TZeosConnectionPool.GetInstance.Release(LConn);
  end;
end;

class procedure TRedeFraternaControllers.HandleGetFamiliasDetalhadas(Req: THorseRequest; Res: THorseResponse);
var
  LTokenData: TTokenData;
  LConn: TZConnection;
  LQry: TZQuery;
  LArr: TJSONArray;
  LCentroId: Integer;
begin
  LTokenData := ValidateToken(GetTokenByReq(Req));
  if GCurrentUser.IsAdmin then
    LCentroId := StrToIntDef(Req.Query['centro_id'], 0)
  else
    LCentroId := GCurrentUser.CentroId;

  LConn := TZeosConnectionPool.GetInstance.Acquire(LTokenData.Database);
  try
    LQry := TZQuery.Create(nil);
    try
      LQry.Connection := LConn;
      LQry.SQL.Text :=
        'SELECT f.*, ' +
        '       c.nome AS centro_nome, ' +
        '       c.sigla AS centro_sigla, ' +
        '       (SELECT COUNT(*) FROM familia_integrantes fi WHERE fi.familia_id = f.id AND fi.ativo = ''S'') AS qtd_integrantes, ' +
        '       (SELECT COUNT(*) FROM familia_auxilios fa WHERE fa.familia_id = f.id) AS qtd_auxilios, ' +
        '       (SELECT MAX(fa2.data_auxilio) FROM familia_auxilios fa2 WHERE fa2.familia_id = f.id) AS ultimo_auxilio ' +
        'FROM familias f ' +
        'LEFT JOIN centros_espiritas c ON c.id = f.centro_id ' +
        'WHERE f.ativo = ''S'' ';
      if LCentroId > 0 then
        LQry.SQL.Text := LQry.SQL.Text + ' AND f.centro_id = :centro_id ';
      LQry.SQL.Text := LQry.SQL.Text + ' ORDER BY f.nome_referencia ASC';

      if LCentroId > 0 then
        LQry.ParamByName('centro_id').AsInteger := LCentroId;

      LQry.Open;
      LArr := LQry.ToJSONArray;
      try
        Res.Send(LArr.AsJSON).ContentType(CONTENT_TYPE_JSON);
      finally
        LArr.Free;
      end;
    finally
      LQry.Free;
    end;
  finally
    TZeosConnectionPool.GetInstance.Release(LConn);
  end;
end;

class procedure TRedeFraternaControllers.HandleGetFamiliaCompleta(Req: THorseRequest; Res: THorseResponse);
var
  LTokenData: TTokenData;
  LConn: TZConnection;
  LQry: TZQuery;
  LFamId: Integer;
  LResp: TJSONObject;
begin
  LFamId := StrToIntDef(Req.Params['id'], 0);
  if LFamId <= 0 then
  begin
    Res.Status(400).Send('{"error": "ID da família inválido."}').ContentType(CONTENT_TYPE_JSON);
    Exit;
  end;

  LTokenData := ValidateToken(GetTokenByReq(Req));
  LConn := TZeosConnectionPool.GetInstance.Acquire(LTokenData.Database);
  try
    LQry := TZQuery.Create(nil);
    try
      LQry.Connection := LConn;
      LQry.SQL.Text :=
        'SELECT f.*, c.nome AS centro_nome, c.sigla AS centro_sigla ' +
        'FROM familias f ' +
        'LEFT JOIN centros_espiritas c ON c.id = f.centro_id ' +
        'WHERE f.id = :id AND f.ativo = ''S''';
      LQry.ParamByName('id').AsInteger := LFamId;
      LQry.Open;

      if LQry.IsEmpty then
      begin
        Res.Status(404).Send('{"error": "Família não encontrada."}').ContentType(CONTENT_TYPE_JSON);
        Exit;
      end;

      if (not GCurrentUser.IsAdmin) and (LQry.FieldByName('centro_id').AsInteger <> GCurrentUser.CentroId) then
      begin
        Res.Status(403).Send('{"error": "Acesso negado: esta família está vinculada a outro Centro Espírita."}').ContentType(CONTENT_TYPE_JSON);
        Exit;
      end;

      LResp := LQry.ToJSONObject;
      try
        // Integrantes
        LQry.Close;
        LQry.SQL.Text :=
          'SELECT * FROM familia_integrantes ' +
          'WHERE familia_id = :id AND ativo = ''S'' ' +
          'ORDER BY id ASC';
        LQry.ParamByName('id').AsInteger := LFamId;
        LQry.Open;
        LResp.Add('integrantes', LQry.ToJSONArray);

        // Histórico de Auxílios
        LQry.Close;
        LQry.SQL.Text :=
          'SELECT fa.*, c.nome AS centro_nome, c.sigla AS centro_sigla ' +
          'FROM familia_auxilios fa ' +
          'LEFT JOIN centros_espiritas c ON c.id = fa.centro_id ' +
          'WHERE fa.familia_id = :id ' +
          'ORDER BY fa.data_auxilio DESC, fa.id DESC';
        LQry.ParamByName('id').AsInteger := LFamId;
        LQry.Open;
        LResp.Add('auxilios', LQry.ToJSONArray);

        // Log de Alterações da Família
        LQry.Close;
        LQry.SQL.Text :=
          'SELECT fl.*, c.nome AS centro_nome ' +
          'FROM familia_logs fl ' +
          'LEFT JOIN centros_espiritas c ON c.id = fl.centro_id ' +
          'WHERE fl.familia_id = :id ' +
          'ORDER BY fl.id DESC';
        LQry.ParamByName('id').AsInteger := LFamId;
        LQry.Open;
        LResp.Add('logs', LQry.ToJSONArray);

        Res.Send(LResp.AsJSON).ContentType(CONTENT_TYPE_JSON);
      finally
        LResp.Free;
      end;
    finally
      LQry.Free;
    end;
  finally
    TZeosConnectionPool.GetInstance.Release(LConn);
  end;
end;

class procedure TRedeFraternaControllers.HandleGetAgendaPublicaCentro(Req: THorseRequest; Res: THorseResponse);
var
  LMasterConn, LTenantConn: TZConnection;
  LQryMaster, LQry: TZQuery;
  LTmpl: TZConnection;
  LMasterDB, LTenantAlias, LTenantDB: string;
  LCentroId: Integer;
  LResp: TJSONObject;
begin
  LCentroId := StrToIntDef(Req.Params['id'], 0);
  if LCentroId <= 0 then
  begin
    Res.Status(400).Send('{"error": "ID do Centro Espírita inválido."}').ContentType(CONTENT_TYPE_JSON);
    Exit;
  end;

  LTenantAlias := Trim(Req.Query['tenant']);
  if LTenantAlias = '' then
    LTenantAlias := 'redefraterna';

  LTmpl := TZeosConnectionPool.GetTampleteConnection;
  if SameText(LTmpl.Protocol, 'sqlite') then
    LMasterDB := ExtractFileName(LTmpl.Database)
  else
    LMasterDB := LTmpl.Database;
  if Trim(LMasterDB) = '' then
    LMasterDB := 'masterdb.db';

  LTenantDB := '';
  LMasterConn := TZeosConnectionPool.GetInstance.Acquire(LMasterDB);
  try
    TRedeFraternaSchema.EnsureMasterSchema(LMasterConn);
    LQryMaster := TZQuery.Create(nil);
    try
      LQryMaster.Connection := LMasterConn;
      LQryMaster.SQL.Text :=
        'SELECT tenant_dbname FROM tb_sistema ' +
        'WHERE UPPER(tenant_alias) = UPPER(:alias) AND sistema = 1';
      LQryMaster.ParamByName('alias').AsString := LTenantAlias;
      LQryMaster.Open;
      if not LQryMaster.IsEmpty then
        LTenantDB := Trim(LQryMaster.FieldByName('tenant_dbname').AsString);
    finally
      LQryMaster.Free;
    end;
  finally
    TZeosConnectionPool.GetInstance.Release(LMasterConn);
  end;

  if LTenantDB = '' then
  begin
    if SameText(LTmpl.Protocol, 'sqlite') then
      LTenantDB := 'redefraterna_db.db'
    else
      LTenantDB := 'redefraterna_db';
  end
  else if SameText(LTmpl.Protocol, 'sqlite') then
    LTenantDB := ExtractFileName(LTenantDB);

  LTenantConn := TZeosConnectionPool.GetInstance.Acquire(LTenantDB);
  try
    TRedeFraternaSchema.EnsureTenantSchema(LTenantConn);
    LQry := TZQuery.Create(nil);
    try
      LQry.Connection := LTenantConn;
      LQry.SQL.Text :=
        'SELECT id, nome, sigla, logradouro, numero, complemento, bairro, cidade, uf, cep, telefone, email, presidente, observacoes ' +
        'FROM centros_espiritas ' +
        'WHERE id = :id AND ativo = ''S''';
      LQry.ParamByName('id').AsInteger := LCentroId;
      LQry.Open;

      if LQry.IsEmpty then
      begin
        Res.Status(404).Send('{"error": "Centro Espírita não encontrado ou inativo."}').ContentType(CONTENT_TYPE_JSON);
        Exit;
      end;

      LResp := LQry.ToJSONObject;
      try
        LQry.Close;
        LQry.SQL.Text :=
          'SELECT id, dia_semana, horario_inicio, horario_fim, tipo_evento, titulo, descricao, responsavel, sala_local ' +
          'FROM agenda_centro ' +
          'WHERE centro_id = :id AND ativo = ''S'' ' +
          'ORDER BY dia_semana ASC, horario_inicio ASC';
        LQry.ParamByName('id').AsInteger := LCentroId;
        LQry.Open;
        LResp.Add('agenda', LQry.ToJSONArray);
        LResp.Add('entidade', ObterConfiguracaoEntidadeJSON(LTenantConn));

        Res.Send(LResp.AsJSON).ContentType(CONTENT_TYPE_JSON);
      finally
        LResp.Free;
      end;
    finally
      LQry.Free;
    end;
  finally
    TZeosConnectionPool.GetInstance.Release(LTenantConn);
  end;
end;

class procedure TRedeFraternaControllers.HandleGetNoticiasPublicas(Req: THorseRequest; Res: THorseResponse);
var
  LMasterConn, LTenantConn: TZConnection;
  LQryMaster, LQry: TZQuery;
  LTmpl: TZConnection;
  LMasterDB, LTenantAlias, LTenantDB: string;
  LCentroId: Integer;
  LResp: TJSONObject;
begin
  LCentroId := StrToIntDef(Req.Query['centro_id'], 0);
  LTenantAlias := Trim(Req.Query['tenant']);
  if LTenantAlias = '' then
    LTenantAlias := 'redefraterna';

  LTmpl := TZeosConnectionPool.GetTampleteConnection;
  if SameText(LTmpl.Protocol, 'sqlite') then
    LMasterDB := ExtractFileName(LTmpl.Database)
  else
    LMasterDB := LTmpl.Database;
  if Trim(LMasterDB) = '' then
    LMasterDB := 'masterdb.db';

  LTenantDB := '';
  LMasterConn := TZeosConnectionPool.GetInstance.Acquire(LMasterDB);
  try
    TRedeFraternaSchema.EnsureMasterSchema(LMasterConn);
    LQryMaster := TZQuery.Create(nil);
    try
      LQryMaster.Connection := LMasterConn;
      LQryMaster.SQL.Text :=
        'SELECT tenant_dbname FROM tb_sistema ' +
        'WHERE UPPER(tenant_alias) = UPPER(:alias) AND sistema = 1';
      LQryMaster.ParamByName('alias').AsString := LTenantAlias;
      LQryMaster.Open;
      if not LQryMaster.IsEmpty then
        LTenantDB := Trim(LQryMaster.FieldByName('tenant_dbname').AsString);
    finally
      LQryMaster.Free;
    end;
  finally
    TZeosConnectionPool.GetInstance.Release(LMasterConn);
  end;

  if LTenantDB = '' then
  begin
    if SameText(LTmpl.Protocol, 'sqlite') then
      LTenantDB := 'redefraterna_db.db'
    else
      LTenantDB := 'redefraterna_db';
  end
  else if SameText(LTmpl.Protocol, 'sqlite') then
    LTenantDB := ExtractFileName(LTenantDB);

  LTenantConn := TZeosConnectionPool.GetInstance.Acquire(LTenantDB);
  try
    TRedeFraternaSchema.EnsureTenantSchema(LTenantConn);
    LResp := TJSONObject.Create;
    LQry := TZQuery.Create(nil);
    try
      LQry.Connection := LTenantConn;

      // Lista de notícias ativas e publicadas (publicado = 'S') com nome/sigla do Centro Espírita
      LQry.SQL.Text :=
        'SELECT n.id, n.centro_id, n.titulo, n.resumo, n.conteudo, n.categoria, ' +
        '       n.autor, n.imagem_url, n.destaque, n.publicado, n.data_publicacao, n.criado_em, ' +
        '       c.nome AS centro_nome, c.sigla AS centro_sigla ' +
        'FROM noticias n ' +
        'LEFT JOIN centros_espiritas c ON c.id = n.centro_id ' +
        'WHERE n.ativo = ''S'' AND COALESCE(n.publicado, ''S'') = ''S'' ';
      if LCentroId > 0 then
        LQry.SQL.Text := LQry.SQL.Text + ' AND n.centro_id = :centro_id ';
      LQry.SQL.Text := LQry.SQL.Text + ' ORDER BY n.destaque DESC, n.data_publicacao DESC, n.id DESC';

      if LCentroId > 0 then
        LQry.ParamByName('centro_id').AsInteger := LCentroId;

      LQry.Open;
      LResp.Add('noticias', LQry.ToJSONArray);

      // Também retorna os centros espíritas ativos para filtro rápido no feed público
      LQry.Close;
      LQry.SQL.Text :=
        'SELECT id, nome, sigla FROM centros_espiritas WHERE ativo = ''S'' ORDER BY nome ASC';
      LQry.Open;
      LResp.Add('centros', LQry.ToJSONArray);
      LResp.Add('entidade', ObterConfiguracaoEntidadeJSON(LTenantConn));

      Res.Send(LResp.AsJSON).ContentType(CONTENT_TYPE_JSON);
    finally
      LQry.Free;
      LResp.Free;
    end;
  finally
    TZeosConnectionPool.GetInstance.Release(LTenantConn);
  end;
end;

class procedure TRedeFraternaControllers.RegisterAllRoutes;
begin
  // Configura FormatSettings padrão para datas ISO (yyyy-mm-dd) usadas pelo JSON/DataSet.Serialize
  DefaultFormatSettings.DateSeparator := '-';
  DefaultFormatSettings.ShortDateFormat := 'yyyy-mm-dd';
  DefaultFormatSettings.TimeSeparator := ':';
  DefaultFormatSettings.ShortTimeFormat := 'hh:nn:ss';
  DefaultFormatSettings.LongTimeFormat := 'hh:nn:ss';

  // Configura DataSet.Serialize para manter chaves JSON em snake_case minúsculo
  TDataSetSerializeConfig.GetInstance.CaseNameDefinition := cndLower;

  // Middleware de isolamento de dados por Centro Espírita (exceto para Administrador 'A')
  THorse.Use(HorseCentroAccessMiddleware);

  // Autenticação e perfil
  RegisterLoginRoute('/api/login', OnAuthenticate);
  THorse.Get('/api/meu-perfil', HandleGetMeuPerfil);
  THorse.Get('/api/configuracoes', HandleGetConfiguracoes);
  THorse.Put('/api/configuracoes', HandlePutConfiguracoes);
  THorse.Post('/api/minha-senha', HandlePostAlterarMinhaSenha);

  // Endpoints enriquecidos
  THorse.Get('/api/dashboard', HandleGetResumoDashboard);
  THorse.Get('/api/familias-detalhadas', HandleGetFamiliasDetalhadas);
  THorse.Get('/api/familias/:id/completa', HandleGetFamiliaCompleta);

  // Endpoints públicos (sem exigência de token JWT)
  THorse.Get('/public/entidade', HandleGetEntidadePublica);
  THorse.Get('/public/agenda/:id', HandleGetAgendaPublicaCentro);
  THorse.Get('/public/noticias', HandleGetNoticiasPublicas);

  // Configuração de prefixo dos controllers CRUD automáticos do TWAPI
  TTWApiController.RoutePrefix := '/api';

  // 1. Usuários (A=Administrador, O=Operador do Sistema, F=Operador da Família)
  FCtrlUsuarios := TTWApiController.Create('usuarios', 'id');
  FCtrlUsuarios.DefaultSortField := 'nome';
  FCtrlUsuarios.SoftDeleteField := 'ativo';
  FCtrlUsuarios.SoftDeleteActiveValue := 'S';
  FCtrlUsuarios.SoftDeleteDeletedValue := 'N';
  FCtrlUsuarios.OptionalListCondition := 'id = :USERID';
  FCtrlUsuarios.OnBeforeCreate := UsuariosBeforeCreate;
  FCtrlUsuarios.OnBeforeUpdate := UsuariosBeforeUpdate;
  FCtrlUsuarios.RegisterRoutes('usuarios');

  // 2. Centros Espíritas
  FCtrlCentros := TTWApiController.Create('centros_espiritas', 'id');
  FCtrlCentros.DefaultSortField := 'nome';
  FCtrlCentros.SoftDeleteField := 'ativo';
  FCtrlCentros.SoftDeleteActiveValue := 'S';
  FCtrlCentros.SoftDeleteDeletedValue := 'N';
  FCtrlCentros.OptionalListCondition := 'id = (SELECT COALESCE(u.centro_id, -1) FROM usuarios u WHERE u.id = :USERID)';
  FCtrlCentros.OnBeforeCreate := CentrosBeforeCreate;
  FCtrlCentros.OnBeforeUpdate := CentrosBeforeUpdate;
  FCtrlCentros.OnBeforeDelete := CentrosBeforeDelete;
  FCtrlCentros.RegisterRoutes('centros');

  // 3. Trabalhadores dos Centros Espíritas
  FCtrlTrabalhadores := TTWApiController.Create('trabalhadores', 'id');
  FCtrlTrabalhadores.DefaultSortField := 'nome';
  FCtrlTrabalhadores.SoftDeleteField := 'ativo';
  FCtrlTrabalhadores.SoftDeleteActiveValue := 'S';
  FCtrlTrabalhadores.SoftDeleteDeletedValue := 'N';
  FCtrlTrabalhadores.OptionalListCondition := 'centro_id = (SELECT COALESCE(u.centro_id, -1) FROM usuarios u WHERE u.id = :USERID)';
  FCtrlTrabalhadores.OnBeforeCreate := TrabalhadoresBeforeCreate;
  FCtrlTrabalhadores.OnBeforeUpdate := TrabalhadoresBeforeUpdate;
  FCtrlTrabalhadores.OnBeforeDelete := TrabalhadoresBeforeDelete;
  FCtrlTrabalhadores.RegisterRoutes('trabalhadores');

  // 4. Agenda Semanal dos Centros Espíritas
  FCtrlAgenda := TTWApiController.Create('agenda_centro', 'id');
  FCtrlAgenda.DefaultSortField := 'dia_semana';
  FCtrlAgenda.SoftDeleteField := 'ativo';
  FCtrlAgenda.SoftDeleteActiveValue := 'S';
  FCtrlAgenda.SoftDeleteDeletedValue := 'N';
  FCtrlAgenda.OptionalListCondition := 'centro_id = (SELECT COALESCE(u.centro_id, -1) FROM usuarios u WHERE u.id = :USERID)';
  FCtrlAgenda.OnBeforeCreate := AgendaBeforeCreate;
  FCtrlAgenda.OnBeforeUpdate := AgendaBeforeUpdate;
  FCtrlAgenda.OnBeforeDelete := AgendaBeforeDelete;
  FCtrlAgenda.RegisterRoutes('agenda');

  // 5. Famílias Assistidas
  FCtrlFamilias := TTWApiController.Create('familias', 'id');
  FCtrlFamilias.DefaultSortField := 'nome_referencia';
  FCtrlFamilias.SoftDeleteField := 'ativo';
  FCtrlFamilias.SoftDeleteActiveValue := 'S';
  FCtrlFamilias.SoftDeleteDeletedValue := 'N';
  FCtrlFamilias.OptionalListCondition := 'centro_id = (SELECT COALESCE(u.centro_id, -1) FROM usuarios u WHERE u.id = :USERID)';
  FCtrlFamilias.OnBeforeCreate := FamiliasBeforeCreate;
  FCtrlFamilias.OnAfterCreate := FamiliasAfterCreate;
  FCtrlFamilias.OnBeforeUpdate := FamiliasBeforeUpdate;
  FCtrlFamilias.OnBeforeDelete := FamiliasBeforeDelete;
  FCtrlFamilias.RegisterRoutes('familias');

  // 6. Integrantes da Família
  FCtrlIntegrantes := TTWApiController.Create('familia_integrantes', 'id');
  FCtrlIntegrantes.DefaultSortField := 'nome';
  FCtrlIntegrantes.SoftDeleteField := 'ativo';
  FCtrlIntegrantes.SoftDeleteActiveValue := 'S';
  FCtrlIntegrantes.SoftDeleteDeletedValue := 'N';
  FCtrlIntegrantes.OptionalListCondition := 'familia_id IN (SELECT f.id FROM familias f WHERE f.centro_id = (SELECT COALESCE(u.centro_id, -1) FROM usuarios u WHERE u.id = :USERID))';
  FCtrlIntegrantes.OnBeforeCreate := IntegrantesBeforeCreate;
  FCtrlIntegrantes.OnAfterCreate := IntegrantesAfterCreate;
  FCtrlIntegrantes.OnBeforeUpdate := IntegrantesBeforeUpdate;
  FCtrlIntegrantes.OnBeforeDelete := IntegrantesBeforeDelete;
  FCtrlIntegrantes.RegisterRoutes('integrantes');

  // 7. Histórico de Auxílios Prestados às Famílias
  FCtrlAuxilios := TTWApiController.Create('familia_auxilios', 'id');
  FCtrlAuxilios.DefaultSortField := 'data_auxilio';
  FCtrlAuxilios.OptionalListCondition := 'centro_id = (SELECT COALESCE(u.centro_id, -1) FROM usuarios u WHERE u.id = :USERID)';
  FCtrlAuxilios.OnBeforeCreate := AuxiliosBeforeCreate;
  FCtrlAuxilios.OnAfterCreate := AuxiliosAfterCreate;
  FCtrlAuxilios.OnBeforeUpdate := AuxiliosBeforeUpdate;
  FCtrlAuxilios.OnBeforeDelete := AuxiliosBeforeDelete;
  FCtrlAuxilios.RegisterRoutes('auxilios');

  // 8. Logs de Alteração dos Dados da Família
  FCtrlLogs := TTWApiController.Create('familia_logs', 'id');
  FCtrlLogs.DefaultSortField := 'id';
  FCtrlLogs.OptionalListCondition := 'familia_id IN (SELECT f.id FROM familias f WHERE f.centro_id = (SELECT COALESCE(u.centro_id, -1) FROM usuarios u WHERE u.id = :USERID))';
  FCtrlLogs.RegisterRoutes('familia-logs');

  // 9. Notícias e Comunicados (Feed de Notícias da UME e Centros Espíritas)
  FCtrlNoticias := TTWApiController.Create('noticias', 'id');
  FCtrlNoticias.DefaultSortField := 'data_publicacao';
  FCtrlNoticias.SoftDeleteField := 'ativo';
  FCtrlNoticias.SoftDeleteActiveValue := 'S';
  FCtrlNoticias.SoftDeleteDeletedValue := 'N';
  FCtrlNoticias.OptionalListCondition := 'centro_id = (SELECT COALESCE(u.centro_id, -1) FROM usuarios u WHERE u.id = :USERID)';
  FCtrlNoticias.OnBeforeCreate := NoticiasBeforeCreate;
  FCtrlNoticias.OnBeforeUpdate := NoticiasBeforeUpdate;
  FCtrlNoticias.OnBeforeDelete := NoticiasBeforeDelete;
  FCtrlNoticias.RegisterRoutes('noticias');
end;

class procedure TRedeFraternaControllers.FinalizeControllers;
begin
  FreeAndNil(FCtrlUsuarios);
  FreeAndNil(FCtrlCentros);
  FreeAndNil(FCtrlTrabalhadores);
  FreeAndNil(FCtrlAgenda);
  FreeAndNil(FCtrlFamilias);
  FreeAndNil(FCtrlIntegrantes);
  FreeAndNil(FCtrlAuxilios);
  FreeAndNil(FCtrlLogs);
  FreeAndNil(FCtrlNoticias);
end;

end.
