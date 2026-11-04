local Client = MZComputerClient

RegisterNUICallback('request', function(data, cb)
    if not Client.open then cb({ ok=false, error='COMPUTER_CLOSED' }); return end
    local generation = Client.generation
    data = type(data) == 'table' and data or {}
    local request = {
        action = data.action,
        payload = type(data.payload) == 'table' and data.payload or {},
        token = Client.sessionToken
    }
    local ok, result = pcall(function()
        return lib.callback.await('mz_computer:server:request', false, request)
    end)
    if not ok or type(result) ~= 'table' then
        cb({ ok=false, error='INTERNAL_ERROR' })
        return
    end
    if generation ~= Client.generation or not Client.open then
        cb({ ok=false, error='COMPUTER_CLOSED' }); return
    end

    if result.ok and type(result.data) == 'table' and result.data._sessionToken then
        Client.sessionToken = result.data._sessionToken
        result.data._sessionToken = nil -- session tokens never cross into browser/NUI JS.
    end
    if data.action == 'auth.logout' and result.ok then Client.resetSession() end
    if result.error == 'SESSION_INVALID' or result.error == 'SESSION_EXPIRED' then Client.resetSession() end
    cb(result)
end)

RegisterNUICallback('close', function(_, cb)
    Client.closeComputer('nui_close', true)
    cb({ ok=true })
end)

RegisterNUICallback('ready', function(_, cb)
    if Client.open and Client.device and (not Client.surface or Client.surface.hybrid) then
        SendNUIMessage({ type='computer:open', device=Client.device, ui=Config.UI, network=Config.Browser.networkName,
            presentation=Client.surface and Client.surface.hybrid and 'world_terminal' or 'notebook' })
    end
    cb({ ok=true })
end)
