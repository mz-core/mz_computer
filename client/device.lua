local Client = MZComputerClient

local function deleteProp()
    if Client.prop and DoesEntityExist(Client.prop) then DeleteEntity(Client.prop) end
    Client.prop = nil
end

local function destroyCamera()
    if Client.camera then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(Client.camera, false)
        Client.camera = nil
    end
end

local function createProp(skin)
    local propCfg = skin and skin.prop
    if not propCfg or not propCfg.enabled or not propCfg.model then return end
    local model = joaat(propCfg.model)
    RequestModel(model)
    local deadline = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(model) then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    if prop and prop ~= 0 then
        local o = propCfg.offset or {}
        local r = propCfg.rotation or {}
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, tonumber(propCfg.bone) or 57005),
            tonumber(o.x) or 0.0, tonumber(o.y) or 0.0, tonumber(o.z) or 0.0,
            tonumber(r.x) or 0.0, tonumber(r.y) or 0.0, tonumber(r.z) or 0.0,
            true, true, false, true, 1, true)
        Client.prop = prop
    end
    SetModelAsNoLongerNeeded(model)
end

local function createCamera(skin)
    local cfg = skin and skin.camera
    if not cfg or not cfg.enabled then return end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, pos.x + forward.x * 0.55, pos.y + forward.y * 0.55, pos.z + 0.55)
    PointCamAtEntity(cam, ped, 0.0, 0.0, 0.45, true)
    SetCamFov(cam, tonumber(cfg.fov) or 50.0)
    RenderScriptCams(true, true, 250, true, true)
    Client.camera = cam
end

function Client.startDeviceVisuals(device)
    local skin = device and device.skinId and Config.DeviceSkins[device.skinId] or Config.DeviceSkins[Config.DefaultSkin]
    createProp(skin)
    createCamera(skin)
end

function Client.stopDeviceVisuals()
    deleteProp()
    destroyCamera()
    ClearPedSecondaryTask(PlayerPedId())
end
