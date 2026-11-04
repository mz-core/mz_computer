MZComputer = MZComputer or {}
local Devices = {}
local contexts = {}
local publicDevices = {}
local leases = {}

local function skinPublic(skinId)
    local skin = Config.DeviceSkins[skinId] or Config.DeviceSkins[Config.DefaultSkin]
    return {
        id = skin.id,
        name = skin.name,
        asset = skin.asset,
        aspectRatio = skin.aspectRatio,
        viewport = skin.viewport
    }
end

local function publicDeviceRow(row, label)
    if not row then return nil end
    return {
        id = tonumber(row.id),
        uid = row.device_uid,
        type = row.device_type,
        skinId = row.skin_id,
        serial = row.serial_number,
        status = row.status,
        label = label or row.serial_number,
        skin = skinPublic(row.skin_id)
    }
end

local function normalizeAnchor(anchor, includeHeading)
    if type(anchor) ~= 'table' then return nil end
    local limit = (Config.TerminalEditor and Config.TerminalEditor.anchorOffsetMax) or 6
    local offset = MZComputer.ScreenGeometry.point(anchor.offset, limit)
    if not offset or MZComputer.ScreenGeometry.length(offset) > limit then return nil end
    local out = {offset=offset}
    if includeHeading then
        out.heading = tonumber(anchor.heading) or 0.0
        out.mode = anchor.mode == 'standing' and 'standing' or 'standing'
    end
    return out
end

local function interactionCoords(term)
    local anchor = term and (term.interactionAnchor or term.playerAnchor)
    if anchor and anchor.offset then
        return MZComputer.ScreenGeometry.worldFromLocal(term.coords,term.heading or 0,anchor.offset) or term.coords
    end
    return term and term.coords or nil
end

local function normalizeTerminal(term)
    if type(term) ~= 'table' or not MZComputer.Validation.id(term.id, 48) then return nil end
    local coords = term.coords
    if not coords or coords.x == nil or coords.y == nil or coords.z == nil then return nil end
    return {
        id = term.id,
        label = term.label or term.id,
        coords = { x = tonumber(coords.x), y = tonumber(coords.y), z = tonumber(coords.z) },
        heading = tonumber(term.heading) or 0.0,
        skin = Config.DeviceSkins[term.skin] and term.skin or 'terminal_basic',
        interactionDistance = tonumber(term.interactionDistance) or Config.Interaction.drawDistance,
        playerAnchor = normalizeAnchor(term.playerAnchor,true),
        interactionAnchor = normalizeAnchor(term.interactionAnchor,false),
        display = term.display
    }
end

local function playerDistanceTo(source, coords)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return nil end
    local p = GetEntityCoords(ped)
    if not p then return nil end
    local dx,dy,dz = p.x - coords.x, p.y - coords.y, p.z - coords.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

function Devices.preparePublic(raw)
        local term = normalizeTerminal(raw)
        if term then
            local uid = 'public:' .. term.id
            local row = MZComputer.Repo.one('SELECT * FROM mz_computer_devices WHERE device_uid = ? LIMIT 1', { uid })
            if not row then
                local serial = ('MZ-PUB-%s'):format(string.upper(MZComputer.Crypto.sha256(term.id):sub(1, 8)))
                local id = MZComputer.Repo.insert([[
                    INSERT INTO mz_computer_devices
                        (device_uid, device_type, skin_id, ownership_type, owner_ref, serial_number, status, metadata_json)
                    VALUES (?, 'public', ?, 'public', ?, ?, 'active', ?)
                ]], { uid, term.skin, 'terminal:' .. term.id, serial, MZComputer.Repo.json({ terminalId = term.id }) })
                row = MZComputer.Repo.one('SELECT * FROM mz_computer_devices WHERE id = ? LIMIT 1', { id })
            else
                MZComputer.Repo.update('UPDATE mz_computer_devices SET skin_id = ?, status = \'active\', revision = revision + 1 WHERE id = ?', { term.skin, row.id })
                row.skin_id = term.skin
                row.status = 'active'
            end
            return { config = term, row = row }
        else
            print('^3[mz_computer]^7 Ignoring invalid public terminal configuration')
        end
end

function Devices.replacePublic(id, entry)
    local affected = {}
    for source, ctx in pairs(contexts) do
        if ctx.terminalId == id then affected[#affected+1] = source end
    end
    for _, source in ipairs(affected) do
        if MZComputer.Sessions then MZComputer.Sessions.revokeSource(source, 'terminal_updated', false) end
        Devices.closeUse(source, 'terminal_updated')
        TriggerClientEvent('mz_computer:client:forceClose', source, 'terminal_updated')
    end
    publicDevices[id] = entry
end

function Devices.bootstrapPublic()
    publicDevices = {}
    local definitions = {}
    for _, raw in ipairs(Config.PublicTerminals) do definitions[raw.id] = raw end
    for _, raw in ipairs(MZComputer.TerminalEditor.load()) do definitions[raw.id] = raw end
    for _, raw in pairs(definitions) do
        local entry = Devices.preparePublic(raw)
        if entry then publicDevices[entry.config.id] = entry end
    end
end

function Devices.getPublicDefinitions()
    local out = {}
    for id, entry in pairs(publicDevices) do
        out[#out + 1] = {
            id = id,
            label = entry.config.label,
            coords = entry.config.coords,
            heading = entry.config.heading,
            interactionDistance = entry.config.interactionDistance,
            playerAnchor = entry.config.playerAnchor,
            interactionAnchor = entry.config.interactionAnchor,
            skin = entry.config.skin,
            display = entry.config.display
        }
    end
    table.sort(out, function(a,b) return a.id < b.id end)
    return out
end

local function claimPublic(source, entry)
    local deviceId = tonumber(entry.row.id)
    local now = os.time()
    local lease = leases[deviceId]
    if lease and lease.expiresAt > now and lease.source ~= source then
        return false, MZComputer.Const.Error.DEVICE_BUSY
    end

    leases[deviceId] = { source = source, expiresAt = now + Config.Devices.publicLeaseSeconds }
    MZComputer.Repo.update('DELETE FROM mz_computer_device_leases WHERE device_id = ?', { deviceId })
    MZComputer.Repo.insert([[
        INSERT INTO mz_computer_device_leases (device_id, session_id, leased_by, leased_at, expires_at, status)
        VALUES (?, NULL, ?, NOW(), FROM_UNIXTIME(?), 'active')
    ]], { deviceId, source, leases[deviceId].expiresAt })
    return true
end

function Devices.beginPublicUse(source, terminalId)
    source = tonumber(source)
    terminalId = MZComputer.Validation.id(terminalId, 48)
    local entry = terminalId and publicDevices[terminalId] or nil
    if not entry or entry.row.status ~= 'active' then
        return nil, MZComputer.Const.Error.DEVICE_UNAVAILABLE
    end

    if Config.Devices.requireServerDistance then
        local distance = playerDistanceTo(source, interactionCoords(entry.config))
        if not distance or distance > math.max(Config.Devices.publicMaxDistance, entry.config.interactionDistance + 0.5) then
            return nil, MZComputer.Const.Error.DEVICE_TOO_FAR
        end
    end

    if MZComputer.Sessions and MZComputer.Sessions.getBySource(source) then
        return nil, MZComputer.Const.Error.DEVICE_BUSY
    end
    if contexts[source] then Devices.closeUse(source, 'switch_device') end

    local ok, err = claimPublic(source, entry)
    if not ok then return nil, err end

    contexts[source] = {
        source = source,
        deviceId = tonumber(entry.row.id),
        deviceUid = entry.row.device_uid,
        deviceType = 'public',
        terminalId = terminalId,
        openedAt = os.time(),
        device = publicDeviceRow(entry.row, entry.config.label)
    }
    MZComputer.Audit.log('device.opened', { source=source, deviceDbId=entry.row.id }, 'public terminal opened', { terminalId=terminalId })
    local device = publicDeviceRow(entry.row, entry.config.label)
    device.terminalId = terminalId
    return device
end

function Devices.getOrCreatePersonal(source, physicalKey)
    local identity, err = MZComputer.Identity.resolve(source)
    if not identity then return nil, err end
    physicalKey = MZComputer.Validation.string(physicalKey, 1, 160) or ('citizen:' .. identity.citizenid)
    local digest = MZComputer.Crypto.sha256(physicalKey)
    local uid = 'personal:' .. digest:sub(1, 48)
    local row = MZComputer.Repo.one('SELECT * FROM mz_computer_devices WHERE device_uid = ? LIMIT 1', { uid })
    if not row then
        local serial = 'MZ-NB-' .. string.upper(digest:sub(1, 8))
        local id = MZComputer.Repo.insert([[
            INSERT INTO mz_computer_devices
                (device_uid, device_type, skin_id, ownership_type, owner_ref, serial_number, status, metadata_json)
            VALUES (?, 'personal', ?, 'personal', ?, ?, 'active', ?)
        ]], { uid, Config.DefaultSkin, physicalKey, serial, MZComputer.Repo.json({ createdByCitizen = identity.citizenid }) })
        row = MZComputer.Repo.one('SELECT * FROM mz_computer_devices WHERE id = ? LIMIT 1', { id })
    end
    if not row or row.status ~= 'active' then return nil, MZComputer.Const.Error.DEVICE_UNAVAILABLE end
    return publicDeviceRow(row, 'Notebook')
end

function Devices.authorizePersonalUse(source, device)
    if not device or not device.id or not device.uid then return false end
    if MZComputer.Sessions and MZComputer.Sessions.getBySource(source) then
        MZComputer.Sessions.revokeSource(source, 'switch_device', true)
    end
    Devices.closeUse(source, 'replace_context')
    contexts[source] = {
        source = tonumber(source),
        deviceId = tonumber(device.id),
        deviceUid = device.uid,
        deviceType = 'personal',
        openedAt = os.time(),
        device = device
    }
    MZComputer.Audit.log('device.opened', { source=source, deviceDbId=device.id }, 'personal notebook opened')
    TriggerClientEvent('mz_computer:client:openAuthorized', source, device)
    return true
end

function Devices.context(source)
    return contexts[tonumber(source)]
end

function Devices.validateUse(source, expectedUid)
    source = tonumber(source)
    local ctx = contexts[source]
    if not ctx then return false, MZComputer.Const.Error.DEVICE_UNAVAILABLE end
    if expectedUid and ctx.deviceUid ~= expectedUid then return false, MZComputer.Const.Error.DEVICE_UNAVAILABLE end
    if ctx.deviceType == 'public' then
        local entry = publicDevices[ctx.terminalId]
        local lease = entry and leases[ctx.deviceId]
        if not entry or not lease or lease.source ~= source or lease.expiresAt <= os.time() then
            return false, MZComputer.Const.Error.DEVICE_UNAVAILABLE
        end
        if Config.Devices.requireServerDistance then
            local distance = playerDistanceTo(source, interactionCoords(entry.config))
            if not distance or distance > math.max(Config.Devices.publicMaxDistance, entry.config.interactionDistance + 0.5) then
                return false, MZComputer.Const.Error.DEVICE_TOO_FAR
            end
        end
        lease.expiresAt = os.time() + Config.Devices.publicLeaseSeconds
    end
    return true, ctx
end

function Devices.attachSession(source, sessionDbId)
    local ctx = contexts[tonumber(source)]
    if not ctx then return end
    if ctx.deviceType == 'public' then
        MZComputer.Repo.update([[
            UPDATE mz_computer_device_leases SET session_id = ?, expires_at = FROM_UNIXTIME(?)
            WHERE device_id = ? AND leased_by = ? AND status = 'active'
        ]], { sessionDbId, os.time() + Config.Devices.publicLeaseSeconds, ctx.deviceId, source })
    end
end

function Devices.closeUse(source, reason)
    source = tonumber(source)
    local ctx = contexts[source]
    if not ctx then return false end
    if ctx.deviceType == 'public' then
        local lease = leases[ctx.deviceId]
        if lease and lease.source == source then leases[ctx.deviceId] = nil end
        MZComputer.Repo.update("UPDATE mz_computer_device_leases SET status='released', expires_at=NOW() WHERE device_id = ? AND leased_by = ? AND status='active'", { ctx.deviceId, source })
    end
    contexts[source] = nil
    MZComputer.Audit.log('device.closed', { source=source, deviceDbId=ctx.deviceId }, tostring(reason or 'closed'))
    return true
end

function Devices.publicDeviceInfo(terminalId)
    local entry = publicDevices[terminalId]
    return entry and publicDeviceRow(entry.row, entry.config.label) or nil
end

function Devices.sweep()
    local now = os.time()
    local toClose = {}
    for source, ctx in pairs(contexts) do
        if ctx.deviceType == 'public' then
            local lease = leases[ctx.deviceId]
            local reason
            if not lease or lease.source ~= source or lease.expiresAt <= now then
                reason = 'lease_expired'
            elseif Config.Devices.requireServerDistance then
                local entry = publicDevices[ctx.terminalId]
                local distance = entry and playerDistanceTo(source, interactionCoords(entry.config)) or nil
                if not distance or distance > math.max(Config.Devices.publicMaxDistance, entry.config.interactionDistance + 0.5) then
                    reason = 'device_too_far'
                end
            end
            if reason then toClose[#toClose + 1] = { source=source, reason=reason } end
        end
    end
    for _, item in ipairs(toClose) do
        if MZComputer.Sessions then MZComputer.Sessions.revokeSource(item.source, item.reason, false) end
        Devices.closeUse(item.source, item.reason)
        TriggerClientEvent('mz_computer:client:forceClose', item.source, item.reason)
    end
end

MZComputer.Devices = Devices
