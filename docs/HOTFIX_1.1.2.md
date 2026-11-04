# 1.1.2 — câmera abre, mas o monitor não mostra o sistema

Foi reproduzida uma corrida no carregamento do DUI. `surface.js` enviava `surfaceReady` antes de `app.js` terminar de carregar e registrar seu listener. O Lua recebia esse sinal, ativava a câmera e enviava `computer:open`. Se o script principal ainda não estivesse pronto, a mensagem se perdia; em seguida, a inicialização do aplicativo escondia a interface. O modelo 3D continuava visível, mas a textura do DUI permanecia transparente.

A prontidão agora é enviada pelo próprio `app.js`, depois do registro dos listeners e do reset inicial. O Lua abre o OS e aguarda `surfaceVisible`, emitido após o layout e uma oportunidade de pintura, antes de ativar câmera e superfície. Se o aplicativo não confirmar a abertura dentro do prazo, a sessão usa a NUI do notebook. O sinal confirma a interface no navegador; não mede a oclusão do modelo dentro do GTA.

O fluxo principal não envia uma segunda abertura ao DUI. As URLs de `surface.js` e `app.js` possuem versão para invalidar o cache.

Validação: `tests/dui_startup.test.cjs` atrasa deliberadamente `app.js` e envia a abertura assim que recebe `surfaceReady`. O teste reproduzia a interface escondida antes da alteração e passa depois. O teste Lua de ciclo de vida também cobre falta da confirmação visual e impede criar a câmera antes dela.

```text
node tests/dui_startup.test.cjs <caminho-do-pacote-playwright> <caminho-do-chrome.exe>
lua tests/world_lifecycle.test.lua
```

Após copiar a versão atualizada, execute `restart mz_computer` no console do servidor e abra novamente o terminal.
