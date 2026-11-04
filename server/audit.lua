MZComputer = MZComputer or {}
local Audit = {}

local function safeMetadata(metadata)
    metadata = type(metadata) == 'table' and metadata or {}
    local copy = {}
    for k, v in pairs(metadata) do
        local key = tostring(k):lower()
        if not key:find('password', 1, true) and not key:find('token', 1, true) and not key:find('hash', 1, true) then
            copy[k] = v
        end
    end
    return copy
end

function Audit.log(eventType, context, description, metadata)
    context = context or {}
    local ok, err = pcall(function()
        MZComputer.Repo.insert([[
            INSERT INTO mz_computer_audit_log
                (event_type, account_id, session_id, device_id, source, description, metadata_json)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], {
            tostring(eventType):sub(1, 64), context.accountId, context.sessionDbId, context.deviceDbId,
            context.source, description and tostring(description):sub(1, 255) or nil,
            MZComputer.Repo.json(safeMetadata(metadata))
        })
    end)
    if not ok and Config.Debug then print(('[mz_computer] audit failure: %s'):format(tostring(err))) end
end

MZComputer.Audit = Audit
