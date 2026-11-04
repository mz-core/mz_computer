# Arquitetura — MZ Computer

## Princípio

O computador é uma plataforma de RP, não um agregador de domínios. A fronteira principal é:

```text
Citizen / Player identity  -> mz_core owns
Digital Account            -> mz_computer owns
Device                      -> mz_computer owns
Computer Session            -> mz_computer owns
Bank / Jobs / Orgs / Houses -> respectivos owners
```

## Fluxo do notebook pessoal

```text
mz_core inventory
  -> RegisterItemUseHandler("notebook")
  -> payload server-side contém source + metadata
  -> serial do item vira physicalKey
  -> mz_computer encontra/cria Device
  -> client abre NUI
  -> login server-side
  -> Session(source + account + citizen + device)
  -> MZ OS
```

A posse do hardware não equivale à posse da conta digital.

## Fluxo de terminal público

```text
client próximo ao interactionAnchor (fallback: coords)
  -> callback openPublic
  -> servidor valida distância no interactionAnchor
  -> claim de lease exclusivo
  -> abre login
  -> autenticação cria sessão
  -> fechar computador
  -> revoga sessão + libera lease
```

## Trust boundaries

### NUI / JavaScript

Não é autoridade. Nunca recebe o token bruto de sessão. Envia ações sem identidade autoritativa.

### Client Lua

Mantém apenas o token bruto da sessão corrente em memória e o anexa às chamadas server-side. Também não define `accountId`, `citizenid`, permissões ou saldo.

### Server Lua

É a autoridade de autenticação e sessão. Deriva player por `source`, resolve identidade via `mz_core`, revalida device e permissões e executa SQL parametrizado.

### Database

Persiste contas, hashes, devices, configurações e conteúdo. A sessão ativa continua sendo controlada em memória; registros antigos são revogados no startup.

## Componentes

```text
server/identity.lua      adapter para mz_core
server/crypto.lua        SHA-256/HMAC/PBKDF2 e tokens
server/accounts.lua      contas digitais
server/auth.lua          login/criação/lockout
server/sessions.lua      sessão server-authoritative
server/devices.lua       devices, public terminals, leases
server/apps.lua          App Registry
server/sites.lua         Site Registry + MZ Net resolver
server/content.lua       notas/documentos/settings
server/notifications.lua notification center
server/bridge.lua        boundary NUI -> server
server/integrations.lua  inventory + debug adapter
```

## Session token

O token bruto:

- é gerado no servidor;
- passa uma única vez para o Lua client;
- é removido da resposta antes da callback chegar ao JavaScript;
- nunca entra em localStorage;
- nunca é logado;
- é vinculado ao `source` ativo;
- expira por TTL.

No banco fica somente `SHA-256(token)` para auditoria/identificação do registro, não o token reutilizável.

## Resource lifecycle

No restart do `mz_computer`:

- sessões persistidas em estado `valid` são marcadas `revoked`;
- leases são expirados;
- NUI client faz cleanup;
- registries são reconstruídos;
- apps/sites externos precisam registrar novamente no lifecycle apropriado.


## World terminal anchors (1.3)

`mz_world_editor` permanece uma dependência de edição/seleção, não um owner do runtime do computador. `mz_computer` persiste offsets locais do `playerAnchor` e `interactionAnchor`, resolve o objeto existente e mantém DUI/câmera/input dentro do próprio domínio. Cadastros sem anchors seguem o comportamento 1.2 baseado em `terminal.coords`.
