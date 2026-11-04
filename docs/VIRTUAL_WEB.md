# MZ Net — rede virtual interna

A MZ Net parece uma web normal para RP, mas não resolve DNS real e não sai da NUI.

## Resolução

Exemplos:

```text
mz://home   -> site "home"
ajuda.mz    -> alias do site "help"
servicos.mz -> alias do diretório
mecânico    -> pesquisa no registry interno
```

Exemplo bloqueado:

```text
https://google.com -> EXTERNAL_URL_BLOCKED
javascript:...     -> EXTERNAL_URL_BLOCKED
```

Um domínio sem scheme que não existir, como `google.com`, vira no máximo uma pesquisa dentro da MZ Net; ele nunca é aberto externamente.

## Registrar site por outro resource

Server-side:

```lua
local ok, err = exports['mz_computer']:RegisterSite({
    id = 'jobs',
    title = 'MZ Jobs',
    icon = 'briefcase',
    aliases = { 'empregos.mz', 'jobs.mz' },
    keywords = { 'emprego', 'vaga', 'curriculo' },
    description = 'Vagas e currículos da cidade.',
    content = 'Acesse as vagas disponíveis e envie seu currículo.',
    permissions = { 'citizen' }
})
```

Na V1, o conteúdo do site descriptor é texto seguro. Não injete HTML/JS.

## App apontando para site

```lua
exports['mz_computer']:RegisterApp({
    id = 'jobs',
    name = 'Empregos',
    icon = 'briefcase',
    category = 'services',
    entryType = 'site',
    entryKey = 'jobs',
    permissions = { 'citizen' }
})
```

Ao abrir o app, o MZ Browser navega para `mz://jobs`.

Para UIs de domínio complexas (bank, MDT, ERP), não injete JavaScript arbitrário. Crie uma integração explicitamente aprovada/empacotada ou evolua o SDK com uma fronteira segura e versionada.
