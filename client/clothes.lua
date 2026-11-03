-- Tirar / vestir peças de roupa com comandos (/hat, /jacket, /shirt, ...) e mudar o estilo
-- (/sleeves, /collar, /bootstyle, /bandana). Ver Config.ClothingCommands.
-- Só muda o que se vê: a roupa guardada da personagem não é alterada (as lojas continuam a gravar a roupa toda).

Clothes = {}

local hidden = {}    -- chave vorp (ex.: "Hat") -> true enquanto está tirada
local styles = {}    -- estilo ("sleeves", "collar", "boots", "bandana") -> true enquanto está ativo
local lastUse = 0

local BASE = joaat("base")
local SHIRT_STATES = {      -- 1 = mangas arregaçadas, 2 = gola aberta
    [0] = joaat("base"),
    [1] = joaat("closed_collar_rolled_sleeve"),
    [2] = joaat("open_collar_full_sleeve"),
    [3] = joaat("open_collar_rolled_sleeve"),
}

-- estilo -> peça que muda e estado quando está ativo
local STYLES = {
    sleeves = { key = "Shirt" },
    collar  = { key = "Shirt" },
    boots   = { key = "Boots", state = joaat("under_pants") },  -- calças por cima das botas
    bandana = { key = "NeckWear", state = joaat("mask_up") },   -- lenço na cara
}
local STYLED_KEYS = { "Shirt", "Boots", "NeckWear" }

local function u32(v) return math.tointeger(v) and (math.tointeger(v) & 0xFFFFFFFF) or v end

local function worn(key)
    local v = CurrentComps and CurrentComps[key]
    local hash = v and (type(v) == "table" and v.comp or v)
    return hash and hash ~= 0 and hash ~= -1 and v or nil
end

local function hashOf(v)
    return N.Int(type(v) == "table" and v.comp or v)
end

local function notify(key)
    TriggerEvent("vorp:TipRight", L(key), 3000)
end

local function stateFor(key)
    if key == "Shirt" then
        return SHIRT_STATES[(styles.sleeves and 1 or 0) + (styles.collar and 2 or 0)]
    end
    for name, s in pairs(STYLES) do
        if s.key == key and s.state then return styles[name] and s.state or BASE end
    end
    return BASE
end

-- a peça tem este estado? (se o jogo não disser nada, tenta-se na mesma)
local function supports(hash, state)
    if u32(state) == u32(BASE) then return true end
    local female = not IsPedMale(PlayerPedId())
    local n = Citizen.InvokeNative(0xFFCC2DB2D9953401, hash, female, true, Citizen.ResultAsInteger()) or 0
    if n <= 0 then return true end
    for i = 0, n - 1 do
        local s = Citizen.InvokeNative(0x6243635AF2F1B826, hash, i, female, true, Citizen.ResultAsInteger())
        if u32(s) == u32(state) then return true end
    end
    return false
end

-- aplica o estilo atual às peças vestidas (mudar o estado repõe as cores, por isso voltam a aplicar-se)
local function applyStyles(ped)
    for _, key in ipairs(STYLED_KEYS) do
        local v = worn(key)
        local state = stateFor(key)
        if v and not hidden[key] and u32(state) ~= u32(BASE) then
            N.SetWearableState(ped, hashOf(v), state)
            N.UpdateVariation(ped)
            Look.Tint(ped, key, v)
            if key == "Boots" and worn("Pant") then Look.Tint(ped, "Pant", worn("Pant")) end
        end
    end
end

-- Roupa que se vê agora (sem as peças tiradas)
function Clothes.Visible(comps)
    if next(hidden) == nil then return comps end
    local out = {}
    for key, v in pairs(comps or {}) do
        if not hidden[key] then out[key] = v end
    end
    return out
end

-- Volta a vestir a roupa toda de raiz, como o /rc: aplicar só uma peça por cima das outras deixa
-- camadas mal ajustadas (camisa por cima do colete, mangas inchadas...)
local function rebuild()
    local ped = PlayerPedId()
    Look.Apply(ped, CurrentSkin, Clothes.Visible(CurrentComps))
    applyStyles(ped)
    N.UpdateVariation(ped)
end

-- Tira (ou volta a vestir) as peças de um comando. Devolve "off", "on" ou nil (nada para tirar)
function Clothes.Toggle(keys)
    if not CurrentSkin or not CurrentComps then return nil end
    local list = {}
    for _, key in ipairs(keys) do
        if worn(key) then list[#list + 1] = key end
    end
    if #list == 0 then return nil end

    -- se alguma peça do grupo ainda está vestida, tira o grupo todo; senão volta a vestir
    local anyOn = false
    for _, key in ipairs(list) do
        if not hidden[key] then anyOn = true break end
    end
    for _, key in ipairs(list) do hidden[key] = anyOn or nil end
    rebuild()
    return anyOn and "off" or "on"
end

-- Veste tudo o que foi tirado
function Clothes.RestoreAll()
    if next(hidden) == nil or not CurrentSkin then return false end
    hidden = {}
    rebuild()
    return true
end

-- Liga / desliga um estilo. Devolve true/false (novo estado) ou nil + erro ("none" / "unsupported")
function Clothes.ToggleStyle(name)
    local s = STYLES[name]
    if not s then return nil, "unknown" end
    local v = worn(s.key)
    if not v or hidden[s.key] then return nil, "none" end

    styles[name] = not styles[name] or nil
    local state = stateFor(s.key)
    if not supports(hashOf(v), state) then
        styles[name] = not styles[name] or nil
        return nil, "unsupported"
    end

    local ped = PlayerPedId()
    if name == "bandana" then
        -- mão à cara (o estado só pega depois da animação)
        Citizen.InvokeNative(0xAE72E7DF013AAA61, ped, hashOf(v), styles.bandana and joaat("BANDANA_ON_RIGHT_HAND") or joaat("BANDANA_OFF_RIGHT_HAND"), 1, 0, -1082130432)
        Wait(700)
    end
    N.SetWearableState(ped, hashOf(v), state)
    N.UpdateVariation(ped)
    Look.Tint(ped, s.key, v)
    if s.key == "Boots" and worn("Pant") then Look.Tint(ped, "Pant", worn("Pant")) end
    return styles[name] == true
end

-- Depois de reaplicar a aparência (ReloadLook, morte...): manter o estilo das peças
function Clothes.Reapply(ped)
    for key in pairs(hidden) do
        if not worn(key) then hidden[key] = nil end
    end
    applyStyles(ped or PlayerPedId())
end

-- Personagem nova / trocada: nada tirado, estilos normais
function Clothes.Reset()
    hidden, styles = {}, {}
end

-- Uma loja de roupa trocou uma peça: essa já não está tirada
function Clothes.Forget(key)
    hidden[key] = nil
end

function Clothes.IsHidden(key)
    return hidden[key] == true
end

exports("ToggleClothing", function(keys)
    if type(keys) == "string" then keys = { keys } end
    if type(keys) ~= "table" then return nil end
    return Clothes.Toggle(keys)
end)
exports("IsClothingHidden", Clothes.IsHidden)
exports("RestoreClothing", Clothes.RestoreAll)
exports("ToggleClothingStyle", Clothes.ToggleStyle)

-- =====================================================================
--  COMANDOS
-- =====================================================================

local cfg = Config.ClothingCommands
if not cfg or not cfg.Enabled then return end

local function canUse()
    if not LocalPlayer.state.IsInSession or not SpawnGuard.inWorld or Scene.active then return false end
    local ped = PlayerPedId()
    if IsEntityDead(ped) or not CurrentComps or not CurrentSkin then return false end
    local now = GetGameTimer()
    if now - lastUse < (cfg.Cooldown or 1000) then return false end
    lastUse = now
    return true
end

local function playAnim(name)
    local anim = cfg.Animations and cfg.Animations[name]
    if not anim then return end
    local ped = PlayerPedId()
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) or IsPedSwimming(ped) then return end
    RequestAnimDict(anim.dict)
    local deadline = GetGameTimer() + 1000
    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < deadline do Wait(0) end
    if not HasAnimDictLoaded(anim.dict) then return end
    -- 31 = só o tronco, deixa andar
    TaskPlayAnim(ped, anim.dict, anim.name, 4.0, -4.0, anim.time or 1200, 31, 0.0, false, 0, false, "", false)
    Wait(anim.wait or 500)
    RemoveAnimDict(anim.dict)
end

for name, keys in pairs(cfg.Commands or {}) do
    RegisterCommand(name, function()
        if not canUse() then return end
        local any = false
        for _, key in ipairs(keys) do
            if worn(key) then any = true break end
        end
        if not any then return notify("clothes_none") end
        playAnim(name)
        Clothes.Toggle(keys)
    end, false)
    TriggerEvent("chat:addSuggestion", "/" .. name, L("clothes_suggest"))
end

for name, style in pairs(cfg.Styles or {}) do
    if STYLES[style] then
        RegisterCommand(name, function()
            if not canUse() then return end
            playAnim(name)
            local ok, err = Clothes.ToggleStyle(style)
            if ok == nil then notify(err == "unsupported" and "clothes_no_style" or "clothes_none") end
        end, false)
        TriggerEvent("chat:addSuggestion", "/" .. name, L("clothes_suggest_style_" .. style))
    else
        print(("^3[fks-character] Config.ClothingCommands.Styles.%s: estilo desconhecido '%s'^7"):format(name, tostring(style)))
    end
end

if cfg.RestoreCommand then
    RegisterCommand(cfg.RestoreCommand, function()
        if not canUse() then return end
        if not Clothes.RestoreAll() then notify("clothes_nothing_hidden") end
    end, false)
    TriggerEvent("chat:addSuggestion", "/" .. cfg.RestoreCommand, L("clothes_suggest_restore"))
end
