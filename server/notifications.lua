MZComputer = MZComputer or {}
local Notifications = {}

local function clean(notification)
    if type(notification) ~= 'table' then return nil end
    local title = MZComputer.Validation.string(notification.title, 1, 100)
    local message = MZComputer.Validation.string(notification.message, 1, 500)
    if not title or not message then return nil end
    return {
        title=title, message=message,
        type=MZComputer.Validation.id(notification.type or 'info', 24) or 'info',
        icon=MZComputer.Validation.id(notification.icon or 'bell', 32) or 'bell',
        data=type(notification.data)=='table' and notification.data or {}
    }
end

function Notifications.list(accountId)
    return MZComputer.Repo.all([[
        SELECT id, title, message, type, icon, is_read, created_at
        FROM mz_computer_notifications WHERE account_id=? ORDER BY created_at DESC LIMIT 50
    ]], { accountId })
end

function Notifications.push(accountId, notification)
    accountId = tonumber(accountId)
    notification = clean(notification)
    if not accountId or not notification then return false end
    local id = MZComputer.Repo.insert([[
        INSERT INTO mz_computer_notifications (account_id, title, message, type, icon, data_json, is_read)
        VALUES (?, ?, ?, ?, ?, ?, 0)
    ]], { accountId, notification.title, notification.message, notification.type, notification.icon, MZComputer.Repo.json(notification.data) })
    local active = MZComputer.Sessions.getByAccount and MZComputer.Sessions.getByAccount(accountId) or nil
    if active then
        local payload = { id=id, title=notification.title, message=notification.message, type=notification.type, icon=notification.icon, is_read=0 }
        TriggerClientEvent('mz_computer:client:notification', active.source, payload)
    end
    return true, id
end

function Notifications.markRead(accountId, id)
    return MZComputer.Repo.update('UPDATE mz_computer_notifications SET is_read=1 WHERE id=? AND account_id=?', { tonumber(id), accountId }) > 0
end

MZComputer.Notifications = Notifications
