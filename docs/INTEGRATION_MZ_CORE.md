# Integração com MZ_CORE

## Objetivo

`mz_computer` foi desenhado para consumir os contratos públicos do `mz_core` e não acessar diretamente tabelas internas de player/inventário.

## Identidade do jogador

O adapter em `server/identity.lua` tenta resolver a identidade pelo export canônico `ResolvePlayerIdentity` e usa `GetPlayerSnapshot` como fallback de snapshot. O `citizenid` obtido é usado apenas como referência da identidade física/personagem; ele não é a chave da conta digital do MZ OS.

## Item notebook

A integração do notebook fica em `server/integrations.lua` e usa:

- `GetItemDefinition` para verificar se o item existe;
- `RegisterItemUseHandler` para registrar o uso server-side;
- `payload.source` como source implícito do uso;
- `payload.metadata.uid`, `device_uid` ou `serial` para obter uma identidade física estável do item;
- `afterCommit` para abrir o computador somente depois de a transação do inventário concluir.

Definição recomendada no catálogo de itens do MZ_CORE:

```lua
notebook = {
  image = 'notebook.png',
  label = 'Notebook',
  weight = 2200,
  stack = false,
  unique = true,
  usable = true,
  closeOnUse = true,
  bindOnReceive = false,
  generateSerial = true
},
```

Copie `integration_assets/notebook.png` para o diretório de imagens usado pela UI do inventário.

## Permissões

O permission resolver não replica jobs/orgs/ACL. Ele consulta o `mz_core` quando um app exige permissões como:

```text
citizen
staff
job:police
org:<code>
perm:<permission>
device:<type|uid|terminalId>
```

A permissão continua sendo decidida no servidor. O frontend não pode transformar um usuário em police/staff/org.

## App Registry

Resources externos devem registrar apenas descriptors confiáveis pelo lado server. A V1 não carrega JavaScript arbitrário de outro resource, não usa `eval` e não transforma URL fornecida pelo jogador em iframe.

Exemplo conceitual:

```lua
exports['mz_computer']:RegisterApp({
  id = 'bank',
  name = 'MZ Bank',
  icon = 'bank',
  entryType = 'native',
  entryKey = 'bank',
  permissions = { 'citizen' },
  version = '1.0.0'
})
```

Antes de registrar apps de produção, coloque o resource chamador em `Config.Security.trustedAppResources` ou adapte a política ao mecanismo canônico de ownership/registration adotado no repositório.

## MZ Docs / Graphify

Este pacote foi gerado a partir do resource isolado enviado no chat. Ele contém documentação local completa, mas não altera automaticamente o checkout principal do `mz_docs` nem o baseline Graphify do repositório do usuário.

Ao integrar no workspace oficial:

1. registrar o ownership de `mz_computer` no índice canônico de docs;
2. registrar os novos contratos públicos App/Site/Notification;
3. adicionar ADR se a governança atual exigir;
4. atualizar o grafo Graphify do novo resource/bloco;
5. verificar que `mz_core` não passou a depender de `mz_computer` e que não surgiu ciclo.

### Delta 1.3.0 para integrar no workspace oficial

Ao aplicar esta versão no repositório principal, atualizar `mz_docs`/Graphify para refletir:

- `mz_computer` continua owner de toda a experiência de terminal 3D;
- `mz_world_editor` é apenas provider do contrato de seleção de entidade; não recebeu mudança;
- novo estado persistente opcional `playerAnchor` e `interactionAnchor` em terminais;
- `server/devices.lua` valida distância usando `interactionAnchor` com fallback legado;
- `client/world.lua` resolve/alinha `playerAnchor` e mantém o lifecycle da câmera/DUI.

O `graphify-out` incluído no ZIP de origem **não foi regravado manualmente** nesta entrega, porque o gerador Graphify do workspace não acompanha o resource isolado. Rebuild incremental do bloco `mz_computer` deve ser feito no checkout oficial para não publicar hashes/arestas derivados artificialmente.
