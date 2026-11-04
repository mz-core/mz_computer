# Relatório final — mz_computer V1

## Baseline recebido

O ZIP original continha uma fundação server-side parcial, sem client, NUI, imagem de runtime tratada, docs completos e vários arquivos referenciados necessários ao funcionamento final.

Foram encontrados também problemas que impediam tratar o skeleton como implementação pronta, incluindo placeholder de senha inseguro, resolução de browser que não garantia o bloqueio de internet externa e lacunas de lifecycle/runtime.

## Arquitetura entregue

```text
Citizen / personagem        -> mz_core
Conta digital MZ OS         -> mz_computer
Device físico/lógico        -> mz_computer
Sessão do computador        -> mz_computer
Apps/sites/desktop           -> mz_computer shell
Banco/jobs/orgs/etc.         -> owners canônicos externos
```

## Entregue

- notebook pessoal identificado por metadata/serial;
- terminais públicos/LAN house com lease exclusivo;
- conta digital separada de citizen e device;
- criação de conta + login;
- PBKDF2-HMAC-SHA256 server-side com salt;
- lockout/rate limit;
- sessões server-authoritative vinculadas ao source/device/citizen/account;
- boot/login/desktop/taskbar/window manager;
- MZ Browser + MZ Net sem internet real;
- Notes, Files/Documents, Settings e About;
- notificações do OS;
- App Registry e Site Registry;
- permission resolver;
- SQL migrations;
- auditoria;
- cleanup de NUI/device/session;
- frame do notebook fornecido pelo usuário, com área interna transparente e viewport calibrado;
- documentação de instalação, arquitetura, segurança, SDK, MZ Net, ownership e testes.

## Área visual calibrada

Referência: 1920x1080.

```text
x: 289..1628
y: 118..956
left:   15.052083%
top:    10.925926%
width:  69.791667%
height: 77.685185%
```

A imagem original foi preservada em `docs/reference/notebook_frame_reference.png`. O overlay de runtime está em `ui/dist/assets/notebook-frame-overlay.png`.

## Segurança

- sem plaintext password;
- sem hash simples de senha;
- sem senha em localStorage/state bag/item metadata;
- token bruto de sessão não chega ao JavaScript/NUI;
- sessão vinculada ao `source` atual;
- SQL parametrizado;
- browser bloqueia protocolos externos;
- sem iframe externo;
- sem `window.open` externo;
- sem `eval`;
- CSP local/restritiva;
- client não define accountId/citizenId/job/staff como autoridade;
- terminais públicos revalidam lease e distância no servidor.

## Validação executada neste ambiente

```text
python tests/static_check.py  -> PASS (57 checks)
node --check ui/dist/app.js   -> PASS
Lua syntax load               -> PASS (28 arquivos Lua/manifest)
```

A implementação criptográfica também foi validada durante a construção contra vetores conhecidos de SHA-256 e PBKDF2-HMAC-SHA256.

## Runtime FiveM/MySQL

```text
NÃO EXECUTADO
```

O ambiente desta entrega não é um FxServer ligado ao banco/runtime real do servidor do usuário. Por isso não é correto declarar runtime aprovado antes do staging.

O checklist manual completo está em `docs/TESTING.md`.

## Integração no projeto oficial

Como o arquivo fornecido foi o resource isolado, esta entrega não escreve diretamente no checkout principal `mz_docs` nem no Graphify do workspace. As ações exatas para essa integração estão em `docs/INTEGRATION_MZ_CORE.md`.
