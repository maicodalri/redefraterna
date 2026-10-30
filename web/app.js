const { createApp } = Vue;

const STORAGE_TOKEN_KEY = 'redefraterna_token_v1';
const STORAGE_USER_KEY = 'redefraterna_user_v1';
const STORAGE_TYPE_KEY = 'redefraterna_user_type_v1';
const STORAGE_TENANT_KEY = 'redefraterna_tenant_v1';
const STORAGE_CENTRO_ID_KEY = 'redefraterna_centro_id_v1';
const STORAGE_CENTRO_NOME_KEY = 'redefraterna_centro_nome_v1';
const STORAGE_ENTIDADE_NOME_KEY = 'redefraterna_entidade_nome_v1';
const STORAGE_ENTIDADE_SIGLA_KEY = 'redefraterna_entidade_sigla_v1';

createApp({
  data() {
    return {
      token: localStorage.getItem(STORAGE_TOKEN_KEY) || '',
      currentUser: localStorage.getItem(STORAGE_USER_KEY) || '',
      currentUserType: localStorage.getItem(STORAGE_TYPE_KEY) || 'F',
      currentUserCentroId: Number(localStorage.getItem(STORAGE_CENTRO_ID_KEY) || 0),
      currentUserCentroNome: localStorage.getItem(STORAGE_CENTRO_NOME_KEY) || '',
      loading: false,
      loginError: '',
      toasts: [],

      // Configuração da Entidade Mantenedora (ex: "UME - Cachoeira do Sul", "UME - Rio Pardo", "AES - Santa Cruz")
      entidade: {
        id: 1,
        nome_mantenedora: localStorage.getItem(STORAGE_ENTIDADE_NOME_KEY) || 'UME - Cachoeira do Sul',
        sigla_mantenedora: localStorage.getItem(STORAGE_ENTIDADE_SIGLA_KEY) || 'UME',
        subtitulo_sistema: 'Gestão Integrada de Centros Espíritas e Assistência Social',
        cnpj_mantenedora: '',
        cidade_mantenedora: 'Cachoeira do Sul',
        uf_mantenedora: 'RS',
        telefone_mantenedora: '',
        email_mantenedora: '',
        endereco_mantenedora: ''
      },
      showEntidadeModal: false,
      entidadeForm: {},

      loginForm: {
        tenantalias: localStorage.getItem(STORAGE_TENANT_KEY) || 'redefraterna',
        usuario: 'admin',
        senha: ''
      },

      activeTab: 'dashboard',
      sidebarOpen: false,

      // Estado da Página Pública da Agenda Semanal (sem login)
      publicAgendaMode: false,
      publicAgendaLoading: false,
      publicAgendaError: '',
      publicCentroData: null,

      // Estado da Página Pública do Feed de Notícias (sem login)
      publicNoticiasMode: false,
      publicNoticiasLoading: false,
      publicNoticiasError: '',
      publicNoticiasList: [],
      publicCentrosList: [],
      selectedPublicNoticia: null,
      publicFiltroTexto: '',
      publicFiltroCategoria: '',
      publicFiltroCentroId: 0,

      // Dados carregados da API
      dashboard: {
        total_centros: 0,
        total_trabalhadores: 0,
        total_eventos_agenda: 0,
        total_familias: 0,
        total_integrantes: 0,
        total_auxilios: 0,
        total_noticias: 0
      },
      centrosList: [],
      trabalhadoresList: [],
      agendaList: [],
      noticiasList: [],
      familiasList: [],
      auxiliosList: [],
      logsList: [],
      usuariosList: [],

      // Filtros das abas
      filtroFamiliaTexto: '',
      filtroFamiliaCentroId: 0,
      filtroFamiliaSituacao: '',

      filtroAuxilioFamiliaId: 0,
      filtroAuxilioCentroId: 0,
      filtroAuxilioTipo: '',

      filtroTrabalhadorCentroId: 0,
      filtroTrabalhadorTexto: '',

      filtroAgendaCentroId: 0,
      filtroAgendaDia: '',
      filtroAgendaTipo: '',

      filtroNoticiaTexto: '',
      filtroNoticiaCategoria: '',
      filtroNoticiaCentroId: 0,
      filtroNoticiaPublicado: '',

      filtroLogFamiliaId: 0,
      filtroLogTexto: '',

      // Constantes de domínio
      categoriasNoticia: [
        { value: 'COMUNICADO', label: 'Comunicado' },
        { value: 'EVENTO', label: 'Evento / Encontro' },
        { value: 'PALESTRA', label: 'Palestra Especial' },
        { value: 'CAMPANHA', label: 'Campanha Fraterna' },
        { value: 'ESTUDO', label: 'Curso / Estudo' },
        { value: 'ARTIGO', label: 'Artigo / Mensagem' }
      ],

      diasSemana: [
        'Domingo',
        'Segunda-feira',
        'Terça-feira',
        'Quarta-feira',
        'Quinta-feira',
        'Sexta-feira',
        'Sábado'
      ],

      diasSemanaCurto: [
        'Dom',
        'Seg',
        'Ter',
        'Qua',
        'Qui',
        'Sex',
        'Sáb'
      ],

      tiposEventoAgenda: [
        { value: 'EXPOSICAO_PUBLICA', label: 'Exposição Pública / Palestra e Passes' },
        { value: 'ESTUDO_SISTEMATIZADO', label: 'Estudo Sistematizado (ESDE / EADE)' },
        { value: 'REUNIAO_MEDIUNICA', label: 'Reunião / Estudo Mediúnico' },
        { value: 'ATENDIMENTO_FRATERNO', label: 'Atendimento Fraterno / Diálogo' },
        { value: 'EVANGELIZACAO', label: 'Evangelização Infantil e Mocidade' },
        { value: 'ASSISTENCIA_SOCIAL', label: 'Assistência e Promoção Social' },
        { value: 'OUTRO_EVENTO', label: 'Outros Eventos / Reuniões da Casa' }
      ],

      tiposAuxilio: [
        { value: 'CESTA_BASICA', label: 'Cesta Básica / Alimentos' },
        { value: 'DINHEIRO', label: 'Ajuda em Dinheiro / Contas Emergenciais' },
        { value: 'SAUDE_MEDICAMENTO', label: 'Auxílio de Saúde / Medicamentos' },
        { value: 'VESTUARIO', label: 'Vestuário, Cobertores e Calçados' },
        { value: 'MATERIAL_ESCOLAR', label: 'Material Escolar' },
        { value: 'ENXOVAL_BEBE', label: 'Enxoval de Bebê / Fraldas' },
        { value: 'VISITA_FRATERNA', label: 'Visita Fraterna / Orientação' },
        { value: 'OUTROS', label: 'Outros Auxílios' }
      ],

      // Modais e Formulários
      showFamiliaModal: false,
      familiaForm: {},

      fichaFamilia: null,
      fichaTab: 'integrantes',
      integranteForm: {},

      showAuxilioModal: false,
      auxilioForm: {},

      showCentroModal: false,
      centroModalTab: 'dados',
      centroForm: {},
      centroAgendaItems: [],
      centroAgendaDeletedIds: [],
      centroAgendaEditIndex: null,
      centroAgendaItemForm: {},

      showTrabalhadorModal: false,
      trabalhadorForm: {},

      showAgendaModal: false,
      agendaForm: {},

      showNoticiaModal: false,
      noticiaForm: {},

      showUsuarioModal: false,
      usuarioForm: {},

      selectedLogDetail: null,

      showPasswordModal: false,
      passwordForm: { senha_atual: '', nova_senha: '', confirma_senha: '' }
    };
  },

  computed: {
    // Administrador ('A') e Operador do Sistema ('O') podem criar/editar/excluir cadastros estruturais
    canEditSystem() {
      return this.currentUserType === 'A' || this.currentUserType === 'O';
    },

    filteredFamilias() {
      const q = (this.filtroFamiliaTexto || '').toLowerCase().trim();
      const qDigits = q.replace(/\D/g, '');
      return this.familiasList.filter(f => {
        if (this.filtroFamiliaCentroId > 0 && Number(f.centro_id) !== Number(this.filtroFamiliaCentroId)) {
          return false;
        }
        if (this.filtroFamiliaSituacao && f.situacao !== this.filtroFamiliaSituacao) {
          return false;
        }
        if (q) {
          const hay = `${f.nome_referencia || ''} ${f.cpf_responsavel || ''} ${f.logradouro || ''} ${f.bairro || ''} ${f.telefone || ''} ${f.observacoes || ''}`.toLowerCase();
          const cpfDigits = String(f.cpf_responsavel || '').replace(/\D/g, '');
          if (!hay.includes(q) && (!qDigits || !cpfDigits.includes(qDigits))) return false;
        }
        return true;
      });
    },

    filteredAuxilios() {
      return this.auxiliosList.filter(a => {
        if (this.filtroAuxilioFamiliaId > 0 && Number(a.familia_id) !== Number(this.filtroAuxilioFamiliaId)) {
          return false;
        }
        if (this.filtroAuxilioCentroId > 0 && Number(a.centro_id) !== Number(this.filtroAuxilioCentroId)) {
          return false;
        }
        if (this.filtroAuxilioTipo && a.tipo_auxilio !== this.filtroAuxilioTipo) {
          return false;
        }
        return true;
      });
    },

    filteredTrabalhadores() {
      const q = (this.filtroTrabalhadorTexto || '').toLowerCase().trim();
      return this.trabalhadoresList.filter(t => {
        if (this.filtroTrabalhadorCentroId > 0 && Number(t.centro_id) !== Number(this.filtroTrabalhadorCentroId)) {
          return false;
        }
        if (q) {
          const hay = `${t.nome || ''} ${t.funcao || ''} ${t.departamento || ''} ${t.cpf || ''}`.toLowerCase();
          if (!hay.includes(q)) return false;
        }
        return true;
      });
    },

    filteredAgenda() {
      return this.agendaList
        .filter(ev => {
          if (this.filtroAgendaCentroId > 0 && Number(ev.centro_id) !== Number(this.filtroAgendaCentroId)) {
            return false;
          }
          if (this.filtroAgendaDia !== '' && Number(ev.dia_semana) !== Number(this.filtroAgendaDia)) {
            return false;
          }
          if (this.filtroAgendaTipo && ev.tipo_evento !== this.filtroAgendaTipo) {
            return false;
          }
          return true;
        })
        .sort((a, b) => {
          const d = Number(a.dia_semana || 0) - Number(b.dia_semana || 0);
          if (d !== 0) return d;
          return String(a.horario_inicio || '').localeCompare(String(b.horario_inicio || ''));
        });
    },

    filteredLogs() {
      const q = (this.filtroLogTexto || '').toLowerCase().trim();
      return this.logsList.filter(l => {
        if (this.filtroLogFamiliaId > 0 && Number(l.familia_id) !== Number(this.filtroLogFamiliaId)) {
          return false;
        }
        if (q) {
          const hay = `${l.resumo_alteracao || ''} ${l.acao || ''} ${l.entidade || ''} ${l.usuario_nome || ''}`.toLowerCase();
          if (!hay.includes(q)) return false;
        }
        return true;
      });
    },

    publicAgendaGroupedByDay() {
      if (!this.publicCentroData || !Array.isArray(this.publicCentroData.agenda)) {
        return [];
      }
      const groups = [];
      for (let d = 0; d <= 6; d++) {
        const items = this.publicCentroData.agenda
          .filter(ev => Number(ev.dia_semana) === d)
          .sort((a, b) => String(a.horario_inicio || '').localeCompare(String(b.horario_inicio || '')));
        if (items.length > 0) {
          groups.push({
            diaIndex: d,
            diaNome: this.diasSemana[d],
            eventos: items
          });
        }
      }
      return groups;
    },

    filteredNoticias() {
      const q = (this.filtroNoticiaTexto || '').toLowerCase().trim();
      return this.noticiasList
        .filter(n => {
          if (this.filtroNoticiaCategoria && n.categoria !== this.filtroNoticiaCategoria) {
            return false;
          }
          if (this.filtroNoticiaPublicado && (n.publicado || 'S') !== this.filtroNoticiaPublicado) {
            return false;
          }
          if (this.filtroNoticiaCentroId === -1 && Number(n.centro_id || 0) > 0) {
            return false;
          }
          if (this.filtroNoticiaCentroId > 0 && Number(n.centro_id || 0) !== Number(this.filtroNoticiaCentroId)) {
            return false;
          }
          if (q) {
            const hay = `${n.titulo || ''} ${n.resumo || ''} ${n.conteudo || ''} ${n.autor || ''}`.toLowerCase();
            if (!hay.includes(q)) return false;
          }
          return true;
        })
        .sort((a, b) => {
          if (a.destaque !== b.destaque) return a.destaque === 'S' ? -1 : 1;
          const dt = String(b.data_publicacao || '').localeCompare(String(a.data_publicacao || ''));
          if (dt !== 0) return dt;
          return Number(b.id || 0) - Number(a.id || 0);
        });
    },

    filteredPublicNoticias() {
      const q = (this.publicFiltroTexto || '').toLowerCase().trim();
      return this.publicNoticiasList.filter(n => {
        if (this.publicFiltroCategoria && n.categoria !== this.publicFiltroCategoria) {
          return false;
        }
        if (this.publicFiltroCentroId === -1 && Number(n.centro_id || 0) > 0) {
          return false;
        }
        if (this.publicFiltroCentroId > 0 && Number(n.centro_id || 0) !== Number(this.publicFiltroCentroId)) {
          return false;
        }
        if (q) {
          const hay = `${n.titulo || ''} ${n.resumo || ''} ${n.conteudo || ''} ${n.autor || ''} ${n.centro_nome || ''}`.toLowerCase();
          if (!hay.includes(q)) return false;
        }
        return true;
      });
    }
  },

  mounted() {
    const params = new URLSearchParams(window.location.search);
    const agendaCentroId = Number(params.get('agenda_centro') || 0);
    const feedParam = (params.get('feed') || '').toLowerCase();
    const noticiasParam = params.get('noticias');
    const noticiaIdParam = Number(params.get('noticia_id') || 0);
    const tenantParam = params.get('tenant') || this.loginForm.tenantalias || 'redefraterna';

    if (agendaCentroId > 0) {
      this.publicAgendaMode = true;
      this.loadPublicAgenda(agendaCentroId, tenantParam);
      return;
    }

    if (feedParam === 'noticias' || noticiasParam === '1' || noticiaIdParam > 0) {
      this.publicNoticiasMode = true;
      const centroFilter = Number(params.get('centro_id') || 0);
      if (centroFilter > 0) {
        this.publicFiltroCentroId = centroFilter;
      }
      this.loadPublicNoticias(tenantParam, noticiaIdParam);
      return;
    }

    if (this.token) {
      this.loadAllInitialData();
    } else {
      this.loadPublicEntidade(tenantParam);
    }
  },

  methods: {
    notify(message, type = 'info') {
      const id = Date.now() + Math.random();
      this.toasts.push({ id, message, type });
      setTimeout(() => this.removeToast(id), 4500);
    },

    removeToast(id) {
      this.toasts = this.toasts.filter(t => t.id !== id);
    },

    roleLabel(tp) {
      if (tp === 'A') return 'Administrador';
      if (tp === 'O') return 'Operador do Sistema';
      return 'Operador da Família';
    },

    fillDemoLogin(user, pass) {
      this.loginForm.usuario = user;
      this.loginForm.senha = pass;
      this.doLogin();
    },

    async apiFetch(url, options = {}) {
      const headers = Object.assign({
        'Content-Type': 'application/json'
      }, options.headers || {});

      if (this.token) {
        headers['Authorization'] = `Bearer ${this.token}`;
      }

      const response = await fetch(url, Object.assign({}, options, { headers }));

      if (response.status === 401) {
        this.doLogout(false);
        throw new Error('Sessão expirada ou não autorizada. Faça login novamente.');
      }

      if (response.status === 204) {
        return null;
      }

      let data = null;
      const text = await response.text();
      if (text) {
        try {
          data = JSON.parse(text);
        } catch (e) {
          data = { raw: text };
        }
      }

      if (!response.ok) {
        const msg = (data && data.error) ? data.error : `Erro HTTP ${response.status}`;
        throw new Error(msg);
      }

      return data;
    },

    async doLogin() {
      this.loading = true;
      this.loginError = '';
      try {
        const payload = {
          usuario: this.loginForm.usuario.trim(),
          senha: this.loginForm.senha,
          tenantalias: (this.loginForm.tenantalias || 'redefraterna').trim(),
          systemid: 1
        };

        const res = await fetch('/api/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });

        const data = await res.json();
        if (!res.ok) {
          throw new Error(data.error || 'Falha no login');
        }

        this.token = data.token;
        this.currentUser = payload.usuario;
        this.currentUserType = data.user_type || 'F';

        localStorage.setItem(STORAGE_TOKEN_KEY, this.token);
        localStorage.setItem(STORAGE_USER_KEY, this.currentUser);
        localStorage.setItem(STORAGE_TYPE_KEY, this.currentUserType);
        localStorage.setItem(STORAGE_TENANT_KEY, payload.tenantalias);

        this.loginForm.senha = '';
        this.activeTab = 'dashboard';
        this.notify(`Bem-vindo(a), ${this.currentUser}!`, 'success');
        await this.loadAllInitialData();
      } catch (err) {
        this.loginError = err.message;
      } finally {
        this.loading = false;
      }
    },

    doLogout(showMessage = true) {
      this.token = '';
      this.currentUser = '';
      this.currentUserType = 'F';
      this.currentUserCentroId = 0;
      this.currentUserCentroNome = '';
      this.fichaFamilia = null;
      localStorage.removeItem(STORAGE_TOKEN_KEY);
      localStorage.removeItem(STORAGE_USER_KEY);
      localStorage.removeItem(STORAGE_TYPE_KEY);
      localStorage.removeItem(STORAGE_CENTRO_ID_KEY);
      localStorage.removeItem(STORAGE_CENTRO_NOME_KEY);
      if (showMessage) {
        this.notify('Você saiu do sistema.', 'info');
      }
    },

    applyEntidadeData(ent) {
      if (!ent || typeof ent !== 'object') return;
      this.entidade = {
        id: Number(ent.id || 1),
        nome_mantenedora: ent.nome_mantenedora || 'UME - Cachoeira do Sul',
        sigla_mantenedora: ent.sigla_mantenedora || 'UME',
        subtitulo_sistema: ent.subtitulo_sistema || 'Gestão Integrada de Centros Espíritas e Assistência Social',
        cnpj_mantenedora: ent.cnpj_mantenedora || '',
        cidade_mantenedora: ent.cidade_mantenedora || 'Cachoeira do Sul',
        uf_mantenedora: ent.uf_mantenedora || 'RS',
        telefone_mantenedora: ent.telefone_mantenedora || '',
        email_mantenedora: ent.email_mantenedora || '',
        endereco_mantenedora: ent.endereco_mantenedora || ''
      };
      localStorage.setItem(STORAGE_ENTIDADE_NOME_KEY, this.entidade.nome_mantenedora);
      localStorage.setItem(STORAGE_ENTIDADE_SIGLA_KEY, this.entidade.sigla_mantenedora);
      if (!this.publicAgendaMode && !this.publicNoticiasMode) {
        document.title = `Rede Fraterna — ${this.entidade.nome_mantenedora}`;
      }
    },

    async loadPublicEntidade(tenantAlias = '') {
      try {
        const tenant = (tenantAlias || this.loginForm.tenantalias || 'redefraterna').trim();
        const res = await fetch(`/public/entidade?tenant=${encodeURIComponent(tenant)}`);
        if (res.ok) {
          const data = await res.json();
          this.applyEntidadeData(data);
        }
      } catch (e) {
        // Mantém valor padrão em caso de falha de rede
      }
    },

    openEntidadeModal() {
      if (this.currentUserType !== 'A') return;
      this.entidadeForm = Object.assign({}, this.entidade);
      this.showEntidadeModal = true;
    },

    async saveEntidade() {
      try {
        if (!this.entidadeForm.nome_mantenedora || !this.entidadeForm.nome_mantenedora.trim()) {
          this.notify('Informe o nome da Entidade Mantenedora.', 'warning');
          return;
        }
        const saved = await this.apiFetch('/api/configuracoes', {
          method: 'PUT',
          body: JSON.stringify(this.entidadeForm)
        });
        this.applyEntidadeData(saved);
        if (this.currentUserType === 'A') {
          this.currentUserCentroNome = `Acesso Global (${this.entidade.nome_mantenedora})`;
          localStorage.setItem(STORAGE_CENTRO_NOME_KEY, this.currentUserCentroNome);
        }
        this.showEntidadeModal = false;
        this.notify(`Entidade Mantenedora atualizada para "${this.entidade.nome_mantenedora}"!`, 'success');
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    async loadMeuPerfil() {
      try {
        const perfil = await this.apiFetch('/api/meu-perfil');
        if (perfil) {
          if (perfil.entidade) {
            this.applyEntidadeData(perfil.entidade);
          }
          this.currentUser = perfil.login || this.currentUser;
          this.currentUserType = perfil.tipo || this.currentUserType;
          this.currentUserCentroId = Number(perfil.centro_id || 0);
          if (this.currentUserType === 'A') {
            this.currentUserCentroNome = `Acesso Global (${this.entidade.nome_mantenedora})`;
          } else {
            const siglaStr = perfil.centro_sigla ? ` (${perfil.centro_sigla})` : '';
            this.currentUserCentroNome = perfil.centro_nome ? `${perfil.centro_nome}${siglaStr}` : '';
          }
          localStorage.setItem(STORAGE_USER_KEY, this.currentUser);
          localStorage.setItem(STORAGE_TYPE_KEY, this.currentUserType);
          localStorage.setItem(STORAGE_CENTRO_ID_KEY, String(this.currentUserCentroId));
          localStorage.setItem(STORAGE_CENTRO_NOME_KEY, this.currentUserCentroNome);
        }
      } catch (e) {
        // Ignora erro caso sessão tenha expirado (apiFetch já desloga em 401)
      }
    },

    async switchTab(tab) {
      this.activeTab = tab;
      this.sidebarOpen = false;
      if (tab === 'dashboard') {
        await Promise.all([this.loadDashboard(), this.loadLogs()]);
      } else if (tab === 'familias') {
        await this.loadFamilias();
      } else if (tab === 'auxilios') {
        await this.loadAuxilios();
      } else if (tab === 'centros') {
        await this.loadCentros();
      } else if (tab === 'trabalhadores') {
        await this.loadTrabalhadores();
      } else if (tab === 'agenda') {
        await this.loadAgenda();
      } else if (tab === 'noticias') {
        await this.loadNoticias();
      } else if (tab === 'logs') {
        await this.loadLogs();
      } else if (tab === 'usuarios' && this.currentUserType === 'A') {
        await this.loadUsuarios();
      }
    },

    async loadAllInitialData() {
      try {
        await this.loadMeuPerfil();
        const tasks = [
          this.loadDashboard(),
          this.loadCentros(),
          this.loadFamilias(),
          this.loadAuxilios(),
          this.loadTrabalhadores(),
          this.loadAgenda(),
          this.loadNoticias(),
          this.loadLogs()
        ];
        if (this.currentUserType === 'A') {
          tasks.push(this.loadUsuarios());
        }
        await Promise.all(tasks);
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    async loadDashboard() {
      this.dashboard = await this.apiFetch('/api/dashboard');
    },

    async loadCentros() {
      this.centrosList = await this.apiFetch('/api/centros?limit=500');
    },

    async loadTrabalhadores() {
      this.trabalhadoresList = await this.apiFetch('/api/trabalhadores?limit=500');
    },

    async loadAgenda() {
      this.agendaList = await this.apiFetch('/api/agenda?limit=500');
    },

    async loadNoticias() {
      this.noticiasList = await this.apiFetch('/api/noticias?limit=500', {
        headers: { 'X-Sort': 'id', 'X-Order': 'DESC' }
      });
    },

    async loadFamilias() {
      this.familiasList = await this.apiFetch('/api/familias-detalhadas');
    },

    async loadAuxilios() {
      this.auxiliosList = await this.apiFetch('/api/auxilios?limit=500', {
        headers: { 'X-Sort': 'id', 'X-Order': 'DESC' }
      });
    },

    async loadLogs() {
      this.logsList = await this.apiFetch('/api/familia-logs?limit=500', {
        headers: { 'X-Sort': 'id', 'X-Order': 'DESC' }
      });
    },

    async loadUsuarios() {
      if (this.currentUserType !== 'A') return;
      this.usuariosList = await this.apiFetch('/api/usuarios?limit=500');
    },

    // =========================================================================
    // FAMÍLIAS E VÍNCULO COM CENTRO ESPÍRITA
    // =========================================================================
    openFamiliaModal(fam = null) {
      if (fam && fam.id) {
        this.familiaForm = {
          id: fam.id,
          centro_id: Number(fam.centro_id || 0),
          nome_referencia: fam.nome_referencia || '',
          cpf_responsavel: fam.cpf_responsavel || '',
          telefone: fam.telefone || '',
          cep: fam.cep || '',
          logradouro: fam.logradouro || '',
          numero: fam.numero || '',
          complemento: fam.complemento || '',
          bairro: fam.bairro || '',
          cidade: fam.cidade || '',
          uf: fam.uf || '',
          situacao: fam.situacao || 'ATIVA',
          renda_familiar: Number(fam.renda_familiar || 0),
          observacoes: fam.observacoes || ''
        };
      } else {
        const defaultCentro = this.currentUserType !== 'A'
          ? (this.currentUserCentroId || (this.centrosList[0] ? this.centrosList[0].id : 0))
          : (this.centrosList.length > 0 ? this.centrosList[0].id : 0);
        this.familiaForm = {
          id: 0,
          centro_id: defaultCentro,
          nome_referencia: '',
          cpf_responsavel: '',
          telefone: '',
          cep: '',
          logradouro: '',
          numero: '',
          complemento: '',
          bairro: '',
          cidade: this.entidade.cidade_mantenedora || 'Cachoeira do Sul',
          uf: this.entidade.uf_mantenedora || 'RS',
          situacao: 'ATIVA',
          renda_familiar: 0,
          observacoes: ''
        };
      }
      this.showFamiliaModal = true;
    },

    async saveFamilia() {
      try {
        const isEdit = Boolean(this.familiaForm.id);
        const payload = Object.assign({}, this.familiaForm);
        delete payload.id;
        if (isEdit) {
          payload._usuario_log = this.currentUser;
        }

        const saved = await this.apiFetch(isEdit ? `/api/familias/${this.familiaForm.id}` : '/api/familias', {
          method: isEdit ? 'PUT' : 'POST',
          body: JSON.stringify(payload)
        });

        this.showFamiliaModal = false;
        this.notify(isEdit ? 'Família atualizada e log registrado com sucesso!' : 'Família cadastrada e vinculada com sucesso!', 'success');
        await Promise.all([this.loadFamilias(), this.loadDashboard(), this.loadLogs()]);

        // Se foi recém-criada, já abre a ficha completa para cadastrar integrantes
        if (!isEdit && saved && saved.id) {
          await this.openFichaFamilia(saved.id, 'integrantes');
        }
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    async deleteFamilia(fam) {
      if (!confirm(`Deseja realmente inativar/excluir a família "${fam.nome_referencia}"?`)) return;
      try {
        await this.apiFetch(`/api/familias/${fam.id}`, { method: 'DELETE' });
        this.notify('Família excluída com sucesso.', 'success');
        await Promise.all([this.loadFamilias(), this.loadDashboard(), this.loadLogs()]);
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    // =========================================================================
    // FICHA COMPLETA DA FAMÍLIA E INTEGRANTES
    // =========================================================================
    async openFichaFamilia(familiaId, defaultTab = 'integrantes') {
      try {
        const data = await this.apiFetch(`/api/familias/${familiaId}/completa`);
        this.fichaFamilia = data;
        this.fichaTab = defaultTab;
        this.resetIntegranteForm();
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    resetIntegranteForm() {
      this.integranteForm = {
        id: 0,
        familia_id: this.fichaFamilia ? this.fichaFamilia.id : 0,
        nome: '',
        cpf: '',
        data_nascimento: '',
        papel_familia: 'Filho(a)',
        info_adicionais: ''
      };
    },

    editIntegrante(intg) {
      this.integranteForm = {
        id: intg.id,
        familia_id: intg.familia_id,
        nome: intg.nome || '',
        cpf: intg.cpf || '',
        data_nascimento: (intg.data_nascimento || '').substring(0, 10),
        papel_familia: intg.papel_familia || 'Filho(a)',
        info_adicionais: intg.info_adicionais || ''
      };
    },

    async saveIntegrante() {
      if (!this.fichaFamilia) return;
      try {
        const isEdit = Boolean(this.integranteForm.id);
        const payload = {
          familia_id: this.fichaFamilia.id,
          nome: this.integranteForm.nome,
          cpf: this.integranteForm.cpf,
          papel_familia: this.integranteForm.papel_familia,
          info_adicionais: this.integranteForm.info_adicionais
        };
        if (this.integranteForm.data_nascimento) {
          payload.data_nascimento = this.integranteForm.data_nascimento;
        }
        if (isEdit) {
          payload._usuario_log = this.currentUser;
        }

        await this.apiFetch(isEdit ? `/api/integrantes/${this.integranteForm.id}` : '/api/integrantes', {
          method: isEdit ? 'PUT' : 'POST',
          body: JSON.stringify(payload)
        });

        this.notify(isEdit ? 'Integrante atualizado!' : 'Integrante adicionado à família!', 'success');
        await this.openFichaFamilia(this.fichaFamilia.id, 'integrantes');
        await Promise.all([this.loadFamilias(), this.loadDashboard(), this.loadLogs()]);
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    async deleteIntegrante(intg) {
      if (!confirm(`Remover o integrante "${intg.nome}" desta família?`)) return;
      try {
        await this.apiFetch(`/api/integrantes/${intg.id}`, { method: 'DELETE' });
        this.notify('Integrante removido.', 'success');
        await this.openFichaFamilia(this.fichaFamilia.id, 'integrantes');
        await Promise.all([this.loadFamilias(), this.loadDashboard(), this.loadLogs()]);
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    // =========================================================================
    // HISTÓRICO DE AUXÍLIOS
    // =========================================================================
    openAuxilioModal(preset = null) {
      const today = new Date().toISOString().substring(0, 10);
      if (preset && preset.id) {
        this.auxilioForm = {
          id: preset.id,
          familia_id: Number(preset.familia_id || 0),
          centro_id: Number(preset.centro_id || 0),
          data_auxilio: (preset.data_auxilio || today).substring(0, 10),
          tipo_auxilio: preset.tipo_auxilio || 'CESTA_BASICA',
          descricao: preset.descricao || '',
          quantidade: preset.quantidade || '',
          valor_estimado: Number(preset.valor_estimado || 0),
          responsavel_entrega: preset.responsavel_entrega || this.currentUser,
          observacoes: preset.observacoes || ''
        };
      } else {
        const famId = (preset && preset.familia_id) ? Number(preset.familia_id) : (this.familiasList[0] ? this.familiasList[0].id : 0);
        const famObj = this.familiasList.find(f => Number(f.id) === Number(famId));
        const cenId = (preset && preset.centro_id) ? Number(preset.centro_id) : (famObj ? Number(famObj.centro_id) : (this.centrosList[0] ? this.centrosList[0].id : 0));

        this.auxilioForm = {
          id: 0,
          familia_id: famId,
          centro_id: cenId,
          data_auxilio: today,
          tipo_auxilio: 'CESTA_BASICA',
          descricao: '',
          quantidade: '1 unidade',
          valor_estimado: 0,
          responsavel_entrega: this.currentUser,
          observacoes: ''
        };
      }
      this.showAuxilioModal = true;
    },

    onSelectAuxilioFamilia() {
      const fam = this.familiasList.find(f => Number(f.id) === Number(this.auxilioForm.familia_id));
      if (fam && fam.centro_id) {
        this.auxilioForm.centro_id = Number(fam.centro_id);
      }
    },

    async saveAuxilio() {
      try {
        const isEdit = Boolean(this.auxilioForm.id);
        const payload = Object.assign({}, this.auxilioForm, {
          usuario_nome: this.currentUser
        });
        delete payload.id;

        await this.apiFetch(isEdit ? `/api/auxilios/${this.auxilioForm.id}` : '/api/auxilios', {
          method: isEdit ? 'PUT' : 'POST',
          body: JSON.stringify(payload)
        });

        this.showAuxilioModal = false;
        this.notify(isEdit ? 'Auxílio atualizado!' : 'Auxílio registrado no histórico da família!', 'success');
        await Promise.all([this.loadAuxilios(), this.loadFamilias(), this.loadDashboard(), this.loadLogs()]);
        if (this.fichaFamilia && Number(this.fichaFamilia.id) === Number(payload.familia_id)) {
          await this.openFichaFamilia(this.fichaFamilia.id, 'auxilios');
        }
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    async deleteAuxilio(aux) {
      if (!confirm(`Deseja excluir o registro de auxílio "${aux.descricao}"?`)) return;
      try {
        await this.apiFetch(`/api/auxilios/${aux.id}`, { method: 'DELETE' });
        this.notify('Registro de auxílio excluído.', 'success');
        await Promise.all([this.loadAuxilios(), this.loadFamilias(), this.loadDashboard(), this.loadLogs()]);
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    // =========================================================================
    // CENTROS ESPÍRITAS + AGENDA SEMANAL (MESTRE / DETALHE) + LINK PÚBLICO
    // =========================================================================
    getPublicAgendaUrl(centroId) {
      const tenant = encodeURIComponent(this.loginForm.tenantalias || 'redefraterna');
      return `${window.location.origin}/?agenda_centro=${centroId}&tenant=${tenant}`;
    },

    async copyPublicAgendaUrl(centroId) {
      const url = this.getPublicAgendaUrl(centroId);
      try {
        await navigator.clipboard.writeText(url);
        this.notify('Link público da agenda copiado para a área de transferência!', 'success');
      } catch (e) {
        prompt('Copie o link público da agenda abaixo:', url);
      }
    },

    async loadPublicAgenda(centroId, tenantAlias) {
      this.publicAgendaLoading = true;
      this.publicAgendaError = '';
      try {
        const res = await fetch(`/public/agenda/${centroId}?tenant=${encodeURIComponent(tenantAlias || 'redefraterna')}`);
        const data = await res.json();
        if (!res.ok) {
          throw new Error(data.error || 'Não foi possível carregar a agenda pública deste centro.');
        }
        this.publicCentroData = data;
        if (data && data.entidade) {
          this.applyEntidadeData(data.entidade);
        }
        if (data && data.nome) {
          document.title = `Agenda Semanal — ${data.nome} | ${this.entidade.nome_mantenedora}`;
        }
      } catch (err) {
        this.publicAgendaError = err.message;
      } finally {
        this.publicAgendaLoading = false;
      }
    },

    getAgendaDoCentro(centroId) {
      return this.agendaList
        .filter(ev => Number(ev.centro_id) === Number(centroId))
        .sort((a, b) => {
          const d = Number(a.dia_semana || 0) - Number(b.dia_semana || 0);
          if (d !== 0) return d;
          return String(a.horario_inicio || '').localeCompare(String(b.horario_inicio || ''));
        });
    },

    resetCentroAgendaItemForm() {
      this.centroAgendaEditIndex = null;
      this.centroAgendaItemForm = {
        id: 0,
        dia_semana: 1,
        horario_inicio: '20:00',
        horario_fim: '21:30',
        tipo_evento: 'EXPOSICAO_PUBLICA',
        titulo: '',
        responsavel: '',
        sala_local: 'Salão Principal',
        descricao: ''
      };
    },

    openCentroModal(centro = null, defaultTab = 'dados') {
      this.centroModalTab = defaultTab || 'dados';
      this.centroAgendaDeletedIds = [];
      this.resetCentroAgendaItemForm();

      if (centro && centro.id) {
        this.centroForm = Object.assign({}, centro);
        this.centroAgendaItems = this.getAgendaDoCentro(centro.id).map(ev => Object.assign({}, ev));
      } else {
        this.centroForm = {
          id: 0,
          nome: '',
          sigla: '',
          cnpj: '',
          presidente: '',
          telefone: '',
          email: '',
          logradouro: '',
          numero: '',
          bairro: '',
          cidade: this.entidade.cidade_mantenedora || 'Cachoeira do Sul',
          uf: this.entidade.uf_mantenedora || 'RS',
          observacoes: ''
        };
        this.centroAgendaItems = [];
      }
      this.showCentroModal = true;
    },

    addOrUpdateCentroAgendaItem() {
      const item = this.centroAgendaItemForm;
      if (!item.titulo || !item.titulo.trim()) {
        this.notify('Informe o título da atividade / exposição na agenda.', 'warning');
        return;
      }
      if (!item.horario_inicio) {
        this.notify('Informe o horário de início da atividade.', 'warning');
        return;
      }

      const copy = {
        id: item.id || 0,
        dia_semana: Number(item.dia_semana || 0),
        horario_inicio: item.horario_inicio,
        horario_fim: item.horario_fim || '',
        tipo_evento: item.tipo_evento || 'EXPOSICAO_PUBLICA',
        titulo: item.titulo.trim(),
        responsavel: (item.responsavel || '').trim(),
        sala_local: (item.sala_local || '').trim(),
        descricao: (item.descricao || '').trim(),
        _modified: true
      };

      if (this.centroAgendaEditIndex !== null && this.centroAgendaItems[this.centroAgendaEditIndex]) {
        this.centroAgendaItems.splice(this.centroAgendaEditIndex, 1, copy);
        this.notify('Atividade atualizada na lista da agenda.', 'info');
      } else {
        this.centroAgendaItems.push(copy);
        this.notify('Atividade incluída na lista da agenda.', 'info');
      }

      this.centroAgendaItems.sort((a, b) => {
        const d = Number(a.dia_semana || 0) - Number(b.dia_semana || 0);
        if (d !== 0) return d;
        return String(a.horario_inicio || '').localeCompare(String(b.horario_inicio || ''));
      });

      this.resetCentroAgendaItemForm();
    },

    editCentroAgendaItem(idx) {
      const target = this.centroAgendaItems[idx];
      if (!target) return;
      this.centroAgendaEditIndex = idx;
      this.centroAgendaItemForm = {
        id: target.id || 0,
        dia_semana: Number(target.dia_semana || 0),
        horario_inicio: target.horario_inicio || '20:00',
        horario_fim: target.horario_fim || '',
        tipo_evento: target.tipo_evento || 'EXPOSICAO_PUBLICA',
        titulo: target.titulo || '',
        responsavel: target.responsavel || '',
        sala_local: target.sala_local || '',
        descricao: target.descricao || ''
      };
    },

    removeCentroAgendaItem(idx) {
      const target = this.centroAgendaItems[idx];
      if (!target) return;
      if (target.id && Number(target.id) > 0) {
        this.centroAgendaDeletedIds.push(Number(target.id));
      }
      this.centroAgendaItems.splice(idx, 1);
      if (this.centroAgendaEditIndex === idx) {
        this.resetCentroAgendaItemForm();
      }
    },

    async saveCentro() {
      try {
        if (!this.centroForm.nome || !this.centroForm.nome.trim()) {
          this.centroModalTab = 'dados';
          this.notify('Informe o nome do Centro Espírita.', 'warning');
          return;
        }

        // Caso o usuário tenha preenchido o sub-formulário da agenda mas esquecido de clicar em "Incluir na Agenda", inclui automaticamente
        if (this.centroAgendaItemForm && this.centroAgendaItemForm.titulo && this.centroAgendaItemForm.titulo.trim()) {
          this.addOrUpdateCentroAgendaItem();
        }

        const isEdit = Boolean(this.centroForm.id);
        const payload = Object.assign({}, this.centroForm);
        delete payload.id;

        const savedCentro = await this.apiFetch(isEdit ? `/api/centros/${this.centroForm.id}` : '/api/centros', {
          method: isEdit ? 'PUT' : 'POST',
          body: JSON.stringify(payload)
        });

        const centroId = isEdit ? Number(this.centroForm.id) : Number(savedCentro && savedCentro.id ? savedCentro.id : 0);

        // Processa exclusões de itens da agenda (Detalhe)
        for (const delId of this.centroAgendaDeletedIds) {
          await this.apiFetch(`/api/agenda/${delId}`, { method: 'DELETE' });
        }

        // Processa criações e atualizações dos itens da agenda (Detalhe)
        if (centroId > 0) {
          for (const item of this.centroAgendaItems) {
            const itemPayload = {
              centro_id: centroId,
              dia_semana: Number(item.dia_semana || 0),
              horario_inicio: item.horario_inicio,
              horario_fim: item.horario_fim || '',
              tipo_evento: item.tipo_evento || 'EXPOSICAO_PUBLICA',
              titulo: item.titulo,
              responsavel: item.responsavel || '',
              sala_local: item.sala_local || '',
              descricao: item.descricao || ''
            };

            if (item.id && Number(item.id) > 0) {
              if (item._modified) {
                await this.apiFetch(`/api/agenda/${item.id}`, {
                  method: 'PUT',
                  body: JSON.stringify(itemPayload)
                });
              }
            } else {
              await this.apiFetch('/api/agenda', {
                method: 'POST',
                body: JSON.stringify(itemPayload)
              });
            }
          }
        }

        this.showCentroModal = false;
        this.notify(isEdit ? 'Centro Espírita e Agenda Semanal atualizados!' : 'Centro Espírita e Agenda Semanal cadastrados!', 'success');
        await Promise.all([this.loadCentros(), this.loadAgenda(), this.loadDashboard()]);
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    async deleteCentro(centro) {
      if (!confirm(`Excluir o centro "${centro.nome}"?`)) return;
      try {
        await this.apiFetch(`/api/centros/${centro.id}`, { method: 'DELETE' });
        this.notify('Centro Espírita removido.', 'success');
        await Promise.all([this.loadCentros(), this.loadDashboard()]);
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    // =========================================================================
    // TRABALHADORES DOS CENTROS
    // =========================================================================
    openTrabalhadorModal(trab = null) {
      if (trab && trab.id) {
        this.trabalhadorForm = Object.assign({}, trab, {
          data_nascimento: (trab.data_nascimento || '').substring(0, 10)
        });
      } else {
        const defaultCentro = this.currentUserType !== 'A'
          ? (this.currentUserCentroId || (this.centrosList[0] ? this.centrosList[0].id : 0))
          : (this.filtroTrabalhadorCentroId || (this.centrosList[0] ? this.centrosList[0].id : 0));
        this.trabalhadorForm = {
          id: 0,
          centro_id: defaultCentro,
          nome: '',
          cpf: '',
          data_nascimento: '',
          funcao: '',
          departamento: '',
          telefone: '',
          email: '',
          observacoes: ''
        };
      }
      this.showTrabalhadorModal = true;
    },

    async saveTrabalhador() {
      try {
        const isEdit = Boolean(this.trabalhadorForm.id);
        const payload = Object.assign({}, this.trabalhadorForm);
        delete payload.id;
        if (!payload.data_nascimento) delete payload.data_nascimento;

        await this.apiFetch(isEdit ? `/api/trabalhadores/${this.trabalhadorForm.id}` : '/api/trabalhadores', {
          method: isEdit ? 'PUT' : 'POST',
          body: JSON.stringify(payload)
        });

        this.showTrabalhadorModal = false;
        this.notify(isEdit ? 'Trabalhador atualizado!' : 'Trabalhador cadastrado!', 'success');
        await Promise.all([this.loadTrabalhadores(), this.loadDashboard()]);
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    async deleteTrabalhador(trab) {
      if (!confirm(`Excluir o trabalhador "${trab.nome}"?`)) return;
      try {
        await this.apiFetch(`/api/trabalhadores/${trab.id}`, { method: 'DELETE' });
        this.notify('Trabalhador removido.', 'success');
        await Promise.all([this.loadTrabalhadores(), this.loadDashboard()]);
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    // =========================================================================
    // AGENDA SEMANAL DO CENTRO
    // =========================================================================
    openAgendaModal(ev = null) {
      if (ev && ev.id) {
        this.agendaForm = Object.assign({}, ev);
      } else {
        const defaultCentro = this.currentUserType !== 'A'
          ? (this.currentUserCentroId || (this.centrosList[0] ? this.centrosList[0].id : 0))
          : (this.filtroAgendaCentroId || (this.centrosList[0] ? this.centrosList[0].id : 0));
        this.agendaForm = {
          id: 0,
          centro_id: defaultCentro,
          dia_semana: 1,
          horario_inicio: '20:00',
          horario_fim: '21:30',
          tipo_evento: 'EXPOSICAO_PUBLICA',
          titulo: '',
          responsavel: '',
          sala_local: 'Salão Principal',
          descricao: ''
        };
      }
      this.showAgendaModal = true;
    },

    async saveAgenda() {
      try {
        const isEdit = Boolean(this.agendaForm.id);
        const payload = Object.assign({}, this.agendaForm);
        delete payload.id;

        await this.apiFetch(isEdit ? `/api/agenda/${this.agendaForm.id}` : '/api/agenda', {
          method: isEdit ? 'PUT' : 'POST',
          body: JSON.stringify(payload)
        });

        this.showAgendaModal = false;
        this.notify(isEdit ? 'Atividade da agenda atualizada!' : 'Atividade adicionada à agenda semanal!', 'success');
        await Promise.all([this.loadAgenda(), this.loadDashboard()]);
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    async deleteAgenda(ev) {
      if (!confirm(`Remover "${ev.titulo}" da agenda semanal?`)) return;
      try {
        await this.apiFetch(`/api/agenda/${ev.id}`, { method: 'DELETE' });
        this.notify('Atividade removida da agenda.', 'success');
        await Promise.all([this.loadAgenda(), this.loadDashboard()]);
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    // =========================================================================
    // NOTÍCIAS E FEED PÚBLICO DE NOTÍCIAS
    // =========================================================================
    getPublicFeedUrl(centroId = 0) {
      const tenant = encodeURIComponent(this.loginForm.tenantalias || 'redefraterna');
      let url = `${window.location.origin}/?feed=noticias&tenant=${tenant}`;
      if (centroId && Number(centroId) > 0) {
        url += `&centro_id=${Number(centroId)}`;
      }
      return url;
    },

    getPublicNoticiaUrl(noticiaId) {
      const tenant = encodeURIComponent(this.loginForm.tenantalias || 'redefraterna');
      return `${window.location.origin}/?feed=noticias&noticia_id=${noticiaId}&tenant=${tenant}`;
    },

    async copyPublicFeedUrl(centroId = 0) {
      const url = this.getPublicFeedUrl(centroId);
      try {
        await navigator.clipboard.writeText(url);
        this.notify('Link público do Feed de Notícias copiado para a área de transferência!', 'success');
      } catch (e) {
        prompt('Copie o link público do Feed de Notícias abaixo:', url);
      }
    },

    async copyPublicNoticiaUrl(noticiaId) {
      const url = this.getPublicNoticiaUrl(noticiaId);
      try {
        await navigator.clipboard.writeText(url);
        this.notify('Link direto desta notícia copiado para a área de transferência!', 'success');
      } catch (e) {
        prompt('Copie o link direto desta notícia abaixo:', url);
      }
    },

    async loadPublicNoticias(tenantAlias, initialNoticiaId = 0) {
      this.publicNoticiasLoading = true;
      this.publicNoticiasError = '';
      try {
        const tenant = tenantAlias || this.loginForm.tenantalias || 'redefraterna';
        const res = await fetch(`/public/noticias?tenant=${encodeURIComponent(tenant)}`);
        const data = await res.json();
        if (!res.ok) {
          throw new Error(data.error || 'Não foi possível carregar o feed público de notícias.');
        }
        this.publicNoticiasList = Array.isArray(data.noticias) ? data.noticias : [];
        this.publicCentrosList = Array.isArray(data.centros) ? data.centros : [];
        if (data && data.entidade) {
          this.applyEntidadeData(data.entidade);
        }
        document.title = `Feed de Notícias — ${this.entidade.nome_mantenedora}`;

        if (initialNoticiaId > 0) {
          const found = this.publicNoticiasList.find(n => Number(n.id) === Number(initialNoticiaId));
          if (found) {
            this.openPublicNoticia(found);
          }
        }
      } catch (err) {
        this.publicNoticiasError = err.message;
      } finally {
        this.publicNoticiasLoading = false;
      }
    },

    openPublicNoticia(n) {
      this.selectedPublicNoticia = n;
      window.scrollTo({ top: 0, behavior: 'smooth' });
      if (n && n.titulo) {
        document.title = `${n.titulo} | Notícias Rede Fraterna`;
      }
    },

    closePublicNoticia() {
      this.selectedPublicNoticia = null;
      document.title = `Feed de Notícias — ${this.entidade.nome_mantenedora}`;
    },

    openNoticiaModal(n = null) {
      const today = new Date().toISOString().substring(0, 10);
      if (n && n.id) {
        this.noticiaForm = {
          id: n.id,
          centro_id: Number(n.centro_id || 0),
          titulo: n.titulo || '',
          resumo: n.resumo || '',
          conteudo: n.conteudo || '',
          categoria: n.categoria || 'COMUNICADO',
          autor: n.autor || this.currentUser,
          imagem_url: n.imagem_url || '',
          destaque: n.destaque === 'S' ? 'S' : 'N',
          publicado: (n.publicado || 'S') === 'N' ? 'N' : 'S',
          data_publicacao: (n.data_publicacao || today).substring(0, 10)
        };
      } else {
        const defaultCentro = this.currentUserType !== 'A'
          ? (this.currentUserCentroId || (this.centrosList[0] ? this.centrosList[0].id : 0))
          : 0;
        this.noticiaForm = {
          id: 0,
          centro_id: defaultCentro,
          titulo: '',
          resumo: '',
          conteudo: '',
          categoria: 'COMUNICADO',
          autor: this.currentUser,
          imagem_url: '',
          destaque: 'N',
          publicado: 'S',
          data_publicacao: today
        };
      }
      this.showNoticiaModal = true;
    },

    async saveNoticia() {
      try {
        const isEdit = Boolean(this.noticiaForm.id);
        const payload = {
          centro_id: Number(this.noticiaForm.centro_id || 0),
          titulo: (this.noticiaForm.titulo || '').trim(),
          resumo: (this.noticiaForm.resumo || '').trim(),
          conteudo: (this.noticiaForm.conteudo || '').trim(),
          categoria: this.noticiaForm.categoria || 'COMUNICADO',
          autor: (this.noticiaForm.autor || '').trim(),
          imagem_url: (this.noticiaForm.imagem_url || '').trim(),
          destaque: this.noticiaForm.destaque === 'S' ? 'S' : 'N',
          publicado: this.noticiaForm.publicado === 'N' ? 'N' : 'S',
          data_publicacao: this.noticiaForm.data_publicacao || new Date().toISOString().substring(0, 10)
        };

        await this.apiFetch(isEdit ? `/api/noticias/${this.noticiaForm.id}` : '/api/noticias', {
          method: isEdit ? 'PUT' : 'POST',
          body: JSON.stringify(payload)
        });

        this.showNoticiaModal = false;
        this.notify(isEdit ? 'Notícia atualizada com sucesso!' : 'Notícia salva com sucesso!', 'success');
        await Promise.all([this.loadNoticias(), this.loadDashboard()]);
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    async togglePublicacaoNoticia(n) {
      if (!this.canEditSystem || !n || !n.id) return;
      const novoStatus = (n.publicado || 'S') === 'S' ? 'N' : 'S';
      try {
        await this.apiFetch(`/api/noticias/${n.id}`, {
          method: 'PUT',
          body: JSON.stringify({ publicado: novoStatus })
        });
        n.publicado = novoStatus;
        this.notify(
          novoStatus === 'S'
            ? 'Notícia publicada e visível no Feed Público!'
            : 'Notícia ocultada do Feed Público (mantida apenas no sistema).',
          'info'
        );
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    async deleteNoticia(n) {
      if (!confirm(`Deseja realmente excluir a notícia "${n.titulo}"?`)) return;
      try {
        await this.apiFetch(`/api/noticias/${n.id}`, { method: 'DELETE' });
        this.notify('Notícia removida do feed.', 'success');
        await Promise.all([this.loadNoticias(), this.loadDashboard()]);
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    formatCategoriaNoticia(cat) {
      const found = this.categoriasNoticia.find(x => x.value === cat);
      return found ? found.label : (cat || 'Comunicado');
    },

    noticiaCategoriaBadge(cat) {
      switch (cat) {
        case 'EVENTO': return 'bg-indigo-100 text-indigo-800';
        case 'PALESTRA': return 'bg-sky-100 text-sky-800';
        case 'CAMPANHA': return 'bg-emerald-100 text-emerald-800';
        case 'ESTUDO': return 'bg-teal-100 text-teal-800';
        case 'ARTIGO': return 'bg-purple-100 text-purple-800';
        default: return 'bg-slate-200 text-slate-800';
      }
    },

    // =========================================================================
    // USUÁRIOS DO SISTEMA (APENAS ADMINISTRADOR)
    // =========================================================================
    openUsuarioModal(u = null) {
      const firstCentroId = this.centrosList.length > 0 ? this.centrosList[0].id : 0;
      if (u && u.id) {
        this.usuarioForm = {
          id: u.id,
          nome: u.nome || '',
          login: u.login || '',
          senha: '',
          tipo: u.tipo || 'F',
          centro_id: u.tipo === 'A' ? 0 : Number(u.centro_id || firstCentroId)
        };
      } else {
        this.usuarioForm = {
          id: 0,
          nome: '',
          login: '',
          senha: '',
          tipo: 'F',
          centro_id: firstCentroId
        };
      }
      this.showUsuarioModal = true;
    },

    async saveUsuario() {
      try {
        if (this.usuarioForm.tipo !== 'A' && (!this.usuarioForm.centro_id || Number(this.usuarioForm.centro_id) <= 0)) {
          this.notify('Selecione o Centro Espírita vinculado para este usuário.', 'warning');
          return;
        }
        const isEdit = Boolean(this.usuarioForm.id);
        const payload = {
          nome: this.usuarioForm.nome,
          login: this.usuarioForm.login,
          tipo: this.usuarioForm.tipo,
          centro_id: this.usuarioForm.tipo === 'A' ? null : Number(this.usuarioForm.centro_id || 0)
        };
        if (this.usuarioForm.senha) {
          payload.senha = this.usuarioForm.senha;
        }

        await this.apiFetch(isEdit ? `/api/usuarios/${this.usuarioForm.id}` : '/api/usuarios', {
          method: isEdit ? 'PUT' : 'POST',
          body: JSON.stringify(payload)
        });

        this.showUsuarioModal = false;
        this.notify(isEdit ? 'Usuário atualizado!' : 'Usuário cadastrado!', 'success');
        await this.loadUsuarios();
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    async deleteUsuario(u) {
      if (!confirm(`Deseja excluir/inativar o usuário "${u.nome}" (${u.login})?`)) return;
      try {
        await this.apiFetch(`/api/usuarios/${u.id}`, { method: 'DELETE' });
        this.notify('Usuário inativado.', 'success');
        await this.loadUsuarios();
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    // =========================================================================
    // ALTERAR MINHA SENHA
    // =========================================================================
    openPasswordModal() {
      this.passwordForm = { senha_atual: '', nova_senha: '', confirma_senha: '' };
      this.showPasswordModal = true;
    },

    async changeMyPassword() {
      try {
        await this.apiFetch('/api/minha-senha', {
          method: 'POST',
          body: JSON.stringify(this.passwordForm)
        });
        this.showPasswordModal = false;
        this.notify('Sua senha foi alterada com sucesso!', 'success');
      } catch (err) {
        this.notify(err.message, 'error');
      }
    },

    // =========================================================================
    // FORMATADORES E HELPERS VISUAIS
    // =========================================================================
    formatCPFInput(val) {
      const digits = String(val || '').replace(/\D/g, '').substring(0, 11);
      if (digits.length <= 3) return digits;
      if (digits.length <= 6) return `${digits.slice(0, 3)}.${digits.slice(3)}`;
      if (digits.length <= 9) return `${digits.slice(0, 3)}.${digits.slice(3, 6)}.${digits.slice(6)}`;
      return `${digits.slice(0, 3)}.${digits.slice(3, 6)}.${digits.slice(6, 9)}-${digits.slice(9, 11)}`;
    },

    getCentroName(id) {
      const c = this.centrosList.find(x => Number(x.id) === Number(id));
      return c ? (c.sigla ? `${c.nome} (${c.sigla})` : c.nome) : `Centro #${id || '-'}`;
    },

    getFamiliaName(id) {
      const f = this.familiasList.find(x => Number(x.id) === Number(id));
      return f ? f.nome_referencia : `Família #${id || '-'}`;
    },

    formatEnderecoCurto(obj) {
      if (!obj) return '-';
      const parts = [];
      if (obj.logradouro) parts.push(`${obj.logradouro}${obj.numero ? ', ' + obj.numero : ''}`);
      if (obj.bairro) parts.push(obj.bairro);
      if (obj.cidade) parts.push(`${obj.cidade}${obj.uf ? '/' + obj.uf : ''}`);
      return parts.length ? parts.join(' - ') : '-';
    },

    formatDate(dtStr) {
      if (!dtStr) return '-';
      const clean = String(dtStr).substring(0, 10);
      const parts = clean.split('-');
      if (parts.length === 3) return `${parts[2]}/${parts[1]}/${parts[0]}`;
      return dtStr;
    },

    formatDateTime(dtStr) {
      if (!dtStr) return '-';
      const str = String(dtStr).replace('T', ' ');
      const datePart = str.substring(0, 10).split('-');
      const timePart = str.substring(11, 19);
      if (datePart.length === 3) {
        return `${datePart[2]}/${datePart[1]}/${datePart[0]}${timePart ? ' ' + timePart : ''}`;
      }
      return dtStr;
    },

    formatMoney(val) {
      return Number(val || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    },

    formatTipoAuxilio(tp) {
      const found = this.tiposAuxilio.find(x => x.value === tp);
      return found ? found.label : tp;
    },

    formatTipoEvento(tp) {
      const found = this.tiposEventoAgenda.find(x => x.value === tp);
      return found ? found.label : tp;
    },

    auxilioBadgeClass(tp) {
      switch (tp) {
        case 'CESTA_BASICA': return 'bg-amber-100 text-amber-800';
        case 'DINHEIRO': return 'bg-emerald-100 text-emerald-800';
        case 'SAUDE_MEDICAMENTO': return 'bg-rose-100 text-rose-800';
        case 'MATERIAL_ESCOLAR': return 'bg-sky-100 text-sky-800';
        case 'VESTUARIO': return 'bg-indigo-100 text-indigo-800';
        default: return 'bg-slate-100 text-slate-700';
      }
    },

    logBadgeClass(acao) {
      if (!acao) return 'bg-slate-100 text-slate-700';
      if (acao.includes('CRIACAO') || acao.includes('ADD') || acao.includes('REGISTRADO')) return 'bg-emerald-100 text-emerald-800';
      if (acao.includes('VINCULO')) return 'bg-purple-100 text-purple-800';
      if (acao.includes('DEL') || acao.includes('EXCLUSAO') || acao.includes('EXCLUIDO')) return 'bg-red-100 text-red-800';
      return 'bg-amber-100 text-amber-800';
    },

    formatPrettyJSON(raw) {
      if (!raw) return '';
      try {
        return JSON.stringify(JSON.parse(raw), null, 2);
      } catch (e) {
        return raw;
      }
    }
  }
}).mount('#app');
