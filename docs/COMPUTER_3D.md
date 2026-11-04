# Computador 3D e desktop — versão 1.3

> **Atualização 1.3:** o editor `/mztela` também grava `playerAnchor` e `interactionAnchor`, além da superfície/câmera. Terminais antigos continuam compatíveis.
> **Atualização 1.3.1:** ao usar um terminal, a câmera passa para uma visão scripted em primeira pessoa baseada na cabeça do personagem.
> **Atualização 1.3.2:** após mapear a superfície, `/mztela` permite andar/olhar em primeira pessoa, captura a pose e o ponto olhado na tela e reproduz a câmera final antes de salvar.
> **Atualização 1.3.3:** terminais passam a usar interação híbrida: DUI leve no mundo + NUI normal projetada nos quatro cantos da tela. O bridge de mouse/teclado da DUI fica apenas como fallback `interactionMode = 'dui'`.

## Uso

- **Notebook pessoal:** use o item `notebook` no inventário. Ele possui serial, não é consumido e abre o novo notebook em NUI. `/mzcomputer` continua disponível conforme as permissões de desenvolvimento existentes.
- **Computador fixo:** aproxime-se do terminal cadastrado e pressione **E**. O sistema cria/carrega a DUI leve do monitor, alinha o personagem e ativa a câmera scripted em primeira pessoa. A interface interativa é a NUI normal, transformada pelos quatro cantos do vidro para parecer parte do monitor.
- **Desktop:** clique para selecionar um aplicativo; duplo clique ou Enter para abrir. F3 pesquisa aplicativos; F5 atualiza a página do navegador interno. O canto direito da barra mostra/esconde as janelas.
- **Saída:** ESC fecha primeiro um menu aberto e depois o computador. Energia permite sair apenas da conta ou desligar. Morte, encerramento de sessão e parada do resource usam a limpeza existente.

## Configuração do terminal

`Config.WorldDisplay` contém os padrões. Cada entrada de `Config.PublicTerminals` pode sobrescrever esses valores com `display`:

```lua
{
    id = 'lanhouse_legion_01',
    label = 'PC 01',
    coords = vec3(446.87, -974.23, 30.44),
    heading = 0.0,
    skin = 'terminal_basic',
    interactionDistance = 1.5,
    playerAnchor = { offset = { x = 0.0, y = -0.65, z = -0.70 }, heading = 180.0, mode = 'standing' },
    interactionAnchor = { offset = { x = 0.0, y = -0.85, z = -0.70 } },
    display = {
        enabled = true,
        model = 'prop_monitor_01c',
        spawnProp = true,
        objectOffset = { x = 0.0, y = 0.0, z = 0.72 },
        screenOffset = { x = 0.0, y = -0.035, z = 0.28 },
        screenWidth = 0.48,
        screenHeight = 0.27,
        screenTilt = 0.0,
        cameraDistance = 0.72,
        cameraFov = 42.0
    }
}
```

As coordenadas acima preservam o terminal que já existia nesta base. **O modelo e os offsets são valores iniciais, não medidas verificadas no jogo.** Não houve acesso ao mapa/FiveM para calibrá-los.

| Campo | Ajuste |
| --- | --- |
| `coords` | Pivot/base do terminal e fallback legado quando não existem anchors. |
| `playerAnchor` | Posição/heading local do personagem durante o uso. |
| `interactionAnchor` | Centro local do prompt e da validação server-side de proximidade. |
| `heading` | Rotação do objeto criado, em graus. |
| `objectOffset` | Posição do objeto em relação ao terminal; X/Y acompanham o heading. Z ajusta a altura da mesa. |
| `screenOffset` | Centro da tela nas coordenadas locais do modelo. X lateral, Y profundidade, Z altura. |
| `screenWidth` / `screenHeight` | Medidas da superfície em metros; manter 16:9 para a resolução padrão. |
| `screenTilt` | Inclinação da tela em graus em torno do eixo local X. Zero representa uma tela vertical. |
| `cameraDistance` | Distância da câmera de calibração/fallback ao centro da tela. No runtime `first_person`, a posição vem da cabeça do personagem. |
| `cameraFov` | Campo de visão; valores menores aproximam visualmente a tela. |
| `width` / `height` | Resolução da apresentação DUI no mundo; padrão 1280×720. A camada NUI interativa usa uma base 1280×720 e é projetada pela homografia. |
| `interactionMode` | `nui_overlay` (padrão): NUI direta sobre o monitor. `dui`: bridge 3D legado para compatibilidade/diagnóstico. |
| `spawnProp` | `true`: cria objeto local. `false`: procura o modelo existente em `objectCoords` ou `coords`, com `matchRadius` padrão de 0,15 m. |

Os campos que são tabelas, como `screenOffset`, devem ser informados completos ao sobrescrever. Para um monitor existente no mapa, use `spawnProp = false` e o nome exato do modelo. Posicione `coords` perto daquele objeto, evitando outro monitor do mesmo modelo no raio de busca. O resource não apaga objetos emprestados do mapa.

### Calibração no FiveM

1. Reinicie `mz_computer` e vá ao terminal. Ajuste `objectOffset` e `heading` até o monitor estar sobre a mesa desejada.
2. Pressione E. Ajuste `screenOffset` para alinhar o centro da interface ao vidro do monitor; a superfície deve ficar ligeiramente à frente da geometria, evitando cintilação/oclusão.
3. Ajuste largura, altura e inclinação para encaixar nos quatro cantos. A face visível aponta para o eixo local -Y; modelos com outra orientação precisam de um perfil adequado.
4. Ajuste distância/FOV para enxergar toda a tela, sem atravessar paredes ou objetos. Reinicie o resource após alterações na configuração.
5. Teste cliques nos cantos, arrastar/redimensionar janelas, seleção de texto, rolagem, Tab, Enter, ESC e caracteres como `ç` e `ã`.

Se o modelo ou o navegador DUI não carregar, a sessão usa a NUI do notebook e exibe uma mensagem. Isso não detecta offsets visuais incorretos: uma tela desalinhada exige calibração.

## Implementação

`client/world.lua` mantém os monitores próximos, cria um único DUI durante o uso e desenha duas faces triangulares com `DrawTexturedPoly`. A textura é aplicada a uma superfície alinhada ao monitor; não há substituição global da textura de todos os objetos do mesmo modelo.

A primeira etapa da prévia usa a normal da tela para facilitar o mapeamento. Em seguida, o editor troca para a gameplay camera em primeira pessoa e captura a posição do personagem, o offset real dos olhos, o FOV e o ponto olhado no plano da tela. No uso real, a câmera scripted nasce a partir de `SKEL_Head` e reproduz esses offsets; terminais antigos continuam mirando pelos defaults globais. O próprio ped é ocultado somente no cliente durante essa visão para evitar clipping; outros jogadores continuam vendo o personagem.

No modo canônico `nui_overlay`, `client/world.lua` continua desenhando a DUI sobre o prop, mas essa DUI carrega `display.html`, uma apresentação leve sem autenticação/apps. Em paralelo, a `ui_page` normal recebe os quatro cantos projetados do vidro. `hybrid-math.js` calcula uma homografia e `surface.js` aplica uma `matrix3d` ao shell de 1280×720; assim o Chromium projeta o MZ OS sobre o trapézio real do monitor e faz o hit-test do mouse diretamente na NUI transformada. Não existe `SendDuiMouseMove`, proxy de texto ou round-trip NUI→Lua→DUI no caminho normal. O bridge antigo permanece disponível com `interactionMode = 'dui'` para diagnóstico/compatibilidade.

O fechamento destrói o DUI e a câmera, limpa a entrada de teclado e solta o personagem quando foi este resource que o congelou. Os monitores criados são removidos ao sair da área ou parar o resource. Os modelos emprestados permanecem. O estado previamente congelado de um personagem é preservado.

A tela é **local ao jogador que utiliza o terminal**. Outros jogadores podem ver o monitor, mas não recebem os dados da sessão nem o conteúdo da tela. O lease exclusivo do terminal continua no servidor. O player pode ser alinhado ao `playerAnchor` antes de ser congelado. Ainda não há animação canônica de sentar/digitar; isso continua dependendo da cadeira/mesa de cada interior.

## Integrações incluídas

- Cadastro canônico do item e imagem no `mz_inventory`.
- Registro de uso pelo `RegisterItemUseHandler`, com autorização de abertura depois do commit do inventário.
- Fechamento do inventário antes do computador e prevenção de reabertura por resposta atrasada de uso/refresh.
- Aplicativo **Meu perfil**, consultando nome, registro e telefone do personagem autenticado pelo servidor. License, snapshot completo e tokens não são enviados à interface.
- Preservados App Registry, Site Registry, notas/documentos persistentes e notificações.

Operações bancárias, veículos e organizações **não foram implementadas nesta versão**. O `mz_bank` exige capability própria por canal; o computador não reaproveita tokens de agência/telefone nem contorna essa autorização. O perfil é uma integração real com o core; as capturas de demonstração usam dados fictícios exclusivamente em testes.

## Validação

Executados no ambiente local:

```powershell
# Dentro de mz_computer
py -3 tests/static_check.py
node tests/screen_math.test.cjs
lua tests/world_lifecycle.test.lua
lua tests/profile_contract.test.lua
lua tests/inventory_handoff.test.lua
```

Os testes Lua usam stubs das natives para verificar ciclo de vida, permissões, isolamento da entrada e troca de foco. Não substituem o runtime do jogo. A sintaxe de todos os Lua do computador, do cadastro de itens e da ponte alterada do inventário também foi verificada com `luac -p`; os JS foram verificados com `node --check`.

Para repetir a automação de navegador, inicie um servidor estático em `ui/dist` na porta 8765 e execute:

```text
node tests/browser_check.cjs <caminho-do-pacote-playwright> <caminho-do-chrome.exe>
```

O teste usa `tests/preview-fixture.js`, que não é carregado pelo resource nem incluído no manifest. Verifica abertura/saída, busca, perfil, edição preservada ao reabrir janela, salvar notas, minimizar/maximizar, temas, login em 1280×720/1920×1080/2560×1080 e ponte de teclado/cursor entre duas páginas independentes. Capturas em `docs/screenshots` também ficam fora do pacote dos jogadores.

**Pendente no FiveM:** aparência do modelo, offsets, oclusão, enquadramento em diferentes interiores, desempenho real e fluxo com o banco de dados/inventário em execução. Após atualizar a base, carregue as alterações de `mz_core`, `mz_inventory` e `mz_computer` na ordem normal de inicialização do servidor.

Referências: [DUI oficial](https://docs.fivem.net/docs/scripting-manual/nui-development/dui/), [DrawTexturedPoly](https://github.com/citizenfx/natives/blob/master/GRAPHICS/DrawTexturedPoly.md). Ícones locais Lucide com licença em `ui/dist/assets/icons/LICENSE.txt`.
