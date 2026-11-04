local Editor, saved, busy = {}, {}, false
local G = MZComputer.ScreenGeometry
local filename = 'terminals.json'

local function number(n, low, high)
    n = tonumber(n)
    return n and n == n and n >= low and n <= high and n or nil
end

local function normalizeAnchor(raw, includeHeading)
    if raw == nil then return nil end
    if type(raw) ~= 'table' then return false end
    local limit = Config.TerminalEditor.anchorOffsetMax or 6
    local offset = G.point(raw.offset, limit)
    if not offset or G.length(offset) > limit then return false end
    local out = {offset=offset}
    if includeHeading then
        local heading = number(raw.heading or 0,-360,360)
        if not heading then return false end
        local mode = raw.mode == nil and 'standing' or MZComputer.Validation.string(raw.mode,1,24)
        if mode ~= 'standing' then return false end
        out.heading,out.mode = heading,mode
    end
    return out
end

function Editor.normalize(raw)
    if type(raw) ~= 'table' then return nil end
    local id = MZComputer.Validation.id(raw.id,48)
    local label = MZComputer.Validation.string(raw.label,1,64)
    local coords = G.point(raw.coords)
    local display = type(raw.display) == 'table' and raw.display or {}
    local model = number(display.model,-2147483648,4294967295)
    local corners = G.rectangle(display.corners)
    local depth = number(display.screenLift,0,.2)
    local distance = number(display.cameraDistance,.15,Config.TerminalEditor.cameraDistanceMax or 20)
    local fov = number(display.cameraFov,20,80)
    local cameraRight = number(display.cameraRight or 0,-2,2)
    local cameraUp = number(display.cameraUp or 0,-2,2)
    local interactionMode = display.interactionMode
    if interactionMode ~= nil and interactionMode ~= 'nui_overlay' and interactionMode ~= 'dui' then return nil end
    local fpEyeForward = display.firstPersonEyeForward
    local fpEyeRight = display.firstPersonEyeRight
    local fpEyeUp = display.firstPersonEyeUp
    local fpTargetRight = display.firstPersonTargetRight
    local fpTargetUp = display.firstPersonTargetUp
    if fpEyeForward ~= nil then fpEyeForward=number(fpEyeForward,-.5,.5); if not fpEyeForward then return nil end end
    if fpEyeRight ~= nil then fpEyeRight=number(fpEyeRight,-.5,.5); if not fpEyeRight then return nil end end
    if fpEyeUp ~= nil then fpEyeUp=number(fpEyeUp,-.5,.5); if not fpEyeUp then return nil end end
    if fpTargetRight ~= nil then fpTargetRight=number(fpTargetRight,-2,2); if not fpTargetRight then return nil end end
    if fpTargetUp ~= nil then fpTargetUp=number(fpTargetUp,-2,2); if not fpTargetUp then return nil end end
    local heading = number(raw.heading,-360,360)
    local interactionDistance = number(raw.interactionDistance or 2.0,
        Config.TerminalEditor.interactionDistanceMin or .5,Config.TerminalEditor.interactionDistanceMax or 4)
    local playerAnchor = normalizeAnchor(raw.playerAnchor,true)
    local interactionAnchor = normalizeAnchor(raw.interactionAnchor,false)
    if playerAnchor == false or interactionAnchor == false then return nil end
    if not id or not label or not coords or not model or model == 0 or model%1 ~= 0
        or not corners or not depth or not distance or not fov or not cameraRight or not cameraUp or not heading
        or not interactionDistance then return nil end
    local normalizedDisplay={enabled=true,spawnProp=false,model=model,objectCoords=coords,matchRadius=.15,
        corners={tl=corners.tl,tr=corners.tr,bl=corners.bl},screenLift=depth,
        cameraDistance=distance,cameraFov=fov,cameraRight=cameraRight,cameraUp=cameraUp}
    normalizedDisplay.firstPersonEyeForward=fpEyeForward
    normalizedDisplay.firstPersonEyeRight=fpEyeRight
    normalizedDisplay.firstPersonEyeUp=fpEyeUp
    normalizedDisplay.firstPersonTargetRight=fpTargetRight
    normalizedDisplay.firstPersonTargetUp=fpTargetUp
    normalizedDisplay.interactionMode=interactionMode
    return {id=id,label=label,coords=coords,heading=heading,skin='terminal_basic',interactionDistance=interactionDistance,
        playerAnchor=playerAnchor,interactionAnchor=interactionAnchor,
        display=normalizedDisplay}
end

function Editor.load()
    local contents = LoadResourceFile(GetCurrentResourceName(),filename)
    if not contents then saved = {}; return {} end
    local ok,data = pcall(json.decode,contents)
    assert(ok and type(data)=='table' and data.version==1 and type(data.terminals)=='table',
        'terminals.json invalido; restaure o arquivo antes de iniciar mz_computer')
    local definitions = {}
    saved = {}
    for _, raw in ipairs(data.terminals) do
        local term = Editor.normalize(raw)
        assert(term and not saved[term.id], 'Cadastro de tela invalido ou duplicado em terminals.json')
        saved[term.id] = term
        definitions[#definitions+1] = term
    end
    return definitions
end

local function allowed(source)
    if source <= 0 then return false end
    if IsPlayerAceAllowed(source,Config.Security.staffAce) then return true end
    if Config.TerminalEditor.allowWorldEditorAdmins and GetResourceState('mz_world_editor')=='started' then
        local ok,result = pcall(function() return exports['mz_world_editor']:CanUseWorldEditor(source) end)
        return ok and result == true
    end
    return false
end

local function nearby(source,coords)
    local ped = GetPlayerPed(source)
    return ped and ped > 0 and G.length(G.sub(GetEntityCoords(ped),coords)) <= 15
end

local function persist(nextSaved)
    local terminals = {}
    for _, term in pairs(nextSaved) do terminals[#terminals+1] = term end
    table.sort(terminals,function(a,b) return a.id < b.id end)
    if #terminals > Config.TerminalEditor.maxTerminals then return false,'Limite de telas cadastradas atingido.' end
    local resource = GetCurrentResourceName()
    local encoded = json.encode({version=1,terminals=terminals})
    local result = SaveResourceFile(resource,filename,encoded,#encoded)
    -- Native bindings can return either BOOL true or numeric 1. Lua's 0 is truthy,
    -- so a generic truthiness check would incorrectly accept a failed write.
    if result ~= true and result ~= 1 then
        local path = GetResourcePath(resource) or resource
        return false,('Nao foi possivel gravar %s/%s (retorno=%s). Verifique a permissao de escrita da pasta do recurso.'):format(path,filename,tostring(result))
    end
    if LoadResourceFile(resource,filename) ~= encoded then
        return false,'O conteudo de terminals.json nao confere apos a gravacao.'
    end
    return true
end

local function configId(id)
    for _, term in ipairs(Config.PublicTerminals) do if term.id==id then return true end end
    return false
end

lib.callback.register('mz_computer:server:editorAllowed',function(source)
    return MZComputer.Ready and Config.TerminalEditor.enabled and allowed(source)
end)

lib.callback.register('mz_computer:server:saveTerminal',function(source,raw,remove)
    if not MZComputer.Ready or not Config.TerminalEditor.enabled or not allowed(source) then
        return {ok=false,error='Sem permissao para cadastrar telas.'}
    end
    if busy then return {ok=false,error='Outro cadastro esta sendo salvo. Tente novamente.'} end
    local term = Editor.normalize(raw)
    if not term or configId(term.id) or not nearby(source,term.coords)
        or (saved[term.id] and not nearby(source,saved[term.id].coords)) then
        return {ok=false,error='Cadastro invalido, distante ou definido manualmente em config.lua.'}
    end
    if remove and not saved[term.id] then return {ok=false,error='Tela nao cadastrada pelo editor.'} end
    if not remove then
        for id,existing in pairs(saved) do
            if id~=term.id and existing.display.model==term.display.model
                and G.length(G.sub(existing.coords,term.coords)) < .15 then
                return {ok=false,error='Este objeto ja foi cadastrado. Use /mztela editar.'}
            end
        end
    end
    busy = true
    local ok,result = pcall(function()
        local nextSaved = {}
        for id,value in pairs(saved) do nextSaved[id] = value end
        nextSaved[term.id] = not remove and term or nil
        -- Prepare the device first; failed SQL or failed file writes leave the live list intact.
        local entry = not remove and MZComputer.Devices.preparePublic(term) or nil
        if not remove then assert(entry and entry.row, 'Nao foi possivel registrar o dispositivo.') end
        local stored,storageError = persist(nextSaved)
        assert(stored,storageError)
        MZComputer.Devices.replacePublic(term.id,entry)
        saved = nextSaved
        TriggerClientEvent('mz_computer:client:terminalsUpdated',-1,MZComputer.Devices.getPublicDefinitions())
        MZComputer.Audit.log(remove and 'terminal.removed' or 'terminal.saved',{source=source},term.id)
        return {ok=true}
    end)
    busy = false
    if not ok then
        print(('[mz_computer] Falha no cadastro de tela: %s'):format(tostring(result)))
        return {ok=false,error='Nao foi possivel salvar. Verifique o console do servidor.'}
    end
    return result
end)

MZComputer.TerminalEditor = Editor
