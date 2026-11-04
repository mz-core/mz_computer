# Monitores existentes — 1.3.2

O `/mztela` usa o `mz_world_editor` somente para selecionar o prop. Geometria, DUI, câmera, anchors, sessão e input continuam sob ownership do `mz_computer`.

## Fluxo de cadastro

1. Execute **`/mztela`**, mire no monitor e selecione o objeto.
2. Marque com **E** os cantos **superior esquerdo**, **superior direito** e **inferior esquerdo** do vidro. O quarto canto é calculado.
3. Na prévia externa, ajuste a superfície:
   - **Scroll:** distância da câmera de calibração;
   - **F:** auto-fit;
   - **W/S:** altura;
   - **A/D:** lateral;
   - **Q/E:** `screenLift` em passos de 1 mm;
   - **G:** nome, FOV, offsets e raio de interação;
   - **R:** remarcar os cantos.
4. Pressione **ENTER** para entrar em **simulação em primeira pessoa**. A DUI continua desenhada no monitor, mas a câmera scripted de calibração é liberada.
5. Use **WASD + mouse** para colocar o personagem exatamente onde o jogador deverá ficar e olhar para o monitor da maneira desejada.
6. Pressione **ENTER**. O editor captura:
   - `playerAnchor.offset` relativo ao prop;
   - heading relativo do personagem;
   - posição dos olhos em relação à superfície;
   - ponto exato da superfície para onde a gameplay camera está olhando;
   - FOV atual da gameplay camera.
7. O editor entra imediatamente em **TESTE DO JOGADOR**, reproduzindo a captura com a mesma câmera scripted de primeira pessoa usada no runtime.
8. Se ficou bom, **ENTER salva**. Se ficou ruim, **R volta à simulação** sem perder a superfície marcada.

O `interactionAnchor` passa a usar por padrão a mesma posição capturada para o `playerAnchor`. O raio do `[E]` continua configurável em **G**.

Para editar, rode `/mztela` novamente e selecione o mesmo objeto. Para remover só o cadastro, use **`/mztela remover`**.

## Dados persistidos

Um terminal novo pode ter:

```lua
playerAnchor = {
    offset = { x = 0.0, y = -0.65, z = -0.70 },
    heading = 180.0,
    mode = 'standing'
},
interactionAnchor = {
    offset = { x = 0.0, y = -0.65, z = -0.70 }
},
interactionDistance = 1.5,
display = {
    -- geometria/câmera de calibração...
    firstPersonEyeForward = 0.04,
    firstPersonEyeRight = 0.00,
    firstPersonEyeUp = 0.01,
    firstPersonTargetRight = 0.00,
    firstPersonTargetUp = 0.00
}
```

Os novos campos de primeira pessoa são opcionais. Terminais antigos continuam usando os defaults de `Config.WorldDisplay`.

## Segurança e compatibilidade

- `terminals.json` continua em `version=1`; não há migration SQL.
- O servidor limita offsets de olho a **±0,5 m** e offsets do alvo da tela a **±2 m**.
- A captura só é aceita quando a gameplay camera está realmente olhando para a área do monitor.
- O runtime continua evitando alinhamento/teleporte de longa distância.
- O notebook pessoal não usa esse fluxo e continua em NUI normal.
- `mz_world_editor` não foi alterado.

## Ownership

```text
mz_world_editor
  -> seleção genérica do objeto

mz_computer
  -> superfície/cantos
  -> DUI + perspectiva/mouse
  -> simulação do editor
  -> câmera runtime
  -> playerAnchor / interactionAnchor
  -> sessão/lease/input
```

## Limite de teste

Os testes automatizados cobrem persistência, limites server-side, lifecycle da DUI, mudança para gameplay first-person, captura de pose/FOV, reprodução da scripted camera, retorno à recalibração e restauração do modo de câmera anterior. O conforto final da câmera e colisões do MLO ainda precisam ser conferidos dentro do FiveM real.
