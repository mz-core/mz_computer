MZComputer = MZComputer or {}
local Bridge = {}
local rate = {}

local function response(ok, data, err)
    return { ok=ok == true, data=data, error=err }
end

local function allowRequest(source)
    local now = GetGameTimer()
    local state = rate[source]
    if not state then
        state = { minuteStart=now, minuteCount=0, burstStart=now, burstCount=0 }
        rate[source] = state
    end
    if now - state.minuteStart >= 60000 then state.minuteStart, state.minuteCount = now, 0 end
    if now - state.burstStart >= 10000 then state.burstStart, state.burstCount = now, 0 end
    state.minuteCount, state.burstCount = state.minuteCount + 1, state.burstCount + 1
    return state.minuteCount <= Config.Security.requestRatePerMinute and state.burstCount <= Config.Security.requestBurst
end

local function protected(source, token)
    if not allowRequest(source) then return nil, MZComputer.Const.Error.AUTH_RATE_LIMITED end
    return MZComputer.Sessions.validate(source, token)
end

local function bootstrap(source, session)
    local account = MZComputer.Accounts.getById(session.accountId)
    local settings = MZComputer.Content.getSettings(session.accountId)
    local ctx = MZComputer.Devices.context(source)
    return {
        account=account,
        session=MZComputer.Sessions.public(session),
        device=ctx and ctx.device or nil,
        apps=MZComputer.Apps.listFor(source),
        settings=settings,
        notifications=MZComputer.Notifications.list(session.accountId),
        network={ name=Config.Browser.networkName, home=Config.Browser.homeUrl },
        version=Config.Version
    }
end

function Bridge.handle(source, request)
    if type(request) ~= 'table' then return response(false, nil, MZComputer.Const.Error.VALIDATION_FAILED) end
    local action = MZComputer.Validation.string(request.action, 1, 64)
    local payload = type(request.payload) == 'table' and request.payload or {}
    local token = type(request.token) == 'string' and request.token or nil
    if not action then return response(false, nil, MZComputer.Const.Error.VALIDATION_FAILED) end

    if action == 'auth.context' then
        if not allowRequest(source) then return response(false, nil, MZComputer.Const.Error.AUTH_RATE_LIMITED) end
        local data, err = MZComputer.Auth.context(source)
        return response(data ~= nil, data, err)
    elseif action == 'auth.create' then
        if not allowRequest(source) then return response(false, nil, MZComputer.Const.Error.AUTH_RATE_LIMITED) end
        local data, err = MZComputer.Auth.create(source, payload.username, payload.password)
        return response(data ~= nil, data, err)
    elseif action == 'auth.login' then
        if not allowRequest(source) then return response(false, nil, MZComputer.Const.Error.AUTH_RATE_LIMITED) end
        local data, err = MZComputer.Auth.login(source, payload.username, payload.password)
        return response(data ~= nil, data, err)
    end

    local session, sessionErr = protected(source, token)
    if not session then return response(false, nil, sessionErr) end

    if action == 'auth.logout' then
        local ok, err = MZComputer.Auth.logout(source, token)
        return response(ok, { loggedOut=ok }, err)
    elseif action == 'os.bootstrap' then
        return response(true, bootstrap(source, session))
    elseif action == 'profile.get' then
        if not MZComputer.Apps.canOpen(source, 'profile') then
            return response(false, nil, MZComputer.Const.Error.APP_FORBIDDEN)
        end
        local identity, err = MZComputer.Identity.resolve(source)
        if not identity then return response(false, nil, err or 'IDENTITY_UNAVAILABLE') end
        -- Only the authenticated character's public profile, never license or
        -- the full player snapshot. Caller-supplied player IDs are ignored.
        return response(true, {
            firstname=identity.firstname, lastname=identity.lastname,
            citizenid=identity.citizenid, phone=identity.phone
        })
    elseif action == 'notes.list' then
        return response(true, MZComputer.Content.listNotes(session.accountId))
    elseif action == 'notes.create' then
        local row, err = MZComputer.Content.createNote(session.accountId, payload.title, payload.content)
        return response(row ~= nil, row, err)
    elseif action == 'notes.update' then
        local row, err = MZComputer.Content.updateNote(session.accountId, payload.id, payload.title, payload.content, payload.revision)
        return response(row ~= nil, row, err)
    elseif action == 'notes.delete' then
        local ok = MZComputer.Content.deleteNote(session.accountId, payload.id)
        return response(ok, { deleted=ok }, ok and nil or MZComputer.Const.Error.VALIDATION_FAILED)
    elseif action == 'documents.list' then
        return response(true, MZComputer.Content.listDocuments(session.accountId))
    elseif action == 'documents.create' then
        local row, err = MZComputer.Content.createDocument(session.accountId, payload.title, payload.content)
        return response(row ~= nil, row, err)
    elseif action == 'documents.update' then
        local row, err = MZComputer.Content.updateDocument(session.accountId, payload.id, payload.title, payload.content, payload.revision)
        return response(row ~= nil, row, err)
    elseif action == 'documents.delete' then
        local ok = MZComputer.Content.deleteDocument(session.accountId, payload.id)
        return response(ok, { deleted=ok }, ok and nil or MZComputer.Const.Error.VALIDATION_FAILED)
    elseif action == 'settings.get' then
        local settings, revision = MZComputer.Content.getSettings(session.accountId)
        return response(true, { settings=settings, revision=revision })
    elseif action == 'settings.save' then
        return response(true, MZComputer.Content.saveSettings(session.accountId, payload.settings))
    elseif action == 'browser.navigate' then
        local site, err = MZComputer.Sites.resolve(source, payload.address)
        if site then return response(true, { kind='site', site=site }) end
        if err == MZComputer.Const.Error.SITE_NOT_FOUND and type(payload.address) == 'string' then
            return response(true, { kind='search', query=payload.address, results=MZComputer.Sites.search(source, payload.address) })
        end
        return response(false, nil, err)
    elseif action == 'browser.search' then
        return response(true, { query=payload.query, results=MZComputer.Sites.search(source, payload.query) })
    elseif action == 'notifications.list' then
        return response(true, MZComputer.Notifications.list(session.accountId))
    elseif action == 'notifications.read' then
        local ok = MZComputer.Notifications.markRead(session.accountId, payload.id)
        return response(ok, { read=ok }, ok and nil or MZComputer.Const.Error.VALIDATION_FAILED)
    elseif action == 'apps.list' then
        return response(true, MZComputer.Apps.listFor(source))
    end

    return response(false, nil, MZComputer.Const.Error.VALIDATION_FAILED)
end

lib.callback.register('mz_computer:server:request', function(source, request)
    if not MZComputer.Ready then return response(false, nil, 'NOT_READY') end
    local ok, result = pcall(Bridge.handle, source, request)
    if not ok then
        print(('[mz_computer] bridge error for %s: %s'):format(source, tostring(result)))
        return response(false, nil, MZComputer.Const.Error.INTERNAL_ERROR)
    end
    return result
end)

lib.callback.register('mz_computer:server:openPublic', function(source, terminalId)
    if not MZComputer.Ready then return response(false, nil, 'NOT_READY') end
    local ok, result, err = pcall(function()
        local device, openErr = MZComputer.Devices.beginPublicUse(source, terminalId)
        return device, openErr
    end)
    if not ok then return response(false, nil, MZComputer.Const.Error.INTERNAL_ERROR) end
    return response(result ~= nil, result, err)
end)

RegisterNetEvent('mz_computer:server:closeDevice', function(reason)
    local source = source
    MZComputer.Sessions.revokeSource(source, 'device_closed', false)
    MZComputer.Devices.closeUse(source, reason or 'client_close')
end)

MZComputer.Bridge = Bridge
