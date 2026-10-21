Core = exports.vorp_core:GetCore()

Characters = {}

local function debug(...)
    if Config.Debug then print("[fks-character]", ...) end
end
Characters.Debug = debug

function Characters.Today()
    local now = os.date("*t")
    return { year = Config.Identity.RoleplayYear or now.year, month = now.month, day = now.day }
end

local function decode(value, default)
    if type(value) == "table" then return value end
    if type(value) ~= "string" or value == "" then return default end
    local ok, res = pcall(json.decode, value)
    if ok and type(res) == "table" then return res end
    return default
end

-- Junta as chaves em falta com os valores por defeito
local function normalizeSkin(skin)
    local model = skin.sex == "mp_female" and "mp_female" or "mp_male"
    local out = Appearance.DefaultSkin(model)
    for k, v in pairs(skin) do out[k] = v end
    out.sex = model
    if not out.Eyes or out.Eyes == 0 then
        out.Eyes = Catalog.Get(model).eyes[1]
    end
    return out
end

-- compPlayer (categoria -> hash) + compTints (categoria -> {[hash] = tints}) => categoria -> {comp, tint0..}
local function convertComps(comps, compTints)
    local out = {}
    for key, value in pairs(comps) do
        local hash = type(value) == "table" and value.comp or value
        hash = tonumber(hash) or -1
        local entry = { comp = hash, tint0 = 0, tint1 = 0, tint2 = 0, palette = 0 }
        local tints = compTints and compTints[key] and compTints[key][tostring(hash)]
        if tints then
            entry.tint0 = tints.tint0 or 0
            entry.tint1 = tints.tint1 or 0
            entry.tint2 = tints.tint2 or 0
            entry.palette = tints.palette or 0
        end
        out[key] = entry
    end
    return out
end

local function ageFromBirthdate(birthdate, today)
    if not birthdate then return nil end
    local y, m, d = birthdate:match("^(%d+)-(%d+)-(%d+)$")
    if not y then return nil end
    return Validate.Age(tonumber(d), tonumber(m), tonumber(y), today)
end

function Characters.GetUser(src)
    local user = Core.getUser(src)
    if not user then return nil end
    return user, user.getIdentifier()
end

-- Personagens ativas do jogador (exclui soft-deleted)
-- Devolve: lista (ordenada por charIdentifier), mapa charId -> objeto VORP
function Characters.GetActive(src)
    local user, identifier = Characters.GetUser(src)
    if not user then return nil end

    local identities = DB.GetIdentities(identifier)
    local list, map = {}, {}
    for _, char in pairs(user.getUserCharacters) do
        local id = identities[char.charIdentifier]
        if not (id and id.deleted) then
            list[#list + 1] = char
            map[char.charIdentifier] = { char = char, identity = id }
        end
    end
    table.sort(list, function(a, b) return a.charIdentifier < b.charIdentifier end)
    return list, map, user, identifier
end

function Characters.TebexMode()
    return Config.Slots and Config.Slots.Mode == "tebex"
end

function Characters.GetSlots(src, user, identifier)
    local base
    if Characters.TebexMode() then
        base = Config.Slots.Tebex.FreeSlots or 1
    else
        base = Config.DefaultCharacterSlots
        if Config.UseVorpCharPerm then
            base = math.max(base, tonumber(user.getCharperm) or 0)
        end
    end
    local extra = DB.GetExtraSlots(identifier)
    for ace, amount in pairs(Config.SlotPermissions or {}) do
        if IsPlayerAceAllowed(src, ace) then extra = extra + amount end
    end
    return math.max(1, math.min(base + extra, Config.MaximumCharacterSlots))
end

-- Resumo enviado à NUI / cliente
function Characters.Summary(char, identity, today)
    local skin = normalizeSkin(decode(char.skin, {}))
    local comps = convertComps(decode(char.comps, {}), decode(char.compTints, {}))
    local coords = decode(char.coords, {})
    local age = identity and ageFromBirthdate(identity.birthdate, today) or tonumber(char.age)

    local summary = {
        charId = char.charIdentifier,
        firstname = char.firstname,
        lastname = char.lastname,
        age = age,
        gender = skin.sex == "mp_female" and "female" or "male",
        model = skin.sex,
        job = Config.Selection.ShowJob and (char.jobLabel or char.job) or nil,
        birthdate = identity and identity.birthdate or nil,
        nationality = identity and identity.nationality or nil,
        height = identity and identity.height or nil,
        isDead = char.isdead == true or char.isdead == 1,
        skin = skin,
        comps = comps,
        coords = coords,
    }
    if Config.Selection.ShowMoney then summary.money = char.money end
    if Config.Selection.ShowGold then summary.gold = char.gold end
    return summary
end

function Characters.IsAdmin(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, Config.AdminAce) then return true end
    local user = Core.getUser(src)
    if user then
        local group = user.getGroup
        for _, g in ipairs(Config.AdminGroups) do
            if g == group then return true end
        end
    end
    return false
end

function Characters.Log(title, description)
    if Config.Logs.Webhook == "" then return end
    Core.AddWebhook(title, Config.Logs.Webhook, description)
end
