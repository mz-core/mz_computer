MZComputer = MZComputer or {}
local Auth = {}
local sourceAttempts = {}

local function sourceAllowed(source)
    local now = os.time()
    local state = sourceAttempts[source]
    if not state or now - state.startedAt >= Config.Auth.failureWindowSeconds then
        state = { startedAt=now, count=0, blockedUntil=0 }
        sourceAttempts[source] = state
    end
    if state.blockedUntil and state.blockedUntil > now then return false end
    return true
end

local function recordSourceFailure(source)
    local now = os.time()
    local state = sourceAttempts[source] or { startedAt=now, count=0, blockedUntil=0 }
    if now - state.startedAt >= Config.Auth.failureWindowSeconds then state = { startedAt=now, count=0, blockedUntil=0 } end
    state.count = state.count + 1
    if state.count >= Config.Auth.maxFailedAttempts * 2 then
        state.blockedUntil = now + math.min(Config.Auth.lockSeconds, 120)
        state.count = 0
    end
    sourceAttempts[source] = state
end

local function clearSourceFailures(source)
    sourceAttempts[source] = nil
end

local function sessionContext(source)
    local valid, deviceContext = MZComputer.Devices.validateUse(source)
    if not valid then return nil, deviceContext end
    local identity, identityErr = MZComputer.Identity.resolve(source)
    if not identity then return nil, identityErr end
    return {
        deviceId = deviceContext.deviceId,
        deviceUid = deviceContext.deviceUid,
        citizenid = identity.citizenid,
        coreAccountId = identity.accountId,
        characterId = identity.characterId,
        coreSessionId = identity.sessionId
    }
end

function Auth.context(source)
    local valid, ctxOrErr = MZComputer.Devices.validateUse(source)
    if not valid then return nil, ctxOrErr end
    local identity, err = MZComputer.Identity.resolve(source)
    if not identity then return nil, err end
    local primary = MZComputer.Accounts.primaryForCitizen(identity.citizenid)
    return {
        hasPersonalAccount = primary ~= nil,
        suggestedUsername = primary and primary.username or nil,
        device = ctxOrErr.device,
        warning = 'Use uma senha apenas para seu personagem. Não reutilize senhas reais.'
    }
end

function Auth.create(source, username, password)
    if not sourceAllowed(source) then return nil, MZComputer.Const.Error.AUTH_RATE_LIMITED end
    local deviceContext, deviceErr = sessionContext(source)
    if not deviceContext then return nil, deviceErr end
    local account, err = MZComputer.Accounts.create(source, username, password)
    if not account then return nil, err end
    local session, sessionErr = MZComputer.Sessions.create(source, account.id, deviceContext)
    if not session then return nil, sessionErr end
    clearSourceFailures(source)
    return { account=account, session=MZComputer.Sessions.public(session), _sessionToken=session.rawToken }
end

function Auth.login(source, username, password)
    if not sourceAllowed(source) then return nil, MZComputer.Const.Error.AUTH_RATE_LIMITED end
    local normalized = MZComputer.Validation.username(username)
    local passOk = MZComputer.Validation.password(password)
    if not normalized or not passOk then
        recordSourceFailure(source)
        return nil, MZComputer.Const.Error.AUTH_INVALID_CREDENTIALS
    end
    local deviceContext, deviceErr = sessionContext(source)
    if not deviceContext then return nil, deviceErr end

    local account = MZComputer.Accounts.getByUsername(normalized)
    if not account then
        -- Equalize the expensive path so username enumeration is less useful.
        MZComputer.Crypto.pbkdf2(password, string.rep('\0', 16), Config.Auth.pbkdf2Iterations)
        recordSourceFailure(source)
        MZComputer.Audit.log('login.failed', { source=source }, 'invalid credentials')
        return nil, MZComputer.Const.Error.AUTH_INVALID_CREDENTIALS
    end

    if account.status == 'disabled' then
        MZComputer.Audit.log('login.failed', { source=source, accountId=account.id }, 'disabled account')
        return nil, MZComputer.Const.Error.AUTH_ACCOUNT_DISABLED
    end
    local lockedUntil = tonumber(account.locked_until_unix) or 0
    if account.status == 'locked' and lockedUntil > os.time() then
        return nil, MZComputer.Const.Error.AUTH_ACCOUNT_LOCKED
    elseif account.status == 'locked' then
        MZComputer.Accounts.clearFailures(account.id)
        account.status = 'active'
    end

    if not MZComputer.Crypto.verifyPassword(password, account.password_hash) then
        MZComputer.Accounts.recordFailure(account)
        recordSourceFailure(source)
        MZComputer.Audit.log('login.failed', { source=source, accountId=account.id }, 'invalid credentials')
        return nil, MZComputer.Const.Error.AUTH_INVALID_CREDENTIALS
    end

    clearSourceFailures(source)
    MZComputer.Accounts.clearFailures(account.id)
    local session, err = MZComputer.Sessions.create(source, account.id, deviceContext)
    if not session then return nil, err end
    return {
        account = { id=tonumber(account.id), username=account.username, status='active', created_at=account.created_at, revision=tonumber(account.revision) },
        session = MZComputer.Sessions.public(session),
        _sessionToken = session.rawToken
    }
end

function Auth.logout(source, token)
    local session, err = MZComputer.Sessions.validate(source, token)
    if not session then return false, err end
    MZComputer.Sessions.revokeSource(source, 'logout', false)
    return true
end

MZComputer.Auth = Auth
