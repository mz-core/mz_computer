# Testes — mz_computer

## Testes estáticos incluídos

Execute na pasta do resource:

```bash
python tests/static_check.py
node --check ui/dist/app.js
```

O static checker valida:

- arquivos referenciados pelo manifest;
- ausência dos placeholders inseguros do skeleton original;
- existência do frame e referência visual;
- bloqueio de protocolos externos;
- presença das principais fronteiras de segurança.

## Runtime manual obrigatório

### A. Startup

1. Inicie `oxmysql`, `ox_lib`, `mz_core` e `mz_computer`.
2. Confirme migrations sem erro.
3. Confirme `MZ OS 1.0.0 ready`.

### B. Conta

1. Abra um notebook/terminal.
2. Crie `teste.player` com senha exclusiva de teste.
3. Feche.
4. Abra novamente.
5. Faça login.
6. Confira que senha errada não entra.
7. Erre repetidamente e confira lock temporário.

### C. Persistência

1. Crie uma nota.
2. Crie um documento.
3. Altere wallpaper/configurações.
4. Feche e faça login em outro device.
5. Confirme persistência.

### D. Terminal público

1. Player A abre PC-01.
2. Player B tenta o mesmo PC-01: deve receber `DEVICE_BUSY`.
3. A fecha o PC.
4. B consegue abrir.
5. A se afasta durante sessão e tenta nova ação: sessão deve ser invalidada/negada.

### E. Device transferido

1. Gere um notebook com serial.
2. Player A usa e faz login.
3. Fecha/logout.
4. Transfira o item para Player B.
5. B abre o mesmo device físico.
6. A conta de A não deve estar autenticada automaticamente.

### F. Browser

Teste a barra:

```text
mz://home
ajuda.mz
servicos.mz
https://google.com
http://example.com
javascript:alert(1)
data:text/html,test
file:///C:/Windows
cfx-nui://other-resource/
```

Somente os endereços MZ devem navegar. Os demais devem mostrar bloqueio.

### G. Segurança de evento

Com client modificado, tente enviar accountId/deviceId/permissão falsa. A bridge não recebe esses campos como autoridade: ações protegidas dependem do token da sessão vinculado ao próprio `source`.

### H. Lifecycle

Teste:

- fechar via ESC;
- power/logout;
- morrer com computador aberto;
- disconnect;
- restart `mz_computer`;
- restart `mz_core`;
- abrir novamente depois do restart.

## Runtime desta entrega

**NÃO EXECUTADO em um FxServer/MySQL real no ambiente de geração.**

Isso precisa permanecer explícito até os testes acima serem feitos em staging.

### I. Anchors de terminal (1.3)

1. Cadastre um monitor novo com `/mztela`.
2. Ajuste a câmera com scroll, W/S, A/D e F.
3. Capture `playerAnchor` exatamente na frente da mesa/tela.
4. Capture `interactionAnchor` no ponto desejado para o prompt.
5. Afaste-se e aproxime-se: `[E]` deve considerar o interaction anchor, não o pivot do prop.
6. Abra o PC: o personagem deve caminhar somente uma curta distância para o player anchor, assumir o heading salvo e então ficar congelado.
7. Feche o PC: o personagem deve ser liberado no ponto de uso.
8. Teste um `terminals.json` antigo sem anchors: deve manter o comportamento legado sem erro.
9. Teste obstáculo/posição distante: o runtime não deve teleportar o personagem de longa distância.
