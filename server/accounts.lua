MZComputer = MZComputer or {}
local Accounts = {}

local function queryAccountByUsername(username)
    return MZComputer.Repo.one([[
        SELECT a.*, UNIX_TIMESTAMP(a.locked_until) AS locked_until_unix
        FROM mz_computer_accounts a WHERE a.username_normalized = ? LIMIT 1
    ]], { username })
end

function Accounts.getByUsername(username)
    local normalized = MZComputer.Validation.username(username)
    return normalized and queryAccountByUsername(normalized) or nil
end

function Accounts.getById(accountId)
    return MZComputer.Repo.one('SELECT id, username, status, created_at, revision FROM mz_computer_accounts WHERE id = ? LIMIT 1', { tonumber(accountId) })
end

function Accounts.primaryForCitizen(citizenid)
    return MZComputer.Repo.one([[
        SELECT a.id, a.username, a.status, a.created_at
        FROM mz_computer_account_identities i
        JOIN mz_computer_accounts a ON a.id = i.account_id
        WHERE i.citizen_id = ? AND i.identity_type = 'primary'
        ORDER BY i.id ASC LIMIT 1
    ]], { tostring(citizenid) })
end

function Accounts.create(source, username, password)
    local identity, identityErr = MZComputer.Identity.resolve(source)
    if not identity then return nil, identityErr or MZComputer.Const.Error.IDENTITY_UNAVAILABLE end
    local normalized, userErr = MZComputer.Validation.username(username)
    if not normalized then return nil, userErr end
    local passOk, passErr = MZComputer.Validation.password(password)
    if not passOk then return nil, passErr end

    if Config.Auth.onePersonalAccountPerCitizen and Accounts.primaryForCitizen(identity.citizenid) then
        return nil, MZComputer.Const.Error.ACCOUNT_EXISTS
    end
    if queryAccountByUsername(normalized) then return nil, MZComputer.Const.Error.ACCOUNT_EXISTS end

    local passwordHash, algo, version = MZComputer.Crypto.hashPassword(password, source)
    local accountId
    local ok, err = pcall(function()
        accountId = MZComputer.Repo.insert([[
            INSERT INTO mz_computer_accounts
                (username, username_normalized, password_hash, password_algo, password_version, status, failed_attempts, revision)
            VALUES (?, ?, ?, ?, ?, 'active', 0, 1)
        ]], { normalized, normalized, passwordHash, algo, version })
        MZComputer.Repo.insert([[
            INSERT INTO mz_computer_account_identities (account_id, citizen_id, identity_type)
            VALUES (?, ?, 'primary')
        ]], { accountId, identity.citizenid })
        MZComputer.Repo.insert('INSERT INTO mz_computer_account_settings (account_id, settings_json, revision) VALUES (?, ?, 1)', {
            accountId, MZComputer.Repo.json({ theme=Config.UI.defaultTheme, scale=Config.UI.defaultScale, sounds=Config.UI.sounds, pinned={'browser','notes','files'} })
        })
    end)
    if not ok then
        if accountId then pcall(function() MZComputer.Repo.update('DELETE FROM mz_computer_accounts WHERE id = ?', { accountId }) end) end
        if Config.Debug then print(('[mz_computer] account creation failed: %s'):format(tostring(err))) end
        return nil, MZComputer.Const.Error.ACCOUNT_EXISTS
    end

    MZComputer.Audit.log('account.created', { source=source, accountId=accountId }, 'digital account created', { citizenid=identity.citizenid, username=normalized })
    return Accounts.getById(accountId)
end

function Accounts.recordFailure(account)
    if not account then return end
    local attempts = (tonumber(account.failed_attempts) or 0) + 1
    if attempts >= Config.Auth.maxFailedAttempts then
        local untilUnix = os.time() + Config.Auth.lockSeconds
        MZComputer.Repo.update([[
            UPDATE mz_computer_accounts SET failed_attempts = 0, locked_until = FROM_UNIXTIME(?), status='locked', revision=revision+1 WHERE id = ?
        ]], { untilUnix, account.id })
        MZComputer.Audit.log('account.locked', { accountId=account.id }, 'too many invalid passwords')
    else
        MZComputer.Repo.update('UPDATE mz_computer_accounts SET failed_attempts = ?, revision=revision+1 WHERE id = ?', { attempts, account.id })
    end
end

function Accounts.clearFailures(accountId)
    MZComputer.Repo.update("UPDATE mz_computer_accounts SET failed_attempts=0, locked_until=NULL, status=CASE WHEN status='locked' THEN 'active' ELSE status END, revision=revision+1 WHERE id = ?", { accountId })
end

MZComputer.Accounts = Accounts
