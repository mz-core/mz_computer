local Client, G = MZComputerClient, MZComputer.ScreenGeometry
local session
local function notify(text,kind) lib.notify({title='Telas do MZ OS',description=text,type=kind or 'inform'}) end
local function point(v) return {x=v.x,y=v.y,z=v.z} end
local function help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0,false,true,-1)
end
local function cameraRay()
    local origin,rot = GetGameplayCamCoord(),GetGameplayCamRot(2)
    local pitch,yaw = math.rad(rot.x),math.rad(rot.z)
    return origin,vector3(-math.sin(yaw)*math.cos(pitch),math.cos(yaw)*math.cos(pitch),math.sin(pitch))
end

local function fitScreen(current)
    local d=current.terminal.display
    local rectangle=G.rectangle(d.corners)
    if not rectangle then return end
    d.cameraDistance=math.max(.15,math.min(Config.TerminalEditor.cameraDistanceMax or 20,
        G.fitCameraDistance(rectangle.width,rectangle.height,d.cameraFov,GetAspectRatio(false))))
    d.cameraRight,d.cameraUp=0,0
    Client.updateScreenPreview(d)
end

function Client.cancelScreenEditor()
    local current = session
    session = nil
    Client.editing = false
    if current then Client.generation=(Client.generation or 0)+1 end
    if current and current.selecting and GetResourceState('mz_world_editor')=='started' then
        pcall(function() exports['mz_world_editor']:CancelActiveSession('computer_editor_closed') end)
    end
    if Client.surface and Client.surface.preview then Client.stopWorldDisplay(); Client.stopDeviceVisuals() end
    if current and current.dialog then lib.closeInputDialog() end
end

local function settings(current)
    local d = current.terminal.display
    current.dialog = true
    local values = lib.inputDialog('Ajustar tela e camera',{
        {type='input',label='Nome do computador',default=current.terminal.label,required=true,max=64},
        {type='number',label='Distancia da camera de calibracao (m)',description='Exemplo: 0.5 m = 500 mm. Afaste para enquadrar a tela inteira.',default=d.cameraDistance,min=.15,max=Config.TerminalEditor.cameraDistanceMax or 20,precision=3,step=.05,required=true},
        {type='number',label='Campo de visao (graus)',default=d.cameraFov,min=20,max=80,required=true},
        {type='number',label='Deslocamento lateral da camera de calibracao (m)',default=d.cameraRight or 0,min=-2,max=2,precision=3,step=.01,required=true},
        {type='number',label='Altura da camera de calibracao (m)',default=d.cameraUp or 0,min=-2,max=2,precision=3,step=.01,required=true},
        {type='number',label='Avanco da tela sobre o vidro (mm)',default=d.screenLift*1000,min=0,max=200,precision=1,step=1,required=true},
        {type='number',label='Distancia para interagir (m)',description='Raio em torno do ponto de interacao onde aparece [E].',default=current.terminal.interactionDistance or 1.5,
            min=Config.TerminalEditor.interactionDistanceMin or .5,max=Config.TerminalEditor.interactionDistanceMax or 4,precision=2,step=.1,required=true}
    })
    current.dialog = false
    if session~=current or not values then return end
    current.terminal.label = values[1]
    d.cameraDistance,d.cameraFov,d.cameraRight,d.cameraUp,d.screenLift = values[2],values[3],values[4],values[5],values[6]/1000
    current.terminal.interactionDistance=values[7]
    Client.updateScreenPreview(d)
end

local save

local function beginPlayerAnchor(current)
    if not Client.beginScreenEditorSimulation or not Client.beginScreenEditorSimulation() then
        notify('Nao foi possivel iniciar a simulacao em primeira pessoa.','error')
        return
    end
    current.phase='simulation'
    current.inputAfter=GetGameTimer()+450
    notify('Simulacao ativa: ande ate a posicao ideal e olhe para a tela como o jogador deve enxergar. ENTER captura e testa.')
end

local function clamp(value,low,high)
    value=tonumber(value) or 0
    if value<low then return low end
    if value>high then return high end
    return value
end

local function capturePlayerAnchor(current)
    local ped=PlayerPedId()
    local world=GetEntityCoords(ped)
    local localPosition=GetOffsetFromEntityGivenWorldCoords(current.entity,world.x,world.y,world.z)
    local offset=point(localPosition)
    local max=Config.TerminalEditor.anchorOffsetMax or 6
    if G.length(offset)>max then notify('A posicao do jogador ficou distante demais do monitor.','error'); return end
    local view=Client.captureScreenEditorView and Client.captureScreenEditorView()
    if not view then notify('Nao foi possivel capturar a visao em primeira pessoa.','error'); return end
    if not view.onScreen then
        notify('Olhe para dentro da area do monitor antes de capturar a visao.','error')
        return
    end

    current.terminal.playerAnchor={offset=offset,heading=G.relativeHeading(GetEntityHeading(current.entity),GetEntityHeading(ped)) or 0,mode='standing'}
    -- The natural use position is also the most intuitive interaction point.
    -- It can still have a wider/narrower radius through interactionDistance.
    current.terminal.interactionAnchor={offset={x=offset.x,y=offset.y,z=offset.z}}
    local d=current.terminal.display
    d.firstPersonEyeForward=clamp(view.eyeForward,-.5,.5)
    d.firstPersonEyeRight=clamp(view.eyeRight,-.5,.5)
    d.firstPersonEyeUp=clamp(view.eyeUp,-.5,.5)
    d.firstPersonTargetRight=clamp(view.targetRight,-2,2)
    d.firstPersonTargetUp=clamp(view.targetUp,-2,2)
    d.cameraFov=clamp(view.fov,20,80)

    if not Client.startScreenEditorRuntimeTest or not Client.startScreenEditorRuntimeTest(d) then
        notify('Captura feita, mas o teste da camera nao iniciou.','error')
        return
    end
    current.phase='test'
    current.inputAfter=GetGameTimer()+350
    notify('Teste ativo. Esta e a visao que o jogador tera ao usar o computador.')
end

local function startPreview(current)
    current.phase='loading'
    local ok,result,warning = pcall(Client.startWorldDisplay,{type='public',label=current.terminal.label},current.terminal)
    if session~=current then return end
    if not ok or not result then
        Client.cancelScreenEditor()
        notify(warning or 'A previa 3D nao carregou. Verifique o F8.','error')
        if not ok then print('[mz_computer] Screen preview: '..tostring(result)) end
        return
    end
    current.phase='preview'
end

save = function(current,remove)
    local previousPhase=current.phase
    current.phase='saving'
    local ok,result = pcall(lib.callback.await,'mz_computer:server:saveTerminal',false,current.terminal,remove==true)
    if session~=current then return end
    if ok and result and result.ok then
        Client.cancelScreenEditor()
        notify(remove and 'Cadastro removido. O objeto continua no mapa.' or 'Tela salva! Aproxime-se e pressione E para usar o computador.','success')
    else
        current.phase = remove and 'selected' or previousPhase
        notify(ok and result and result.error or 'O servidor nao respondeu ao cadastro.','error')
        if remove then Client.cancelScreenEditor() end
    end
end

local function chooseCorner(current)
    local origin,direction = cameraRay()
    local position
    if #current.points==0 then
        -- Only one synchronous trace per click, never an expensive trace every frame.
        local target = origin + direction*15
        local handle = StartExpensiveSynchronousShapeTestLosProbe(origin.x,origin.y,origin.z,target.x,target.y,target.z,511,PlayerPedId(),7)
        local _,hit,coords,normal,entity = GetShapeTestResult(handle)
        if (hit~=1 and hit~=true) or entity~=current.entity then
            notify('Mire no vidro do objeto selecionado. O primeiro ponto precisa atingir a colisao do monitor.','error'); return
        end
        current.plane,current.normal = point(coords),point(normal)
        position = point(coords)
    else
        position = G.rayPlane(origin,direction,current.plane,current.normal)
        if not position then notify('Olhe de frente para a tela.','error'); return end
    end
    local localPosition = GetOffsetFromEntityGivenWorldCoords(current.entity,position.x,position.y,position.z)
    current.points[#current.points+1] = point(localPosition)
    if #current.points~=3 then return end
    local tl,tr,bl = table.unpack(current.points)
    local r = G.sub(tr,tl)
    local width = G.length(r)
    if width > .001 then
        -- Remove aiming drift along the top edge so all four corners stay rectangular.
        local down = G.sub(bl,tl)
        bl = G.add(tl,G.sub(down,G.scale(r,G.dot(down,r)/(width*width))))
    end
    local corners = {tl=tl,tr=tr,bl=bl}
    local rectangle = G.rectangle(corners)
    if not rectangle then
        current.points={}; notify('Area invalida. Marque superior esquerdo, superior direito e inferior esquerdo.','error'); return
    end
    local cameraLocal = GetOffsetFromEntityGivenWorldCoords(current.entity,origin.x,origin.y,origin.z)
    if G.dot(rectangle.normal,G.sub(cameraLocal,rectangle.center))<=0 then
        current.points={}; notify('Os cantos ficaram invertidos. Marque-os na ordem indicada, olhando de frente.','error'); return
    end
    current.terminal.display.corners = corners
    fitScreen(current)
    startPreview(current)
end

AddEventHandler('mz_world_editor:client:selectionResult',function(requestId,data)
    local current = session
    if not current or requestId~=current.requestId then return end
    current.selecting=false
    current.inputAfter=GetGameTimer()+300 -- do not reuse the selector's E press as corner 1
    if not data or not data.entity or not DoesEntityExist(data.entity) or GetEntityType(data.entity)~=3 then
        Client.cancelScreenEditor(); notify('Objeto indisponivel.','error'); return
    end
    current.entity = data.entity
    local coords = point(GetEntityCoords(data.entity))
    if G.length(G.sub(coords,GetEntityCoords(PlayerPedId())))>15 then
        Client.cancelScreenEditor(); notify('Aproxime-se do monitor para cadastra-lo.','error'); return
    end
    local model = GetEntityModel(data.entity)
    for _, term in ipairs(Client.terminals) do
        if term.display and term.display.corners and term.display.model==model and G.length(G.sub(term.coords,coords))<.15 then
            current.terminal=json.decode(json.encode(term)); break
        end
    end
    if current.remove then
        if not current.terminal then Client.cancelScreenEditor(); notify('Este objeto nao tem uma tela cadastrada.','error'); return end
        CreateThread(function()
            local answer=lib.alertDialog({header='Remover cadastro da tela?',content=current.terminal.label,centered=true,cancel=true})
            if session~=current then return end
            if answer=='confirm' then save(current,true) else Client.cancelScreenEditor() end
        end)
        return
    end
    if current.terminal then
        CreateThread(function() startPreview(current) end)
        return
    end
    current.terminal = {id=('screen_%s_%s'):format(GetPlayerServerId(PlayerId()),GetGameTimer()),
        label='Computador',coords=coords,heading=GetEntityHeading(data.entity),skin='terminal_basic',interactionDistance=1.5,
        display={enabled=true,spawnProp=false,model=model,objectCoords=coords,matchRadius=.15,screenLift=.008,
            cameraDistance=.72,cameraFov=42,cameraRight=0,cameraUp=0}}
    current.phase,current.points='corners',{}
    notify('Marque os tres cantos do vidro com a mira e E. Backspace cancela.')
end)

AddEventHandler('mz_world_editor:client:selectionCancelled',function(requestId)
    if session and session.requestId==requestId then session.selecting=false; Client.cancelScreenEditor() end
end)

RegisterCommand(Config.TerminalEditor.command,function(_,args)
    if session then Client.cancelScreenEditor(); return end
    if Client.open then Client.closeComputer('screen_editor',true) end
    local current = {phase='permission',requestId='mz_computer:'..GetGameTimer(),remove=args[1]=='remover'}
    session,Client.editing = current,true
    local ok,allowed=pcall(lib.callback.await,'mz_computer:server:editorAllowed',false)
    if session~=current then return end
    if not ok or not allowed then Client.cancelScreenEditor(); notify('Sem permissao ou recurso ainda iniciando.','error'); return end
    if GetResourceState('mz_world_editor')~='started' then
        Client.cancelScreenEditor(); notify('Inicie mz_world_editor para selecionar o monitor.','error'); return
    end
    current.selecting=true
    local called,started=pcall(function()
        return exports['mz_world_editor']:StartEntitySelection({requestId=current.requestId,objectsOnly=true,
            title=current.remove and 'Remover tela cadastrada' or 'Selecionar monitor do MZ OS',targetLabel='monitor'})
    end)
    if not called or not started then current.selecting=false; Client.cancelScreenEditor(); notify('O editor do mundo esta ocupado.','error') end
end,false)

CreateThread(function()
    while true do
        local current=session
        if not current or current.selecting then Wait(200)
        else
            Wait(0)
            if session==current then
                DisablePlayerFiring(PlayerId(),true)
                for _, control in ipairs({0,23,24,25,37,38,44,45,47,177,200,201,241,242}) do DisableControlAction(0,control,true) end
                if IsDisabledControlJustPressed(0,177) or IsDisabledControlJustPressed(0,200) or IsEntityDead(PlayerPedId()) then
                    Client.cancelScreenEditor()
                elseif current.entity and not DoesEntityExist(current.entity) then
                    Client.cancelScreenEditor(); notify('O objeto foi removido ou deixou de estar carregado.','error')
                elseif not current.dialog and current.phase=='corners' and GetGameTimer()>=(current.inputAfter or 0) then
                    local names={'superior esquerdo','superior direito','inferior esquerdo'}
                    help(('Canto %d/3: ~b~%s~s~ | ~INPUT_CONTEXT~ Marcar | ~INPUT_CELLPHONE_CANCEL~ Cancelar'):format(#current.points+1,names[#current.points+1]))
                    DrawRect(.5,.5,.002,.006,80,220,255,255)
                    for _, p in ipairs(current.points) do
                        local w=GetOffsetFromEntityInWorldCoords(current.entity,p.x,p.y,p.z)
                        DrawMarker(28,w.x,w.y,w.z,0.,0.,0.,0.,0.,0.,.008,.008,.008,80,220,255,255,false,false,2,false,nil,nil,false)
                    end
                    if IsDisabledControlJustPressed(0,38) then chooseCorner(current) end
                elseif not current.dialog and current.phase=='preview' then
                    local d=current.terminal.display
                    for _,control in ipairs({32,33,34,35}) do DisableControlAction(0,control,true) end
                    help(('Camera: %.3f m | ENTER Proximo | G Ajustes | F Enquadrar | R Remarcar~n~Scroll: distancia | W/S: altura | A/D: lateral | Q/E: vidro | SHIFT acelera | BACKSPACE Sair'):format(d.cameraDistance))
                    local fast=IsControlPressed(0,21)
                    local step=fast and .25 or .025
                    local offsetStep=fast and .025 or .005
                    if IsDisabledControlJustPressed(0,241) then d.cameraDistance=math.max(.15,d.cameraDistance-step)
                    elseif IsDisabledControlJustPressed(0,242) then d.cameraDistance=math.min(Config.TerminalEditor.cameraDistanceMax or 20,d.cameraDistance+step)
                    elseif IsDisabledControlJustPressed(0,23) then fitScreen(current)
                    elseif IsDisabledControlJustPressed(0,44) then d.screenLift=math.min(.2,d.screenLift+.001)
                    elseif IsDisabledControlJustPressed(0,38) then d.screenLift=math.max(0,d.screenLift-.001)
                    elseif IsDisabledControlJustPressed(0,47) then settings(current)
                    elseif IsDisabledControlJustPressed(0,45) then
                        Client.stopWorldDisplay(); Client.stopDeviceVisuals()
                        current.points,current.phase={},'corners'
                        Wait(300)
                    elseif IsDisabledControlJustPressed(0,201) then beginPlayerAnchor(current)
                    elseif IsDisabledControlPressed(0,32) then d.cameraUp=math.min(2,(d.cameraUp or 0)+offsetStep)
                    elseif IsDisabledControlPressed(0,33) then d.cameraUp=math.max(-2,(d.cameraUp or 0)-offsetStep)
                    elseif IsDisabledControlPressed(0,34) then d.cameraRight=math.max(-2,(d.cameraRight or 0)-offsetStep)
                    elseif IsDisabledControlPressed(0,35) then d.cameraRight=math.min(2,(d.cameraRight or 0)+offsetStep) end
                    if session==current and current.phase=='preview' then Client.updateScreenPreview(d) end
                elseif current.phase=='simulation' and GetGameTimer()>=(current.inputAfter or 0) then
                    help('SIMULACAO 1a PESSOA | WASD mover | Mouse olhar | ~INPUT_FRONTEND_ACCEPT~ Capturar + testar | ~INPUT_CELLPHONE_CANCEL~ Cancelar')
                    DrawRect(.5,.5,.002,.006,80,220,255,220)
                    if IsDisabledControlJustPressed(0,201) then capturePlayerAnchor(current) end
                elseif current.phase=='test' and GetGameTimer()>=(current.inputAfter or 0) then
                    help(('TESTE DO JOGADOR | raio [E] %.2fm | ~INPUT_FRONTEND_ACCEPT~ Salvar | R Recalibrar posicao/visao | ~INPUT_CELLPHONE_CANCEL~ Cancelar'):format(current.terminal.interactionDistance or 1.5))
                    if IsDisabledControlJustPressed(0,201) then
                        save(current,false)
                    elseif IsDisabledControlJustPressed(0,45) then
                        if Client.returnScreenEditorSimulation and Client.returnScreenEditorSimulation() then
                            current.phase='simulation'
                            current.inputAfter=GetGameTimer()+300
                            notify('Recalibracao ativa. Ajuste sua posicao e a visao, depois pressione ENTER novamente.')
                        end
                    end
                end
            end
        end
    end
end)

AddEventHandler('onClientResourceStop',function(resource)
    if resource==GetCurrentResourceName() or resource=='mz_world_editor' then Client.cancelScreenEditor() end
end)
