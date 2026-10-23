-- Criador de personagens: estado, esquema da NUI e aplicação em tempo real.

Creator = { active = false }

local S = {}   -- estado: model, skin, comps (key -> hash), values (id -> valor), initial, opts

local MAKEUP = {
    { name = "lipsticks", section = "sec_lipstick" },
    { name = "shadows",   section = "sec_shadows" },
    { name = "blush",     section = "sec_blush" },
    { name = "eyeliners", section = "sec_eyeliner" },
}
local SKIN_MARKS = { "scars", "spots", "disc", "complex", "acne", "ageing", "freckles", "moles" }

local overlayByName = {}
for _, o in ipairs(Appearance.Overlays) do overlayByName[o.name] = o end

local function ped() return PlayerPedId() end
local function cat() return Catalog.Get(S.model) end

local function makeupAllowed()
    return Config.Makeup.Enabled and (not Config.Makeup.FemaleOnly or S.model == "mp_female")
end

local function copy(t) return json.decode(json.encode(t)) end

-- =====================================================================
--  ESTADO / VALORES
-- =====================================================================

local function toneIndex()
    return S.values.tone or 1
end

local function tone()
    return cat().tones[toneIndex()] or cat().tones[1]
end

local function refreshOverlays()
    Look.Overlays(ped(), S.skin)
end

local function setOverlayField(name, field, value)
    local o = overlayByName[name]
    local p = o.prefix
    local skin = S.skin
    local patch = {}
    if field == "tx" then
        skin[p .. "_tx_id"] = value
        if value > 0 and (tonumber(skin[p .. "_opacity"]) or 0) <= 0 then
            skin[p .. "_opacity"] = 1.0
            S.values["ov:" .. name .. ":op"] = 1.0
            patch["ov:" .. name .. ":op"] = { value = 1.0 }
        end
    elseif field == "op" then
        skin[p .. "_opacity"] = value
        if o.fixedTexture then
            skin[p .. "_tx_id"] = value > 0 and 1 or 0
        elseif value > 0 and (tonumber(skin[p .. "_tx_id"]) or 0) == 0 then
            skin[p .. "_tx_id"] = 1
            S.values["ov:" .. name .. ":tx"] = 1
            patch["ov:" .. name .. ":tx"] = { value = 1 }
        end
    elseif field == "color" then
        skin[o.colorKey] = Appearance.Palettes[value] or 0
    elseif field == "var" then
        skin[o.variantKey] = value
    end
    local visible = (tonumber(skin[p .. "_tx_id"]) or 0) > 0 and (tonumber(skin[p .. "_opacity"]) or 0) > 0
    skin[p .. "_visibility"] = visible and 1 or 0
    refreshOverlays()
    return patch
end

local function clothingVariants(key)
    local groups = cat().clothing[key] or {}
    local gi = S.values["cloth:" .. key] or 0
    return groups[gi] or {}
end

local function applyClothing(key)
    local gi = S.values["cloth:" .. key] or 0
    local patch = {}
    if gi == 0 then
        Look.SetClothing(ped(), S.comps, key, -1)
    else
        local variants = clothingVariants(key)
        local vi = math.min(S.values["clothVar:" .. key] or 1, #variants)
        local item = variants[vi]
        if item then
            local before = copy(S.comps)
            Look.SetClothing(ped(), S.comps, key, item.hash, item.remove)
            -- sincronizar categorias removidas por incompatibilidade
            for k, v in pairs(before) do
                if v ~= -1 and S.comps[k] == -1 and k ~= key then
                    S.values["cloth:" .. k] = 0
                    patch["cloth:" .. k] = { value = 0 }
                    patch["clothVar:" .. k] = { value = 1, count = 1 }
                end
            end
        end
    end
    patch["clothVar:" .. key] = { value = S.values["clothVar:" .. key] or 1, count = math.max(1, #clothingVariants(key)) }
    return patch
end

-- Handlers por prefixo de id
local Set = {}

Set.tone = function(v)
    local t = cat().tones[v]
    if not t then return end
    S.values.tone = v
    S.skin.albedo = t.albedo
    S.skin.HeadType = t.heads[S.values.head or 1] or t.heads[1]
    S.skin.BodyType = t.bodies[S.values.torso or 1] or t.bodies[1]
    S.skin.Torso = S.skin.BodyType
    S.skin.LegsType = t.legs[S.values.legs or 1] or t.legs[1]
    local p = ped()
    N.WaitReady(p)
    N.ApplyItem(p, S.skin.HeadType)
    N.ApplyItem(p, S.skin.BodyType)
    N.ApplyItem(p, S.skin.LegsType)
    N.UpdateVariation(p)
    Look.FaceFeatures(p, S.skin)
    refreshOverlays()
end

Set.head = function(v)
    local h = tone().heads[v]
    if not h then return end
    S.values.head = v
    S.skin.HeadType = h
    N.ApplyItem(ped(), h)
    N.UpdateVariation(ped())
    Look.FaceFeatures(ped(), S.skin)
    refreshOverlays()
end

Set.torso = function(v)
    local h = tone().bodies[v]
    if not h then return end
    S.values.torso = v
    S.skin.BodyType, S.skin.Torso = h, h
    N.ApplyItem(ped(), h)
    N.UpdateVariation(ped())
end

Set.legs = function(v)
    local h = tone().legs[v]
    if not h then return end
    S.values.legs = v
    S.skin.LegsType = h
    N.ApplyItem(ped(), h)
    N.UpdateVariation(ped())
end

Set.bodyShape = function(v)
    local h = Appearance.BodyShapes[v]
    if not h then return end
    S.values.bodyShape = v
    S.skin.Body = h
    N.EquipOutfit(ped(), h)
    N.UpdateVariation(ped())
end

Set.waist = function(v)
    local h = Appearance.Waists[v]
    if not h then return end
    S.values.waist = v
    S.skin.Waist = h
    N.EquipOutfit(ped(), h)
    N.UpdateVariation(ped())
end

Set.eyes = function(v)
    local h = cat().eyes[v]
    if not h then return end
    S.values.eyes = v
    S.skin.Eyes = h
    N.ApplyItem(ped(), h)
    N.UpdateVariation(ped())
end

Set.teeth = function(v)
    local h = cat().teeth[v]
    if not h then return end
    S.values.teeth = v
    S.comps.Teeth = h
    N.ApplyItem(ped(), h)
    N.UpdateVariation(ped())
end

local function setHairLike(kind, colorId, skinKey, tagKey, v, isColor)
    local groups = cat()[kind]
    local gi = isColor and (S.values[kind] or 0) or v
    if isColor then S.values[colorId] = v else
        S.values[kind] = v
        S.values[colorId] = math.min(S.values[colorId] or 1, math.max(1, #(groups[v] or {})))
    end
    local p = ped()
    if gi == 0 then
        S.skin[skinKey] = 0
        N.RemoveTag(p, Appearance.Categories[tagKey])
    else
        local variants = groups[gi] or {}
        local h = variants[S.values[colorId]] or variants[1]
        S.skin[skinKey] = h or 0
        N.ApplyItem(p, h)
    end
    N.UpdateVariation(p)
    local count = gi == 0 and 1 or #(groups[gi] or {})
    return { [colorId] = { value = S.values[colorId] or 1, count = math.max(1, count) } }
end

Set.hair = function(v) return setHairLike("hair", "hairColor", "Hair", "Hair", v, false) end
Set.hairColor = function(v) return setHairLike("hair", "hairColor", "Hair", "Hair", v, true) end
Set.beard = function(v) return setHairLike("beard", "beardColor", "Beard", "Beard", v, false) end
Set.beardColor = function(v) return setHairLike("beard", "beardColor", "Beard", "Beard", v, true) end

local function dispatch(id, value)
    local prefix, rest = id:match("^(%w+):(.+)$")
    if prefix == "f" then
        if not Appearance.FeatureHash[rest] then return end
        local v = math.max(-1.0, math.min(1.0, tonumber(value) or 0.0))
        S.values[id] = v
        S.skin[rest] = v
        N.SetFaceFeature(ped(), Appearance.FeatureHash[rest], v + 0.0)
        N.UpdateVariation(ped())
        return
    elseif prefix == "ov" then
        local name, field = rest:match("^(%w+):(%w+)$")
        if not overlayByName[name] then return end
        local v = tonumber(value) or 0
        if field ~= "op" then v = math.floor(v) end
        S.values[id] = v
        return setOverlayField(name, field, v)
    elseif prefix == "cloth" or prefix == "clothVar" then
        S.values[id] = math.floor(tonumber(value) or 0)
        if prefix == "cloth" then S.values["clothVar:" .. rest] = 1 end
        return applyClothing(rest)
    end
    local handler = Set[id]
    if handler then return handler(math.floor(tonumber(value) or 0)) end
end

-- =====================================================================
--  ESQUEMA DA NUI
-- =====================================================================

local function list(id, label, count, none)
    return { id = id, type = "list", label = L(label), count = math.max(1, count), none = none or false }
end

local function range(id, label, min, max, step)
    return { id = id, type = "range", label = L(label), min = min, max = max, step = step }
end

local function featureSection(group, section, title)
    local controls = {}
    for _, f in ipairs(Appearance.Features) do
        if f.group == group and f.section == section then
            controls[#controls + 1] = range("f:" .. f.key, "f_" .. f.key, -1.0, 1.0, 0.05)
        end
    end
    return { title = L(title), controls = controls }
end

local function overlaySection(name, title, opts)
    local o = overlayByName[name]
    local controls = {}
    if not o.fixedTexture then
        controls[#controls + 1] = list("ov:" .. name .. ":tx", "ctl_style", #Appearance.OverlayIds[name], true)
    end
    if o.variantKey then
        controls[#controls + 1] = list("ov:" .. name .. ":var", "ctl_variant", o.variants, false)
    end
    if o.colored and not (opts and opts.noColor) then
        controls[#controls + 1] = list("ov:" .. name .. ":color", "ctl_color", #Appearance.Palettes, false)
    end
    controls[#controls + 1] = range("ov:" .. name .. ":op", "ctl_opacity", 0.0, 1.0, 0.05)
    return { title = title, controls = controls }
end

local function buildSchema()
    local c = cat()
    local tabs = {}

    tabs[#tabs + 1] = { id = "identity", label = L("tab_identity") }

    tabs[#tabs + 1] = { id = "face", label = L("tab_face"), sections = {
        { title = L("sec_model"), controls = {
            list("head", "ctl_head", #tone().heads),
            list("teeth", "ctl_teeth", #c.teeth),
        } },
        featureSection("face", "head", "sec_head"),
        featureSection("face", "jaw", "sec_jaw"),
        featureSection("face", "chin", "sec_chin"),
        featureSection("face", "cheek", "sec_cheek"),
        featureSection("face", "nose", "sec_nose"),
        featureSection("face", "mouth", "sec_mouth"),
        featureSection("face", "ears", "sec_ears"),
    } }

    local marks = { title = L("sec_marks"), controls = {} }
    for _, name in ipairs(SKIN_MARKS) do
        marks.controls[#marks.controls + 1] = list("ov:" .. name .. ":tx", "o_" .. name, #Appearance.OverlayIds[name], true)
        marks.controls[#marks.controls + 1] = range("ov:" .. name .. ":op", "ctl_opacity", 0.0, 1.0, 0.05)
        marks.controls[#marks.controls].sub = true
    end
    tabs[#tabs + 1] = { id = "skin", label = L("tab_skin"), sections = {
        { title = L("sec_tone"), controls = { list("tone", "ctl_skin_tone", #c.tones) } },
        marks,
    } }

    local brows = overlaySection("eyebrows", L("sec_brows"))
    local browFeatures = featureSection("eyes", "brows", "sec_brows")
    for _, ctl in ipairs(browFeatures.controls) do brows.controls[#brows.controls + 1] = ctl end
    local eyesSec = featureSection("eyes", "eyes", "sec_eyes")
    table.insert(eyesSec.controls, 1, list("eyes", "ctl_eye_color", #c.eyes))
    tabs[#tabs + 1] = { id = "eyes", label = L("tab_eyes"), sections = { eyesSec, brows } }

    local hairSections = {
        { title = L("sec_hair"), controls = {
            list("hair", "ctl_style", #c.hair, true),
            list("hairColor", "ctl_color", 1),
        } },
    }
    if S.model == "mp_male" then
        hairSections[#hairSections + 1] = { title = L("sec_beard"), controls = {
            list("beard", "ctl_style", #c.beard, true),
            list("beardColor", "ctl_color", 1),
        } }
        local stubble = overlaySection("beardstabble", L("ctl_stubble"))
        hairSections[#hairSections + 1] = stubble
    end
    tabs[#tabs + 1] = { id = "hair", label = L("tab_hair"), sections = hairSections }

    tabs[#tabs + 1] = { id = "body", label = L("tab_body"), sections = {
        { title = L("sec_build"), controls = {
            list("bodyShape", "ctl_body_shape", #Appearance.BodyShapes),
            list("waist", "ctl_waist", #Appearance.Waists),
            list("torso", "ctl_torso", #tone().bodies),
            list("legs", "ctl_legs", #tone().legs),
        } },
        featureSection("body", "upper", "sec_upper"),
        featureSection("body", "lower", "sec_lower"),
    } }

    if makeupAllowed() then
        local sections = {}
        for _, m in ipairs(MAKEUP) do
            sections[#sections + 1] = overlaySection(m.name, L(m.section))
        end
        tabs[#tabs + 1] = { id = "makeup", label = L("tab_makeup"), sections = sections }
    end

    local clothing = Catalog.StarterCategories(S.model)
    if #clothing > 0 then
        local controls = {}
        for _, cc in ipairs(clothing) do
            controls[#controls + 1] = list("cloth:" .. cc.key, "c_" .. cc.label, Catalog.ClothingCount(S.model, cc.key), true)
            controls[#controls + 1] = list("clothVar:" .. cc.key, "ctl_variation", 1)
            controls[#controls].sub = true
        end
        tabs[#tabs + 1] = { id = "clothing", label = L("tab_clothing"), sections = { { title = L("tab_clothing"), controls = controls } } }
    end

    tabs[#tabs + 1] = { id = "finish", label = L("tab_finish") }
    return tabs
end

-- Contagens dependentes do estado atual (cores de cabelo, variações de roupa)
local function dynamicCounts()
    local c = cat()
    local counts = {}
    counts.hairColor = math.max(1, #(c.hair[S.values.hair or 0] or {}))
    counts.beardColor = math.max(1, #(c.beard[S.values.beard or 0] or {}))
    for _, cc in ipairs(Catalog.StarterCategories(S.model)) do
        counts["clothVar:" .. cc.key] = math.max(1, #clothingVariants(cc.key))
    end
    return counts
end

-- =====================================================================
--  CONSTRUÇÃO / ALEATÓRIO / RESET
-- =====================================================================

-- Recalcula `values` a partir de skin/comps (usado após aleatório/reset)
local function valuesFromLook()
    local c, skin, v = cat(), S.skin, {}
    v.tone = 1
    for i, t in ipairs(c.tones) do if t.albedo == skin.albedo then v.tone = i break end end
    local t = c.tones[v.tone]
    v.head = Catalog.FindInList(t.heads, skin.HeadType) or 1
    v.torso = Catalog.FindInList(t.bodies, skin.BodyType) or 1
    v.legs = Catalog.FindInList(t.legs, skin.LegsType) or 1
    v.bodyShape = Catalog.FindInList(Appearance.BodyShapes, skin.Body) or 1
    v.waist = Catalog.FindInList(Appearance.Waists, skin.Waist) or 1
    v.eyes = Catalog.FindInList(c.eyes, skin.Eyes) or 1
    v.teeth = Catalog.FindInList(c.teeth, S.comps.Teeth) or 1
    v.hair, v.hairColor = Catalog.FindIndex(c.hair, skin.Hair)
    v.beard, v.beardColor = Catalog.FindIndex(c.beard, skin.Beard)
    for _, f in ipairs(Appearance.Features) do v["f:" .. f.key] = skin[f.key] or 0.0 end
    for _, o in ipairs(Appearance.Overlays) do
        local p = o.prefix
        v["ov:" .. o.name .. ":tx"] = skin[p .. "_tx_id"] or 0
        v["ov:" .. o.name .. ":op"] = skin[p .. "_opacity"] or 0.0
        if o.colorKey then v["ov:" .. o.name .. ":color"] = Catalog.FindInList(Appearance.Palettes, skin[o.colorKey]) or 1 end
        if o.variantKey then v["ov:" .. o.name .. ":var"] = skin[o.variantKey] or 0 end
    end
    for _, cc in ipairs(Catalog.StarterCategories(S.model)) do
        v["cloth:" .. cc.key], v["clothVar:" .. cc.key] = Catalog.FindIndex(c.clothing[cc.key] or {}, S.comps[cc.key])
    end
    S.values = v
end

local function compsTable()
    local out = {}
    for k, h in pairs(S.comps) do
        if h ~= -1 then out[k] = { comp = h, tint0 = 0, tint1 = 0, tint2 = 0, palette = 0 } end
    end
    return out
end

local function applyAll()
    local p = ped()
    Look.Apply(p, S.skin, compsTable())
    SetPedScale(p, Validate.HeightToScale(S.height or Config.Identity.DefaultHeight, S.model) + 0.0)
end

local function setOverlay(skin, name, tx, opacity, color, variant)
    local o = overlayByName[name]
    local p = o.prefix
    skin[p .. "_tx_id"] = tx
    skin[p .. "_opacity"] = opacity
    skin[p .. "_visibility"] = (tx > 0 and opacity > 0) and 1 or 0
    if color and o.colorKey then skin[o.colorKey] = color end
    if variant and o.variantKey then skin[o.variantKey] = variant end
end

local function defaultLook(model)
    local c = Catalog.Get(model)
    local skin = Appearance.DefaultSkin(model)
    local t = c.tones[1]
    skin.albedo = t.albedo
    skin.HeadType = t.heads[model == "mp_male" and 8 or 1]
    skin.BodyType, skin.Torso = t.bodies[1], t.bodies[1]
    skin.LegsType = t.legs[1]
    skin.Body = Appearance.BodyShapes[1]
    skin.Waist = Appearance.Waists[1]
    skin.Eyes = c.eyes[#c.eyes]
    skin.Hair = c.hair[1] and c.hair[1][1] or 0
    setOverlay(skin, "eyebrows", 1, 1.0, Appearance.DefaultOverlayColor)

    local comps = {}
    for _, key in ipairs(Appearance.ClothingKeys) do comps[key] = -1 end
    comps.Teeth = c.teeth[1]
    for _, key in ipairs({ "Shirt", "Pant", "Boots" }) do
        local allowed = false
        for _, cc in ipairs(Catalog.StarterCategories(model)) do if cc.key == key then allowed = true end end
        if allowed and c.clothing[key] and c.clothing[key][1] then comps[key] = c.clothing[key][1][1].hash end
    end
    return skin, comps
end
Creator.DefaultLook = defaultLook

local function rnd(min, max) return math.random(min, max) end
local function rndf(a) return (math.random() * 2.0 - 1.0) * a end

local function randomLook()
    local c = cat()
    local skin, comps = defaultLook(S.model)
    local ti = rnd(1, #c.tones)
    local t = c.tones[ti]
    skin.albedo = t.albedo
    skin.HeadType = t.heads[rnd(1, #t.heads)]
    skin.BodyType = t.bodies[rnd(1, #t.bodies)]
    skin.Torso = skin.BodyType
    skin.LegsType = t.legs[rnd(1, #t.legs)]
    skin.Body = Appearance.BodyShapes[rnd(1, #Appearance.BodyShapes)]
    skin.Waist = Appearance.Waists[rnd(1, math.min(10, #Appearance.Waists))]
    skin.Eyes = c.eyes[rnd(1, #c.eyes)]

    local function pick(groups)
        if #groups == 0 then return 0 end
        local g = groups[rnd(1, #groups)]
        return g[rnd(1, #g)]
    end
    skin.Hair = pick(c.hair)
    if S.model == "mp_male" and math.random() < 0.6 then skin.Beard = pick(c.beard) end

    for _, f in ipairs(Appearance.Features) do
        skin[f.key] = math.floor(rndf(f.group == "body" and 0.6 or 0.45) * 20 + 0.5) / 20
    end
    local color = Appearance.Palettes[rnd(1, #Appearance.Palettes)]
    setOverlay(skin, "eyebrows", rnd(1, #Appearance.OverlayIds.eyebrows), 1.0, color)
    for _, name in ipairs({ "freckles", "moles", "spots", "complex" }) do
        if math.random() < 0.3 then
            setOverlay(skin, name, rnd(1, #Appearance.OverlayIds[name]), math.floor(math.random() * 6 + 2) / 10)
        end
    end
    if S.model == "mp_male" and math.random() < 0.5 then
        setOverlay(skin, "beardstabble", 1, math.floor(math.random() * 7 + 3) / 10, color)
    end

    for _, cc in ipairs(Catalog.StarterCategories(S.model)) do
        local essential = cc.key == "Shirt" or cc.key == "Pant" or cc.key == "Boots"
        if essential or (math.random() < 0.3 and cc.key ~= "Dress" and cc.key ~= "Skirt") then
            local groups = c.clothing[cc.key]
            local count = Catalog.ClothingCount(S.model, cc.key)
            if count > 0 then
                local g = groups[rnd(1, count)]
                comps[cc.key] = g[rnd(1, #g)].hash
            end
        end
    end
    -- resolver incompatibilidades na ordem da configuração
    for _, cc in ipairs(Config.StarterClothing.Categories) do
        if comps[cc.key] and comps[cc.key] ~= -1 then
            for _, other in ipairs(Appearance.Incompatible[cc.key] or {}) do comps[other] = -1 end
        end
    end
    return skin, comps
end

-- =====================================================================
--  VISTA (desenhada pelo fks-core)
-- =====================================================================

local function ageOf(b)
    local t = Today or { year = 1899, month = 1, day = 1 }
    local age = t.year - b.year
    if t.month < b.month or (t.month == b.month and t.day < b.day) then age = age - 1 end
    return age
end

local function filled(v)
    return type(v) == "string" and v:match("%S") and v or nil
end

-- Uma secção do esquema -> título + mostradores (opções em lista) + barras (valores contínuos)
local function sectionNodes(sec, counts)
    if not sec.controls or #sec.controls == 0 then return {} end
    local lists, ranges, paired, prevLabel = {}, {}, false, ""
    for _, ctl in ipairs(sec.controls) do
        -- uma barra "sub" (intensidade de uma marca) usa o nome da opção anterior
        local label = (ctl.sub and ctl.type == "range") and prevLabel or ctl.label
        if not ctl.sub then prevLabel = ctl.label end
        if ctl.type == "range" then
            ranges[#ranges + 1] = {
                kind = "slider", id = ctl.id, label = label, min = ctl.min, max = ctl.max, step = ctl.step,
                value = S.values[ctl.id] or 0, format = (ctl.min == 0 and ctl.max == 1) and "percent" or "signed",
            }
        else
            if ctl.sub then paired = true end
            lists[#lists + 1] = {
                id = ctl.id, label = label, value = S.values[ctl.id], count = counts[ctl.id] or ctl.count,
                none = ctl.none, noneLabel = L("ctl_none"),
            }
        end
    end
    local out = { { type = "section", label = sec.title } }
    if #lists > 0 then out[#out + 1] = { type = "dials", action = "cr:set", cols = paired and 2 or 3, items = lists } end
    if #ranges > 0 then out[#out + 1] = { type = "stats", action = "cr:set", rows = ranges } end
    return out
end

local function heightSlider()
    local cfg = Config.Identity
    return {
        type = "slider", style = "field", name = "height", label = L("id_height"),
        min = cfg.MinHeight, max = cfg.MaxHeight, step = 1, value = S.height,
        format = "int", suffix = " cm", action = "cr:height", throttle = 120,
    }
end

local function identityBody()
    if S.opts.edit then
        return { { type = "text", text = L("edit_text") }, heightSlider() }
    end
    local cfg, t = Config.Identity, Today or { year = 1899 }
    return {
        { type = "grid", cols = 2, children = {
            { type = "input", name = "firstname", label = L("id_firstname"), max = cfg.NameMaxLength, live = true, action = "cr:name" },
            { type = "input", name = "lastname", label = L("id_lastname"), max = cfg.NameMaxLength, live = true, action = "cr:name" },
        } },
        -- género fixo se foi escolhido na cutscene inicial
        { type = "segmented", name = "model", label = L("id_gender"), value = S.model, locked = S.genderLocked or nil, action = "cr:model",
          options = { { value = "mp_male", label = L("male"), icon = "male" }, { value = "mp_female", label = L("female"), icon = "female" } } },
        { type = "date", id = "birth", name = "birth", label = L("id_birthdate"), value = S.birth,
          minYear = t.year - cfg.MaxAge, maxYear = t.year - cfg.MinAge, action = "cr:birth",
          labels = { day = L("id_day"), month = L("id_month"), year = L("id_year") },
          note = L("id_age_preview", ageOf(S.birth)) },
        heightSlider(),
        { type = "grid", cols = 2, children = {
            { type = "input", name = "nationality", label = L("id_nationality"), optional = not cfg.RequireNationality, max = cfg.NationalityMaxLength },
            { type = "input", name = "birthplace", label = L("id_birthplace"), optional = not cfg.RequireBirthplace, max = cfg.BirthplaceMaxLength },
        } },
        { type = "textarea", name = "biography", label = L("id_biography"), optional = not cfg.RequireBiography, max = cfg.BiographyMaxLength },
    }
end

-- Resumo do "Finalizar" a partir dos valores do formulário
local function summaryItems(v)
    local b = type(v.birth) == "table" and v.birth or S.birth
    return {
        { label = L("id_firstname"), value = filled(v.firstname) or "—" },
        { label = L("id_lastname"), value = filled(v.lastname) or "—" },
        { label = L("id_birthdate"), value = ("%02d/%02d/%d"):format(b.day, b.month, b.year) },
        { label = L("sel_age"), value = ("%d %s"):format(ageOf(b), L("sel_years")) },
        { label = L("id_gender"), value = L(S.model == "mp_male" and "male" or "female") },
        { label = L("id_height"), value = ("%d cm"):format(tonumber(v.height) or S.height) },
        { label = L("id_nationality"), value = filled(v.nationality) },
        { label = L("id_birthplace"), value = filled(v.birthplace) },
    }
end

local function finishBody()
    local body = {
        { type = "text", text = L("finish_text") },
        { type = "kv", id = "summary", items = summaryItems({}) },
    }
    local spawns = Selection.payload and Selection.payload.spawns
    if spawns and #spawns > 0 then
        local options = {}
        for i, label in ipairs(spawns) do options[i] = { value = i, label = label } end
        body[#body + 1] = { type = "section", label = L("act_spawn") }
        body[#body + 1] = { type = "segmented", style = "list", name = "spawn", value = 1, options = options }
    end
    -- a ação de criar está no botão dourado em baixo
    body[#body + 1] = { type = "text", text = L("finish_hint") }
    return body
end

-- Ecrã dos kits iniciais (página em ecrã inteiro, antes de criar)
local function kitsPage(kits)
    local function img(name) return name and (kits.imagePath or ""):gsub("%%s", name) or nil end
    local cards = {}
    for _, kit in ipairs(kits.list) do
        local lines = {}
        for _, it in ipairs(kit.items or {}) do
            lines[#lines + 1] = { img = img(it.item), amount = it.amount, label = it.label or it.item }
        end
        cards[#cards + 1] = {
            value = kit.id, title = kit.label, text = kit.description or "",
            img = img(kit.icon or (kit.items and kit.items[1] and kit.items[1].item)), lines = lines,
        }
    end
    return {
        layout = "center", back = false, camera = false, hints = {},
        eyebrow = L("kits_eyebrow"), heading = L("kits_title"), desc = L("kits_desc"),
        body = { { type = "cards", name = "kit", items = cards, submit = { action = "cr:finish" } } },
        footer = {
            main = false,
            buttons = {
                { type = "button", label = L("act_back"), style = "ghost", go = "finish" },
                { type = "button", label = L("kits_confirm"), style = "main", iconRight = "fwd", requires = "kit", action = "cr:finish" },
            },
        },
    }
end

local function creatorView()
    local edit = S.opts.edit
    local tabs = buildSchema()
    if edit then
        -- /skinmenu: sem identidade nem "Finalizar"; o separador da identidade só tem a altura
        local kept = {}
        for _, tab in ipairs(tabs) do
            if tab.id ~= "finish" then kept[#kept + 1] = tab end
            if tab.id == "identity" then tab.label = L("tab_height") end
        end
        tabs = kept
    end

    local counts = dynamicCounts()
    local pages, chips = {}, {}
    for i, tab in ipairs(tabs) do
        chips[i] = { page = tab.id, label = tab.label }
        local body
        if tab.id == "identity" then
            body = identityBody()
        elseif tab.id == "finish" then
            body = finishBody()
        else
            body = {}
            for _, sec in ipairs(tab.sections or {}) do
                for _, node in ipairs(sectionNodes(sec, counts)) do body[#body + 1] = node end
            end
        end
        -- no primeiro separador, "anterior" volta à seleção (ou sai do /skinmenu)
        local prev = tabs[i - 1] and tabs[i - 1].id or ((not S.opts.firstCharacter) and { action = "cr:cancel" } or nil)
        pages[tab.id] = {
            title = tab.label,
            count = ("%d / %d"):format(i, #tabs),
            desc = L((edit and tab.id == "identity") and "desc_edit_identity" or ("desc_" .. tab.id)),
            nav = { prev = prev, next = tabs[i + 1] and tabs[i + 1].id or nil },
            body = body,
        }
    end

    if not edit then
        pages.finish.footer = { main = { label = L("act_create"), action = "cr:finish", pulse = true } }
        local kits = Selection.payload and Selection.payload.kits
        if kits and kits.list and #kits.list > 0 then pages.kits = kitsPage(kits) end
    end

    return {
        eyebrow = L(edit and "edit_eyebrow" or "cr_eyebrow"),
        title = edit and L("edit_title") or (S.title or L("cr_new")),
        page = S.tab,
        tabs = chips,
        pages = pages,
        camera = UI.CameraRail(Config.Cameras.TabPresets[S.tab] or "general"),
        footer = {
            buttons = {
                { type = "button", label = L("act_random"), icon = "dice", style = "ghost", small = true, action = "cr:random" },
                { type = "button", label = L("act_reset"), icon = "undo", style = "ghost", small = true, action = "cr:reset" },
            },
            -- botão dourado: leva ao "Finalizar" (lá cria a personagem) ou guarda no /skinmenu
            main = edit and { label = L("edit_save"), action = "cr:save", pulse = true } or { label = L("act_finish"), go = "finish" },
        },
    }
end

local function placePed(p)
    local sp = Config.CreatorScene.stage
    SetEntityCoords(p, sp.x, sp.y, sp.z, false, false, false, false)
    SetEntityHeading(p, sp.w)
    SetEntityCollision(p, true, true)
    FreezeEntityPosition(p, false)
    SetEntityVisible(p, true)
    SetEntityInvincible(p, true)
    ClearPedTasksImmediately(p)
    ForcePedMotionState(p, joaat("MotionState_DoNothing"), false, 0, false)
    SetFacialIdleAnimOverride(p, "mood_normal_zoom", S.model == "mp_male" and "FACE_HUMAN@GEN_MALE@BASE" or "FACE_HUMAN@GEN_FEMALE@BASE")
end

-- look = { skin, comps } opcional (modo /skinmenu); sem ele usa a aparência por defeito
local function setModel(model, look)
    local hash = N.LoadModel(model)
    if not hash then return false end
    S.model = model
    SetPlayerModel(PlayerId(), hash, false)
    SetModelAsNoLongerNeeded(hash)
    local p = ped()
    N.WaitReady(p)
    placePed(p)
    if look then
        S.skin, S.comps = copy(look.skin), copy(look.comps)
    else
        S.skin, S.comps = defaultLook(model)
    end
    S.initial = { skin = copy(S.skin), comps = copy(S.comps) }
    applyAll()
    valuesFromLook()
    Scene.lightPed = p
    local sp = Config.CreatorScene.stage
    Cam.Start(p, sp, sp.w, "general")
    return true
end

-- =====================================================================
--  ABRIR / FECHAR
-- =====================================================================

-- opts.firstCharacter: não há seleção para onde voltar
-- opts.edit = { skin, comps, height, model, returnTo = vector4 }: modo /skinmenu
function Creator.Open(opts)
    Creator.active = true
    opts = opts or {}
    S = { opts = opts, values = {}, height = (opts.edit and opts.edit.height) or Config.Identity.DefaultHeight }
    S.tab = opts.edit and "face" or "identity"
    local year = (Today and Today.year or 1899) - math.max(Config.Identity.MinAge, 25)
    S.birth = { day = 1, month = 1, year = year }
    if not IsScreenFadedOut() then
        DoScreenFadeOut(500)
        repeat Wait(0) until IsScreenFadedOut()
    end
    N.Spinner(L("sel_loading"))
    Scene.Enter("creator")
    BusyspinnerOff()

    if opts.edit then
        local comps = {}
        for k, v in pairs(opts.edit.comps or {}) do comps[k] = type(v) == "table" and v.comp or v end
        setModel(opts.edit.model, { skin = opts.edit.skin, comps = comps })
    else
        -- cutscene inicial: escolhe homem ou mulher (devolve nil se estiver desligada)
        local chosen = Intro.Play()
        -- escolhido na cutscene => já não se pode trocar no menu
        S.genderLocked = chosen ~= nil
        setModel(chosen or "mp_male")
    end

    UI.Open(creatorView(), { closable = false })
    Wait(300)
    DoScreenFadeIn(1500)
end

function Creator.Cleanup()
    if not Creator.active then return end
    Creator.active = false
end

-- Fecha o modo /skinmenu e devolve o jogador ao sítio onde estava
local function endEdit(skin, comps)
    local edit = S.opts.edit
    UI.Close()
    DoScreenFadeOut(600)
    repeat Wait(0) until IsScreenFadedOut()
    Cam.Stop()
    Creator.Cleanup()
    Scene.Leave()

    CurrentSkin = skin
    CurrentComps = {}
    for k, v in pairs(comps) do
        CurrentComps[k] = type(v) == "table" and v or { comp = v, tint0 = 0, tint1 = 0, tint2 = 0, palette = 0 }
    end
    local p = PlayerPedId()
    Look.Apply(p, CurrentSkin, CurrentComps)
    Look.ReleaseAll(p)
    local r = edit.returnTo
    Scene.Teleport(r)
    SetEntityHeading(PlayerPedId(), r.w)
    SetEntityInvincible(PlayerPedId(), false)
    DisplayRadar(true)
    Scene.SetExternalHud(true)
    DoScreenFadeIn(1000)
end

-- Aberto pelo servidor (/skinmenu)
RegisterNetEvent("fks-character:client:skinMenu", function(payload)
    if Creator.active or type(payload) ~= "table" then return end
    local p = PlayerPedId()
    local c = GetEntityCoords(p)
    payload.returnTo = vector4(c.x, c.y, c.z, GetEntityHeading(p))
    Creator.Open({ edit = payload })
end)

-- =====================================================================
--  NUI
-- =====================================================================

UI.On("cr:set", function(data)
    if not Creator.active or type(data.id) ~= "string" then return { ok = false } end
    local patch = dispatch(data.id, data.value)
    return { ok = true, patch = patch }
end)

UI.On("cr:model", function(data)
    if not Creator.active or S.genderLocked or S.opts.edit then return { ok = false } end
    local model = data.value == "mp_female" and "mp_female" or "mp_male"
    if model == S.model then return { ok = true } end
    DoScreenFadeOut(300)
    repeat Wait(0) until IsScreenFadedOut()
    setModel(model)
    DoScreenFadeIn(500)
    -- outro modelo = outras opções (barba, maquilhagem, roupa): a vista é refeita, o formulário fica
    return { ok = true, view = creatorView() }
end)

UI.On("cr:random", function()
    if not Creator.active then return { ok = false } end
    S.skin, S.comps = randomLook()
    applyAll()
    valuesFromLook()
    return { ok = true, view = creatorView() }
end)

UI.On("cr:reset", function()
    if not Creator.active or not S.initial then return { ok = false } end
    S.skin, S.comps = copy(S.initial.skin), copy(S.initial.comps)
    applyAll()
    valuesFromLook()
    return { ok = true, view = creatorView() }
end)

-- Nome escrito -> título do painel
UI.On("cr:name", function(data)
    if not Creator.active then return end
    local v = data.values or {}
    local full = ("%s %s"):format(filled(v.firstname) or "", filled(v.lastname) or ""):match("^%s*(.-)%s*$")
    S.title = full ~= "" and full or nil
    return { patch = { title = { text = S.title or L("cr_new") } } }
end)

-- Data de nascimento -> idade por baixo
UI.On("cr:birth", function(data)
    if not Creator.active or type(data.value) ~= "table" then return end
    local b = data.value
    S.birth = { day = tonumber(b.day) or 1, month = tonumber(b.month) or 1, year = tonumber(b.year) or S.birth.year }
    return { patch = { birth = { note = L("id_age_preview", ageOf(S.birth)) } } }
end)

UI.On("cr:height", function(data)
    local h = tonumber(data.value)
    if not h then return { ok = false } end
    S.height = math.max(Config.Identity.MinHeight, math.min(Config.Identity.MaxHeight, math.floor(h)))
    if Config.Identity.ApplyHeightScale then
        SetPedScale(ped(), Validate.HeightToScale(S.height, S.model) + 0.0)
    end
    return { ok = true }
end)

-- Mudança de separador: câmara do separador e, no "Finalizar", o resumo atualizado
UI.On("page", function(data)
    if not Creator.active then return end
    S.tab = data.to
    local res = { patch = {} }
    local preset = Config.Cameras.TabPresets[data.to]
    if preset then
        Cam.SetPreset(preset)
        res.patch.camera = { preset = preset }
    end
    if data.to == "finish" then res.patch.summary = { items = summaryItems(data.values or {}) } end
    return res
end)

-- erro da validação -> campo do formulário onde aparece
local ERR_FIELD = {
    err_date_invalid = "birth", err_date_future = "birth", err_age_min = "birth", err_age_max = "birth",
    err_height = "height", err_gender = "model",
    err_nationality_required = "nationality", err_nationality_length = "nationality", err_nationality_invalid = "nationality",
    err_birthplace_required = "birthplace", err_birthplace_length = "birthplace", err_birthplace_invalid = "birthplace",
    err_biography_required = "biography", err_biography_length = "biography", err_biography_invalid = "biography",
}

local function errorField(err, identity)
    if ERR_FIELD[err] then return ERR_FIELD[err] end
    if tostring(err):find("^err_name") then
        return Validate.Name(identity.firstname) and "lastname" or "firstname"
    end
end

local function identityFrom(v)
    local b = type(v.birth) == "table" and v.birth or S.birth
    local function text(x) return type(x) == "string" and x or "" end
    return {
        firstname = text(v.firstname), lastname = text(v.lastname),
        day = tonumber(b.day), month = tonumber(b.month), year = tonumber(b.year),
        height = tonumber(v.height) or S.height, model = S.model,
        nationality = text(v.nationality), birthplace = text(v.birthplace), biography = text(v.biography),
    }
end

UI.On("cr:cancel", function()
    if not Creator.active or S.opts.firstCharacter then return { ok = false } end
    if S.opts.edit then
        ServerCall("skinmenu:cancel")
        local original = S.opts.edit
        endEdit(original.skin, original.comps)
        return { ok = true }
    end
    UI.Close()
    DoScreenFadeOut(800)
    repeat Wait(0) until IsScreenFadedOut()
    Cam.Stop()
    Look.ReleaseAll()
    Creator.Cleanup()
    Selection.Return()
    return { ok = true }
end)

UI.On("cr:finish", function(data)
    if not Creator.active or S.opts.edit then return { ok = false, error = "err_generic" } end
    local v = data.values or {}
    local identity = identityFrom(v)
    local checked, err = Validate.Identity(identity, Today)
    if not checked then
        local field = errorField(err, identity)
        if field then return { errors = { [field] = L(err) } } end   -- volta ao campo, na Identidade
        return { ok = false, error = err }
    end

    -- há kits iniciais: primeiro escolhe-se um (o ecrã dos kits volta a chamar esta ação)
    local kits = Selection.payload and Selection.payload.kits
    local kit = type(v.kit) == "string" and v.kit or nil
    if kits and kits.list and #kits.list > 0 and not kit then return { go = "kits" } end

    UI.Loading(L("creating"))
    local res = ServerCall("create", {
        identity = identity,
        skin = S.skin,
        comps = S.comps,
        spawn = tonumber(v.spawn),
        kit = kit,
    }, Config.Session.LoadTimeout + 5000)

    if not res or not res.ok then
        UI.Loading(false)
        res = res or { ok = false, error = "err_generic" }
        local field = res.error and errorField(res.error, identity)
        if field then return { errors = { [field] = L(res.error) } } end
        return res
    end

    PlaySoundFrontend("Ready_Up_Flash", "RDRO_In_Game_Menu_Sounds", true, 0)
    AnimpostfxPlay("RespawnPulse01")
    DoScreenFadeOut(1000)
    repeat Wait(0) until IsScreenFadedOut()
    LoadCharacterIntoWorld(res, true)
    return { ok = true }
end)

-- Modo /skinmenu: guardar a nova aparência
UI.On("cr:save", function(data)
    if not Creator.active or not S.opts.edit then return { ok = false, error = "err_generic" } end
    UI.Loading(L("saving"))
    local res = ServerCall("skinmenu:save", {
        skin = S.skin, comps = S.comps, height = tonumber((data.values or {}).height) or S.height,
    })
    if not res or not res.ok then
        UI.Loading(false)
        return res or { ok = false, error = "err_generic" }
    end
    UI.Loading(false)
    endEdit(res.skin, res.comps)
    return { ok = true }
end)
