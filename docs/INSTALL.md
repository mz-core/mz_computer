# Instalação — mz_computer

## 1. Copiar o resource

Coloque a pasta `mz_computer` junto aos demais resources MZ. Os callbacks usam o nome do resource em execução; mantenha `mz_computer` para compatibilidade com integrações externas.

## 2. Dependências

Garanta que estes resources iniciem antes:

```cfg
ensure oxmysql
ensure ox_lib
ensure mz_core
ensure mz_world_editor # seletor de monitores para /mztela
ensure mz_computer
```

As migrations são aplicadas automaticamente na primeira inicialização. Não importe o SQL manualmente salvo se sua política de deploy exigir isso.

## 3. Verificar o item notebook no mz_inventory

Neste repositório, o item já foi cadastrado em `mz_inventory/shared/items.lua` e a imagem está em `mz_inventory/web/images/notebook.png`. Ao instalar em outra base, adicione a entrada abaixo dentro de `MZItems` no `mz_inventory`:

```lua
notebook = {
  image = 'notebook.png',
  label = 'Notebook',
  weight = 2200,
  stack = false,
  unique = true,
  usable = true,
  closeOnUse = true,
  bindOnReceive = false,
  generateSerial = true
},
```

`generateSerial = true` é importante: o `mz_computer` usa `metadata.serial` como identidade física estável quando disponível. Se o notebook for transferido para outra pessoa, o mesmo device continua existindo, mas a conta anterior **não fica logada**.

Copie também:

```text
mz_computer/integration_assets/notebook.png
```

para a pasta de imagens usada pelo seu inventário, mantendo o nome `notebook.png` (ou altere o campo `image` para o nome adotado por sua UI de inventário).

## 4. Configurar LAN house / terminais públicos

Use **`/mztela`** para selecionar um monitor existente e calibrar vidro/câmera. Veja [o guia do editor](SCREEN_EDITOR.md). Os cadastros são gravados em `terminals.json`; preserve esse arquivo nas atualizações.

Para definições manuais de desenvolvimento, edite `Config.PublicTerminals` em `config.lua` e configure `display` conforme [Computador 3D](COMPUTER_3D.md). As coordenadas de exemplo abaixo não identificam monitores medidos no seu mapa:

```lua
Config.PublicTerminals = {
  {
    id = 'lanhouse_01',
    label = 'PC 01',
    coords = vec3(215.76, -810.12, 30.73),
    heading = 0.0,
    skin = 'terminal_basic',
    interactionDistance = 1.8
  },
  {
    id = 'lanhouse_02',
    label = 'PC 02',
    coords = vec3(216.65, -810.12, 30.73),
    heading = 0.0,
    skin = 'terminal_basic',
    interactionDistance = 1.8
  }
}
```

As coordenadas acima são **somente exemplo**. Troque pelas coordenadas reais da sua LAN house.

Cada `id` é estável e vira um device persistente no banco.

Na versão 1.1, os terminais usam monitor 3D por padrão. Configure o modelo, a altura da mesa, a superfície da tela e a câmera conforme [COMPUTER_3D.md](COMPUTER_3D.md). O notebook pessoal e `/mzcomputer` usam a moldura CSS. Para desativar globalmente o 3D, use `Config.WorldDisplay.enabled = false`.

## 5. Teste de desenvolvimento sem item

O comando:

```text
/mzcomputer
```

só abre um notebook de debug quando:

- `Config.Debug = true`; ou
- o jogador possui ACE `mzcomputer.debug`.

Exemplo de ACE para desenvolvimento:

```cfg
add_ace group.admin mzcomputer.debug allow
```

Não dê esse ACE para jogadores comuns.

## 6. Imagem/moldura

A referência original fica em:

```text
docs/reference/notebook_frame_reference.png
```

A versão runtime com transparência fica em:

```text
ui/dist/assets/notebook-frame-overlay.png
```

Área medida da tela na referência 1920×1080:

```text
x: 289..1628
y: 118..956
left:   15.052083%
top:    10.925926%
width:  69.791667%
height: 77.685185%
```

Esses números estão no `Config.DeviceSkins.notebook_basic.viewport` e também no CSS baseline.

## 7. Primeira execução

No console do servidor, confirme:

```text
[mz_computer] Applying migration ...
[mz_computer] MZ OS 1.0.0 ready (... public terminals)
[mz_computer] Notebook item handler registered for "notebook"
```

Se aparecer aviso dizendo que `notebook` não existe no `mz_core`, adicione a definição do item e reinicie `mz_core` + `mz_computer` de forma controlada.
