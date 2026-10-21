-- Ponto de entrada do cliente + compatibilidade com o vorp_character.

CharId = nil
CurrentSkin = nil
CurrentComps = nil
Today = nil

RegisterNetEvent("fks-character:client:open", function(payload)
    if type(payload) ~= "table" then return end
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    UI.Send("init", { locale = GetLocaleTable() })
    Selection.Open(payload)
end)

-- =====================================================================
--  COMPATIBILIDADE vorp_character (barbearias, lojas, outros recursos)
-- =====================================================================

local function normalizeComps(comps)
    local out = {}
    for key, value in pairs(comps) do
        if type(value) == "table" then
            out[key] = { comp = value.comp, tint0 = value.tint0 or 0, tint1 = value.tint1 or 0, tint2 = value.tint2 or 0, palette = value.palette or 0 }
        else
            out[key] = { comp = value, tint0 = 0, tint1 = 0, tint2 = 0, palette = 0 }
        end
    end
    return out
end

local function oldStructure(comps)
    local out = {}
    for key, value in pairs(comps or {}) do out[key] = value.comp end
    return out
end

local function decodeMaybe(v)
    if type(v) == "table" then return v end
    if type(v) == "string" then
        local ok, res = pcall(json.decode, v)
        if ok then return res end
    end
end

local function saveCache()
    if CurrentSkin and CurrentComps then
        TriggerServerEvent("vorpcharacter:setPlayerCompChange", CurrentSkin, oldStructure(CurrentComps))
    end
end

RegisterNetEvent("vorpcharacter:updateCache", function(skin, comps)
    skin, comps = decodeMaybe(skin), decodeMaybe(comps)
    if skin then CurrentSkin = skin end
    if comps then
        CurrentComps = CurrentComps or {}
        for k, v in pairs(normalizeComps(comps)) do CurrentComps[k] = v end
    end
    saveCache()
end)

RegisterNetEvent("vorpcharacter:savenew", function(comps, skin)
    comps, skin = decodeMaybe(comps), decodeMaybe(skin)
    if comps then
        CurrentComps = CurrentComps or {}
        for k, v in pairs(normalizeComps(comps)) do CurrentComps[k] = v end
    end
    if skin and CurrentSkin then
        for k, v in pairs(skin) do
            if CurrentSkin[k] ~= nil then CurrentSkin[k] = v end
        end
    end
    saveCache()
end)

local function reloadLook()
    if not CurrentSkin or not CurrentComps then return end
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    if model ~= joaat("mp_male") and model ~= joaat("mp_female") then
        local hash = N.LoadModel(CurrentSkin.sex)
        if not hash then return end
        SetPlayerModel(PlayerId(), hash, false)
        SetModelAsNoLongerNeeded(hash)
        ped = PlayerPedId()
    end
    Look.Apply(ped, CurrentSkin, CurrentComps)
end

AddEventHandler("vorpcharacter:reloadafterdeath", function()
    reloadLook()
    local ped = PlayerPedId()
    SetAttributeCoreValue(ped, 0, 100)
    SetEntityHealth(ped, 600, 1)
    SetAttributeCoreValue(ped, 1, 100)
end)

AddEventHandler("fks-character:client:reloadLook", reloadLook)

if Config.ReloadCommand then
    RegisterCommand(Config.ReloadCommand, function()
        if not LocalPlayer.state.IsInSession or IsEntityDead(PlayerPedId()) then return end
        reloadLook()
    end, false)
end

exports("GetPlayerComponent", function(category)
    return CurrentComps and CurrentComps[category] or nil
end)

exports("GetAllPlayerComponents", function()
    return CurrentComps or {}
end)

exports("GetPlayerSkin", function()
    return CurrentSkin
end)

exports("ApplyAppearance", function(ped, skin, comps)
    Look.Apply(ped, skin, normalizeComps(comps or {}))
end)

-- Manter a escala quando a altura física está ativa (o jogo repõe-na em algumas animações)
if Config.Identity.ApplyHeightScale then
    CreateThread(function()
        while true do
            Wait(2000)
            local ped = PlayerPedId()
            if CurrentSkin and LocalPlayer.state.IsInSession and not IsEntityDead(ped) then
                SetPedScale(ped, (tonumber(CurrentSkin.Scale) or 1.0) + 0.0)
            end
        end
    end)
end

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    Selection.DeletePeds()
    Look.ReleaseAll(PlayerPedId())
    Cam.Stop()
    UI.Focus(false)
    if Scene.active then
        Scene.Leave()
        Creator.Cleanup()
    end
    DoScreenFadeIn(100)
end)
