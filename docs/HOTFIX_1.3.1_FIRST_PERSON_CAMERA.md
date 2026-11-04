# MZ Computer 1.3.1 — First-person terminal camera

## Objetivo

Evitar que o próprio personagem apareça entre a câmera e o monitor durante o uso de PCs do mundo.

## Runtime

- `playerAnchor` continua definindo onde o corpo fica.
- A câmera de uso é uma `DEFAULT_SCRIPTED_CAMERA` posicionada a partir de `SKEL_Head`.
- A câmera avança alguns centímetros em direção à tela e aponta para o centro da superfície DUI.
- O ped é ocultado apenas localmente enquanto a visão está ativa, evitando clipping de cabeça/corpo; outros jogadores continuam vendo o personagem normalmente.
- A DUI, projeção, mouse e sessão não mudaram.
- A prévia do `/mztela` mantém a câmera externa de calibração, portanto o fluxo de cadastro não muda.

## Configuração

Os defaults ficam em `Config.WorldDisplay`:

- `cameraMode = 'first_person'`
- `firstPersonHeadBone = 31086`
- `firstPersonEyeForward`
- `firstPersonEyeRight`
- `firstPersonEyeUp`
- `firstPersonTargetRight`
- `firstPersonTargetUp`
- `hideLocalPlayerInFirstPerson`

`cameraFov` continua sendo respeitado no runtime. `cameraDistance`, `cameraRight` e `cameraUp` continuam usados pela câmera de prévia/calibração e pelo fallback de câmera screen-based.

## Compatibilidade

Nenhuma migration de `terminals.json` é necessária. Terminais 1.3.0 continuam válidos.
