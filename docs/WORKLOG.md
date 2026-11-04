# Worklog da reconstrução

O ZIP de origem continha apenas uma fundação server-side parcial. A V1 foi reconstruída para tornar o resource instalável e coerente com a proposta do MZ OS.

Principais correções sobre o skeleton:

- corrigido manifest que apontava para arquivos inexistentes;
- removido placeholder de senha que concatenava `bcrypt:` com a senha em texto puro;
- substituído por PBKDF2-HMAC-SHA256 server-side;
- corrigida resolução de navegador que removia `http(s)` e, portanto, não bloqueava internet externa;
- eliminados helpers/sintaxe Lua inválidos do skeleton;
- criado client runtime completo;
- criada NUI completa;
- criada versão transparente da moldura do notebook;
- adicionados account/device/session separation e leases;
- adicionado App Registry e Site Registry seguros;
- adicionados Notes/Files/Settings/Notifications;
- adicionadas migrations, audit, permission resolver e docs;
- adicionada integração real com o item-use handler do `mz_core`.

Runtime FiveM permanece pendente de staging; ver `TESTING.md`.


## 1.3.0 — anchors de terminal

- preservada a superfície DUI/cantos existente;
- adicionado `playerAnchor` relativo ao prop;
- adicionado `interactionAnchor` relativo ao prop;
- câmera ganhou ajuste visual W/S/A/D no `/mztela`;
- distância client/server deixou de depender obrigatoriamente do pivot do prop;
- personagem recebe alinhamento curto e limitado antes do freeze;
- terminais antigos permanecem compatíveis;
- `mz_world_editor` foi analisado e não precisou de alteração.
