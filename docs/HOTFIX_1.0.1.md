# Hotfix 1.0.1 — fullscreen preto ao iniciar o resource

## Sintoma
Ao executar `ensure mz_computer`, a NUI podia pintar um canvas preto fullscreen mesmo com o computador fechado.

## Causa
A página NUI fica montada pelo FiveM durante toda a vida do resource. O documento usava `color-scheme: dark` no elemento raiz e dependia apenas da classe CSS de ocultação. Em alguns builds/CEF isso permite que o canvas raiz seja composto como preto mesmo quando o shell visual está oculto.

## Correção
- removido `color-scheme: dark` do root do documento;
- `html` e `body` agora forçam fundo RGBA transparente;
- o shell começa com `display:none` inline;
- JS aplica hard-hide/hard-show com `display`, `visibility`, `opacity` e `pointer-events`;
- NUI executa reset antes do handshake `ready`;
- client limpa NUI focus e envia `computer:close` no resource start, repetindo após 500 ms como proteção contra race do CEF.

## Resultado esperado
`ensure mz_computer` não deve alterar a tela do jogador. A interface só aparece depois de `Client.openComputer(...)`.
