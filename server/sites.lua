MZComputer = MZComputer or {}
local Sites = {}
local registry, aliases, owners = {}, {}, {}

local function normalizeAlias(alias)
    alias = MZComputer.Validation.trim(alias):lower()
    alias = alias:gsub('^www%.', ''):gsub('/+$', '')
    if #alias < 1 or #alias > 96 then return nil end
    if alias:find('[^a-z0-9%.%-_]') then return nil end
    return alias
end

local function publicSite(site)
    return {
        id=site.id, title=site.title, description=site.description, icon=site.icon,
        aliases=site.aliases, keywords=site.keywords, content=site.content
    }
end

function Sites.register(descriptor, origin)
    if type(descriptor) ~= 'table' then return false, 'descriptor' end
    local id = MZComputer.Validation.id(descriptor.id, 48)
    local title = MZComputer.Validation.string(descriptor.title, 1, 80)
    if not id or not title then return false, 'id_or_title' end
    origin = origin or GetInvokingResource() or GetCurrentResourceName()
    if registry[id] and owners[id] ~= origin then return false, 'site_id_owned' end

    local siteAliases = {}
    for _, value in ipairs(type(descriptor.aliases) == 'table' and descriptor.aliases or {}) do
        local alias = normalizeAlias(value)
        if alias and (not aliases[alias] or aliases[alias] == id) then siteAliases[#siteAliases + 1] = alias end
        if #siteAliases >= 12 then break end
    end
    if #siteAliases == 0 then siteAliases[1] = id .. '.mz' end

    local keywords = {}
    for _, value in ipairs(type(descriptor.keywords) == 'table' and descriptor.keywords or {}) do
        local clean = MZComputer.Validation.string(value, 1, 48)
        if clean then keywords[#keywords + 1] = clean:lower() end
        if #keywords >= 24 then break end
    end

    local permissions = {}
    for _, value in ipairs(type(descriptor.permissions) == 'table' and descriptor.permissions or {}) do
        local clean = MZComputer.Validation.string(value, 1, 80)
        if clean then permissions[#permissions + 1] = clean end
        if #permissions >= 12 then break end
    end

    local old = registry[id]
    if old then for _, alias in ipairs(old.aliases) do if aliases[alias] == id then aliases[alias] = nil end end end
    local site = {
        id=id, title=title,
        description=MZComputer.Validation.string(descriptor.description or '', 0, 320) or '',
        icon=MZComputer.Validation.id(descriptor.icon or 'globe', 48) or 'globe',
        aliases=siteAliases, keywords=keywords, permissions=permissions,
        visibility=descriptor.visibility == 'disabled' and 'disabled' or 'visible',
        content=MZComputer.Validation.string(descriptor.content or '', 0, 6000) or ''
    }
    registry[id], owners[id] = site, origin
    for _, alias in ipairs(siteAliases) do aliases[alias] = id end
    return true
end

function Sites.unregister(siteId, origin)
    siteId = MZComputer.Validation.id(siteId, 48)
    local site = siteId and registry[siteId]
    if not site then return false end
    origin = origin or GetInvokingResource() or GetCurrentResourceName()
    if owners[siteId] ~= origin and origin ~= GetCurrentResourceName() then return false end
    for _, alias in ipairs(site.aliases) do if aliases[alias] == siteId then aliases[alias] = nil end end
    registry[siteId], owners[siteId] = nil, nil
    return true
end

local function blockedScheme(input)
    local lower = input:lower()
    for _, scheme in ipairs(Config.Browser.blockedSchemes) do
        if lower:sub(1, #scheme) == scheme then return true end
    end
    if lower:find('^[%a][%w+.-]*://') and lower:sub(1,5) ~= 'mz://' then return true end
    return false
end

function Sites.resolve(source, address)
    if type(address) ~= 'string' then return nil, MZComputer.Const.Error.VALIDATION_FAILED end
    local input = MZComputer.Validation.trim(address)
    if #input < 1 or #input > 180 then return nil, MZComputer.Const.Error.VALIDATION_FAILED end
    if blockedScheme(input) then return nil, MZComputer.Const.Error.EXTERNAL_URL_BLOCKED end

    local lower = input:lower()
    if lower:sub(1,5) == 'mz://' then lower = lower:sub(6) end
    lower = lower:gsub('^www%.', ''):gsub('^/+', '')
    local host, path = lower:match('^([^/]+)(/.*)$')
    if not host then host, path = lower, '/' end
    host = normalizeAlias(host)
    if not host then return nil, MZComputer.Const.Error.SITE_NOT_FOUND end

    local siteId = aliases[host] or (registry[host] and host) or nil
    local site = siteId and registry[siteId] or nil
    if not site or site.visibility == 'disabled' then return nil, MZComputer.Const.Error.SITE_NOT_FOUND end
    if not MZComputer.Permissions.any(source, site.permissions, MZComputer.Devices.context(source)) then
        return nil, MZComputer.Const.Error.APP_FORBIDDEN
    end
    local result = publicSite(site)
    result.url = 'mz://' .. site.id .. (path ~= '/' and path or '')
    result.path = path
    return result
end

function Sites.search(source, query)
    query = MZComputer.Validation.string(query, 1, 120)
    if not query then return {} end
    local needle = query:lower()
    local results = {}
    for _, site in pairs(registry) do
        if site.visibility ~= 'disabled' and MZComputer.Permissions.any(source, site.permissions, MZComputer.Devices.context(source)) then
            local hay = (site.title .. ' ' .. site.description .. ' ' .. table.concat(site.keywords, ' ') .. ' ' .. table.concat(site.aliases, ' ')):lower()
            if hay:find(needle, 1, true) then results[#results + 1] = publicSite(site) end
        end
    end
    table.sort(results, function(a,b) return a.title:lower() < b.title:lower() end)
    return results
end

function Sites.unregisterOrigin(resourceName)
    local ids = {}
    for id, owner in pairs(owners) do if owner == resourceName then ids[#ids + 1] = id end end
    for _, id in ipairs(ids) do Sites.unregister(id, resourceName) end
end

function Sites.bootstrap()
    Sites.register({
        id='home', title='MZ Net', aliases={'home.mz','inicio.mz','home'}, icon='home',
        keywords={'inicio','mz','rede','sites'},
        description='A rede digital interna da cidade.',
        content='Bem-vindo à MZ Net. Esta rede existe somente dentro da cidade. Use a barra de endereços para acessar sites registrados ou pesquise serviços internos.'
    }, GetCurrentResourceName())
    Sites.register({
        id='help', title='Central MZ', aliases={'ajuda.mz','help.mz'}, icon='help',
        keywords={'ajuda','suporte','computador','conta','senha'},
        description='Ajuda do MZ OS e da MZ Net.',
        content='Sua conta digital é separada do dispositivo. Nunca reutilize uma senha real. Computadores públicos encerram a sessão ao sair. A MZ Net não acessa a internet real.'
    }, GetCurrentResourceName())
    Sites.register({
        id='directory', title='Diretório de Serviços', aliases={'servicos.mz','sites.mz'}, icon='grid',
        keywords={'servicos','diretorio','sites','apps'},
        description='Diretório dos serviços disponíveis na rede.',
        content='Novos serviços aparecem aqui quando resources da MZ Framework registram sites e aplicativos no mz_computer.'
    }, GetCurrentResourceName())
end

MZComputer.Sites = Sites
