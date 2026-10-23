-- Sequência cinematográfica: comboio chega à estação escolhida e a personagem sai na plataforma.
-- Tudo é calculado a partir de Config.FirstSpawn.Locations[i].coords (ponto na plataforma):
--   1. o comboio é criado na linha mais próxima desse ponto (= sítio onde vai parar);
--   2. com o ecrã preto recua alguns segundos;
--   3. avança e trava até ao ponto inicial, com câmaras de cinema;
--   4. a personagem sai da carruagem mais próxima da plataforma.
-- Qualquer falha (native, modelo, timeout) termina a sequência e o spawn normal continua.

Arrival = {}

local NATIVE = {
    CreateMissionTrain = 0xC239DBD9A57D2A71,
    DeleteMissionTrain = 0x0D3630FB07E8B570,
    SetTrainSpeed = 0xDFBA6BBFF7CCAFBB,
    SetTrainCruiseSpeed = 0x01021EB2E96B793C,
    GetTrainCarriage = 0xD0FB093A4CDB932C,
    NumCarsInConfig = 0x635423D55CA84FC8,
    ModelInConfig = 0x8DF5F6A19F99F0D5,
    SetTrainStopsForStations = 0x4182C037AA1F0091,
}

local SKIP_KEYS = { joaat("INPUT_FRONTEND_ACCEPT"), joaat("INPUT_JUMP") }

local function invoke(hash, ...)
    return Citizen.InvokeNative(hash, ...)
end

local function setSpeed(train, speed)
    invoke(NATIVE.SetTrainCruiseSpeed, train, speed + 0.0)
    invoke(NATIVE.SetTrainSpeed, train, speed + 0.0)
end

local function flat(v) return vector3(v.x, v.y, 0.0) end

local function normalize(v)
    local len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if len < 0.0001 then return vector3(0.0, 1.0, 0.0) end
    return vector3(v.x / len, v.y / len, v.z / len)
end

local function headingTo(from, to)
    return (math.deg(math.atan(to.y - from.y, to.x - from.x)) - 90.0) % 360.0
end

local function loadTrainModels(config)
    local count = invoke(NATIVE.NumCarsInConfig, config, Citizen.ResultAsInteger()) or 0
    for i = 0, count - 1 do
        local model = invoke(NATIVE.ModelInConfig, config, i, Citizen.ResultAsInteger())
        if model and model ~= 0 then N.LoadModel(model) end
    end
    return count
end

local function waitFade(out, ms)
    if out then DoScreenFadeOut(ms) else DoScreenFadeIn(ms) end
    local deadline = GetGameTimer() + ms + 1000
    repeat Wait(0) until (out and IsScreenFadedOut() or (not out and IsScreenFadedIn())) or GetGameTimer() > deadline
end

local function makeCam(pos, fov)
    local cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, fov or 45.0, false, 2)
    SetCamActive(cam, true)
    return cam
end

-- Carruagem mais próxima da plataforma (exclui a locomotiva quando possível)
local function closestCarriage(train, point)
    local best, bestDist = train, math.huge
    for i = 1, 12 do
        local car = invoke(NATIVE.GetTrainCarriage, train, i, Citizen.ResultAsInteger())
        if not car or car == 0 or not DoesEntityExist(car) then break end
        local d = #(flat(GetEntityCoords(car)) - flat(point))
        if d < bestDist then best, bestDist = car, d end
    end
    return best
end

-- Devolve vector4 final (posição/heading na plataforma) ou nil se não correu
function Arrival.Play(index, opts)
    opts = opts or {}
    local cfg = Config.Arrival
    local loc = Config.FirstSpawn.Locations[index]
    if not cfg.Enabled or not loc or loc.train == false then return nil end

    local state = { train = nil, cams = {}, skipped = false, running = true }
    local exit = loc.coords
    local final = nil

    if not opts.test then
        local res = ServerCall("arrival:begin")
        if not res or not res.ok then return nil end
    end

    -- controlos bloqueados + saltar
    CreateThread(function()
        while state.running do
            DisableAllControlActions(0)
            HideHudAndRadarThisFrame()
            if cfg.AllowSkip then
                for _, key in ipairs(SKIP_KEYS) do
                    if IsDisabledControlJustPressed(0, key) then state.skipped = true end
                end
            end
            Wait(0)
        end
    end)

    local ok, err = pcall(function()
        Scene.SetExternalHud(false)
        if not IsScreenFadedOut() then waitFade(true, 500) end

        -- carregar a zona com o jogador escondido na plataforma
        local ped = PlayerPedId()
        SetEntityVisible(ped, false)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, false)
        Scene.Teleport(exit)
        ped = PlayerPedId()
        SetEntityVisible(ped, false)
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)

        local config = joaat(cfg.TrainConfig)
        if loadTrainModels(config) == 0 then error("train config sem carruagens: " .. cfg.TrainConfig) end

        local train = invoke(NATIVE.CreateMissionTrain, config, exit.x, exit.y, exit.z, false, false, true, false, Citizen.ResultAsInteger())
        local deadline = GetGameTimer() + 5000
        while (not train or train == 0 or not DoesEntityExist(train)) and GetGameTimer() < deadline do Wait(50) end
        if not train or train == 0 or not DoesEntityExist(train) then error("comboio não foi criado") end
        state.train = train
        pcall(invoke, NATIVE.SetTrainStopsForStations, train, false)

        local stopPos = GetEntityCoords(train)
        local fwd = normalize(flat(GetEntityForwardVector(train)))
        local right = vector3(fwd.y, -fwd.x, 0.0)
        -- lado da plataforma = lado onde estão as coords de saída
        local side = ((exit.x - stopPos.x) * right.x + (exit.y - stopPos.y) * right.y) >= 0 and 1.0 or -1.0

        -- recuar com o ecrã preto
        setSpeed(train, -cfg.ReverseSpeed)
        local t0 = GetGameTimer()
        while GetGameTimer() - t0 < cfg.ReverseTime and not state.skipped do Wait(0) end
        setSpeed(train, 0.0)
        Wait(300)

        -- plano 1: plataforma, à frente do ponto de paragem, a olhar para o comboio que chega
        local camPos = loc.trainCam and vector3(loc.trainCam.x, loc.trainCam.y, loc.trainCam.z)
            or (stopPos + fwd * 14.0 + right * (side * 7.0) + vector3(0.0, 0.0, 2.2))
        local cam1 = makeCam(camPos, 42.0)
        state.cams[#state.cams + 1] = cam1
        PointCamAtEntity(cam1, train, 0.0, 0.0, 1.0, true)
        RenderScriptCams(true, false, 0, true, true, 0)

        UI.Cinematic({ title = loc.label, sub = cfg.Year, skip = cfg.AllowSkip and L("cine_skip") or nil })
        if not state.skipped then waitFade(false, 1500) end

        -- aproximação com travagem progressiva
        local started = GetGameTimer()
        local closest = math.huge
        setSpeed(train, cfg.MaxSpeed)
        while not state.skipped do
            local d = #(flat(GetEntityCoords(train)) - flat(stopPos))
            closest = math.min(closest, d)
            local speed = math.min(cfg.MaxSpeed, d * cfg.Braking)
            if d <= cfg.StopRadius or speed < 0.4 or d > closest + 3.0 then break end
            setSpeed(train, math.max(speed, 1.0))
            if GetGameTimer() - started > cfg.Timeout then break end
            Wait(0)
        end
        setSpeed(train, 0.0)
        UI.Cinematic({})   -- esconde o cartão de título, mantém as barras

        if not state.skipped then Wait(1500) end

        -- personagem sai da carruagem mais próxima da plataforma
        local car = closestCarriage(train, exit)
        local carPos = GetEntityCoords(car)
        local dir = normalize(flat(vector3(exit.x - carPos.x, exit.y - carPos.y, 0.0)))
        local door = vector3(carPos.x + dir.x * 1.9, carPos.y + dir.y * 1.9, exit.z)
        local heading = headingTo(door, exit)

        SetEntityCoords(ped, door.x, door.y, door.z, false, false, false, false)
        SetEntityHeading(ped, heading)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true)
        final = vector4(exit.x, exit.y, exit.z, exit.w or heading)

        if not state.skipped then
            TaskGoStraightToCoord(ped, exit.x, exit.y, exit.z, 1.0, -1, heading, 0.5, 0)

            -- plano 2: de frente para a personagem, a partir da plataforma
            local cam2Pos = vector3(exit.x, exit.y, exit.z) + dir * 3.2 + vector3(0.0, 0.0, 0.7)
            local cam2 = makeCam(cam2Pos, 38.0)
            state.cams[#state.cams + 1] = cam2
            PointCamAtEntity(cam2, ped, 0.0, 0.0, 0.4, true)
            SetCamActiveWithInterp(cam2, cam1, 1800, 1, 1)

            local walkEnd = GetGameTimer() + cfg.WalkTime
            while GetGameTimer() < walkEnd and not state.skipped do Wait(0) end
        end
    end)

    if not ok then print(("^3[fks-character] chegada de comboio cancelada: %s^7"):format(tostring(err))) end

    -- limpeza (sempre)
    waitFade(true, 800)
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    if final then
        SetEntityCoords(ped, final.x, final.y, final.z, false, false, false, false)
        SetEntityHeading(ped, final.w)
    end
    for _, cam in ipairs(state.cams) do
        SetCamActive(cam, false)
        DestroyCam(cam, false)
    end
    RenderScriptCams(false, false, 0, true, true, 0)
    if state.train and DoesEntityExist(state.train) then
        invoke(NATIVE.DeleteMissionTrain, Citizen.PointerValueIntInitialized(state.train))
        if DoesEntityExist(state.train) then DeleteEntity(state.train) end
    end
    UI.Cinematic(false)
    state.running = false
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)
    Scene.SetExternalHud(true)

    if not opts.test then ServerCall("arrival:end") end
    return final
end

-- Ferramentas de configuração (apenas em DevMode)
if Config.DevMode then
    RegisterCommand("fks_arrival", function(_, args)
        local index = tonumber(args[1]) or 1
        CreateThread(function()
            local final = Arrival.Play(index, { test = true })
            DoScreenFadeIn(1000)
            print(("[fks-character] chegada %s: %s"):format(index, final and "ok" or "falhou (ver F8)"))
        end)
    end, false)

    RegisterCommand("fks_coords", function()
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        -- posição real do ped (centro do corpo), pronta a colar no config
        local line = ("vector4(%.2f, %.2f, %.2f, %.2f)"):format(c.x, c.y, c.z, GetEntityHeading(ped))
        print(line)
        TriggerEvent("chat:addMessage", { args = { "fks_coords", line } })
    end, false)

    -- Aponta a câmara para um sítio (ex.: o assento de uma cadeira) e devolve esse ponto exato
    RegisterCommand("fks_aim", function()
        local from = GetGameplayCamCoord()
        local rot = GetGameplayCamRot(2)
        local rx, rz = math.rad(rot.x), math.rad(rot.z)
        local dir = vector3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
        local to = from + dir * 15.0
        local ray = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, -1, PlayerPedId(), 0)
        local result, hit, pos
        local deadline = GetGameTimer() + 1000
        repeat
            Wait(0)
            result, hit, pos = GetShapeTestResult(ray)
        until result ~= 1 or GetGameTimer() > deadline
        if hit ~= 1 and hit ~= true then
            return TriggerEvent("chat:addMessage", { args = { "fks_aim", "não acertou em nada — aponta mais perto" } })
        end
        local line = ("vector3(%.2f, %.2f, %.2f),"):format(pos.x, pos.y, pos.z)
        print(line)
        TriggerEvent("chat:addMessage", { args = { "fks_aim", line } })
    end, false)

    -- Copia a câmara do jogo tal como a estás a ver (posição, rotação e zoom), pronta a colar
    RegisterCommand("fks_camcoords", function()
        local p = GetGameplayCamCoord()
        local r = GetGameplayCamRot(2)
        local line = ("camera = { pos = vector3(%.2f, %.2f, %.2f), rot = vector3(%.2f, %.2f, %.2f), fov = %.1f },")
            :format(p.x, p.y, p.z, r.x, r.y, r.z, GetGameplayCamFov())
        print(line)
        TriggerEvent("chat:addMessage", { args = { "fks_camcoords", line } })
    end, false)
end
