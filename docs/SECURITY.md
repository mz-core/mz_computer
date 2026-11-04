# Segurança — mz_computer

## Senhas

A V1 usa **PBKDF2-HMAC-SHA256**, implementado server-side e parametrizado por `Config.Auth.pbkdf2Iterations`.

Formato persistido:

```text
pbkdf2-sha256$<iterations>$<saltHex>$<derivedKeyHex>
```

Regras:

- salt aleatório por conta;
- comparação em tempo constante;
- nunca plaintext;
- nunca reversível;
- nunca em metadata do item;
- nunca em state bag;
- nunca em NUI storage;
- nunca em logs.

A tela recomenda explicitamente ao jogador não reutilizar uma senha real.

Se no futuro o projeto adotar uma implementação canônica de Argon2id/bcrypt no FxServer, mantenha o campo `password_algo` e faça upgrade versionado; não faça fallback para plaintext.

## Brute force

Há duas camadas:

1. rate limit geral da bridge por `source`;
2. falhas consecutivas da conta, com `locked_until` após o limite.

Login de username inexistente também executa um KDF dummy para reduzir enumeração por timing.

## Sessões

- TTL configurável.
- Um login interativo por conta no MVP.
- Novo login revoga a sessão antiga.
- Sessão é vinculada ao `source`, account, citizen e device.
- Disconnect, logout, close/restart revogam sessão.
- Terminal público revalida lease e distância.

## Browser / MZ Net

Bloqueados explicitamente:

```text
http:
https:
ftp:
file:
javascript:
data:
blob:
nui:
cfx-nui:
ws:
wss:
```

O Browser não usa iframe, `window.open`, `eval`, proxy ou fetch para endereço digitado pelo jogador.

Todos os sites são descriptors do `SiteRegistry` e o conteúdo vindo de servidor é renderizado como texto/HTML escapado.

## CSP

A NUI possui CSP que:

- limita scripts/styles/assets ao próprio resource;
- bloqueia frames e objects;
- limita `connect-src` ao callback NUI do `mz_computer`.

Por isso, renomear o resource exige atualizar a CSP em `ui/dist/index.html`.

## Permissões

Permissões de apps/sites são resolvidas no servidor. Suporte V1:

```text
citizen
staff
job:police
org:<code>
perm:<permission>
device:<type|uid|terminalId>
```

O resolver consulta `mz_core` para identidade/snapshot/orgs/permissions. A UI jamais concede permissão.

## SQL

Todas as queries com dados variáveis usam parâmetros do oxmysql. Conteúdo criado por jogador não é concatenado em SQL.

## Debug

`/mzcomputer` exige `Config.Debug=true` ou ACE `mzcomputer.debug`.

Não existe bypass de login/admin no MZ OS.
