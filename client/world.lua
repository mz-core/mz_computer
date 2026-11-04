local Client = MZComputerClient
local G = MZComputer.ScreenGeometry
local objects, stopping, textureDictionary = {}, false, nil
local sequence = 0

local function displayConfig(terminal)
    local cfg = {}
    for k, v in pairs(Config.WorldDisplay or {}) do cfg[k] = v end
    for k, v in pairs(terminal.display or {}) do cfg[k] = v end
    return cfg
end

local function findTerminal(id)
    for _, terminal in ipairs(Client.terminals or {}) do
        if terminal.id == id then return terminal end
    end
    for _, terminal in ipairs(Config.PublicTerminals) do
        if terminal.id == id then return terminal end
    end
end

local function releaseObject(id)
    local entry = objects[id]
    if entry and entry.owned and entry.entity and DoesEntityExist(entry.entity) then
        DeleteEntity(entry.entity)
    end
    objects[id] = nil
end

local function ensureObject(terminal, cfg)
    local existing = objects[terminal.id]
    if existing then
        if existing.loading then return nil end
        if existing.entity and DoesEntityExist(existing.entity) then return existing.entity end
        releaseObject(terminal.id)
    end
    if not cfg.enabled then return nil end
    local entry = { loading = true }
    objects[terminal.id] = entry
    local model = type(cfg.model)=='number' and cfg.model or joaat(cfg.model)
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        entry.loading = false
        return nil
    end
    if cfg.spawnProp == false then
        local c = cfg.objectCoords or terminal.coords
        local entity = GetClosestObjectOfType(c.x, c.y, c.z, cfg.matchRadius or .15, model, false, false, false)
        entry.loading, entry.entity = false, entity ~= 0 and entity or nil
        return entry.entity
    end
    RequestModel(model)
    local deadline = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < deadline and not stopping do Wait(0) end
    if stopping or not HasModelLoaded(model) then
        SetModelAsNoLongerNeeded(model)
        entry.loading = false
        return nil
    end
    local offset = cfg.objectOffset or {}
    local heading = math.rad(terminal.heading or 0.0)
    local x, y = offset.x or 0.0, offset.y or 0.0
    local c = terminal.coords
    local entity = CreateObjectNoOffset(model,
        c.x + x * math.cos(heading) - y * math.sin(heading),
        c.y + x * math.sin(heading) + y * math.cos(heading),
        c.z + (offset.z or 0.0), false, false, false)
    SetModelAsNoLongerNeeded(model)
    entry.loading = false
    if entity == 0 then return nil end
    entry.entity, entry.owned = entity, true
    SetEntityHeading(entity, terminal.heading or 0.0)
    FreezeEntityPosition(entity, true)
    return entity
end

local function anchorWorld(terminal, anchor, entity)
    if type(anchor) ~= 'table' or type(anchor.offset) ~= 'table' then return nil end
    local o = MZComputer.ScreenGeometry.point(anchor.offset,(Config.TerminalEditor and Config.TerminalEditor.anchorOffsetMax) or 6)
    if not o then return nil end
    if entity and DoesEntityExist(entity) then
        return GetOffsetFromEntityInWorldCoords(entity,o.x,o.y,o.z)
    end
    local p = MZComputer.ScreenGeometry.worldFromLocal(terminal.coords,terminal.heading or 0,o)
    return p and vector3(p.x,p.y,p.z) or nil
end

function Client.resolveTerminalAnchorWorld(terminal, kind)
    if type(terminal) ~= 'table' then return nil end
    local anchor = kind == 'player' and terminal.playerAnchor or terminal.interactionAnchor
    if not anchor and kind ~= 'player' then anchor = terminal.playerAnchor end
    if not anchor then
        local c=terminal.coords
        return c and vector3(c.x,c.y,c.z) or nil
    end
    local entry=objects[terminal.id]
    return anchorWorld(terminal,anchor,entry and entry.entity)
end

local function alignPedForTerminal(surface, terminal)
    if surface.preview or type(terminal.playerAnchor) ~= 'table' or terminal.playerAnchor.mode == 'none'
        or surface.cfg.playerAlignEnabled == false then return true end
    local ped=surface.ped
    if not ped or not DoesEntityExist(ped) or IsEntityDead(ped) then return false,'Nao foi possivel posicionar o personagem neste computador.' end
    if IsPedInAnyVehicle and IsPedInAnyVehicle(ped,false) then return false,'Saia do veiculo para usar este computador.' end
    local target=anchorWorld(terminal,terminal.playerAnchor,surface.entity)
    if not target then return true end -- malformed legacy/manual anchor: preserve old behaviour
    local current=GetEntityCoords(ped)
    local distance=#(current-target)
    local maxDistance=tonumber(surface.cfg.playerAlignMaxDistance) or 2.5
    if distance > maxDistance then return false,'Aproxime-se da posicao de uso deste computador.' end
    local targetHeading=MZComputer.ScreenGeometry.worldHeading(GetEntityHeading(surface.entity),terminal.playerAnchor.heading or 0) or GetEntityHeading(ped)
    local tolerance=tonumber(surface.cfg.playerAlignTolerance) or .18
    if distance > tolerance and not surface.wasFrozen and TaskGoStraightToCoord then
        TaskGoStraightToCoord(ped,target.x,target.y,target.z,tonumber(surface.cfg.playerAlignSpeed) or 1.0,
            tonumber(surface.cfg.playerAlignTimeoutMs) or 2800,targetHeading,0.08)
        local deadline=GetGameTimer()+(tonumber(surface.cfg.playerAlignTimeoutMs) or 2800)
        repeat
            Wait(0)
            if Client.surface~=surface or IsEntityDead(ped) then return false,'Posicionamento cancelado.' end
            distance=#(GetEntityCoords(ped)-target)
        until distance<=tolerance or GetGameTimer()>=deadline
        if ClearPedTasks then ClearPedTasks(ped) end
    end
    distance=#(GetEntityCoords(ped)-target)
    -- Correct only a tiny residual after the walking task; never teleport from afar.
    if distance > tolerance and distance <= .45 and SetEntityCoordsNoOffset and not surface.wasFrozen then
        SetEntityCoordsNoOffset(ped,target.x,target.y,target.z,false,false,false)
        distance=#(GetEntityCoords(ped)-target)
    end
    if distance > .45 then return false,'Nao consegui alinhar o personagem. Chegue mais perto da marca de uso.' end
    if not surface.wasFrozen then SetEntityHeading(ped,targetHeading) end
    return true
end

local function geometry(entity, cfg)
    if cfg.corners then
        local localGeometry = assert(MZComputer.ScreenGeometry.rectangle(cfg.corners),'Invalid screen corners')
        local origin = GetEntityCoords(entity)
        local n = localGeometry.normal
        local normal = GetOffsetFromEntityInWorldCoords(entity,n.x,n.y,n.z)-origin
        local lift = normal * (cfg.screenLift or .008)
        local g = {normal=normal,width=localGeometry.width,height=localGeometry.height}
        for _, key in ipairs({'tl','tr','bl','br','center'}) do
            local p = localGeometry[key]
            g[key] = GetOffsetFromEntityInWorldCoords(entity,p.x,p.y,p.z)+lift
        end
        g.right = (g.tr-g.tl)*(1/localGeometry.width)
        g.up = (g.tl-g.bl)*(1/localGeometry.height)
        return g
    end
    local o = cfg.screenOffset
    local center = GetOffsetFromEntityInWorldCoords(entity, o.x, o.y, o.z)
    local origin = GetEntityCoords(entity)
    local right = GetOffsetFromEntityInWorldCoords(entity, 1.0, 0.0, 0.0) - origin
    local forward = GetOffsetFromEntityInWorldCoords(entity, 0.0, 1.0, 0.0) - origin
    local vertical = GetOffsetFromEntityInWorldCoords(entity, 0.0, 0.0, 1.0) - origin
    local tilt = math.rad(cfg.screenTilt or 0.0)
    local up = vertical * math.cos(tilt) + forward * math.sin(tilt)
    local normal = -forward * math.cos(tilt) + vertical * math.sin(tilt)
    local r, u = right * (cfg.screenWidth / 2), up * (cfg.screenHeight / 2)
    return { center = center, normal = normal, right=right, up=up, width=cfg.screenWidth, height=cfg.screenHeight,
        tl = center-r+u, tr = center+r+u, bl = center-r-u, br = center+r-u }
end

local function firstPersonCameraPosition(surface, g, cfg)
    local ped = surface.ped
    local head
    if GetPedBoneCoords then
        head = GetPedBoneCoords(ped, tonumber(cfg.firstPersonHeadBone) or 31086, 0.0, 0.0, 0.0)
    end
    if not head then
        local base = GetEntityCoords(ped)
        head = base + vector3(0.0, 0.0, tonumber(cfg.firstPersonFallbackHeight) or .68)
    end
    -- g.normal points from the glass toward the calibrated viewing side, so a
    -- negative normal offset advances the virtual eyes toward the monitor.
    return head
        - g.normal * (tonumber(cfg.firstPersonEyeForward) or .06)
        + g.right * (tonumber(cfg.firstPersonEyeRight) or 0.0)
        + g.up * (tonumber(cfg.firstPersonEyeUp) or .01)
end

local function gameplayCameraDirection()
    local rot = GetGameplayCamRot(2)
    local pitch,yaw = math.rad(rot.x),math.rad(rot.z)
    return vector3(-math.sin(yaw)*math.cos(pitch),math.cos(yaw)*math.cos(pitch),math.sin(pitch))
end

local function cameraPose(surface, g, cfg)
    if not surface.preview and cfg.cameraMode == 'first_person' then
        local position = firstPersonCameraPosition(surface, g, cfg)
        local target = g.center
            + g.right * (tonumber(cfg.firstPersonTargetRight) or 0.0)
            + g.up * (tonumber(cfg.firstPersonTargetUp) or 0.0)
        return position, target, true
    end
    local position = g.center + g.normal * cfg.cameraDistance
        + g.right * (cfg.cameraRight or 0) + g.up * (cfg.cameraUp or 0)
    return position, g.center, false
end

function Client.sendUI(message)
    -- In hybrid mode the ordinary NUI is the authoritative interactive browser.
    -- The DUI is presentation-only, so never route app/input state through it.
    if Client.surface and Client.surface.ready and not Client.surface.hybrid then
        SendDuiMessage(Client.surface.dui, json.encode(message))
    else
        SendNUIMessage(message)
    end
end

function Client.stopWorldDisplay()
    local surface = Client.surface
    if surface and surface.previousViewMode ~= nil and SetFollowPedCamViewMode then
        SetFollowPedCamViewMode(surface.previousViewMode)
        surface.previousViewMode=nil
    end
    Client.surface = nil
    if surface and surface.hybrid then SendNUIMessage({ type='hybrid:stop', id=surface.id }) end
    SendNUIMessage({ type = 'surface:stop' })
    if surface then
        if surface.dui then DestroyDui(surface.dui) end
        if surface.ped and DoesEntityExist(surface.ped) and not surface.wasFrozen then
            FreezeEntityPosition(surface.ped, false)
        end
    end
end

function Client.startWorldDisplay(device, previewTerminal)
    local terminal = previewTerminal or (device.type == 'public' and findTerminal(device.terminalId))
    if not terminal then return false end
    local cfg = displayConfig(terminal)
    if not cfg.enabled then return false end
    local generation = Client.generation
    local deadline = GetGameTimer() + (cfg.loadTimeoutMs or 8000)
    local entity
    repeat
        entity = ensureObject(terminal, cfg)
        if not entity then Wait(100) end
    until entity or GetGameTimer() >= deadline or generation ~= Client.generation
    if generation ~= Client.generation then return false end
    if not entity then return false, 'O monitor 3D não está disponível. Abrindo a interface do notebook.' end

    sequence = sequence + 1
    local interactionMode = tostring(cfg.interactionMode or 'dui')
    local surface = { id = tostring(sequence), entity = entity, cfg = cfg, terminalId = terminal.id,
        preview=previewTerminal~=nil, interactionMode=interactionMode }
    surface.hybrid = not surface.preview and interactionMode == 'nui_overlay'
    Client.surface = surface
    local page = surface.preview and 'calibration.html' or (surface.hybrid and 'display.html' or 'index.html')
    surface.dui = CreateDui(('https://cfx-nui-%s/ui/dist/%s?surface=%s'):format(
        GetCurrentResourceName(), page, surface.id), cfg.width, cfg.height)
    while Client.surface == surface and GetGameTimer() < deadline do
        if IsDuiAvailable(surface.dui) and surface.browserReady then break end
        Wait(0)
    end
    if Client.surface ~= surface then return false end
    if not surface.browserReady or not IsDuiAvailable(surface.dui) then
        Client.stopWorldDisplay()
        return false, 'A tela 3D demorou para responder. Abrindo a interface do notebook.'
    end
    if not textureDictionary then textureDictionary = CreateRuntimeTxd('mz_computer_display') end
    CreateRuntimeTextureFromDuiHandle(textureDictionary, 'screen', GetDuiHandle(surface.dui))
    SendDuiMessage(surface.dui, json.encode({type='computer:open', device=device,
        ui=Config.UI, network=Config.Browser.networkName}))
    while Client.surface == surface and not surface.uiVisible and GetGameTimer() < deadline do Wait(0) end
    if Client.surface ~= surface then return false end
    if not surface.uiVisible then
        Client.stopWorldDisplay()
        return false, 'A interface do monitor não abriu. Usando o notebook.'
    end
    surface.ped = PlayerPedId()
    surface.wasFrozen = IsEntityPositionFrozen(surface.ped)
    local aligned,alignWarning = alignPedForTerminal(surface,terminal)
    if not aligned then
        Client.stopWorldDisplay()
        return false,alignWarning
    end
    surface.ready = true
    surface.geometry = geometry(entity, cfg)
    local g = surface.geometry
    local position, target, firstPerson = cameraPose(surface, g, cfg)
    surface.firstPerson = firstPerson
    local camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(camera, position.x, position.y, position.z)
    PointCamAtCoord(camera, target.x, target.y, target.z)
    SetCamFov(camera, cfg.cameraFov)
    if SetCamNearClip then SetCamNearClip(camera, .01) end
    RenderScriptCams(true, true, cfg.transitionMs, true, true)
    Client.camera = camera
    FreezeEntityPosition(surface.ped, true)
    if not surface.preview and not surface.hybrid then SendNUIMessage({ type='surface:start', id=surface.id }) end
    return true
end

function Client.updateScreenPreview(display)
    local surface = Client.surface
    if not surface or not surface.preview or not Client.camera then return end
    for k,v in pairs(display) do surface.cfg[k]=v end
    surface.geometry = geometry(surface.entity,surface.cfg)
    local g,cfg = surface.geometry,surface.cfg
    local position = g.center + g.normal*cfg.cameraDistance + g.right*(cfg.cameraRight or 0) + g.up*(cfg.cameraUp or 0)
    SetCamCoord(Client.camera,position.x,position.y,position.z)
    PointCamAtCoord(Client.camera,g.center.x,g.center.y,g.center.z)
    SetCamFov(Client.camera,cfg.cameraFov)
end

-- Switch the calibration surface to the real gameplay camera so the admin can
-- walk into the exact use position and look at the screen naturally. The DUI
-- keeps rendering on the mapped glass while the scripted calibration camera is
-- released. Runtime public PCs remain untouched by this editor-only mode.
function Client.beginScreenEditorSimulation()
    local surface = Client.surface
    if not surface or not surface.preview or not surface.ready then return false end
    if Client.camera then Client.stopDeviceVisuals() end
    if surface.ped and DoesEntityExist(surface.ped) and not surface.wasFrozen then
        FreezeEntityPosition(surface.ped,false)
    end
    surface.editorSimulation = true
    surface.firstPerson = false
    if surface.previousViewMode == nil and GetFollowPedCamViewMode then
        surface.previousViewMode = GetFollowPedCamViewMode()
    end
    if SetFollowPedCamViewMode then SetFollowPedCamViewMode(4) end
    return true
end

function Client.captureScreenEditorView()
    local surface = Client.surface
    if not surface or not surface.preview or not surface.editorSimulation or not surface.geometry then return nil end
    local g,ped = surface.geometry,surface.ped or PlayerPedId()
    if not ped or not DoesEntityExist(ped) then return nil end

    local camera = GetGameplayCamCoord()
    local head
    if GetPedBoneCoords then head = GetPedBoneCoords(ped,tonumber(surface.cfg.firstPersonHeadBone) or 31086,0.0,0.0,0.0) end
    if not head then
        local base=GetEntityCoords(ped)
        head=base+vector3(0.0,0.0,tonumber(surface.cfg.firstPersonFallbackHeight) or .68)
    end
    local delta=G.sub(camera,head)
    local direction=gameplayCameraDirection()
    local hit=G.rayPlane(camera,direction,g.center,g.normal)
    local target=hit or g.center
    local targetDelta=G.sub(target,g.center)
    local targetRight=G.dot(targetDelta,g.right)
    local targetUp=G.dot(targetDelta,g.up)
    return {
        eyeForward=-G.dot(delta,g.normal),
        eyeRight=G.dot(delta,g.right),
        eyeUp=G.dot(delta,g.up),
        targetRight=targetRight,
        targetUp=targetUp,
        onScreen=hit~=nil and math.abs(targetRight)<=g.width*.65 and math.abs(targetUp)<=g.height*.65,
        fov=GetGameplayCamFov and GetGameplayCamFov() or surface.cfg.cameraFov
    }
end

function Client.startScreenEditorRuntimeTest(display)
    local surface=Client.surface
    if not surface or not surface.preview or not surface.ready then return false end
    if display then
        for k,v in pairs(display) do surface.cfg[k]=v end
        surface.geometry=geometry(surface.entity,surface.cfg)
    end
    local g,cfg=surface.geometry,surface.cfg
    local position=firstPersonCameraPosition(surface,g,cfg)
    local target=g.center
        + g.right*(tonumber(cfg.firstPersonTargetRight) or 0.0)
        + g.up*(tonumber(cfg.firstPersonTargetUp) or 0.0)
    if Client.camera then Client.stopDeviceVisuals() end
    local camera=CreateCam('DEFAULT_SCRIPTED_CAMERA',true)
    SetCamCoord(camera,position.x,position.y,position.z)
    PointCamAtCoord(camera,target.x,target.y,target.z)
    SetCamFov(camera,tonumber(cfg.cameraFov) or 42.0)
    if SetCamNearClip then SetCamNearClip(camera,.01) end
    RenderScriptCams(true,true,tonumber(cfg.transitionMs) or 250,true,true)
    Client.camera=camera
    surface.editorSimulation=false
    surface.editorTest=true
    surface.firstPerson=true
    if surface.ped and DoesEntityExist(surface.ped) then FreezeEntityPosition(surface.ped,true) end
    return true
end

function Client.returnScreenEditorSimulation()
    local surface=Client.surface
    if not surface or not surface.preview or not surface.ready then return false end
    if Client.camera then Client.stopDeviceVisuals() end
    if surface.ped and DoesEntityExist(surface.ped) and not surface.wasFrozen then FreezeEntityPosition(surface.ped,false) end
    surface.editorTest=false
    surface.editorSimulation=true
    surface.firstPerson=false
    if SetFollowPedCamViewMode then SetFollowPedCamViewMode(4) end
    return true
end

local function drawTriangle(a, b, c, u1, v1, u2, v2, u3, v3)
    DrawTexturedPoly(a.x,a.y,a.z, b.x,b.y,b.z, c.x,c.y,c.z,
        255,255,255,255, 'mz_computer_display','screen', u1,v1,1.0, u2,v2,1.0, u3,v3,1.0)
end

CreateThread(function()
    local nextProjection = 0
    while not stopping do
        local surface = Client.surface
        if surface and surface.ready then
            Wait(0)
            if Client.surface == surface then
                if not DoesEntityExist(surface.entity) then
                    if surface.preview then Client.stopWorldDisplay(); Client.stopDeviceVisuals()
                    else Client.closeComputer('monitor_removed', true) end
                else
                    local g = surface.geometry
                    drawTriangle(g.tl,g.bl,g.tr, 0.0,0.0, 0.0,1.0, 1.0,0.0)
                    drawTriangle(g.tr,g.bl,g.br, 1.0,0.0, 0.0,1.0, 1.0,1.0)
                    -- Both windings support models facing either side; depth testing still applies.
                    drawTriangle(g.tr,g.bl,g.tl, 1.0,0.0, 0.0,1.0, 0.0,0.0)
                    drawTriangle(g.br,g.bl,g.tr, 1.0,1.0, 0.0,1.0, 1.0,0.0)
                    HideHudAndRadarThisFrame()
                    if surface.firstPerson and surface.cfg.hideLocalPlayerInFirstPerson ~= false
                        and surface.ped and DoesEntityExist(surface.ped) and SetEntityLocallyInvisible then
                        -- One-frame local invisibility prevents the head/body clipping into
                        -- the scripted eye camera without hiding the character for others.
                        SetEntityLocallyInvisible(surface.ped)
                    end
                    if not surface.preview and (not surface.hybrid or surface.hybridStarted) and GetGameTimer() >= nextProjection then
                        nextProjection = GetGameTimer() + (tonumber(surface.cfg.hybridProjectionIntervalMs) or 50)
                        local points, visible = {}, true
                        local cx,cy=0.0,0.0
                        for _, point in ipairs({g.tl,g.tr,g.br,g.bl}) do
                            local onScreen, x, y = GetScreenCoordFromWorldCoord(point.x,point.y,point.z)
                            visible = visible and onScreen
                            points[#points+1] = {x=x, y=y}
                            cx,cy=cx+(x or 0),cy+(y or 0)
                        end
                        local messageType=surface.hybrid and 'hybrid:projection' or 'surface:projection'
                        SendNUIMessage({ type=messageType, id=surface.id, points=visible and points or false })
                        if surface.hybrid and visible and not surface.cursorSeeded and SetCursorLocation then
                            SetCursorLocation(cx/4.0,cy/4.0)
                            surface.cursorSeeded=true
                        end
                    end
                end
            end
        else Wait(200) end
    end
end)

CreateThread(function()
    while not stopping do
        local coords = GetEntityCoords(PlayerPedId())
        for _, terminal in ipairs(Client.terminals or {}) do
            local cfg = displayConfig(terminal)
            local c = terminal.coords
            local distance = #(coords - vector3(c.x,c.y,c.z))
            if cfg.enabled and distance < (cfg.spawnDistance or 35.0) then
                ensureObject(terminal, cfg)
            elseif not (Client.surface and Client.surface.terminalId == terminal.id) then
                releaseObject(terminal.id)
            end
        end
        Wait(1500)
    end
end)

function Client.applyTerminals(terminals)
    if Client.open and Client.device and Client.device.type=='public' then
        local replacement
        for _, terminal in ipairs(terminals) do if terminal.id==Client.device.terminalId then replacement=terminal; break end end
        -- Edits revoke affected sessions on the server. Unrelated saves must not close this PC.
        if not replacement then Client.closeComputer('terminal_updated',true) end
    end
    for id in pairs(objects) do
        if not (Client.surface and Client.surface.terminalId==id) then releaseObject(id) end
    end
    Client.terminals = terminals
end

RegisterNUICallback('surfaceReady', function(data, cb)
    data = type(data) == 'table' and data or {}
    if Client.surface and data.id == Client.surface.id then Client.surface.browserReady = true end
    cb({ok=true})
end)

RegisterNUICallback('surfaceVisible', function(data, cb)
    data = type(data) == 'table' and data or {}
    if Client.surface and data.id == Client.surface.id and Client.surface.browserReady then
        Client.surface.uiVisible = true
    end
    cb({ok=true})
end)

RegisterNUICallback('surfaceFocus', function(data, cb)
    data = type(data) == 'table' and data or {}
    local surface = Client.surface
    if surface and surface.ready and data.id == surface.id then
        SendNUIMessage({ type='surface:focus', id=surface.id, field=data.field,
            value=type(data.value)=='string' and data.value:sub(1,80000) or '',
            start=data.start, finish=data.finish, multiline=data.multiline, maxLength=data.maxLength })
    end
    cb({ok=true})
end)

RegisterNUICallback('surfaceInput', function(data, cb)
    data = type(data) == 'table' and data or {}
    local s = Client.surface
    if not s or not s.ready or not Client.open or data.id ~= s.id then cb({ok=false}); return end
    if s.hybrid then cb({ok=false,error='HYBRID_DIRECT_NUI'}); return end
    if data.kind == 'pointer' then
        local x, y = tonumber(data.x), tonumber(data.y)
        if x and y and x == x and y == y then
            SendDuiMouseMove(s.dui, math.floor(math.max(0,math.min(1,x))*(s.cfg.width-1)),
                math.floor(math.max(0,math.min(1,y))*(s.cfg.height-1)))
            if data.event == 'down' then SendDuiMouseDown(s.dui, 'left')
            elseif data.event == 'up' then SendDuiMouseUp(s.dui, 'left')
            elseif data.event == 'wheel' then
                SendDuiMouseWheel(s.dui, math.floor(math.max(-500,math.min(500,tonumber(data.delta) or 0))), 0)
            end
        end
    elseif data.kind == 'text' and type(data.value) == 'string' and #data.value <= 80000 then
        SendDuiMessage(s.dui, json.encode({type='surface:text', field=data.field,
            value=data.value, start=data.start, finish=data.finish}))
    elseif data.kind == 'key' and ({Enter=true,Tab=true,Escape=true,F3=true,F5=true})[data.key] then
        SendDuiMessage(s.dui, json.encode({type='surface:key', key=data.key, shift=data.shift==true}))
    end
    cb({ok=true})
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopping = true
    Client.stopWorldDisplay()
    for id in pairs(objects) do releaseObject(id) end
end)
