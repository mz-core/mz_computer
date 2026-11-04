# 1.3.3 — Hybrid world-terminal NUI

## Objetivo

Remover a latência perceptível causada pelo caminho mouse/NUI controller → Lua → `SendDuiMouse*` → Chromium DUI, sem perder a tela física mapeada no prop.

## Runtime canônico

- A câmera e os anchors 1.3.2 permanecem.
- A DUI no prop usa `ui/dist/display.html`, uma página leve de apresentação.
- O MZ OS interativo continua sendo a `ui_page` normal do resource.
- Os quatro cantos 3D são projetados para a tela a cada intervalo configurável.
- `ui/dist/hybrid-math.js` resolve a homografia 2D.
- `surface.js` converte a homografia em CSS `matrix3d`, fazendo a NUI acompanhar perspectiva e inclinação do vidro.
- Mouse, teclado, seleção, IME e scroll são processados diretamente pelo Chromium NUI.
- O modo anterior continua acessível por `Config.WorldDisplay.interactionMode = 'dui'`.

## Compatibilidade

Nenhuma migration de banco ou `terminals.json` é necessária. `interactionMode` é default global e pode ser sobrescrito dentro de `terminal.display`. Notebook e `/mztela` mantêm seus fluxos anteriores.
