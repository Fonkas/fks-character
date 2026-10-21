-- Catálogo derivado dos dados do jogo, usado pelo cliente (UI / natives)
-- e pelo servidor (validação). Construído uma vez por modelo e guardado em cache.

Catalog = {}

local cache = {}

local function formatList(list, letter)
    local out = {}
    for i, name in ipairs(list) do
        out[i] = joaat(name:format(letter))
    end
    return out
end

local function variantsList(groups, field)
    local out = {}
    for _, group in ipairs(groups or {}) do
        local variants = {}
        for _, v in ipairs(group) do
            variants[#variants + 1] = v[field or "hash"]
        end
        if #variants > 0 then out[#out + 1] = variants end
    end
    return out
end

local function clothingList(groups)
    local out = {}
    for _, group in ipairs(groups or {}) do
        local variants = {}
        for _, v in ipairs(group) do
            if v.hash and v.hash ~= 0 then
                variants[#variants + 1] = { hash = v.hash, remove = v.remove }
            end
        end
        if #variants > 0 then out[#out + 1] = variants end
    end
    return out
end

function Catalog.Get(model)
    if cache[model] then return cache[model] end
    local letter = Appearance.GenderLetter(model)
    local hairGender = Appearance.HairGender(model)
    local dataGender = Appearance.DataGender(model)

    local c = { model = model, tones = {}, sets = {} }

    for i, tone in ipairs(Appearance.SkinTones) do
        c.tones[i] = {
            heads = formatList(tone.heads, letter),
            bodies = formatList(tone.bodies, letter),
            legs = formatList(tone.legs, letter),
            albedo = joaat(tone.albedo:format(letter)),
        }
    end

    c.eyes = formatList(Appearance.Eyes, letter)
    c.teeth = formatList(Appearance.Teeth, letter)

    local hairData = HairComponents and HairComponents[hairGender] or {}
    c.hair = variantsList(hairData.hair)
    c.beard = variantsList(hairData.beard)

    c.clothing = {}
    local clothingData = Data and Data.clothing and Data.clothing[dataGender] or {}
    for key, groups in pairs(clothingData) do
        c.clothing[key] = clothingList(groups)
    end

    -- Conjuntos para validação O(1)
    local function toSet(name, list)
        local s = {}
        for _, h in ipairs(list) do s[h] = true end
        c.sets[name] = s
    end

    local heads, bodies, legs, albedos = {}, {}, {}, {}
    for _, t in ipairs(c.tones) do
        for _, h in ipairs(t.heads) do heads[#heads + 1] = h end
        for _, h in ipairs(t.bodies) do bodies[#bodies + 1] = h end
        for _, h in ipairs(t.legs) do legs[#legs + 1] = h end
        albedos[#albedos + 1] = t.albedo
    end
    toSet("heads", heads)
    toSet("bodies", bodies)
    toSet("legs", legs)
    toSet("albedo", albedos)
    toSet("eyes", c.eyes)
    toSet("teeth", c.teeth)
    toSet("bodyShape", Appearance.BodyShapes)
    toSet("waist", Appearance.Waists)
    toSet("palette", Appearance.Palettes)

    local function flatten(groups)
        local flat = {}
        for _, g in ipairs(groups) do
            for _, v in ipairs(g) do flat[#flat + 1] = type(v) == "table" and v.hash or v end
        end
        return flat
    end
    toSet("hair", flatten(c.hair))
    toSet("beard", flatten(c.beard))

    c.clothingSets = {}
    for key, groups in pairs(c.clothing) do
        local s = {}
        for _, h in ipairs(flatten(groups)) do s[h] = true end
        c.clothingSets[key] = s
    end

    cache[model] = c
    return c
end

-- Encontra (grupo, variante) de um hash numa lista de grupos
function Catalog.FindIndex(groups, hash)
    if not hash or hash == 0 or hash == -1 then return 0, 1 end
    for gi, g in ipairs(groups) do
        for vi, v in ipairs(g) do
            local h = type(v) == "table" and v.hash or v
            if h == hash then return gi, vi end
        end
    end
    return 0, 1
end

function Catalog.FindInList(list, hash)
    for i, h in ipairs(list) do
        if h == hash then return i end
    end
    return nil
end

-- Lista de categorias de roupa disponíveis no criador para um modelo
function Catalog.StarterCategories(model)
    local out = {}
    local sc = Config.StarterClothing
    if not sc.Enabled then return out end
    local gender = Appearance.DataGender(model)
    local c = Catalog.Get(model)
    for _, cat in ipairs(sc.Categories) do
        local allowed = (not cat.allow or sc[cat.allow]) and (not cat.gender or cat.gender == gender)
        if allowed and c.clothing[cat.key] and #c.clothing[cat.key] > 0 then
            out[#out + 1] = cat
        end
    end
    return out
end

function Catalog.ClothingCount(model, key)
    local list = Catalog.Get(model).clothing[key] or {}
    local max = Config.StarterClothing.MaxItemsPerCategory
    if max and max < #list then return max end
    return #list
end
