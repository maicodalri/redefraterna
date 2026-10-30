📌 Sobre o Projeto

O Rede Fraterna é uma plataforma web completa desenvolvida para atender às demandas administrativas, doutrinárias e de assistência e promoção social das Uniões Municipais Espíritas (como a UME Cachoeira do Sul, UME Rio Pardo, AES Santa Cruz ou qualquer entidade mantenedora) e de todas as casas espíritas filiadas ao seu município ou região.

O objetivo primordial do sistema é integrar as atividades dos centros espíritas, divulgar suas programações públicas e organizar a assistência social às famílias, garantindo que o apoio material e moral chegue a quem realmente precisa através da validação de unicidade de CPF (evitando duplicidade de benefícios entre diferentes casas espíritas) e da rastreabilidade total por auditoria.

✨ Principais Funcionalidades
🏛️ Gestão da Entidade Mantenedora (Multi-UME / AES)
Identidade visual e institucional configurável (ex: UME - Cachoeira do Sul, UME - Rio Pardo, AES - Santa Cruz).
Adaptação dinâmica de nomes, siglas, cabeçalho, tela de login, rodapés e páginas públicas.
🏢 Cadastro de Centros Espíritas Filiados & Trabalhadores
Registro de casas espíritas com dados cadastrais, diretoria e localização.
Gestão de trabalhadores voluntários por área de atuação (assistência social, doutrinária, evangelização, passes, etc.).
📅 Agenda Semanal Mestre-Detalhe & Link Público
Cadastro de exposições públicas, estudos doutrinários sistematizados (ESDE/EADE), reuniões mediúnicas e evangelização infantil.
Link público exclusivo para cada centro espírita: compartilhamento direto da programação semanal no WhatsApp e redes sociais sem necessidade de login.
📰 Mural & Feed Público de Notícias
Divulgação de comunicados, campanhas fraternas do quilo, palestras especiais e eventos.
Controle de publicação (visível no Feed Público ou mantida em rascunho interno).
Página pública dedicada para a comunidade com leitura limpa e responsiva.
👨‍👩‍👧‍👦 Assistência Social Fraterna às Famílias
Cadastro de Famílias e Integrantes: Acompanhamento de composição familiar, situação de vulnerabilidade, renda estimada e observações sociais.
Controle Rigoroso de Unicidade por CPF: Validação em nível de banco de dados e aplicação tanto para o responsável quanto para os membros, impedindo duplicidade de cadastros simultâneos em diferentes casas espíritas.
Histórico Completo de Auxílios: Registro detalhado de cestas básicas, ajuda emergencial em dinheiro, medicamentos/saúde, vestuário, material escolar e visitas fraternas.
Trilha de Auditoria (Logs Automáticos): Histórico completo com detalhes de quem criou, editou, transferiu de centro ou registrou auxílios, com registro técnico dos dados anteriores e novos.
🔐 Segurança e Isolamento por Centro Espírita
Administrador (UME): Acesso global irrestrito a todos os centros, famílias, relatórios, configurações e gestão de usuários.
Operador do Sistema: Acesso operacional total restrito exclusivamente ao seu próprio Centro Espírita.
Operador da Família: Foco dedicado ao acolhimento social das famílias vinculadas ao seu centro.
🛠️ Tecnologias Utilizadas
Back-end: Free Pascal / Lazarus
 com o framework TWAPI (Tiny Web API) e Horse
.
Banco de Dados: SQLite
 (pronto para uso imediato em arquivo local) e compatível com PostgreSQL
 para ambientes corporativos cliente-servidor.
Front-end: Single Page Application (SPA) construída com Vue.js 3 e estilizada com Tailwind CSS e FontAwesome (direto via CDN, sem dependências de build ou Node.js).
