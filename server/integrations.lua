MZComputer = MZComputer or {}
local Integrations = {}
local inventoryRegistered = false

local function physicalKeyFromMetadata(identity, metadata)
    metadata = type(metadata) == 'table' and metadata or {}
    for _, key in ipairs(Config.NotebookItem.metadataKeys) do
        local value = metadata[key]
        if value ~= nil then
            value = tostring(value)
            if #value >= 1 and #value <= 120 then return 'item:' .. value end
        end
    end
    return 'citizen:' .. identity.citizenid
end

function Integrations.registerInventory()
    if inventoryRegistered or not Config.NotebookItem.enabled then return inventoryRegistered end
    if GetResourceState('mz_inventory') ~= 'started' then return false end

    local itemOk, itemDefinition = pcall(function()
        return exports['mz_inventory']:GetItemDefinition(Config.NotebookItem.itemName)
    end)
    if itemOk and not itemDefinition then
        print(('^3[mz_computer]^7 Item "%s" is not defined in mz_inventory; notebook item integration is waiting. See docs/INSTALL.md.'):format(Config.NotebookItem.itemName))
        return false
    end

    local ok, result = pcall(function()
        return exports['mz_inventory']:RegisterItemUseHandler(Config.NotebookItem.itemName, function(payload)
            local source = payload and tonumber(payload.source)
            if not source then return { ok=false, error='invalid_source' } end
            local identity, identityErr = MZComputer.Identity.resolve(source)
            if not identity then return { ok=false, error=identityErr or 'identity_unavailable' } end
            local physicalKey = physicalKeyFromMetadata(identity, payload.metadata)
            local device, deviceErr = MZComputer.Devices.getOrCreatePersonal(source, physicalKey)
            if not device then return { ok=false, error=deviceErr or 'device_unavailable' } end
            return {
                ok=true,
                consume=false,
                data={ deviceUid=device.uid, serial=device.serial },
                afterCommit=function()
                    return MZComputer.Devices.authorizePersonalUse(source, device)
                end
            }
        end)
    end)
    inventoryRegistered = ok and result ~= false
    if inventoryRegistered then
        print(('[mz_computer] Notebook item handler registered for "%s"'):format(Config.NotebookItem.itemName))
    elseif Config.Debug then
        print(('[mz_computer] Could not register notebook handler: %s'):format(tostring(result)))
    end
    return inventoryRegistered
end

function Integrations.resetInventoryRegistration()
    inventoryRegistered = false
end

function Integrations.openDebugNotebook(source)
    if not Config.Developer.allowPortableCommand then return false end
    if not Config.Debug and not IsPlayerAceAllowed(source, Config.Security.debugAce) then return false end
    local identity = MZComputer.Identity.resolve(source)
    if not identity then return false end
    local device = MZComputer.Devices.getOrCreatePersonal(source, 'debug:' .. identity.citizenid)
    if not device then return false end
    return MZComputer.Devices.authorizePersonalUse(source, device)
end

RegisterCommand('mzcomputer', function(source)
    if source <= 0 then return end
    if not Integrations.openDebugNotebook(source) then
        TriggerClientEvent('mz_computer:client:toast', source, 'Acesso de desenvolvimento não autorizado.')
    end
end, false)

MZComputer.Integrations = Integrations
