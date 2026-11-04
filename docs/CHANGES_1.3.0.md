# Changes 1.3.0

## Código alterado

- `config.lua`
- `fxmanifest.lua`
- `shared/screen_geometry.lua`
- `client/world.lua`
- `client/interaction.lua`
- `client/terminal_editor.lua`
- `server/devices.lua`
- `server/terminal_editor.lua`
- `tests/terminal_editor.test.lua`
- `tests/world_lifecycle.test.lua`

## Documentação alterada/adicionada

- `README.md`
- `docs/SCREEN_EDITOR.md`
- `docs/COMPUTER_3D.md`
- `docs/ARCHITECTURE.md`
- `docs/WORKLOG.md`
- `docs/INTEGRATION_MZ_CORE.md`
- `docs/TESTING.md`
- `docs/HOTFIX_1.3.0_TERMINAL_ANCHORS.md`
- `docs/VALIDATION_1.3.0.txt`

## Não alterado

`mz_world_editor` foi inspecionado para confirmar o contrato `StartEntitySelection`/cancelamento/permissão, mas nenhum arquivo dele precisou ser modificado.

`graphify-out` foi preservado como veio no ZIP. O grafo deve ser regenerado no workspace oficial com o Graphify canônico após integrar este delta.
