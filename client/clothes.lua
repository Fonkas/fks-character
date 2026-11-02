-- Tirar / vestir peças de roupa com comandos (/hat, /jacket, /shirt, ...). Ver Config.ClothingCommands.
-- Só muda o que se vê: a roupa guardada da personagem não é alterada (as lojas continuam a gravar a roupa toda).

Clothes = {}

local hidden = {}    -- chave vorp (ex.: "Hat") -> true enquanto está tirada
local lastUse = 0

local function worn(key)
    local v = CurrentComps and CurrentComps[key]
    local hash = v and (type(v) == "table" and v.comp or v)
    return hash and hash ~= 0 and hash ~= -1 and v or nil
end

local function notify(key)
    TriggerEvent("vorp:TipRight", L(key), 3000)
end

-- volta a pôr por cima as camadas que ficam mal quando se veste outra peça (igual a Look.Comps)
local function relayer(ped)
    for _, key in ipairs(Look.Layered) do
        local v = worn(key)
        if v and not hidden[key] then Look.Component(ped, key, v) end
    end
end

local function hide(ped, key)
    local category = Appearance.Categories[key]
    if category then N.RemoveTag(ped, category) end
    hidden[key] = true
end

-- Tira (ou volta a vestir) as peças de um comando. Devolve "off", "on" ou nil (nada para tirar)
function Clothes.Toggle(keys)
    local ped = PlayerPedId()
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

    if anyOn then
        for _, key in ipairs(list) do hide(ped, key) end
    else
        for _, key in ipairs(list) do
            hidden[key] = nil
            Look.Component(ped, key, worn(key))
        end
        relayer(ped)
    end
    N.UpdateVariation(ped)
    return anyOn and "off" or "on"
end

-- Veste tudo o que foi tirado
function Clothes.RestoreAll()
    local ped = PlayerPedId()
    local any = false
    for key in pairs(hidden) do
        hidden[key] = nil
        local v = worn(key)
        if v then
            any = true
            Look.Component(ped, key, v)
        end
    end
    if any then
        relayer(ped)
        N.UpdateVariation(ped)
    end
    return any
end

-- Depois de reaplicar a aparência (ReloadLook, morte...), as peças tiradas continuam tiradas
function Clothes.Reapply(ped)
    if next(hidden) == nil then return end
    ped = ped or PlayerPedId()
    for key in pairs(hidden) do
        if worn(key) then hide(ped, key) else hidden[key] = nil end
    end
    N.UpdateVariation(ped)
end

-- Personagem nova / trocada: nada tirado
function Clothes.Reset()
    hidden = {}
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

-- =====================================================================
--  COMANDOS
-- =====================================================================

local cfg = Config.ClothingCommands
if not cfg or not cfg.Enabled then return end

local function canUse()
    if not LocalPlayer.state.IsInSession or not SpawnGuard.inWorld or Scene.active then return false end
    local ped = PlayerPedId()
    if IsEntityDead(ped) or not CurrentComps then return false end
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

if cfg.RestoreCommand then
    RegisterCommand(cfg.RestoreCommand, function()
        if not canUse() then return end
        if not Clothes.RestoreAll() then notify("clothes_nothing_hidden") end
    end, false)
    TriggerEvent("chat:addSuggestion", "/" .. cfg.RestoreCommand, L("clothes_suggest_restore"))
end
