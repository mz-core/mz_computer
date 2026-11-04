MZComputer = MZComputer or {}
local Sessions = {}
local bySource, byAccount = {}, {}

local function publicSession(session)
    return {
        id = session.sessionDbId,
        accountId = session.accountId,
        deviceUid = session.deviceUid,
        issuedAt = session.issuedAt,
        expiresAt = session.expiresAt
    }
end

function Sessions.revokeSource(source, reason, notifyClient)
    source = tonumber(source)
    local session = bySource[source]
    if not session then return false end
    bySource[source] = nil
    if byAccount[session.accountId] == session then byAccount[session.accountId] = nil end
    MZComputer.Repo.update("UPDATE mz_computer_sessions SET status='revoked', source=NULL, last_activity=NOW() WHERE id = ?", { session.sessionDbId })
    MZComputer.Audit.log('session.revoked', {
        source=source, accountId=session.accountId, sessionDbId=session.sessionDbId, deviceDbId=session.deviceId
    }, tostring(reason or 'revoked'))
    if notifyClient ~= false then TriggerClientEvent('mz_computer:client:forceLogout', source, tostring(reason or 'session_revoked')) end
    return true
end

function Sessions.revokeAccount(accountId, reason)
    accountId = tonumber(accountId)
    local active = byAccount[accountId]
    if active then Sessions.revokeSource(active.source, reason or 'new_login', true) end
    MZComputer.Repo.update("UPDATE mz_computer_sessions SET status='revoked', source=NULL WHERE account_id = ? AND status='valid'", { accountId })
end

function Sessions.create(source, accountId, deviceContext)
    source, accountId = tonumber(source), tonumber(accountId)
    if not source or not accountId or not deviceContext then return nil, MZComputer.Const.Error.SESSION_INVALID end
    local identity, identityErr = MZComputer.Identity.resolve(source)
    if not identity then return nil, identityErr or MZComputer.Const.Error.SESSION_INVALID end
    if tonumber(deviceContext.coreSessionId) ~= tonumber(identity.sessionId)
        or tonumber(deviceContext.coreAccountId) ~= tonumber(identity.accountId)
        or tonumber(deviceContext.characterId) ~= tonumber(identity.characterId) then
        return nil, MZComputer.Const.Error.SESSION_INVALID
    end
    Sessions.revokeSource(source, 'relogin', false)
    if Config.Sessions.maxConcurrentPerAccount == 1 and Config.Sessions.revokeOldSessionOnLogin then
        Sessions.revokeAccount(accountId, 'new_login')
    elseif byAccount[accountId] then
        return nil, MZComputer.Const.Error.CONFLICT
    end

    local rawToken = MZComputer.Crypto.randomHex(32, source, 'session')
    local tokenHash = MZComputer.Crypto.sha256(rawToken)
    local issuedAt = os.time()
    local expiresAt = issuedAt + Config.Sessions.ttlSeconds
    local sessionId = MZComputer.Repo.insert([[
        INSERT INTO mz_computer_sessions
            (session_token, account_id, device_id, citizen_id, source, status, issued_at, expires_at, last_activity, revision)
        VALUES (?, ?, ?, ?, ?, 'valid', NOW(), FROM_UNIXTIME(?), NOW(), 1)
    ]], { tokenHash, accountId, deviceContext.deviceId, deviceContext.citizenid, source, expiresAt })

    local session = {
        source = source, accountId = accountId, sessionDbId = tonumber(sessionId),
        deviceId = tonumber(deviceContext.deviceId), deviceUid = deviceContext.deviceUid,
        citizenid = deviceContext.citizenid, rawToken = rawToken, tokenHash = tokenHash,
        coreAccountId = tonumber(identity.accountId), characterId = tonumber(identity.characterId),
        coreSessionId = tonumber(identity.sessionId),
        issuedAt = issuedAt, expiresAt = expiresAt, lastDbTouch = issuedAt
    }
    bySource[source], byAccount[accountId] = session, session
    MZComputer.Devices.attachSession(source, session.sessionDbId)
    MZComputer.Audit.log('login.success', {
        source=source, accountId=accountId, sessionDbId=session.sessionDbId, deviceDbId=session.deviceId
    }, 'session created')
    return session
end

function Sessions.validate(source, rawToken)
    source = tonumber(source)
    local session = bySource[source]
    if not session or type(rawToken) ~= 'string' then return nil, MZComputer.Const.Error.SESSION_INVALID end
    if not MZComputer.Crypto.constantTimeEquals(session.rawToken, rawToken) then
        return nil, MZComputer.Const.Error.SESSION_INVALID
    end
    if session.expiresAt <= os.time() then
        Sessions.revokeSource(source, 'expired', true)
        return nil, MZComputer.Const.Error.SESSION_EXPIRED
    end
    local identity, identityErr = MZComputer.Identity.resolve(source)
    if not identity
        or tonumber(identity.sessionId) ~= session.coreSessionId
        or tonumber(identity.accountId) ~= session.coreAccountId
        or tonumber(identity.characterId) ~= session.characterId then
        Sessions.revokeSource(source, identityErr or 'core_identity_changed', true)
        return nil, MZComputer.Const.Error.SESSION_INVALID
    end
    local validUse, useErr = MZComputer.Devices.validateUse(source, session.deviceUid)
    if not validUse then
        Sessions.revokeSource(source, useErr or 'device_invalid', true)
        return nil, useErr or MZComputer.Const.Error.SESSION_INVALID
    end
    if os.time() - session.lastDbTouch >= 60 then
        session.lastDbTouch = os.time()
        MZComputer.Repo.update('UPDATE mz_computer_sessions SET last_activity=NOW() WHERE id = ? AND status=\'valid\'', { session.sessionDbId })
    end
    return session
end

function Sessions.getBySource(source)
    return bySource[tonumber(source)]
end

function Sessions.getByAccount(accountId)
    return byAccount[tonumber(accountId)]
end

function Sessions.public(session)
    return session and publicSession(session) or nil
end

function Sessions.shutdown()
    local sources = {}
    for source in pairs(bySource) do sources[#sources + 1] = source end
    for _, source in ipairs(sources) do Sessions.revokeSource(source, 'resource_stop', false) end
end

MZComputer.Sessions = Sessions
