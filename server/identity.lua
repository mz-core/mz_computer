MZComputer = MZComputer or {}

local Identity = {}

local function debugEnabled()
    return Config and Config.Debug == true
end

local function debugLog(message)
    if debugEnabled() then
        print(('[mz_computer][identity] %s'):format(tostring(message or '')))
    end
end

-- FiveM Lua exports are method-style calls.
--
-- Static usage normally looks like:
--   exports['mz_core']:ResolvePlayerIdentity(source)
--
-- When the export name is dynamic, calling:
--   exports['mz_core'][name](source)
-- loses the export proxy ("self") and the first real argument is consumed as self.
-- In practice mz_core then receives source=nil and correctly returns invalid_source.
--
-- Bind the proxy explicitly so this dynamic helper behaves exactly like ":".
local function coreExport(name, ...)
    if GetResourceState('mz_core') ~= 'started' then
        return nil, 'mz_core_unavailable'
    end

    local proxy = exports['mz_core']
    local exportFn = proxy[name]

    if type(exportFn) ~= 'function' then
        return nil, ('export_unavailable:%s'):format(tostring(name))
    end

    local args = table.pack(...)
    local result = table.pack(pcall(function()
        return exportFn(proxy, table.unpack(args, 1, args.n))
    end))

    if result[1] ~= true then
        return nil, tostring(result[2] or 'export_failed')
    end

    return table.unpack(result, 2, result.n)
end

local function orgExport(name, ...)
    if GetResourceState('mz_org') ~= 'started' then return nil, 'mz_org_unavailable' end
    local proxy = exports['mz_org']
    local exportFn = proxy[name]
    if type(exportFn) ~= 'function' then return nil, ('export_unavailable:%s'):format(tostring(name)) end
    local args = table.pack(...)
    local result = table.pack(pcall(function()
        return exportFn(proxy, table.unpack(args, 1, args.n))
    end))
    if result[1] ~= true then return nil, tostring(result[2] or 'export_failed') end
    return table.unpack(result, 2, result.n)
end

local function fromResolved(source, result)
    if type(result) ~= 'table' or result.ok ~= true then
        return nil
    end

    local citizenid = tostring(result.citizenid or '')
    local accountId = tonumber(result.accountId or result.account_id)
    local characterId = tonumber(result.characterId or result.character_id)
    local sessionId = tonumber(result.sessionId or result.session_id)
    if citizenid == '' or not accountId or not characterId or not sessionId then
        return nil
    end

    return {
        source = tonumber(source),
        accountId = accountId,
        characterId = characterId,
        sessionId = sessionId,
        citizenid = citizenid,
        firstname = tostring(result.firstname or ''),
        lastname = tostring(result.lastname or ''),
        phone = tostring(result.phone or '')
    }
end

local function resolveFromCore(source)
    local result, callErr = coreExport('ResolvePlayerIdentity', source)

    if type(result) == 'table' then
        local identity = fromResolved(source, result)
        if identity then
            return identity, nil, result
        end

        return nil, tostring(result.error or 'identity_unavailable'), result
    end

    return nil, tostring(callErr or 'identity_unavailable'), result
end

function Identity.resolve(source)
    source = tonumber(source)
    if not source or source <= 0 then
        return nil, 'invalid_source'
    end

    -- Runtime authority must come from the current core session. A player
    -- snapshot alone is not sufficient because source can be reused.
    local resolvedIdentity, resolveErr, resolvedRaw = resolveFromCore(source)
    if resolvedIdentity then
        return resolvedIdentity
    end

    debugLog(('initial resolve source=%s error=%s'):format(
        tostring(source), tostring(resolveErr)
    ))

    if type(resolvedRaw) == 'table' then
        debugLog(('identity unavailable source=%s core_error=%s detail=%s'):format(
            tostring(source),
            tostring(resolvedRaw.error or resolveErr),
            tostring(resolvedRaw.detail or '')
        ))
    else
        debugLog(('identity unavailable source=%s core_error=%s'):format(
            tostring(source), tostring(resolveErr)
        ))
    end

    return nil, 'identity_unavailable'
end

function Identity.playerOrgs(source)
    source = tonumber(source)
    if not source or source <= 0 then
        return {}
    end

    local result = orgExport('GetPlayerOrgs', source)
    return type(result) == 'table' and result or {}
end

function Identity.hasPermission(source, permission)
    source = tonumber(source)
    if not source or source <= 0 then
        return false
    end

    local result = coreExport('HasPermission', source, permission)
    return result == true
end

function Identity.hasGlobalPermission(source, permission)
    source = tonumber(source)
    if not source or source <= 0 then
        return false
    end

    local result = coreExport('HasGlobalPermission', source, permission)
    return result == true
end

MZComputer.Identity = Identity
