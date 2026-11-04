MZComputer = MZComputer or {}
local Content = {}

local function ownedRow(tableName, id, accountId)
    return MZComputer.Repo.one(('SELECT * FROM %s WHERE id = ? AND account_id = ? LIMIT 1'):format(tableName), { tonumber(id), tonumber(accountId) })
end

function Content.listNotes(accountId)
    return MZComputer.Repo.all('SELECT id, title, content, created_at, updated_at, revision FROM mz_computer_notes WHERE account_id = ? ORDER BY updated_at DESC LIMIT ?', { accountId, Config.Content.maxNotes })
end

function Content.createNote(accountId, title, body)
    title = MZComputer.Validation.string(title or 'Nova nota', 1, Config.Content.maxNoteTitle)
    body = type(body) == 'string' and body or ''
    if not title or #body > Config.Content.maxNoteContent then return nil, MZComputer.Const.Error.VALIDATION_FAILED end
    local count = tonumber(MZComputer.Repo.scalar('SELECT COUNT(*) FROM mz_computer_notes WHERE account_id = ?', { accountId })) or 0
    if count >= Config.Content.maxNotes then return nil, MZComputer.Const.Error.LIMIT_REACHED end
    local id = MZComputer.Repo.insert('INSERT INTO mz_computer_notes (account_id, title, content, revision) VALUES (?, ?, ?, 1)', { accountId, title, body })
    return ownedRow('mz_computer_notes', id, accountId)
end

function Content.updateNote(accountId, id, title, body, revision)
    title = MZComputer.Validation.string(title, 1, Config.Content.maxNoteTitle)
    body = type(body) == 'string' and body or nil
    revision = tonumber(revision)
    if not title or not body or #body > Config.Content.maxNoteContent or not revision then return nil, MZComputer.Const.Error.VALIDATION_FAILED end
    local changed = MZComputer.Repo.update([[
        UPDATE mz_computer_notes SET title=?, content=?, revision=revision+1, updated_at=NOW()
        WHERE id=? AND account_id=? AND revision=?
    ]], { title, body, tonumber(id), accountId, revision })
    if changed == 0 then return nil, MZComputer.Const.Error.CONFLICT end
    return ownedRow('mz_computer_notes', id, accountId)
end

function Content.deleteNote(accountId, id)
    return MZComputer.Repo.update('DELETE FROM mz_computer_notes WHERE id=? AND account_id=?', { tonumber(id), accountId }) > 0
end

function Content.listDocuments(accountId)
    return MZComputer.Repo.all('SELECT id, title, content, created_at, updated_at, revision FROM mz_computer_documents WHERE account_id = ? ORDER BY updated_at DESC LIMIT ?', { accountId, Config.Content.maxDocuments })
end

function Content.createDocument(accountId, title, body)
    title = MZComputer.Validation.string(title or 'Novo documento', 1, Config.Content.maxDocumentTitle)
    body = type(body) == 'string' and body or ''
    if not title or #body > Config.Content.maxDocumentContent then return nil, MZComputer.Const.Error.VALIDATION_FAILED end
    local count = tonumber(MZComputer.Repo.scalar('SELECT COUNT(*) FROM mz_computer_documents WHERE account_id = ?', { accountId })) or 0
    if count >= Config.Content.maxDocuments then return nil, MZComputer.Const.Error.LIMIT_REACHED end
    local id = MZComputer.Repo.insert('INSERT INTO mz_computer_documents (account_id, title, content, revision) VALUES (?, ?, ?, 1)', { accountId, title, body })
    return ownedRow('mz_computer_documents', id, accountId)
end

function Content.updateDocument(accountId, id, title, body, revision)
    title = MZComputer.Validation.string(title, 1, Config.Content.maxDocumentTitle)
    body = type(body) == 'string' and body or nil
    revision = tonumber(revision)
    if not title or not body or #body > Config.Content.maxDocumentContent or not revision then return nil, MZComputer.Const.Error.VALIDATION_FAILED end
    local changed = MZComputer.Repo.update([[
        UPDATE mz_computer_documents SET title=?, content=?, revision=revision+1, updated_at=NOW()
        WHERE id=? AND account_id=? AND revision=?
    ]], { title, body, tonumber(id), accountId, revision })
    if changed == 0 then return nil, MZComputer.Const.Error.CONFLICT end
    return ownedRow('mz_computer_documents', id, accountId)
end

function Content.deleteDocument(accountId, id)
    return MZComputer.Repo.update('DELETE FROM mz_computer_documents WHERE id=? AND account_id=?', { tonumber(id), accountId }) > 0
end

local function sanitizeSettings(input)
    input = type(input) == 'table' and input or {}
    local out = {
        theme = input.theme == 'light' and 'light' or 'dark',
        scale = MZComputer.Validation.clamp(input.scale, Config.UI.minScale, Config.UI.maxScale),
        sounds = input.sounds ~= false,
        wallpaper = ({ midnight=true, ocean=true, ember=true })[input.wallpaper] and input.wallpaper or 'midnight',
        pinned = {}
    }
    if type(input.pinned) == 'table' then
        local seen = {}
        for _, appId in ipairs(input.pinned) do
            appId = MZComputer.Validation.id(appId, 48)
            if appId and not seen[appId] and #out.pinned < 8 then seen[appId]=true; out.pinned[#out.pinned+1]=appId end
        end
    end
    return out
end

function Content.getSettings(accountId)
    local row = MZComputer.Repo.one('SELECT settings_json, revision FROM mz_computer_account_settings WHERE account_id=? LIMIT 1', { accountId })
    if not row then return sanitizeSettings({}), 1 end
    return sanitizeSettings(MZComputer.Repo.decode(row.settings_json, {})), tonumber(row.revision) or 1
end

function Content.saveSettings(accountId, settings)
    settings = sanitizeSettings(settings)
    MZComputer.Repo.update([[
        INSERT INTO mz_computer_account_settings (account_id, settings_json, revision)
        VALUES (?, ?, 1)
        ON DUPLICATE KEY UPDATE settings_json=VALUES(settings_json), revision=revision+1, updated_at=NOW()
    ]], { accountId, MZComputer.Repo.json(settings) })
    return settings
end

MZComputer.Content = Content
