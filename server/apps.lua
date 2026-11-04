MZComputer = MZComputer or {}
local Apps = {}
local registry = {}
local owners = {}

local function copyDescriptor(app)
    return {
        id = app.id, name = app.name, icon = app.icon, version = app.version,
        category = app.category, entryType = app.entryType, entryKey = app.entryKey,
        permissions = app.permissions or {}, visibility = app.visibility, defaultInstalled = app.defaultInstalled == true
    }
end

local function validateDescriptor(descriptor)
    if type(descriptor) ~= 'table' then return nil, 'descriptor' end
    local id = MZComputer.Validation.id(descriptor.id, 48)
    local name = MZComputer.Validation.string(descriptor.name, 1, 64)
    if not id or not name then return nil, 'id_or_name' end
    local entryType = descriptor.entryType or 'site'
    if entryType ~= 'internal' and entryType ~= 'site' then return nil, 'entry_type' end
    local permissions = {}
    if type(descriptor.permissions) == 'table' then
        for _, p in ipairs(descriptor.permissions) do
            local clean = MZComputer.Validation.string(p, 1, 80)
            if clean then permissions[#permissions + 1] = clean end
            if #permissions >= 12 then break end
        end
    end
    return {
        id = id,
        name = name,
        icon = MZComputer.Validation.id(descriptor.icon or 'app', 48) or 'app',
        version = MZComputer.Validation.string(descriptor.version or '1.0.0', 1, 24) or '1.0.0',
        category = MZComputer.Validation.id(descriptor.category or 'general', 32) or 'general',
        entryType = entryType,
        entryKey = MZComputer.Validation.id(descriptor.entryKey or id, 64) or id,
        permissions = permissions,
        visibility = descriptor.visibility == 'hidden' and 'hidden' or (descriptor.visibility == 'disabled' and 'disabled' or 'visible'),
        defaultInstalled = descriptor.defaultInstalled ~= false
    }
end

function Apps.register(descriptor, origin, builtIn)
    local app, err = validateDescriptor(descriptor)
    if not app then return false, err end
    origin = origin or GetInvokingResource() or GetCurrentResourceName()
    if app.entryType == 'internal' and not builtIn and origin ~= GetCurrentResourceName() and not Config.Security.trustedAppResources[origin] then
        return false, 'internal_apps_require_trusted_resource'
    end
    if registry[app.id] and owners[app.id] ~= origin and not builtIn then return false, 'app_id_owned' end
    registry[app.id], owners[app.id] = app, origin
    return true
end

function Apps.unregister(appId, origin)
    appId = MZComputer.Validation.id(appId, 48)
    if not appId or not registry[appId] then return false end
    origin = origin or GetInvokingResource() or GetCurrentResourceName()
    if owners[appId] ~= origin and origin ~= GetCurrentResourceName() then return false end
    registry[appId], owners[appId] = nil, nil
    return true
end

function Apps.get(appId) return registry[appId] end

function Apps.listFor(source)
    local out = {}
    local ctx = MZComputer.Devices.context(source)
    for _, app in pairs(registry) do
        if app.visibility ~= 'disabled' and MZComputer.Permissions.any(source, app.permissions, ctx) then
            out[#out + 1] = copyDescriptor(app)
        end
    end
    table.sort(out, function(a,b) return a.name:lower() < b.name:lower() end)
    return out
end

function Apps.canOpen(source, appId)
    local app = registry[appId]
    return app ~= nil and app.visibility ~= 'disabled' and MZComputer.Permissions.any(source, app.permissions, MZComputer.Devices.context(source))
end

function Apps.unregisterOrigin(resourceName)
    local ids = {}
    for id, owner in pairs(owners) do if owner == resourceName then ids[#ids + 1] = id end end
    for _, id in ipairs(ids) do registry[id], owners[id] = nil, nil end
end

function Apps.bootstrap()
    local builtIns = {
        { id='profile', name='Meu perfil', icon='user', category='city', entryType='internal', entryKey='profile', permissions={'citizen'} },
        { id='browser', name='MZ Browser', icon='globe', category='system', entryType='internal', entryKey='browser', permissions={'citizen'} },
        { id='notes', name='Notas', icon='note', category='productivity', entryType='internal', entryKey='notes', permissions={'citizen'} },
        { id='files', name='Arquivos', icon='folder', category='productivity', entryType='internal', entryKey='files', permissions={'citizen'} },
        { id='settings', name='Configurações', icon='settings', category='system', entryType='internal', entryKey='settings', permissions={'citizen'} },
        { id='about', name='Sobre o MZ OS', icon='info', category='system', entryType='internal', entryKey='about', permissions={'citizen'} }
    }
    for _, app in ipairs(builtIns) do Apps.register(app, GetCurrentResourceName(), true) end
end

MZComputer.Apps = Apps
