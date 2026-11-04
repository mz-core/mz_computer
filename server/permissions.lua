MZComputer = MZComputer or {}
local Permissions = {}

local function normalizeName(value)
    return type(value) == 'string' and string.lower(value) or nil
end

local function hasOrg(source, wanted, requiredType)
    wanted = normalizeName(wanted)
    for key, org in pairs(MZComputer.Identity.playerOrgs(source)) do
        if normalizeName(tostring(key)) == wanted then return true end
        if type(org) == 'string' and normalizeName(org) == wanted then return true end
        if type(org) == 'table' then
            local id = normalizeName(org.code or org.id or org.name or org.org)
            local orgType = normalizeName(org.type)
            if id == wanted and (not requiredType or orgType == requiredType) then return true end
        end
    end
    return false
end

function Permissions.has(source, permission, deviceContext)
    if type(permission) ~= 'string' or permission == '' then return false end
    if permission == 'citizen' then return MZComputer.Identity.resolve(source) ~= nil end
    if permission == 'staff' then
        if IsPlayerAceAllowed(source, Config.Security.staffAce) then return true end
        return MZComputer.Identity.hasGlobalPermission(source, 'staff')
    end
    local prefix, value = permission:match('^([%w_%-]+):(.+)$')
    if prefix == 'job' then return hasOrg(source, value, 'job') end
    if prefix == 'org' then return hasOrg(source, value) end
    if prefix == 'perm' then return MZComputer.Identity.hasPermission(source, value) end
    if prefix == 'device' then
        local ctx = deviceContext or MZComputer.Devices.context(source)
        return ctx and (ctx.deviceType == value or ctx.deviceUid == value or ctx.terminalId == value) or false
    end
    return false
end

function Permissions.any(source, permissions, deviceContext)
    if type(permissions) ~= 'table' or #permissions == 0 then return true end
    for _, permission in ipairs(permissions) do
        if Permissions.has(source, permission, deviceContext) then return true end
    end
    return false
end

MZComputer.Permissions = Permissions
