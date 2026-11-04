MZComputer = MZComputer or {}
MZComputer.Ready = false

local function bootstrap()
    MZComputer.Migrations.run()
    MZComputer.Devices.bootstrapPublic()
    MZComputer.Apps.bootstrap()
    MZComputer.Sites.bootstrap()
    MZComputer.Integrations.registerInventory()
    MZComputer.Ready = true
    print(('^2[mz_computer]^7 MZ OS %s ready (%d public terminals)'):format(Config.Version, #MZComputer.Devices.getPublicDefinitions()))
end

MySQL.ready(function()
    local ok, err = pcall(bootstrap)
    if not ok then
        MZComputer.Ready = false
        print(('^1[mz_computer]^7 Startup failed closed: %s'):format(tostring(err)))
    end
end)

lib.callback.register('mz_computer:server:getTerminals', function(source)
    if not MZComputer.Ready then return {} end
    return MZComputer.Devices.getPublicDefinitions()
end)

AddEventHandler('playerDropped', function()
    local source = source
    MZComputer.Sessions.revokeSource(source, 'player_dropped', false)
    MZComputer.Devices.closeUse(source, 'player_dropped')
end)

AddEventHandler('mz_core:server:identitySessionClosed', function(sourceId)
    MZComputer.Sessions.revokeSource(sourceId, 'core_session_closed', false)
    MZComputer.Devices.closeUse(sourceId, 'core_session_closed')
end)

AddEventHandler('onServerResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        MZComputer.Ready = false
        MZComputer.Sessions.shutdown()
        return
    end
    MZComputer.Apps.unregisterOrigin(resourceName)
    MZComputer.Sites.unregisterOrigin(resourceName)
    if resourceName == 'mz_core' then
        MZComputer.Sessions.shutdown()
        MZComputer.Integrations.resetInventoryRegistration()
    end
end)

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == 'mz_core' and MZComputer.Ready then
        SetTimeout(1000, function() MZComputer.Integrations.registerInventory() end)
    end
end)

CreateThread(function()
    while true do
        Wait(60 * 60 * 1000)
        if MZComputer.Ready then
            pcall(function()
                MZComputer.Repo.update('DELETE FROM mz_computer_notifications WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)')
            end)
        end
    end
end)


CreateThread(function()
    while true do
        Wait(10000)
        if MZComputer.Ready then pcall(MZComputer.Devices.sweep) end
    end
end)
