local Client = MZComputerClient


-- Defensive NUI reset on resource start. The browser page is mounted even while the
-- computer is closed, so always clear focus and force the visual shell hidden.
CreateThread(function()
    Wait(0)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type='computer:close' })
    Wait(500)
    if not Client.open then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type='computer:close' })
    end
end)

function Client.openComputer(device)
    if type(device) ~= 'table' then return false end
    if Client.editing and Client.cancelScreenEditor then Client.cancelScreenEditor() end
    -- The server has already authorized the new context. Do not revoke it while
    -- disposing of an older local display.
    if Client.open then Client.closeComputer('replace', false); Wait(100) end
    Client.generation = (Client.generation or 0) + 1
    local generation = Client.generation
    Client.open, Client.closing, Client.device = true, false, device
    Client.resetSession()
    if GetResourceState('mz_inventory') == 'started' then
        pcall(function()
            if exports['mz_inventory']:IsOpen() then exports['mz_inventory']:CloseView() end
        end)
    end
    local ok, world, warning = pcall(Client.startWorldDisplay, device)
    if generation ~= Client.generation or not Client.open then return false end
    if not ok then
        print(('[mz_computer] 3D display failed: %s'):format(tostring(world)))
        Client.stopWorldDisplay()
        Client.stopDeviceVisuals()
        world, warning = false, 'Não foi possível abrir o monitor 3D. Usando o notebook.'
    end
    if not world then Client.startDeviceVisuals(device) end
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    local hybrid = world and Client.surface and Client.surface.hybrid
    if hybrid then
        Client.surface.hybridStarted=true
        -- The world DUI has already acknowledged its lightweight presentation.
        -- Start the ordinary NUI as the direct, low-latency interaction layer.
        SendNUIMessage({ type='hybrid:start', id=Client.surface.id })
        SendNUIMessage({ type='computer:open', device=device, ui=Config.UI, network=Config.Browser.networkName,
            presentation='world_terminal' })
    elseif not world then
        Client.sendUI({ type='computer:open', device=device, ui=Config.UI, network=Config.Browser.networkName, presentation='notebook' })
    end
    if warning then TriggerEvent('mz_computer:client:toast', warning) end
    return true
end

function Client.closeComputer(reason, notifyServer)
    if not Client.open or Client.closing then return end
    Client.closing = true
    Client.generation = (Client.generation or 0) + 1
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type='computer:close' })
    Client.stopWorldDisplay()
    Client.stopDeviceVisuals()
    Client.resetSession()
    Client.device = nil
    Client.open = false
    Client.closing = false
    if notifyServer ~= false then TriggerServerEvent('mz_computer:server:closeDevice', reason or 'closed') end
end

RegisterNetEvent('mz_computer:client:openAuthorized', function(device)
    Client.openComputer(device)
end)

RegisterNetEvent('mz_computer:client:forceLogout', function(reason)
    Client.resetSession()
    Client.sendUI({ type='auth:forceLogout', reason=reason or 'session_revoked' })
end)

RegisterNetEvent('mz_computer:client:forceClose', function(reason)
    if Client.open then
        TriggerEvent('mz_computer:client:toast', reason == 'device_too_far' and 'Você se afastou do computador.' or 'A sessão deste terminal foi encerrada.')
        Client.closeComputer('server_force', false)
    end
end)

RegisterNetEvent('mz_computer:client:notification', function(notification)
    if Client.open then Client.sendUI({ type='notification:push', notification=notification }) end
end)

RegisterNetEvent('mz_computer:client:openApp', function(appId)
    if Client.open then Client.sendUI({ type='app:open', appId=appId }) end
end)

RegisterNetEvent('mz_computer:client:toast', function(message)
    if Client.open then
        Client.sendUI({ type='toast', message=tostring(message) })
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(tostring(message))
        EndTextCommandThefeedPostTicker(false, false)
    end
end)

CreateThread(function()
    while true do
        if Client.open then
            Wait(350)
            if Config.Devices.closeOnDeath and IsEntityDead(PlayerPedId()) then Client.closeComputer('player_dead', true) end
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if Client.open then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        Client.stopDeviceVisuals()
    end
end)
