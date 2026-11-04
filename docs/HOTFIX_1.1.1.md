# 1.1.1 — tela preta ao iniciar o resource

Sintoma: iniciar `mz_computer` cobre o jogo com preto, sem usar o item ou o terminal.

Causa reproduzida em Chromium: `desktop.css` aplicava `color-scheme: dark` ao `:root` do documento. Dentro do iframe da NUI, o navegador pintava um canvas opaco mesmo com `html`/`body` transparentes e `#computer-root` escondido. Os testes anteriores verificavam visibilidade dos elementos, mas não os pixels compostos sobre a cena.

Correção: documento com `color-scheme: normal`; temas escuro/claro limitados a `#os-root`. A folha `desktop.css` tem uma versão na URL para invalidar o cache. O novo teste `tests/idle_transparency.test.cjs` compara capturas pixel a pixel de uma cena com e sem a NUI sobreposta. Falhava antes da correção e passa depois, cobrindo início, fechamento e controle do DUI.

Após copiar os arquivos atualizados, execute `restart mz_computer` no console do servidor. Não é necessário alterar banco de dados ou desligar o modo 3D.

Para repetir o teste:

```text
node tests/idle_transparency.test.cjs <caminho-do-pacote-playwright> <caminho-do-chrome.exe>
```

O teste serve os arquivos reais via interceptação local do navegador e não precisa de servidor HTTP externo nem de conta do jogo.
