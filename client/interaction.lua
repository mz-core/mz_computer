local Client = MZComputerClient

local function drawHelp(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function distance(a, b)
    local dx,dy,dz = a.x-b.x, a.y-b.y, a.z-b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function refreshTerminals()
    local ok, result = pcall(function() return lib.callback.await('mz_computer:server:getTerminals', false) end)
    if ok and type(result) == 'table' then Client.applyTerminals(result) end
end

RegisterNetEvent('mz_computer:client:terminalsUpdated',function(terminals)
    if type(terminals)=='table' then Client.applyTerminals(terminals) end
end)

CreateThread(function()
    Wait(1500)
    for _ = 1, 5 do
        refreshTerminals()
        if #Client.terminals > 0 then break end
        Wait(3000)
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then CreateThread(refreshTerminals) end
end)

CreateThread(function()
    while true do
        local wait = 1000
        if Config.Interaction.enabled and not Client.open and not Client.editing and #Client.terminals > 0 then
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, nearestDistance
            for _, terminal in ipairs(Client.terminals) do
                local anchor = Client.resolveTerminalAnchorWorld and Client.resolveTerminalAnchorWorld(terminal,'interaction') or terminal.coords
                local d = anchor and distance(coords, anchor) or math.huge
                if not nearestDistance or d < nearestDistance then nearest, nearestDistance = terminal, d end
            end
            if nearest and nearestDistance <= Config.Interaction.drawDistance then
                wait = 0
                if nearestDistance <= (nearest.interactionDistance or 1.8) then
                    drawHelp(Config.Interaction.prompt)
                    if IsControlJustReleased(0, Config.Interaction.key) then
                        local result = lib.callback.await('mz_computer:server:openPublic', false, nearest.id)
                        if result and result.ok and result.data then
                            Client.openComputer(result.data)
                        else
                            local code = result and result.error or 'DEVICE_UNAVAILABLE'
                            TriggerEvent('mz_computer:client:toast', code == 'DEVICE_BUSY' and 'Este computador já está sendo usado.' or 'Não foi possível usar este computador.')
                        end
                        Wait(500)
                    end
                end
            end
        end
        Wait(wait)
    end
end)
