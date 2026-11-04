# App SDK v1

Contrato lógico: `computer.app.v1` / `computer.site.v1`.

## RegisterApp

Server export:

```lua
local ok, err = exports['mz_computer']:RegisterApp({
    id = 'company',
    name = 'Empresa',
    icon = 'briefcase',
    version = '1.0.0',
    category = 'business',
    entryType = 'site',
    entryKey = 'company',
    permissions = { 'citizen' },
    visibility = 'visible'
})
```

Tipos V1:

- `internal`: somente apps embutidos no `mz_computer` ou resources allowlisted em `Config.Security.trustedAppResources`;
- `site`: abre um site do Site Registry.

Não existe loader de JS/HTML arbitrário.

## RegisterSite

Veja `VIRTUAL_WEB.md`.

## PushNotification

```lua
exports['mz_computer']:PushNotification(accountId, {
    title = 'MZ Bank',
    message = 'Seu salário foi depositado.',
    type = 'success',
    icon = 'bank',
    data = { reference = 'payroll' }
})
```

A notificação é persistida; se a conta estiver com sessão ativa, chega também em tempo real.

## GetSessionContext

```lua
local ctx = exports['mz_computer']:GetSessionContext(source)
```

Retorna apenas contexto sanitizado e **não retorna token**.

## HasComputerPermission

```lua
if exports['mz_computer']:HasComputerPermission(source, 'job:police') then
    -- ação server-side ainda precisa validar o domínio real no owner correspondente
end
```

Isso é conveniência de UI/acesso; não substitui os guards do resource owner.

## OpenComputer

Um resource server-side pode abrir um device lógico:

```lua
exports['mz_computer']:OpenComputer(source, {
    physicalKey = ('business:%s:terminal:%s'):format(companyId, terminalId)
})
```

Use uma chave estável e derivada do domínio do caller.

## OpenApp

```lua
exports['mz_computer']:OpenApp(source, 'company')
```

Só funciona se existir uma sessão ativa e a permissão do app for válida.

## Lifecycle

Se seu resource registra app/site dinamicamente, registre novamente quando `mz_computer` iniciar. Ao parar o resource origin, `mz_computer` remove seus descriptors em memória automaticamente.
