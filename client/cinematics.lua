-- Momentos cinematográficos do criador:
--   Intro.Play()  -> NPC fala, homem e mulher entram e param à frente; TAB alterna, ENTER escolhe.
--   Photo.Play()  -> no fim, a personagem senta-se, imagem a preto e branco, "tira um printscreen".

Intro, Photo = {}, {}

local KEY = {
    toggle = joaat("INPUT_CREATOR_MENU_TOGGLE"),  -- TAB
    accept = joaat("INPUT_CREATOR_ACCEPT"),       -- ENTER
    left = joaat("INPUT_FRONTEND_LEFT"),
    right = joaat("INPUT_FRONTEND_RIGHT"),
    frontAccept = joaat("INPUT_FRONTEND_ACCEPT"),
}

local function pressed(...)
    for _, k in ipairs({ ... }) do
        if IsDisabledControlJustPressed(0, k) then return true end
    end
    return false
end

local function forward(h)
    local r = math.rad(h)
    return vector3(-math.sin(r), math.cos(r), 0.0)
end

local function fade(out, ms)
    if out then DoScreenFadeOut(ms) else DoScreenFadeIn(ms) end
    local deadline = GetGameTimer() + ms + 1000
    repeat Wait(0) until (out and IsScreenFadedOut() or (not out and IsScreenFadedIn())) or GetGameTimer() > deadline
end

local function spawnPed(model, pos, heading)
    local hash = N.LoadModel(model)
    if not hash then return nil end
    local ped = CreatePed(hash, pos.x, pos.y, pos.z, heading or 0.0, false, false, false, false)
    local deadline = GetGameTimer() + 5000
    repeat Wait(0) until DoesEntityExist(ped) or GetGameTimer() > deadline
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return nil end
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    return ped
end

-- Fala ambiente do jogo (opcional). Se a voz do modelo não tiver a linha, não acontece nada.
local function speak(ped, line)
    if not line or not DataView then return end
    pcall(function()
        local buf = DataView.ArrayBuffer(128)
        buf:SetInt64(0, CreateVarString(10, "LITERAL_STRING", line))
        buf:SetInt64(8, CreateVarString(10, "LITERAL_STRING", ""))
        buf:SetInt32(16, 1)
        buf:SetInt32(24, joaat("speech_params_force"))
        buf:SetInt32(32, 0)
        buf:SetInt32(40, 1)
        buf:SetInt32(48, 1)
        buf:SetInt32(56, 1)
        Citizen.InvokeNative(0x8E04FEDD28D42462, ped, buf:Buffer()) -- PLAY_PED_AMBIENT_SPEECH_NATIVE
    end)
end

-- Escolha feita pela NUI (TAB/setas/rato e ENTER/clique) — ver UI.On("intro:*") abaixo
local choice = { active = false, sel = 1, confirmed = false }

local function camAt(point, eyeHeight, fov)
    local cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", point.x, point.y, point.z + eyeHeight,
        0.0, 0.0, point.w, fov or 45.0, false, 2)
    return cam
end

-- Devolve "mp_male" / "mp_female" (ou nil se a intro estiver desligada / falhar)
function Intro.Play()
    local cfg = Config.CreatorScene.Intro
    if not cfg or not cfg.Enabled then return nil end
    local eye = cfg.eyeHeight or 0.65
    local spawned, cams = {}, {}
    local chosen = nil

    local ok, err = pcall(function()
        -- Plano 1: o NPC a falar
        local talkCam = camAt(cfg.talkCam, eye, 45.0)
        cams[#cams + 1] = talkCam
        SetCamActive(talkCam, true)
        RenderScriptCams(true, false, 0, true, true, 0)

        local npc
        if cfg.npc and cfg.npc.model then
            local c = cfg.npc.coords
            -- aceita um modelo ou uma lista (usa o primeiro que existir)
            local models = type(cfg.npc.model) == "table" and cfg.npc.model or { cfg.npc.model }
            for _, m in ipairs(models) do
                if IsModelValid(joaat(m)) then
                    npc = spawnPed(m, c, c.w)
                    if npc then break end
                end
            end
            if not npc then print("^3[fks-character] nenhum modelo de NPC válido em Config.CreatorScene.Intro.npc.model^7") end
            if npc then
                spawned[#spawned + 1] = npc
                -- sem roupa aplicada os peds de script ficam invisíveis no RDR3
                Citizen.InvokeNative(0x283978A15512B2FE, npc, true) -- _SET_RANDOM_OUTFIT_VARIATION
                N.UpdateVariation(npc)
                if cfg.npc.scenario then
                    Citizen.InvokeNative(0x524B54361229154F, npc, joaat(cfg.npc.scenario), -1, false, 0, -1.0, 0)
                end
            end
        end

        -- Homem e mulher: já parados lado a lado no ponto da escolha (coupleStand)
        local st = cfg.coupleStand
        local right = vector3(math.cos(math.rad(st.w)), math.sin(math.rad(st.w)), 0.0)
        local half = (cfg.coupleSpread or 0.9) / 2
        local offsets = { mp_male = -half, mp_female = half }
        local couple = {}
        for model, off in pairs(offsets) do
            local pos = vector3(st.x, st.y, st.z) + right * off
            local ped = spawnPed(model, pos, st.w)
            if ped then
                spawned[#spawned + 1] = ped
                local skin, comps = Creator.DefaultLook(model)
                local look = {}
                for k, v in pairs(comps) do if v ~= -1 then look[k] = { comp = v } end end
                Look.Apply(ped, skin, look)
                couple[model] = ped
            end
        end

        -- assentar todos no chão ANTES de o ecrã abrir (senão vê-se o ped a cair)
        for _, ped in ipairs(spawned) do
            PlaceEntityOnGroundProperly(ped)
            FreezeEntityPosition(ped, false)
        end
        Wait(cfg.settleTime or 800)
        for model, ped in pairs(couple) do SetEntityHeading(ped, st.w) end
        if npc then SetEntityHeading(npc, cfg.npc.coords.w) end

        fade(false, 1200)

        for _, line in ipairs(cfg.lines or {}) do
            UI.Send("subtitle", { text = L(line.text) })  -- chave de tradução ou texto direto
            if npc then speak(npc, line.speech) end
            local untilT = GetGameTimer() + (line.time or 4000)
            while GetGameTimer() < untilT do
                if cfg.Skippable and pressed(KEY.accept, KEY.frontAccept) then break end
                Wait(0)
            end
        end
        UI.Send("subtitle", false)

        -- Plano 2: vira-se para o homem e a mulher
        local doorCam = camAt(cfg.coupleCam, eye, 42.0)
        cams[#cams + 1] = doorCam
        SetCamActiveWithInterp(doorCam, talkCam, cfg.turnTime or 1800, 1, 1)
        Wait(cfg.turnTime or 1800)

        -- Escolha: uma câmara a apontar para cada um, alternando com interpolação
        local order = { "mp_male", "mp_female" }
        local aimCams = {}
        for i, model in ipairs(order) do
            local c = camAt(cfg.coupleCam, eye, cfg.chooseFov or 30.0)
            if couple[model] then PointCamAtEntity(c, couple[model], 0.0, 0.0, 0.3, true) end
            aimCams[i] = c
            cams[#cams + 1] = c
        end

        choice.active, choice.sel, choice.confirmed = true, 1, false
        local current = doorCam
        local shown = 0
        UI.Focus(true)
        while not choice.confirmed do
            -- teclas do jogo como reserva (se o foco da NUI falhar)
            if pressed(KEY.toggle, KEY.left, KEY.right) then choice.sel = choice.sel == 1 and 2 or 1 end
            if pressed(KEY.accept, KEY.frontAccept) then choice.confirmed = true end
            if shown ~= choice.sel then
                if shown ~= 0 then
                    PlaySoundFrontend(choice.sel == 1 and "gender_left" or "gender_right", "RDRO_Character_Creator_Sounds", true, 0)
                end
                SetCamActiveWithInterp(aimCams[choice.sel], current, 700, 1, 1)
                current = aimCams[choice.sel]
                shown = choice.sel
                UI.Send("choose", { on = true, selected = order[choice.sel] })
            end
            Wait(0)
        end
        UI.Focus(false)
        PlaySoundFrontend("SELECT", "RDRO_Character_Creator_Sounds", true, 0)
        chosen = order[choice.sel]
        UI.Send("choose", { on = false })
        fade(true, 700)
    end)

    choice.active = false
    UI.Focus(false)
    if not ok then print(("^3[fks-character] intro cancelada: %s^7"):format(tostring(err))) end
    UI.Send("subtitle", false)
    UI.Send("choose", { on = false })
    if not IsScreenFadedOut() then fade(true, 400) end
    for _, ped in ipairs(spawned) do
        Look.Release(ped)
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    for _, cam in ipairs(cams) do
        SetCamActive(cam, false)
        DestroyCam(cam, false)
    end
    RenderScriptCams(false, false, 0, true, true, 0)
    return chosen
end

UI.On("intro:select", function(data)
    if not choice.active then return { ok = false } end
    choice.sel = data.model == "mp_female" and 2 or 1
    return { ok = true }
end)

UI.On("intro:toggle", function()
    if not choice.active then return { ok = false } end
    choice.sel = choice.sel == 1 and 2 or 1
    return { ok = true }
end)

UI.On("intro:confirm", function()
    if not choice.active then return { ok = false } end
    choice.confirmed = true
    return { ok = true }
end)

-- Pose final na cadeira + efeito de foto
function Photo.Play(ped)
    local cfg = Config.CreatorScene.Photo
    if not cfg or not cfg.Enabled then return end
    if not IsScreenFadedOut() then fade(true, 600) end
    -- o vorp/fks-hud voltam a mostrar o HUD quando a personagem fica ativa
    Scene.SetExternalHud(false)

    local ok, err = pcall(function()
        local model = GetEntityModel(ped) == joaat("mp_female") and "mp_female" or "mp_male"
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true)
        Scene.lightPed = ped
        Scene.lightFront = cfg.frontLight ~= false

        local heading
        if cfg.pose == "stand" then
            -- de pé, virada para a câmara
            ClearPedTasksImmediately(ped)
            SetEntityCoords(ped, cfg.seat.x, cfg.seat.y, cfg.seat.z + 1.0, false, false, false, false)
            PlaceEntityOnGroundProperly(ped)
            SetEntityHeading(ped, cfg.seat.w)
            heading = cfg.seat.w
        else
            Scene.SitAt(ped, cfg.seat, cfg.scenarios[model], nil, cfg.searchRadius or 1.0)
            heading = GetEntityHeading(ped)
        end

        -- proteção: se a personagem não ficou junto ao banco (ex.: caiu do interior), fica de pé ali
        Wait(300)
        if #(GetEntityCoords(ped) - vector3(cfg.seat.x, cfg.seat.y, cfg.seat.z)) > 2.0 then
            print("^3[fks-character] foto: a personagem saiu do sítio, a usar pose de pé^7")
            ClearPedTasksImmediately(ped)
            SetEntityCoords(ped, cfg.seat.x, cfg.seat.y, cfg.seat.z + 1.0, false, false, false, false)
            PlaceEntityOnGroundProperly(ped)
            SetEntityHeading(ped, cfg.seat.w)
            heading = cfg.seat.w
        end

        if Cam.IsActive() then
            Cam.Focus(ped, heading, "photo")
        else
            Cam.Start(ped, cfg.seat, heading, "photo", { rotatePed = false })
        end
        Wait(900)

        -- a personagem olha para a lente
        local c = Cam.GetCoord()
        if c and cfg.lookAtCamera ~= false then
            pcall(TaskLookAtCoord, ped, c.x, c.y, c.z, -1, 0, 51, false)
        end
        Wait(400)

        if cfg.effect then AnimpostfxPlay(cfg.effect) end
        Scene.SetExternalHud(false)
        fade(false, 1200)
        PlaySoundFrontend("Ready_Up_Flash", "RDRO_In_Game_Menu_Sounds", true, 0)
        local total = cfg.time or 20000
        UI.Send("photo", { on = true, seconds = math.floor(total / 1000) })

        local untilT = GetGameTimer() + total
        Wait(1500) -- evita saltar com o mesmo ENTER que criou a personagem
        while GetGameTimer() < untilT do
            if pressed(KEY.accept, KEY.frontAccept) then break end
            Wait(0)
        end
    end)
    if not ok then print(("^3[fks-character] momento da foto cancelado: %s^7"):format(tostring(err))) end

    UI.Send("photo", { on = false })
    fade(true, 800)
    if cfg.effect then AnimpostfxStop(cfg.effect) end
    pcall(TaskClearLookAt, ped)
    ClearPedTasksImmediately(ped)
end
