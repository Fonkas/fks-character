-- /skinmenu [id] — um admin reabre o criador de aparência para a personagem ativa de um jogador
-- (sem CK nem criar personagem nova). A identidade e o género não mudam.

local Edits = {}  -- src -> { charId, model, comps (estrutura antiga), by }

local function decode(value)
    if type(value) == "table" then return value end
    local ok, res = pcall(json.decode, value or "")
    return ok and type(res) == "table" and res or {}
end

local function reply(src, msg)
    if src == 0 then print("[fks-character] " .. msg) else Core.NotifyRightTip(src, msg, 5000) end
end

RegisterCommand(Config.SkinMenuCommand or "skinmenu", function(src, args)
    if not Characters.IsAdmin(src) then return reply(src, L("adm_no_perm")) end
    local target = tonumber(args[1]) or src
    if target == 0 or GetPlayerName(target) == nil then return reply(src, L("adm_not_found")) end
    if not Player(target).state.IsInSession then return reply(src, L("adm_not_in_session")) end
    if Edits[target] then return reply(src, L("adm_skin_busy")) end

    local user = Core.getUser(target)
    local char = user and user.getUsedCharacter
    if not char or not char.charIdentifier then return reply(src, L("adm_not_found")) end

    local skin = decode(char.skin)
    local model = skin.sex == "mp_female" and "mp_female" or "mp_male"
    local comps = decode(char.comps)

    -- mesma conversão que a seleção usa (com tints)
    local summary = Characters.Summary(char, nil, Characters.Today())
    local height = DB.GetHeight(char.charIdentifier) or Config.Identity.DefaultHeight

    Edits[target] = { charId = char.charIdentifier, model = model, comps = comps, by = src }
    SetPlayerRoutingBucket(target, Config.Session.RoutingBucketOffset + target)
    TriggerClientEvent("fks-character:client:skinMenu", target, {
        skin = summary.skin, comps = summary.comps, height = height, model = model,
    })
    reply(src, L("adm_skin_opened", GetPlayerName(target)))
    Characters.Log("Skin menu", ("%s abriu o skin menu a %s (personagem #%s)"):format(
        src == 0 and "consola" or GetPlayerName(src), GetPlayerName(target), char.charIdentifier))
end, false)

RPC.Register("skinmenu:save", function(src, data)
    local edit = Edits[src]
    if not edit or type(data) ~= "table" then return { ok = false, error = "err_generic" } end
    local user, identifier = Characters.GetUser(src)
    local char = user and user.getUsedCharacter
    if not char or char.charIdentifier ~= edit.charId then return { ok = false, error = "err_not_owner" } end

    local skin, clean = Validate.Appearance(edit.model, data.skin, data.comps)
    if not skin then return { ok = false, error = clean } end

    local id = Config.Identity
    local height = math.floor(tonumber(data.height) or id.DefaultHeight)
    if height < id.MinHeight or height > id.MaxHeight then return { ok = false, error = "err_height" } end
    skin.Scale = Validate.HeightToScale(height, edit.model)

    -- só as categorias do criador são substituídas; o resto da roupa mantém-se
    local merged = {}
    for k, v in pairs(edit.comps) do merged[k] = type(v) == "table" and v.comp or v end
    for _, cat in ipairs(Catalog.StarterCategories(edit.model)) do merged[cat.key] = clean[cat.key] end
    merged.Teeth = clean.Teeth

    char.updateSkin(json.encode(skin))
    char.updateComps(json.encode(merged))
    DB.SetHeight(edit.charId, identifier, height)

    Edits[src] = nil
    SetPlayerRoutingBucket(src, 0)
    Characters.Log("Skin menu", ("%s guardou nova aparência (personagem #%s)"):format(GetPlayerName(src), edit.charId))
    return { ok = true, skin = skin, comps = merged }
end)

RPC.Register("skinmenu:cancel", function(src)
    if not Edits[src] then return { ok = false } end
    Edits[src] = nil
    SetPlayerRoutingBucket(src, 0)
    return { ok = true }
end)

AddEventHandler("playerDropped", function()
    Edits[source] = nil
end)
