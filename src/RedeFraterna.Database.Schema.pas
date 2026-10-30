{*******************************************************************************
  RedeFraterna.Database.Schema - Criação e Migração Automática do Banco de Dados
  Projeto: Rede Fraterna - Sistema de Controle da União Municipal Espírita (UME)

  Descrição:
    Unit responsável por verificar e criar todas as tabelas e índices do sistema
    Rede Fraterna de forma abstraída para PostgreSQL e SQLite utilizando
    ISQLCreateTableBuilder (twapi.SQLBuilder).
*******************************************************************************}
unit RedeFraterna.Database.Schema;

{$mode Delphi}{$H+}
{$codepage UTF8}

interface

uses
  Classes, SysUtils, SyncObjs, DB, ZConnection, ZDataset,
  twapi.SQLBuilder, twapi.TextFileLog,
  RedeFraterna.Database.Seeds;

type
  { TRedeFraternaSchema }
  TRedeFraternaSchema = class
  private
    class function TableExists(AConn: TZConnection; ABuilder: ISQLCreateTableBuilder): Boolean;
    class function ColumnExists(AConn: TZConnection; const ATableName, AColumnName: string): Boolean;
    class procedure CreateTableIfNotExists(AConn: TZConnection; ABuilder: ISQLCreateTableBuilder);
    class procedure CreateIndexSafe(AConn: TZConnection; const AIndexSQL: string);
    class function EnsureColumnExists(AConn: TZConnection; const ATableName, AColumnName, AColumnDef: string): Boolean;
  public
    class procedure EnsureMasterSchema(AConn: TZConnection);
    class procedure EnsureTenantSchema(AConn: TZConnection);
  end;

implementation

var
  GSchemaLock: TCriticalSection = nil;
  GInitializedSchemas: TStringList = nil;

{ TRedeFraternaSchema }

class function TRedeFraternaSchema.TableExists(AConn: TZConnection; ABuilder: ISQLCreateTableBuilder): Boolean;
var
  LQry: TZQuery;
begin
  Result := False;
  LQry := TZQuery.Create(nil);
  try
    LQry.Connection := AConn;
    LQry.SQL.Text := ABuilder.BuildCheckTableExists;
    LQry.Open;
    if not LQry.IsEmpty then
      Result := LQry.Fields[0].AsInteger > 0;
  finally
    LQry.Free;
  end;
end;

class procedure TRedeFraternaSchema.CreateTableIfNotExists(AConn: TZConnection; ABuilder: ISQLCreateTableBuilder);
begin
  if not TableExists(AConn, ABuilder) then
    AConn.ExecuteDirect(ABuilder.Build);
end;

class procedure TRedeFraternaSchema.CreateIndexSafe(AConn: TZConnection; const AIndexSQL: string);
begin
  if Trim(AIndexSQL) <> '' then
    AConn.ExecuteDirect(AIndexSQL);
end;

class function TRedeFraternaSchema.ColumnExists(AConn: TZConnection; const ATableName, AColumnName: string): Boolean;
var
  LQry: TZQuery;
begin
  Result := False;
  if (AConn = nil) or (not AConn.Connected) then Exit;
  LQry := TZQuery.Create(nil);
  try
    LQry.Connection := AConn;
    if SameText(AConn.Protocol, 'sqlite') then
    begin
      LQry.SQL.Text := Format('PRAGMA table_info(%s)', [ATableName]);
      LQry.Open;
      while not LQry.EOF do
      begin
        if SameText(LQry.FieldByName('name').AsString, AColumnName) then
        begin
          Result := True;
          Break;
        end;
        LQry.Next;
      end;
    end
    else
    begin
      LQry.SQL.Text :=
        'SELECT 1 FROM information_schema.columns ' +
        'WHERE LOWER(table_name) = LOWER(:tbl) AND LOWER(column_name) = LOWER(:col)';
      LQry.ParamByName('tbl').AsString := ATableName;
      LQry.ParamByName('col').AsString := AColumnName;
      LQry.Open;
      Result := not LQry.IsEmpty;
    end;
  finally
    LQry.Free;
  end;
end;

class function TRedeFraternaSchema.EnsureColumnExists(AConn: TZConnection; const ATableName, AColumnName, AColumnDef: string): Boolean;
begin
  Result := False;
  if not ColumnExists(AConn, ATableName, AColumnName) then
  begin
    try
      AConn.ExecuteDirect(Format('ALTER TABLE %s ADD COLUMN %s %s', [ATableName, AColumnName, AColumnDef]));
      Result := True;
    except
    end;
  end;
end;

class procedure TRedeFraternaSchema.EnsureMasterSchema(AConn: TZConnection);
var
  LBuilder: ISQLCreateTableBuilder;
  LProtocol, LDbKey: string;
  LQry: TZQuery;
begin
  if (AConn = nil) or (not AConn.Connected) then Exit;

  GSchemaLock.Enter;
  try
    LDbKey := 'MASTER:' + LowerCase(Trim(AConn.Database));
    if GInitializedSchemas.IndexOf(LDbKey) >= 0 then Exit;

    LProtocol := AConn.Protocol;
    SetDefaultSQLDialect(StringToSQLDialect(LProtocol));

    if SameText(LProtocol, 'sqlite') then
    begin
      AConn.ExecuteDirect('PRAGMA busy_timeout = 5000;');
      AConn.ExecuteDirect('PRAGMA journal_mode = WAL;');
    end;

    LBuilder := SQLCreateTable('tb_sistema', LProtocol)
      .IfNotExists
      .AddPrimaryKey('id', True)
      .AddVarchar('tenant_name', 60, True)
      .AddVarchar('tenant_alias', 30, True)
      .AddVarchar('tenant_dbname', 100, True)
      .AddInteger('sistema', True)
      .AddVarchar('tenant_doc', 30)
      .AddVarchar('tenant_fone', 30)
      .AddDate('tenant_dt_limite', True);

    CreateTableIfNotExists(AConn, LBuilder);
    EnsureColumnExists(AConn, 'tb_sistema', 'tenant_dbname', 'VARCHAR(100)');
    CreateIndexSafe(AConn, 'CREATE INDEX IF NOT EXISTS idx_tb_sistema_lookup ON tb_sistema(tenant_alias, sistema)');

    // Garante o tenant 'redefraterna' (ou 'ume') no MasterDB
    LQry := TZQuery.Create(nil);
    try
      LQry.Connection := AConn;
      LQry.SQL.Text := 'SELECT COUNT(*) FROM tb_sistema WHERE UPPER(tenant_alias) = ''REDEFRATERNA'' AND sistema = 1';
      LQry.Open;
      if LQry.Fields[0].AsInteger = 0 then
      begin
        LQry.Close;
        LQry.SQL.Text :=
          'INSERT INTO tb_sistema (tenant_name, tenant_alias, tenant_dbname, sistema, tenant_doc, tenant_fone, tenant_dt_limite) ' +
          'VALUES (:name, :alias, :db, :sis, :doc, :fone, :dt)';
        LQry.ParamByName('name').AsString := 'UME - Cachoeira do Sul';
        LQry.ParamByName('alias').AsString := 'redefraterna';
        if SameText(LProtocol, 'sqlite') then
          LQry.ParamByName('db').AsString := 'redefraterna_db.db'
        else
          LQry.ParamByName('db').AsString := 'redefraterna_db';
        LQry.ParamByName('sis').AsInteger := 1;
        LQry.ParamByName('doc').AsString := '00.000.000/0001-00';
        LQry.ParamByName('fone').AsString := '(51) 3722-0000';
        LQry.ParamByName('dt').AsDate := EncodeDate(2099, 12, 31);
        LQry.ExecSQL;
      end;

      // Também garante o alias curto 'ume' apontando para o mesmo banco
      LQry.Close;
      LQry.SQL.Text := 'SELECT COUNT(*) FROM tb_sistema WHERE UPPER(tenant_alias) = ''UME'' AND sistema = 1';
      LQry.Open;
      if LQry.Fields[0].AsInteger = 0 then
      begin
        LQry.Close;
        LQry.SQL.Text :=
          'INSERT INTO tb_sistema (tenant_name, tenant_alias, tenant_dbname, sistema, tenant_doc, tenant_fone, tenant_dt_limite) ' +
          'VALUES (:name, :alias, :db, :sis, :doc, :fone, :dt)';
        LQry.ParamByName('name').AsString := 'UME - Cachoeira do Sul';
        LQry.ParamByName('alias').AsString := 'ume';
        if SameText(LProtocol, 'sqlite') then
          LQry.ParamByName('db').AsString := 'redefraterna_db.db'
        else
          LQry.ParamByName('db').AsString := 'redefraterna_db';
        LQry.ParamByName('sis').AsInteger := 1;
        LQry.ParamByName('doc').AsString := '00.000.000/0001-00';
        LQry.ParamByName('fone').AsString := '(51) 3722-0000';
        LQry.ParamByName('dt').AsDate := EncodeDate(2099, 12, 31);
        LQry.ExecSQL;
      end;
    finally
      LQry.Free;
    end;

    GInitializedSchemas.Add(LDbKey);
  finally
    GSchemaLock.Leave;
  end;
end;

class procedure TRedeFraternaSchema.EnsureTenantSchema(AConn: TZConnection);
var
  LProtocol, LDbKey: string;
  LBuilder: ISQLCreateTableBuilder;
begin
  if (AConn = nil) or (not AConn.Connected) then Exit;

  GSchemaLock.Enter;
  try
    LDbKey := 'TENANT:' + LowerCase(Trim(AConn.Database));
    if GInitializedSchemas.IndexOf(LDbKey) >= 0 then Exit;

    LProtocol := AConn.Protocol;
    SetDefaultSQLDialect(StringToSQLDialect(LProtocol));

    if StringToSQLDialect(LProtocol) = sdPostgreSQL then
      AConn.ExecuteDirect('CREATE SEQUENCE IF NOT EXISTS seq_global_id START 1;')
    else
    begin
      AConn.ExecuteDirect('PRAGMA busy_timeout = 5000;');
      AConn.ExecuteDirect('PRAGMA journal_mode = WAL;');
      AConn.ExecuteDirect('PRAGMA foreign_keys = ON;');
    end;

  // 1. Tabela: usuarios
  // Perfis: A = Administrador (acesso global UME), O = Operador do Sistema (vinculado a centro_id), F = Operador da Família (vinculado a centro_id)
  LBuilder := SQLCreateTable('usuarios', LProtocol)
    .IfNotExists
    .AddPrimaryKey('id', True)
    .AddInteger('centro_id', False)
    .AddVarchar('login', 60, True, '', True)
    .AddVarchar('nome', 120, True)
    .AddVarchar('senha_hash', 120, True)
    .AddVarchar('tipo', 1, True, 'F')
    .AddVarchar('ativo', 1, True, 'S')
    .AddDateTime('criado_em', False, True);
  CreateTableIfNotExists(AConn, LBuilder);
  EnsureColumnExists(AConn, 'usuarios', 'centro_id', 'INTEGER');
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_usuarios_centro', ['centro_id']));

  // 2. Tabela: centros_espiritas
  LBuilder := SQLCreateTable('centros_espiritas', LProtocol)
    .IfNotExists
    .AddPrimaryKey('id', True)
    .AddVarchar('nome', 150, True)
    .AddVarchar('sigla', 30)
    .AddVarchar('cnpj', 25)
    .AddVarchar('cep', 12)
    .AddVarchar('logradouro', 150)
    .AddVarchar('numero', 25)
    .AddVarchar('complemento', 80)
    .AddVarchar('bairro', 80)
    .AddVarchar('cidade', 80)
    .AddVarchar('uf', 2)
    .AddVarchar('telefone', 30)
    .AddVarchar('email', 120)
    .AddVarchar('presidente', 120)
    .AddDate('data_fundacao')
    .AddText('observacoes')
    .AddVarchar('ativo', 1, True, 'S')
    .AddDateTime('criado_em', False, True);
  CreateTableIfNotExists(AConn, LBuilder);
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_centros_nome', ['nome']));

  // 3. Tabela: trabalhadores (Vinculados a um Centro Espírita)
  LBuilder := SQLCreateTable('trabalhadores', LProtocol)
    .IfNotExists
    .AddPrimaryKey('id', True)
    .AddInteger('centro_id', True)
    .AddVarchar('nome', 150, True)
    .AddVarchar('cpf', 18)
    .AddDate('data_nascimento')
    .AddVarchar('telefone', 30)
    .AddVarchar('email', 120)
    .AddVarchar('funcao', 100)
    .AddVarchar('departamento', 100)
    .AddDate('data_ingresso')
    .AddText('observacoes')
    .AddVarchar('ativo', 1, True, 'S')
    .AddDateTime('criado_em', False, True)
    .AddForeignKey('centro_id', 'centros_espiritas', 'id', fkRestrict);
  CreateTableIfNotExists(AConn, LBuilder);
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_trabalhadores_centro', ['centro_id']));
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_trabalhadores_nome', ['nome']));

  // 4. Tabela: agenda_centro (Agenda Semanal do Centro Espírita)
  LBuilder := SQLCreateTable('agenda_centro', LProtocol)
    .IfNotExists
    .AddPrimaryKey('id', True)
    .AddInteger('centro_id', True)
    .AddInteger('dia_semana', True, '0') // 0=Dom, 1=Seg, 2=Ter, 3=Qua, 4=Qui, 5=Sex, 6=Sáb
    .AddVarchar('horario_inicio', 10, True)
    .AddVarchar('horario_fim', 10)
    .AddVarchar('tipo_evento', 40, True, 'EXPOSICAO_PUBLICA')
    .AddVarchar('titulo', 150, True)
    .AddText('descricao')
    .AddVarchar('responsavel', 120)
    .AddVarchar('sala_local', 80)
    .AddVarchar('ativo', 1, True, 'S')
    .AddForeignKey('centro_id', 'centros_espiritas', 'id', fkCascade);
  CreateTableIfNotExists(AConn, LBuilder);
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_agenda_centro_dia', ['centro_id', 'dia_semana']));

  // 5. Tabela: familias (Famílias assistidas e vinculadas a um Centro Espírita)
  LBuilder := SQLCreateTable('familias', LProtocol)
    .IfNotExists
    .AddPrimaryKey('id', True)
    .AddInteger('centro_id', True)
    .AddVarchar('nome_referencia', 150, True)
    .AddVarchar('cpf_responsavel', 18, False, '', True) // UNIQUE no banco de dados
    .AddVarchar('telefone', 30)
    .AddVarchar('cep', 12)
    .AddVarchar('logradouro', 150)
    .AddVarchar('numero', 25)
    .AddVarchar('complemento', 80)
    .AddVarchar('bairro', 80)
    .AddVarchar('cidade', 80)
    .AddVarchar('uf', 2)
    .AddVarchar('situacao', 30, True, 'ATIVA') // ATIVA, ACOMPANHAMENTO, SUSPENSA, DESLIGADA
    .AddNumeric('renda_familiar', 15, 2, False, '0')
    .AddText('observacoes')
    .AddVarchar('ativo', 1, True, 'S')
    .AddDateTime('criado_em', False, True)
    .AddDateTime('atualizado_em', False, True)
    .AddForeignKey('centro_id', 'centros_espiritas', 'id', fkRestrict);
  CreateTableIfNotExists(AConn, LBuilder);
  EnsureColumnExists(AConn, 'familias', 'cpf_responsavel', 'VARCHAR(18)');
  AConn.ExecuteDirect('UPDATE familias SET cpf_responsavel = NULL WHERE TRIM(COALESCE(cpf_responsavel, '''')) = ''''');
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_familias_centro', ['centro_id']));
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_familias_nome', ['nome_referencia']));
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('uk_familias_cpf_resp', ['cpf_responsavel'], True));

  // 6. Tabela: familia_integrantes (Integrantes da Família)
  LBuilder := SQLCreateTable('familia_integrantes', LProtocol)
    .IfNotExists
    .AddPrimaryKey('id', True)
    .AddInteger('familia_id', True)
    .AddVarchar('nome', 150, True)
    .AddVarchar('cpf', 18, False, '', True)    // UNIQUE no banco de dados
    .AddDate('data_nascimento')
    .AddVarchar('papel_familia', 80, True) // Ex: Responsável, Mãe, Pai, Filho(a), Avô(ó), Outro
    .AddText('info_adicionais')            // Campo texto de livre digitação
    .AddVarchar('ativo', 1, True, 'S')
    .AddDateTime('criado_em', False, True)
    .AddForeignKey('familia_id', 'familias', 'id', fkCascade);
  CreateTableIfNotExists(AConn, LBuilder);
  AConn.ExecuteDirect('UPDATE familia_integrantes SET cpf = NULL WHERE TRIM(COALESCE(cpf, '''')) = ''''');
  AConn.ExecuteDirect('DROP INDEX IF EXISTS idx_integrantes_cpf');
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_integrantes_familia', ['familia_id']));
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('uk_integrantes_cpf', ['cpf'], True));

  // 7. Tabela: familia_auxilios (Histórico de Auxílios prestados à Família pelo Centro Espírita)
  LBuilder := SQLCreateTable('familia_auxilios', LProtocol)
    .IfNotExists
    .AddPrimaryKey('id', True)
    .AddInteger('familia_id', True)
    .AddInteger('centro_id', True)
    .AddDate('data_auxilio', True, True)
    .AddVarchar('tipo_auxilio', 50, True, 'CESTA_BASICA') // CESTA_BASICA, DINHEIRO, SAUDE_MEDICAMENTO, VESTUARIO, MATERIAL_ESCOLAR, VISITA_FRATERNA, OUTROS
    .AddVarchar('descricao', 250, True)
    .AddNumeric('valor_estimado', 15, 2, False, '0')
    .AddVarchar('quantidade', 60)
    .AddVarchar('responsavel_entrega', 120)
    .AddText('observacoes')
    .AddInteger('usuario_id', False)
    .AddVarchar('usuario_nome', 100)
    .AddDateTime('criado_em', False, True)
    .AddForeignKey('familia_id', 'familias', 'id', fkCascade)
    .AddForeignKey('centro_id', 'centros_espiritas', 'id', fkRestrict);
  CreateTableIfNotExists(AConn, LBuilder);
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_auxilios_familia', ['familia_id']));
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_auxilios_centro', ['centro_id']));
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_auxilios_data', ['data_auxilio']));

  // 8. Tabela: familia_logs (Log de Auditoria de todas as alterações nos dados da Família e Integrantes)
  LBuilder := SQLCreateTable('familia_logs', LProtocol)
    .IfNotExists
    .AddPrimaryKey('id', True)
    .AddInteger('familia_id', True)
    .AddInteger('centro_id', False)
    .AddDateTime('data_hora', False, True)
    .AddInteger('usuario_id', False)
    .AddVarchar('usuario_nome', 100)
    .AddVarchar('acao', 40, True)       // CRIACAO, ALTERACAO, VINCULO_CENTRO, EXCLUSAO, INTEGRANTE_ADD, INTEGRANTE_EDIT, INTEGRANTE_DEL, AUXILIO_REGISTRADO
    .AddVarchar('entidade', 40, True)   // FAMILIA, INTEGRANTE, AUXILIO
    .AddInteger('entidade_id', False)
    .AddText('resumo_alteracao', True)
    .AddText('dados_anteriores')
    .AddText('dados_novos')
    .AddForeignKey('familia_id', 'familias', 'id', fkCascade);
  CreateTableIfNotExists(AConn, LBuilder);
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_familia_logs_fam', ['familia_id']));
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_familia_logs_dt', ['data_hora']));

  // 9. Tabela: noticias (Feed de Notícias e Comunicados da UME e dos Centros Espíritas)
  LBuilder := SQLCreateTable('noticias', LProtocol)
    .IfNotExists
    .AddPrimaryKey('id', True)
    .AddInteger('centro_id', False)                // NULL ou 0 = Notícia Geral da UME; > 0 = Vinculada a um Centro Espírita
    .AddVarchar('titulo', 200, True)
    .AddVarchar('resumo', 300)
    .AddText('conteudo', True)
    .AddVarchar('categoria', 50, True, 'COMUNICADO') // COMUNICADO, EVENTO, PALESTRA, CAMPANHA, ESTUDO, ARTIGO
    .AddVarchar('autor', 120)
    .AddVarchar('imagem_url', 500)
    .AddVarchar('destaque', 1, True, 'N')            // S = Notícia em destaque no topo do feed
    .AddVarchar('publicado', 1, True, 'S')           // S = Visível no Feed Público, N = Rascunho / Oculta do Feed Público
    .AddDate('data_publicacao', True, True)
    .AddVarchar('ativo', 1, True, 'S')
    .AddDateTime('criado_em', False, True);
  CreateTableIfNotExists(AConn, LBuilder);
  if EnsureColumnExists(AConn, 'noticias', 'publicado', 'VARCHAR(1) DEFAULT ''S''') then
    AConn.ExecuteDirect('UPDATE noticias SET publicado = ''S'' WHERE publicado IS NULL OR publicado = ''''');
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_noticias_data', ['data_publicacao']));
  CreateIndexSafe(AConn, LBuilder.BuildCreateIndex('idx_noticias_centro', ['centro_id']));

  // 10. Tabela: configuracoes (Identificação da Entidade Mantenedora: ex: "UME - Cachoeira do Sul", "UME - Rio Pardo", "AES - Santa Cruz")
  LBuilder := SQLCreateTable('configuracoes', LProtocol)
    .IfNotExists
    .AddPrimaryKey('id', True)
    .AddVarchar('nome_mantenedora', 150, True, 'UME - Cachoeira do Sul')
    .AddVarchar('sigla_mantenedora', 40, False, 'UME')
    .AddVarchar('subtitulo_sistema', 200, False, 'Gestão Integrada de Centros Espíritas e Assistência Social')
    .AddVarchar('cnpj_mantenedora', 25)
    .AddVarchar('cidade_mantenedora', 80, False, 'Cachoeira do Sul')
    .AddVarchar('uf_mantenedora', 2, False, 'RS')
    .AddVarchar('telefone_mantenedora', 30)
    .AddVarchar('email_mantenedora', 120)
    .AddVarchar('endereco_mantenedora', 200)
    .AddDateTime('atualizado_em', False, True);
  CreateTableIfNotExists(AConn, LBuilder);

  // Popula dados iniciais se o banco estiver vazio
  TRedeFraternaSeeds.SeedInitialData(AConn);

    GInitializedSchemas.Add(LDbKey);
  finally
    GSchemaLock.Leave;
  end;
end;

initialization
  GSchemaLock := TCriticalSection.Create;
  GInitializedSchemas := TStringList.Create;

finalization
  FreeAndNil(GInitializedSchemas);
  FreeAndNil(GSchemaLock);

end.
