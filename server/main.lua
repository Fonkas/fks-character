-- Fluxo do servidor: abrir seleção, criar, selecionar, eliminar, renomear.

Sessions = {}
local debug = Characters.Debug

local function waitFor(predicate, timeout)
    local deadline = GetGameTimer() + timeout
    while not predicate() do
        if GetGameTimer() > deadline then return false end
        Wait(100)
    end
    return true
end

local function buildPayload(src)
    local list, map, user, identifier = Characters.GetActive(src)
    if not list then return nil end
    local today = Characters.Today()
    local summaries = {}
    for _, char in ipairs(list) do
        summaries[#summaries + 1] = Characters.Summary(char, map[char.charIdentifier].identity, today)
    end

    local spawns
    if Config.FirstSpawn.Enabled then
        spawns = {}
        for i, loc in ipairs(Config.FirstSpawn.Locations) do spawns[i] = loc.label end
    end

    local slots = Characters.GetSlots(src, user, identifier)
    return {
        characters = summaries,
        slots = slots,
        canDelete = Config.AllowCharacterDeletion,
        canRename = Config.AllowCharacterRenaming,
        today = today,
        spawns = spawns,
        autoSpawn = Config.AutoSpawnSingleCharacter and slots == 1 and #summaries == 1,
        -- modo Tebex: mostra um slot bloqueado para desbloquear com uma compra
        tebex = (Characters.TebexMode() and slots < Config.MaximumCharacterSlots)
            and { storeUrl = Config.Slots.Tebex.StoreUrl } or nil,
        kits = Kits and Kits.ForUI() or nil,
    }
end
BuildSelectionPayload = buildPayload

local function openSelection(src)
    src = tonumber(src)
    if not src or GetPlayerName(src) == nil then return end
    if Player(src).state.IsInSession then return debug("jogador já em sessão", src) end

    if not waitFor(function() return DB.Ready and Core.getUser(src) ~= nil end, 15000) then
        return print(("^1[fks-character] utilizador %s não carregou a tempo^7"):format(src))
    end

    -- As personagens do VORP são carregadas de forma assíncrona no playerJoining
    Wait(250)
    local payload = buildPayload(src)
    if not payload then return end

    Sessions[src] = { stage = "menu" }
    SetPlayerRoutingBucket(src, Config.Session.RoutingBucketOffset + src)
    TriggerClientEvent("fks-character:client:open", src, payload)
end

-- Eventos internos do vorp_core (TriggerEvent no servidor, não são net events)
AddEventHandler("vorp_CreateNewCharacter", openSelection)
AddEventHandler("vorp_character:server:GoToSelectionMenu", openSelection)
AddEventHandler("vorp_character:server:SpawnUniqueCharacter", openSelection)

-- Disparado pelo core quando uma personagem fica ativa
AddEventHandler("vorp:SelectedCharacter", function(src, character)
    local session = Sessions[src]
    if session and session.stage == "creating" and character then
        session.createdCharId = character.charIdentifier
    end
end)

AddEventHandler("playerDropped", function()
    Sessions[source] = nil
end)

local function getMenuSession(src)
    local session = Sessions[src]
    if not session or session.stage ~= "menu" then return nil end
    return session
end

local function resolveFirstSpawn(index)
    local locs = Config.FirstSpawn.Locations
    if #locs == 0 then return Config.Spawn.Fallback, nil end
    if Config.FirstSpawn.Enabled then
        index = tonumber(index)
        if not index or not locs[index] then return nil end
        return locs[index].coords, index
    end
    index = math.random(1, #locs)
    return locs[index].coords, index
end

local function fallbackCoords()
    local fb = Config.Spawn.Fallback
    return { x = fb.x, y = fb.y, z = fb.z }, fb.w
end

-- =====================================================================
--  RPC
-- =====================================================================

RPC.Register("refresh", function(src)
    if not Sessions[src] then return { ok = false, error = "err_generic" } end
    return { ok = true, payload = buildPayload(src) }
end, { cooldown = 300 })

RPC.Register("create", function(src, data)
    local session = getMenuSession(src)
    if not session then return { ok = false, error = "err_already_selected" } end
    if type(data) ~= "table" then return { ok = false, error = "err_generic" } end

    local identity, err = Validate.Identity(data.identity, Characters.Today())
    if not identity then return { ok = false, error = err } end

    local skin, comps = Validate.Appearance(identity.model, data.skin, data.comps)
    if not skin then return { ok = false, error = comps } end
    skin.Scale = Validate.HeightToScale(identity.height, identity.model)

    local spawn, spawnIndex = resolveFirstSpawn(data.spawn)
    if not spawn then return { ok = false, error = "err_spawn" } end

    local kit = nil
    if Kits.Enabled() then
        if not Kits.IsValid(data.kit) then return { ok = false, error = "err_kit" } end
        kit = data.kit
    end

    local list, _, user, identifier = Characters.GetActive(src)
    if not list then return { ok = false, error = "err_generic" } end
    if #list >= Characters.GetSlots(src, user, identifier) then
        return { ok = false, error = "err_slots" }
    end

    session.stage = "creating"
    session.createdCharId = nil

    user.addCharacter({
        firstname = identity.firstname,
        lastname = identity.lastname,
        skin = json.encode(skin),
        comps = json.encode(comps),
        compTints = "{}",
        age = identity.age,
        gender = identity.gender,
        charDescription = identity.biography ~= "" and identity.biography or "none",
        nickname = "none",
    })

    if not waitFor(function() return session.createdCharId ~= nil end, Config.Session.LoadTimeout) then
        session.stage = "menu"
        print(("^1[fks-character] criação de personagem expirou para %s^7"):format(src))
        return { ok = false, error = "err_timeout" }
    end

    local charId = session.createdCharId
    DB.InsertIdentity(charId, identifier, identity)
    session.stage = "done"
    session.arrival = Config.Arrival.Enabled and spawnIndex ~= nil
    if kit then Kits.Give(src, charId, kit) end

    Characters.Log("Personagem criada", ("**%s** (%s)\nPersonagem: %s %s (#%s)"):format(GetPlayerName(src), identifier, identity.firstname, identity.lastname, charId))
    debug("personagem criada", src, charId)

    -- Outros recursos (ex.: kits iniciais) escutam este evento do vorp_character
    SetTimeout(3000, function()
        TriggerEvent("vorp_NewCharacter", src)
        TriggerEvent("fks-character:server:characterCreated", src, charId)
    end)

    return {
        ok = true,
        charId = charId,
        skin = skin,
        comps = comps,
        coords = { x = spawn.x, y = spawn.y, z = spawn.z },
        heading = spawn.w,
        spawnIndex = session.arrival and spawnIndex or nil,
    }
end)

-- Chegada de comboio: o jogador fica sozinho numa sessão até a sequência acabar
RPC.Register("arrival:begin", function(src)
    local session = Sessions[src]
    if not session or session.stage ~= "done" or not session.arrival then return { ok = false } end
    SetPlayerRoutingBucket(src, Config.Session.RoutingBucketOffset + src)
    -- proteção: se o cliente nunca terminar a sequência, devolver ao mundo partilhado
    SetTimeout(Config.Arrival.Timeout + 20000, function()
        if Sessions[src] and Sessions[src].arrival then
            Sessions[src].arrival = false
            SetPlayerRoutingBucket(src, 0)
        end
    end)
    return { ok = true }
end, { cooldown = false })

RPC.Register("arrival:end", function(src)
    local session = Sessions[src]
    if not session or not session.arrival then return { ok = false } end
    session.arrival = false
    SetPlayerRoutingBucket(src, 0)
    return { ok = true }
end, { cooldown = false })

RPC.Register("select", function(src, data)
    local session = getMenuSession(src)
    if not session then return { ok = false, error = "err_already_selected" } end
    local charId = type(data) == "table" and tonumber(data.charId)
    if not charId then return { ok = false, error = "err_generic" } end

    local _, map, user = Characters.GetActive(src)
    local entry = map and map[charId]
    if not entry then return { ok = false, error = "err_not_owner" } end

    local summary = Characters.Summary(entry.char, entry.identity, Characters.Today())

    session.stage = "done"
    user.setUsedCharacter(charId)

    local coords, heading = summary.coords, summary.coords and summary.coords.heading
    local valid = Config.Spawn.UseLastPosition and type(coords) == "table"
        and tonumber(coords.x) and tonumber(coords.y) and tonumber(coords.z)
    if valid then
        coords = { x = tonumber(coords.x), y = tonumber(coords.y), z = tonumber(coords.z) }
        heading = tonumber(heading) or 0.0
    else
        coords, heading = fallbackCoords()
    end

    debug("personagem selecionada", src, charId)
    TriggerEvent("fks-character:server:characterSelected", src, charId)

    return {
        ok = true,
        charId = charId,
        skin = summary.skin,
        comps = summary.comps,
        coords = coords,
        heading = heading,
        isDead = summary.isDead,
    }
end)

local function normalizeName(s)
    return (tostring(s or ""):lower():gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

RPC.Register("delete", function(src, data)
    if not Config.AllowCharacterDeletion then return { ok = false, error = "err_delete_disabled" } end
    if not getMenuSession(src) then return { ok = false, error = "err_already_selected" } end
    local charId = type(data) == "table" and tonumber(data.charId)
    if not charId then return { ok = false, error = "err_generic" } end

    local _, map, user, identifier = Characters.GetActive(src)
    local entry = map and map[charId]
    if not entry then return { ok = false, error = "err_not_owner" } end

    local fullName = entry.char.firstname .. " " .. entry.char.lastname
    if normalizeName(data.confirm) ~= normalizeName(fullName) then
        return { ok = false, error = "err_delete_confirm" }
    end

    if Config.DeletionMode == "hard" then
        user.removeCharacter(charId)
        DB.HardDelete(charId)
    else
        DB.SoftDelete(charId, identifier, identifier)
    end

    Characters.Log("Personagem eliminada", ("**%s** (%s)\nPersonagem: %s (#%s)\nModo: %s"):format(GetPlayerName(src), identifier, fullName, charId, Config.DeletionMode))
    TriggerEvent("fks-character:server:characterDeleted", src, charId, Config.DeletionMode)

    return { ok = true, payload = buildPayload(src) }
end)

RPC.Register("rename", function(src, data)
    if not Config.AllowCharacterRenaming then return { ok = false, error = "err_rename_disabled" } end
    if not getMenuSession(src) then return { ok = false, error = "err_already_selected" } end
    if type(data) ~= "table" then return { ok = false, error = "err_generic" } end
    local charId = tonumber(data.charId)

    local _, map = Characters.GetActive(src)
    local entry = charId and map and map[charId]
    if not entry then return { ok = false, error = "err_not_owner" } end

    local first, err = Validate.Name(data.firstname, false)
    if not first then return { ok = false, error = err } end
    local last
    last, err = Validate.Name(data.lastname, true)
    if not last then return { ok = false, error = err } end

    entry.char.setFirstname(first)
    entry.char.setLastname(last)
    MySQL.update.await("UPDATE characters SET firstname = ?, lastname = ? WHERE charidentifier = ?", { first, last, charId })

    return { ok = true, payload = buildPayload(src) }
end)

-- =====================================================================
--  COMPATIBILIDADE vorp_character
-- =====================================================================

-- Recursos como o vorp_barbershop disparam vorpcharacter:savenew no cliente,
-- que por sua vez envia a aparência atualizada para aqui.
RegisterNetEvent("vorpcharacter:setPlayerCompChange", function(skin, comps)
    local src = source
    if not Player(src).state.IsInSession then return end
    local user = Core.getUser(src)
    if not user then return end
    local character = user.getUsedCharacter
    if not character or not character.updateSkin then return end

    if type(comps) == "table" then
        local encoded = json.encode(comps)
        if #encoded < 16384 then character.updateComps(encoded) end
    end
    if type(skin) == "table" and (skin.sex == "mp_male" or skin.sex == "mp_female") then
        local encoded = json.encode(skin)
        if #encoded < 16384 then character.updateSkin(encoded) end
    end
end)

RegisterNetEvent("vorpcharacter:reloadedskinlistener", function() end)

-- =====================================================================
--  EXPORTS
-- =====================================================================

exports("GetCharacterIdentity", function(charId)
    return MySQL.single.await(
        "SELECT charidentifier, identifier, DATE_FORMAT(birthdate, '%Y-%m-%d') AS birthdate, height, nationality, birthplace, biography FROM fks_characters WHERE charidentifier = ? AND deleted_at IS NULL",
        { charId })
end)

exports("GetCharacterSlots", function(src)
    local user, identifier = Characters.GetUser(src)
    if not user then return nil end
    return Characters.GetSlots(src, user, identifier)
end)

exports("OpenSelection", openSelection)

if Config.DevMode then
    RegisterCommand("fkschars", function(src)
        if src == 0 then return end
        Player(src).state:set("IsInSession", false, true)
        openSelection(src)
    end, false)
end
