-- Menu multicharacter: pré-visualização das personagens e ações.

Selection = { payload = nil, current = nil, busy = false }

local peds = {}           -- charId -> { ped, spot = vector4 }
local overviewCam = nil   -- câmara fixa que vê a mesa toda
local activeSeats = nil   -- cadeiras usadas (detetadas ou do config)

local function stopOverview()
    if overviewCam then
        SetCamActive(overviewCam, false)
        DestroyCam(overviewCam, false)
        overviewCam = nil
        RenderScriptCams(false, false, 0, true, true, 0)
    end
end

local function startOverview()
    if overviewCam then return end
    -- usa exatamente a posição/rotação/zoom copiados com /fks_camcoords
    local c = Config.SelectionScene.camera
    overviewCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", c.pos.x, c.pos.y, c.pos.z,
        c.rot.x, c.rot.y, c.rot.z, c.fov or 50.0, false, 2)
    SetCamActive(overviewCam, true)
    RenderScriptCams(true, false, 0, true, true, 0)
end

local function findChar(charId)
    for _, c in ipairs(Selection.payload and Selection.payload.characters or {}) do
        if c.charId == charId then return c end
    end
end

local function deletePeds()
    stopOverview()
    Scene.lightPed = nil
    for id, entry in pairs(peds) do
        Look.Release(entry.ped)
        if DoesEntityExist(entry.ped) then DeleteEntity(entry.ped) end
        peds[id] = nil
    end
end
Selection.DeletePeds = deletePeds

-- Cria a personagem sentada na cadeira `index` (ou de pé, se não houver cadeiras suficientes)
local function spawnSeated(char, index)
    if peds[char.charId] and DoesEntityExist(peds[char.charId].ped) then return peds[char.charId] end
    local cfg = Config.SelectionScene
    local seat = (activeSeats or cfg.seats)[index]
    -- cadeira dada só como posição (/fks_aim): fica virada para o centro da mesa
    if seat and type(seat) == "vector3" then
        -- centro da mesa = média das cadeiras (mais exato do que um ponto fixo)
        local list = activeSeats or cfg.seats
        local sx, sy, n = 0.0, 0.0, 0
        for _, s in ipairs(list) do sx, sy, n = sx + s.x, sy + s.y, n + 1 end
        local t = n > 1 and vector3(sx / n, sy / n, seat.z) or (cfg.autoChairs and cfg.autoChairs.table) or seat
        local heading = math.deg(math.atan(seat.x - t.x, t.y - seat.y)) % 360.0
        seat = vector4(seat.x, seat.y, seat.z, heading)
    end
    local spot = seat or cfg.standing
    local model = N.LoadModel(char.model)
    if not model then return nil end
    local ped = CreatePed(model, spot.x, spot.y, spot.z, spot.w, false, false, false, false)
    local deadline = GetGameTimer() + 5000
    repeat Wait(0) until DoesEntityExist(ped) or GetGameTimer() > deadline
    if not DoesEntityExist(ped) then return nil end
    SetModelAsNoLongerNeeded(model)

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)

    -- cópia para não alterar os dados originais (fillDefaults altera a tabela)
    local skin = json.decode(json.encode(char.skin))
    Look.Apply(ped, skin, char.comps)
    if seat then
        -- não deixar duas personagens ficarem na mesma cadeira
        local taken = {}
        for _, other in pairs(peds) do taken[#taken + 1] = GetEntityCoords(other.ped) end
        Scene.SitAt(ped, seat, cfg.seatScenarios[char.model], taken)
        -- o ponto real da cadeira pode estar ligeiramente diferente: a câmara usa a pose final
        local c = GetEntityCoords(ped)
        spot = vector4(c.x, c.y, c.z, GetEntityHeading(ped))
    else
        SetEntityHeading(ped, spot.w)
    end
    peds[char.charId] = { ped = ped, spot = spot }
    return peds[char.charId]
end

-- Procura as cadeiras reais à volta da mesa (Config.SelectionScene.autoChairs).
-- Devolve uma lista de vector4: posição da cadeira + heading virado para a mesa.
local function findChairs()
    local cfg = Config.SelectionScene.autoChairs
    if not cfg or not cfg.enabled then return nil end
    local ok, pool = pcall(GetGamePool, "CObject")
    if not ok or type(pool) ~= "table" then return nil end
    local t = cfg.table
    local found = {}
    for _, obj in ipairs(pool) do
        local p = GetEntityCoords(obj)
        local dx, dy = p.x - t.x, p.y - t.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d >= cfg.minDistance and d <= cfg.maxDistance and math.abs(p.z - t.z) <= cfg.maxHeight then
            -- quem se senta fica virado para o centro da mesa
            local heading = math.deg(math.atan(dx, -dy)) % 360.0
            found[#found + 1] = { pos = vector4(p.x, p.y, p.z, heading), angle = math.atan(dy, dx) }
        end
    end
    -- ordem estável à volta da mesa
    table.sort(found, function(a, b) return a.angle < b.angle end)
    local seats = {}
    for _, f in ipairs(found) do seats[#seats + 1] = f.pos end
    if Config.Debug then print(("[fks-character] cadeiras encontradas: %d"):format(#seats)) end
    return seats
end


local function spawnAll()
    local chairs = findChairs()
    local needed = #Selection.payload.characters
    activeSeats = (chairs and #chairs >= math.min(needed, 4)) and chairs or Config.SelectionScene.seats
    for i, char in ipairs(Selection.payload.characters) do spawnSeated(char, i) end
end

local function showPreview(charId)
    local char = findChar(charId)
    if not char then return end
    local entry = peds[charId] or spawnSeated(char, #Selection.payload.characters)
    if not entry then return UI.Error("err_load") end

    -- câmara fixa com a mesa toda; a escolhida fica com a luz por cima
    startOverview()
    Scene.lightPed = entry.ped
    PlaySoundFrontend("Ready_Up_Flash", "RDRO_In_Game_Menu_Sounds", true, 0)
    Selection.current = charId
end

-- Dados para a NUI (sem skin/comps, que só interessam ao Lua)
local function uiCharacters()
    local out = {}
    for _, c in ipairs(Selection.payload.characters) do
        out[#out + 1] = {
            charId = Config.Selection.ShowCharId and c.charId or nil, key = c.charId,
            firstname = c.firstname, lastname = c.lastname, age = c.age, gender = c.gender,
            job = c.job, money = c.money, gold = c.gold, birthdate = c.birthdate,
            nationality = c.nationality, isDead = c.isDead,
        }
    end
    return out
end

local function pushToUI()
    UI.Send("selection", {
        characters = uiCharacters(),
        slots = Selection.payload.slots,
        canDelete = Selection.payload.canDelete,
        canRename = Selection.payload.canRename,
        tebex = Selection.payload.tebex,
        selected = Selection.current,
    })
end

function Selection.Open(payload)
    Selection.payload = payload
    Selection.busy = false
    Today = payload.today

    if #payload.characters == 0 then
        return Creator.Open({ firstCharacter = true })
    end

    if payload.autoSpawn then
        return Selection.Play(payload.characters[1].charId)
    end

    if not IsScreenFadedOut() then
        DoScreenFadeOut(500)
        repeat Wait(0) until IsScreenFadedOut()
    end
    N.Spinner(L("sel_loading"))
    Scene.Enter("selection")
    Scene.HidePlayer()  -- ao voltar do criador o jogador ainda está visível no palco
    spawnAll()
    showPreview(Selection.current and findChar(Selection.current) and Selection.current or payload.characters[1].charId)
    BusyspinnerOff()
    Wait(500)
    DoScreenFadeIn(1500)

    pushToUI()
    UI.Focus(true)
end

-- Voltar à seleção (ex.: cancelar o criador)
function Selection.Return()
    local res = ServerCall("refresh")
    if res and res.ok and res.payload then
        Selection.Open(res.payload)
    elseif Selection.payload then
        Selection.Open(Selection.payload)
    end
end

-- Aplica personagem ao jogador e entrega o controlo ao vorp_core
function LoadCharacterIntoWorld(res, isNew)
    local ped
    local finished = false
    local success = false

    -- Guarda contra carregamentos que bloqueiem (modelo ou streaming)
    SetTimeout(Config.Session.LoadTimeout, function()
        if not finished then
            finished = true
            print("^1[fks-character] carregamento da personagem expirou^7")
        end
    end)

    local model = N.LoadModel(res.skin.sex)
    if model and not finished then
        SetPlayerModel(PlayerId(), model, false)
        SetModelAsNoLongerNeeded(model)
        ped = PlayerPedId()
        N.WaitReady(ped)
        CurrentSkin = res.skin
        CurrentComps = {}
        for k, v in pairs(res.comps) do
            CurrentComps[k] = type(v) == "table" and v or { comp = v, tint0 = 0, tint1 = 0, tint2 = 0, palette = 0 }
        end
        Look.Apply(ped, CurrentSkin, CurrentComps)
        SetAttributeCoreValue(ped, 0, 100)
        SetAttributeCoreValue(ped, 1, 100)
        success = not finished
    end
    finished = true

    -- Personagem nova: senta-se, pose, foto a preto e branco
    UI.Send("close")
    UI.Focus(false)
    if isNew and success then Photo.Play(PlayerPedId()) end

    Cam.Stop()
    deletePeds()
    Creator.Cleanup()
    Scene.Leave()
    Look.ReleaseAll(PlayerPedId())
    UI.Send("close")
    UI.Focus(false)
    CharId = res.charId

    if not success then
        -- mesmo assim entregamos ao core para não deixar o jogador preso
        print("^3[fks-character] a continuar com aparência parcial^7")
    end

    local c, heading = res.coords, res.heading or 0.0

    -- Personagem nova: comboio a chegar à estação escolhida
    if isNew and res.spawnIndex then
        local final = Arrival.Play(res.spawnIndex)
        if final then
            c, heading = { x = final.x, y = final.y, z = final.z }, final.w
        end
    end

    Scene.SetExternalHud(true)
    TriggerEvent("vorp:initCharacter", vector3(c.x, c.y, c.z), heading + 0.0, res.isDead == true)
    TriggerEvent("fks-character:client:characterLoaded", res.charId, isNew == true)
end

function Selection.Play(charId)
    if Selection.busy then return { ok = false, error = "err_busy" } end
    Selection.busy = true
    UI.Send("loading", { text = L("sel_loading") })

    local res = ServerCall("select", { charId = charId })
    if not res or not res.ok then
        Selection.busy = false
        UI.Send("loading", false)
        return res or { ok = false, error = "err_generic" }
    end

    AnimpostfxPlay("RespawnPulse01")
    PlaySoundFrontend("Ready_Up_Flash", "RDRO_In_Game_Menu_Sounds", true, 0)
    DoScreenFadeOut(1000)
    repeat Wait(0) until IsScreenFadedOut()
    LoadCharacterIntoWorld(res, false)
    return { ok = true }
end

-- =====================================================================
--  NUI
-- =====================================================================

UI.On("sel:preview", function(data)
    local charId = tonumber(data.key)
    if not charId or charId == Selection.current or Selection.busy then return { ok = true } end
    showPreview(charId)
    return { ok = true }
end)

UI.On("sel:play", function(data)
    local charId = tonumber(data.key)
    if not charId then return { ok = false, error = "err_generic" } end
    return Selection.Play(charId)
end)

UI.On("sel:create", function()
    if Selection.busy then return { ok = false, error = "err_busy" } end
    if #Selection.payload.characters >= Selection.payload.slots then return { ok = false, error = "err_slots" } end
    Selection.busy = true
    UI.Send("close")
    UI.Focus(false)
    DoScreenFadeOut(800)
    repeat Wait(0) until IsScreenFadedOut()
    Cam.Stop()
    deletePeds()
    Selection.busy = false
    Creator.Open({ firstCharacter = false })
    return { ok = true }
end)

local function applyPayload(res)
    if not res or not res.ok then return res or { ok = false, error = "err_generic" } end
    Selection.payload = res.payload
    -- remover peds de personagens que já não existem
    for id, entry in pairs(peds) do
        if not findChar(id) then
            Look.Release(entry.ped)
            DeleteEntity(entry.ped)
            peds[id] = nil
        end
    end
    if #res.payload.characters == 0 then
        UI.Send("close")
        UI.Focus(false)
        DoScreenFadeOut(800)
        repeat Wait(0) until IsScreenFadedOut()
        Cam.Stop()
        deletePeds()
        Creator.Open({ firstCharacter = true })
        return { ok = true }
    end
    if not findChar(Selection.current) then
        showPreview(res.payload.characters[1].charId)
    end
    pushToUI()
    return { ok = true }
end

UI.On("sel:delete", function(data)
    if Selection.busy then return { ok = false, error = "err_busy" } end
    local res = ServerCall("delete", { charId = tonumber(data.key), confirm = tostring(data.confirm or "") })
    if res and res.ok then
        PlaySoundFrontend("TITLE_SCREEN_EXIT", "DEATH_FAIL_RESPAWN_SOUNDS", true, 0)
    end
    return applyPayload(res)
end)

UI.On("sel:tebex", function(data)
    if Selection.busy then return { ok = false, error = "err_busy" } end
    local res = ServerCall("tebex:redeem", { code = tostring(data.code or "") }, 20000)
    if res and res.ok then
        PlaySoundFrontend("Ready_Up_Flash", "RDRO_In_Game_Menu_Sounds", true, 0)
        UI.Send("toast", { type = "info", text = L("tebex_ok", res.slots or 1) })
    end
    return applyPayload(res)
end)

UI.On("sel:rename", function(data)
    if Selection.busy then return { ok = false, error = "err_busy" } end
    local res = ServerCall("rename", { charId = tonumber(data.key), firstname = data.firstname, lastname = data.lastname })
    return applyPayload(res)
end)
