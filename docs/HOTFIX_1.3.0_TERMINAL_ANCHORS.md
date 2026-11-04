# MZ Computer 1.3.0 — Terminal Anchors

## Objetivo

Fechar o fluxo de uso de computadores fixos sem reescrever a implementação DUI existente.

## Alterações

- `playerAnchor` relativo ao prop: posição + heading de uso do personagem.
- `interactionAnchor` relativo ao prop: centro do prompt/interação.
- calibração visual de câmera com W/S/A/D além do auto-fit/scroll/dialog existente;
- alinhamento curto do personagem por `TaskGoStraightToCoord`, com limite de distância e fallback seguro;
- validação server-side de proximidade baseada no `interactionAnchor`;
- cadastros antigos sem anchors continuam usando `terminal.coords`;
- notebook pessoal/NUI normal não foi alterado;
- `mz_world_editor` não foi modificado.

## Arquivos principais

- `client/world.lua`
- `client/interaction.lua`
- `client/terminal_editor.lua`
- `server/devices.lua`
- `server/terminal_editor.lua`
- `shared/screen_geometry.lua`
- `config.lua`

## Compatibilidade

Não há migration SQL. `terminals.json` continua com `version=1`; os campos novos são opcionais.
