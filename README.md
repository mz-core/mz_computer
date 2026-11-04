# mz_computer — MZ OS

`mz_computer` é a plataforma de computador in-game da MZ Framework. Ela cria uma identidade digital separada do personagem e do hardware, um MZ OS persistente, notebooks pessoais, terminais públicos/LAN house, aplicativos internos e a rede fictícia **MZ Net**.

## O que a versão 1.3.3 entrega

- **`/mztela`** cadastra monitores que já existem no mundo, usando o seletor do `mz_world_editor`, três cantos do vidro, prévia externa e simulação controlável em primeira pessoa para capturar `playerAnchor` + visão real do jogador. [Como usar o editor](docs/SCREEN_EDITOR.md).
- **1.3.3 híbrida:** no uso real, o MZ OS interativo é a NUI principal (input direto); a NUI recebe uma homografia pelos quatro cantos do monitor, enquanto a DUI 3D usa `display.html`, uma apresentação leve sem executar uma segunda sessão completa do desktop.
- Terminais novos podem alinhar o personagem em uma posição de uso relativa ao prop; o prompt [E] também deixa de depender do pivot do objeto. Cadastros antigos continuam funcionando sem migração.

- Notebook com moldura em CSS, ícones Lucide locais, temas e papéis de parede.
- Monitor 3D híbrido nos terminais públicos: DUI leve permanece no prop, enquanto a interação usa NUI normal projetada sobre os quatro cantos do vidro para reduzir latência de mouse/teclado.
- Menu com pesquisa, seleção por clique / abertura por duplo clique, janelas redimensionáveis, minimizar, maximizar e mostrar desktop.
- Boot, lock/login, criação de conta, desktop, taskbar, janelas e notificações.
- Senhas processadas exclusivamente no servidor com PBKDF2-HMAC-SHA256 + salt; nunca plaintext.
- Sessões opacas vinculadas a `source`, device e TTL. O token bruto permanece somente no Lua client e nunca entra no JavaScript/NUI.
- Notebook físico como item do `mz_core`, usando `RegisterItemUseHandler` e serial/metadata para identificar o dispositivo.
- Terminais públicos com lease server-side, um usuário por terminal e limpeza de sessão ao fechar.
- Apps built-in: MZ Browser, Notas, Arquivos, Meu perfil, Configurações e Sobre.
- Meu perfil consulta o personagem autenticado no `mz_core`. O item notebook e sua imagem estão incluídos no core/inventário deste repositório.
- MZ Browser totalmente interno: `http`, `https`, `javascript:`, `file:`, `data:` etc. são bloqueados.
- App Registry e Site Registry para integração modular de outros resources.
- Persistência SQL versionada via migrations.
- Rate limit, lockout, validation, ownership checks, revision em conteúdo e auditoria.

## Dependências

```text
oxmysql
ox_lib
mz_core
mz_computer
```

Ordem recomendada no `server.cfg`:

```cfg
ensure oxmysql
ensure ox_lib
ensure mz_core
ensure mz_computer
```

Leia primeiro [docs/INSTALL.md](docs/INSTALL.md) e [configuração do computador 3D](docs/COMPUTER_3D.md).

Prévias com dados fictícios de teste: [desktop](docs/screenshots/desktop.png), [login](docs/screenshots/login.png), [perfil](docs/screenshots/profile.png) e [tela sem moldura para DUI](docs/screenshots/monitor-surface.png). Essas imagens são capturas do navegador, não do GTA.

## Ownership

`mz_computer` owns:

- conta digital do MZ OS;
- device model e serial lógico;
- sessão do computador;
- lease de terminal público;
- desktop/settings;
- notas/documentos internos;
- App Registry;
- Site Registry / MZ Net;
- notificações do OS.

Ele **não owns** identidade do player, inventário, emprego, organização, saldo bancário, propriedades ou veículos. Esses domínios continuam sob seus resources canônicos.

## Segurança do navegador

O browser não contém iframe externo, `window.open`, proxy, WebSocket, shell ou navegação real. A barra visual resolve apenas sites registrados no `SiteRegistry`.

```text
mz://home     -> permitido
ajuda.mz      -> permitido
https://...   -> bloqueado
javascript:   -> bloqueado
file://       -> bloqueado
```

## Estado de validação desta entrega

Foram executados testes estáticos, sintaxe Lua/JS, testes Lua de ciclo de vida e permissão, regressão da troca de foco do inventário, projeção do cursor e automação Chromium em 720p, 1080p e ultrawide. A ponte de DUI foi exercitada entre duas páginas independentes, com cliques, Tab, acentos e texto multilinha. **Runtime FiveM/MySQL real não foi executado aqui**; o modelo 3D e os offsets iniciais precisam ser calibrados no mapa. Veja [validação 1.1](docs/COMPUTER_3D.md#validação).

## Documentos adicionais

- [Integração com MZ_CORE](docs/INTEGRATION_MZ_CORE.md)
- [Relatório final da V1](docs/FINAL_REPORT.md)
