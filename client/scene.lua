-- Gestão do "palco" (interior da destilaria): isolamento visual, interior, luz e controlos.
-- A seleção e o criador partilham o mesmo interior (Config.Interior).

Scene = { active = nil, lightPed = nil }

-- Mostra/esconde HUDs de outros recursos (Config.ExternalHud)
function Scene.SetExternalHud(show)
    local cfg = Config.ExternalHud or {}
    for _, e in ipairs(cfg.exports or {}) do
        if GetResourceState(e[1]) == "started" then
            pcall(function() exports[e[1]][e[2]](exports[e[1]], show) end)
        end
    end
    for _, ev in ipairs(cfg.events or {}) do TriggerEvent(ev, show) end
end

local lightThread = false

local function weathersync(fn, ...)
    if GetResourceState("weathersync") ~= "started" then return false end
    local args = { ... }
    return pcall(function() exports.weathersync[fn](exports.weathersync, table.unpack(args)) end)
end

local function setWorld(hour, weather)
    if not weathersync("setSyncEnabled", false) then
        NetworkClockTimeOverride(hour, 0, 0, 0, true)
        return
    end
    weathersync("setMyWeather", weather or "sunny", 0, false)
    weathersync("setMyTime", hour, 0, 0, 0, true)
end

local function restoreWorld()
    if not weathersync("setSyncEnabled", true) then
        NetworkClearClockTimeOverride()
    end
end

function Scene.Teleport(coords)
    local ped = PlayerPedId()
    StartPlayerTeleport(PlayerId(), coords.x, coords.y, coords.z, coords.w or 0.0, true, true, true, true)
    local deadline = GetGameTimer() + 10000
    repeat Wait(0) until not IsPlayerTeleportActive() or GetGameTimer() > deadline
    ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    deadline = GetGameTimer() + 8000
    repeat Wait(0) until HasCollisionLoadedAroundEntity(ped) or GetGameTimer() > deadline
end

-- Carrega o interior e ativa os entity sets (normalmente só ativados ao entrar pela porta)
local function loadInterior()
    local cfg = Config.Interior
    for _, imap in ipairs(cfg.imaps or {}) do
        pcall(RequestImap, joaat(imap))
    end
    local a = cfg.anchor
    local interior = GetInteriorAtCoords(a.x, a.y, a.z)
    local deadline = GetGameTimer() + 8000
    while (not interior or interior == 0 or not IsValidInterior(interior)) and GetGameTimer() < deadline do
        Wait(100)
        interior = GetInteriorAtCoords(a.x, a.y, a.z)
    end
    if not interior or interior == 0 then
        return print("^3[fks-character] interior não encontrado em Config.Interior.anchor^7")
    end
    pcall(PinInteriorInMemory, interior)
    deadline = GetGameTimer() + 8000
    while not IsInteriorReady(interior) and GetGameTimer() < deadline do Wait(100) end
    for _, set in ipairs(cfg.entitySets or {}) do
        if IsInteriorEntitySetValid(interior, set) and not IsInteriorEntitySetActive(interior, set) then
            ActivateInteriorEntitySet(interior, set, 0)
        end
    end
    pcall(RefreshInterior, interior)
end

local function lockThread()
    CreateThread(function()
        while Scene.active do
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            SetAmbientAnimalDensityMultiplierThisFrame(0.0)
            SetAmbientHumanDensityMultiplierThisFrame(0.0)
            SetAmbientPedDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0)
            SetVehicleDensityMultiplierThisFrame(0.0)
            Citizen.InvokeNative(0x9911F4A24485F653, true) -- bloquear eventos de peds ambientes
            HideHudAndRadarThisFrame()
            Wait(0)
        end
    end)
end

local function hidePlayer()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityCollision(ped, false, false)
end
Scene.HidePlayer = hidePlayer

-- Luz por cima da personagem (criador: o jogador; seleção: a personagem escolhida)
local function startLight()
    if lightThread then return end
    lightThread = true
    CreateThread(function()
        local l = Config.CreatorScene.light
        while Scene.active do
            local ped = Scene.lightPed or (Scene.active == "creator" and PlayerPedId() or 0)
            if DoesEntityExist(ped) and IsEntityVisible(ped) then
                local idx = GetEntityBoneIndexByName(ped, "skel_head")
                local p = (idx and idx ~= -1) and GetWorldPositionOfEntityBone(ped, idx) or (GetEntityCoords(ped) + vector3(0.0, 0.0, 0.6))
                if Scene.lightFront then
                    -- à frente da cara, ligeiramente acima (retrato)
                    local f = GetEntityForwardVector(ped)
                    DrawLightWithRange(p.x + f.x * 0.9, p.y + f.y * 0.9, p.z + 0.2, l.color[1], l.color[2], l.color[3], l.range, l.intensity)
                else
                    DrawLightWithRange(p.x, p.y, p.z + l.height, l.color[1], l.color[2], l.color[3], l.range, l.intensity)
                end
            end
            Wait(0)
        end
        lightThread = false
    end)
end

function Scene.Enter(kind)
    local first = Scene.active == nil
    Scene.active = kind
    if first then
        DisplayRadar(false)
        DisplayHud(false)
        Scene.SetExternalHud(false)
        lockThread()
        hidePlayer()
        loadInterior()
        Scene.Teleport(Config.CreatorScene.stage)
        hidePlayer()
        setWorld(Config.Interior.hour, Config.Interior.weather)
    end
    if kind == "selection" then Scene.lightPed = nil end
    startLight()
end

function Scene.Leave()
    if not Scene.active then return end
    Scene.active = nil
    Scene.lightPed = nil
    Scene.lightFront = false

    ClearTimecycleModifier()
    TriggerMusicEvent("MC_MUSIC_STOP")
    AnimpostfxStopAll()
    restoreWorld()

    local ped = PlayerPedId()
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)
    SetEntityInvincible(ped, false)
    DisplayHud(true)
end

-- Tenta vários cenários até um pegar (nem todos existem para os dois modelos)
local function waitScenario(ped, ms)
    local deadline = GetGameTimer() + ms
    while GetGameTimer() < deadline do
        if IsPedUsingAnyScenario(ped) then return true end
        Wait(100)
    end
    return false
end

-- 1.º tenta o ponto de "sentar" real da cadeira/banco mais próximo (altura e orientação certas);
-- se o interior não tiver pontos ali, usa a animação na posição do config.
-- taken = posições já ocupadas por outras personagens (evita duas na mesma cadeira)
function Scene.SitAt(ped, seat, scenarios, taken, searchRadius)
    ClearPedTasksImmediately(ped)
    SetEntityCoords(ped, seat.x, seat.y, seat.z, false, false, false, false)
    SetEntityHeading(ped, seat.w)
    local radius = searchRadius or Config.SelectionScene.seatSearchRadius or 1.0
    if radius > 0 then
        local ok = pcall(TaskUseNearestScenarioToCoordWarp, ped, seat.x, seat.y, seat.z, radius, -1)
        if ok and waitScenario(ped, 1500) then
            local pos, free = GetEntityCoords(ped), true
            for _, t in ipairs(taken or {}) do
                if #(pos - t) < 0.6 then free = false break end
            end
            if free then return true end
        end
        ClearPedTasksImmediately(ped)
        SetEntityCoords(ped, seat.x, seat.y, seat.z, false, false, false, false)
        SetEntityHeading(ped, seat.w)
    end
    for _, name in ipairs(scenarios or {}) do
        local ok = pcall(TaskStartScenarioAtPosition, ped, joaat(name), seat.x, seat.y, seat.z, seat.w, -1, true, true, "", 0.0, false)
        if ok and waitScenario(ped, 1500) then
            if #(GetEntityCoords(ped) - vector3(seat.x, seat.y, seat.z)) < 2.0 then return true end
            break -- atravessou o chão: não insistir
        end
    end
    -- nada funcionou: de pé no sítio, assente no chão (nunca a cair do interior)
    ClearPedTasksImmediately(ped)
    SetEntityCoords(ped, seat.x, seat.y, seat.z + 1.0, false, false, false, false)
    PlaceEntityOnGroundProperly(ped)
    SetEntityHeading(ped, seat.w)
    return false
end
