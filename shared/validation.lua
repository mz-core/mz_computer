MZComputer = MZComputer or {}
local V = {}

function V.trim(value)
    if type(value) ~= 'string' then return '' end
    return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

function V.username(value)
    local username = string.lower(V.trim(value))
    if #username < Config.Auth.usernameMinLength or #username > Config.Auth.usernameMaxLength then
        return nil, 'username_length'
    end
    if not username:match('^[a-z0-9%._%-]+$') then
        return nil, 'username_charset'
    end
    if username:match('^%.') or username:match('%.$') or username:find('%.%.', 1, true) then
        return nil, 'username_format'
    end
    local reserved = { admin=true, administrator=true, root=true, system=true, mz=true, staff=true, support=true }
    if reserved[username] then return nil, 'username_reserved' end
    return username
end

function V.password(value)
    if type(value) ~= 'string' then return false, 'password_type' end
    local len = #value
    if len < Config.Auth.passwordMinLength or len > Config.Auth.passwordMaxLength then
        return false, 'password_length'
    end
    if value:find('%z') then return false, 'password_nul' end
    return true
end

function V.string(value, minLen, maxLen)
    if type(value) ~= 'string' then return nil end
    value = V.trim(value)
    if minLen and #value < minLen then return nil end
    if maxLen and #value > maxLen then return nil end
    return value
end

function V.id(value, maxLen)
    if type(value) ~= 'string' then return nil end
    if #value < 1 or #value > (maxLen or 64) then return nil end
    if not value:match('^[a-zA-Z0-9_%.:%-]+$') then return nil end
    return value
end

function V.table(value)
    return type(value) == 'table' and value or {}
end

function V.clamp(value, minV, maxV)
    value = tonumber(value)
    if not value then return minV end
    if value < minV then return minV end
    if value > maxV then return maxV end
    return value
end

function V.safeJsonDecode(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback or {} end
    local ok, decoded = pcall(json.decode, value)
    if not ok or type(decoded) ~= 'table' then return fallback or {} end
    return decoded
end

MZComputer.Validation = V
