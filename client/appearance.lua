-- Aplicação de aparência (formato vorp_character) a qualquer ped.

Look = {}

local textures = {}      -- ped -> textureId
local overlayJobs = {}   -- ped -> { skin = skin, running = bool }
local HEADS = joaat("heads")
local BASE = joaat("base")

-- Preenche cabeça/tronco/pernas em falta a partir do albedo (tal como o vorp)
local function fillDefaults(skin)
    local c = Catalog.Get(skin.sex)
    local tone
    for _, t in ipairs(c.tones) do
        if t.albedo == skin.albedo then tone = t break end
    end
    tone = tone or c.tones[1]
    if not skin.albedo or skin.albedo == 0 then skin.albedo = tone.albedo end
    if not skin.HeadType or skin.HeadType == 0 then skin.HeadType = tone.heads[1] end
    if not skin.BodyType or skin.BodyType == 0 then skin.BodyType = tone.bodies[1] end
    if not skin.LegsType or skin.LegsType == 0 then skin.LegsType = tone.legs[1] end
    if not skin.Torso or skin.Torso == 0 then skin.Torso = skin.BodyType end
    if not skin.Eyes or skin.Eyes == 0 then skin.Eyes = c.eyes[1] end
    return skin
end

function Look.FaceFeatures(ped, skin)
    for _, f in ipairs(Appearance.Features) do
        local v = tonumber(skin[f.key]) or 0.0
        N.SetFaceFeature(ped, f.hash, v + 0.0)
    end
end

function Look.Base(ped, skin)
    fillDefaults(skin)
    N.EquipOutfitPreset(ped, skin.sex == "mp_male" and 4 or 7)
    N.WaitReady(ped)
    for _, tag in pairs(Appearance.Categories) do N.RemoveTag(ped, tag) end
    N.ResetComponents(ped)
    N.WaitReady(ped)

    N.ApplyItem(ped, skin.HeadType)
    N.ApplyItem(ped, skin.BodyType)
    N.ApplyItem(ped, skin.LegsType)
    N.ApplyItem(ped, skin.Eyes)
    N.ApplyItem(ped, skin.Hair)
    if skin.sex == "mp_male" then N.ApplyItem(ped, skin.Beard) end
    N.ApplyItem(ped, skin.Torso)
    N.EquipOutfit(ped, skin.Waist)
    N.EquipOutfit(ped, skin.Body)
    N.UpdateVariation(ped)
    Look.FaceFeatures(ped, skin)
    N.UpdateVariation(ped)
    N.WaitReady(ped)
end

-- Reaplica tons (palette/tints) guardados nas lojas de roupa
local function applyTint(ped, key, value)
    if not value.palette or value.palette == 0 then return end
    local category = Appearance.Categories[key]
    if not category then return end
    for i = 0, N.NumComponents(ped) - 1 do
        if N.ComponentCategory(ped, i) == category then
            local drawable, albedo, normal, material = Citizen.InvokeNative(0xA9C28516A6DC9D56, ped, i,
                Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
            Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped, drawable, albedo, normal, material,
                value.palette, value.tint0 or 0, value.tint1 or 0, value.tint2 or 0)
            return
        end
    end
end

local function applyComponent(ped, key, value)
    local hash = type(value) == "table" and value.comp or value
    if not hash or hash == -1 or hash == 0 then return end
    N.ApplyItem(ped, hash)
    if key ~= "Boots" then N.SetWearableState(ped, hash, BASE) end
    N.UpdateVariation(ped)
    if type(value) == "table" then applyTint(ped, key, value) end
end

function Look.Comps(ped, comps)
    for key, value in pairs(comps) do
        applyComponent(ped, key, value)
    end
    -- reaplicar camadas que costumam ficar por baixo
    for _, key in ipairs({ "Shirt", "Vest", "Boots" }) do
        if comps[key] then applyComponent(ped, key, comps[key]) end
    end
    N.RemoveTag(ped, Appearance.Categories.AmmoPistol)
    N.UpdateVariation(ped)
end

local function buildTexture(ped, skin)
    local tt = Appearance.TextureTypes[skin.sex] or Appearance.TextureTypes.mp_male
    if textures[ped] then
        N.ReleaseTexture(textures[ped])
        textures[ped] = nil
    end

    local tex = N.RequestTexture(skin.albedo, tt.normal, tt.material)
    for _, o in ipairs(Appearance.Overlays) do
        local p = o.prefix
        if (tonumber(skin[p .. "_visibility"]) or 0) ~= 0 then
            local ids = Appearance.OverlayIds[o.name]
            local tx = tonumber(skin[p .. "_tx_id"]) or 1
            local txHash = (o.fixedTexture or tx < 1) and ids[1] or (ids[tx] or ids[1])
            local opacity = tonumber(skin[p .. "_opacity"]) or 1.0
            if opacity <= 0 then opacity = 1.0 end

            local layer
            if o.colored then
                layer = N.AddTextureLayer(tex, txHash, 1, 0, 0, 1.0, 0)
                local color = tonumber(skin[o.colorKey]) or 0
                if color == 0 then color = Appearance.DefaultOverlayColor end
                local c2 = tonumber(skin[p .. "_palette_color_secondary"]) or 0
                local c3 = tonumber(skin[p .. "_palette_color_tertiary"]) or 0
                N.SetLayerPalette(tex, layer, Appearance.Palettes[1])
                N.SetLayerTint(tex, layer, color, c2, c3)
                N.SetLayerVariant(tex, layer, o.variantKey and (tonumber(skin[o.variantKey]) or 0) or 0)
            else
                layer = N.AddTextureLayer(tex, txHash, 0, 0, 1, 1.0, 0)
                N.SetLayerVariant(tex, layer, 0)
            end
            N.SetLayerAlpha(tex, layer, opacity + 0.0)
        end
    end

    local deadline = GetGameTimer() + 3000
    while not N.IsTextureValid(tex) do
        if GetGameTimer() > deadline or not DoesEntityExist(ped) then
            N.ReleaseTexture(tex)
            return
        end
        Wait(0)
    end
    N.ApplyTexture(ped, HEADS, tex)
    N.UpdateTexture(tex)
    N.UpdateVariation(ped)
    textures[ped] = tex
end

-- Aplica overlays de forma assíncrona; pedidos repetidos são agrupados
-- (útil enquanto o jogador arrasta um slider).
function Look.Overlays(ped, skin, sync)
    if sync then return buildTexture(ped, skin) end
    local job = overlayJobs[ped]
    if job then
        job.skin = skin
        job.dirty = true
        return
    end
    job = { skin = skin, dirty = true }
    overlayJobs[ped] = job
    CreateThread(function()
        while job.dirty do
            job.dirty = false
            buildTexture(ped, job.skin)
            Wait(50)
        end
        overlayJobs[ped] = nil
    end)
end

function Look.Apply(ped, skin, comps)
    Look.Base(ped, skin)
    Look.Comps(ped, comps or {})
    Look.Overlays(ped, skin, true)
    SetPedScale(ped, (tonumber(skin.Scale) or 1.0) + 0.0)
    N.UpdateVariation(ped)
end

function Look.Release(ped)
    if textures[ped] then
        N.ReleaseTexture(textures[ped])
        textures[ped] = nil
    end
end

function Look.ReleaseAll(except)
    for ped, tex in pairs(textures) do
        if ped ~= except then
            N.ReleaseTexture(tex)
            textures[ped] = nil
        end
    end
end

-- Equipa uma peça no criador tratando incompatibilidades.
-- comps: categoria -> hash (-1 = nada)
function Look.SetClothing(ped, comps, key, hash, removeList)
    local function strip(cat)
        if comps[cat] and comps[cat] ~= -1 then
            comps[cat] = -1
        end
        if Appearance.Categories[cat] then N.RemoveTag(ped, Appearance.Categories[cat]) end
    end

    if hash == -1 then
        strip(key)
    else
        for _, other in ipairs(Appearance.Incompatible[key] or {}) do strip(other) end
        for _, other in ipairs(removeList or {}) do strip(other) end
        comps[key] = hash
        applyComponent(ped, key, hash)
    end
    N.UpdateVariation(ped)
end
