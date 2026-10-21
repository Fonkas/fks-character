-- Validação partilhada. O cliente usa-a para feedback imediato,
-- o servidor volta a correr TUDO e é a única fonte de verdade.

Validate = {}

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Letras latinas (ASCII + Latin-1 Supplement + Latin Extended-A/B)
local function isLetter(cp)
    if (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122) then return true end
    if cp >= 0xC0 and cp <= 0x24F and cp ~= 0xD7 and cp ~= 0xF7 then return true end
    return false
end

local separators = { [32] = true, [39] = true, [45] = true } -- espaço ' -

local function isLeapYear(y)
    return (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0
end

function Validate.DaysInMonth(m, y)
    local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if m == 2 and isLeapYear(y) then return 29 end
    return days[m]
end

local function toInt(v)
    local n = tonumber(v)
    if not n or n ~= n or n ~= math.floor(n) then return nil end
    return n
end

-- Devolve nome limpo ou nil, chaveErro
function Validate.Name(value, allowSpaces)
    if type(value) ~= "string" then return nil, "err_name_empty" end
    value = trim(value)
    if value == "" then return nil, "err_name_empty" end

    local ok, len = pcall(utf8.len, value)
    if not ok or not len then return nil, "err_name_chars" end
    local id = Config.Identity
    if len < id.NameMinLength or len > id.NameMaxLength then return nil, "err_name_length" end

    local prevSep = true -- não pode começar com separador
    for _, cp in utf8.codes(value) do
        if separators[cp] then
            if prevSep or (cp == 32 and not allowSpaces) then return nil, "err_name_chars" end
            prevSep = true
        elseif isLetter(cp) then
            prevSep = false
        else
            return nil, "err_name_chars"
        end
    end
    if prevSep then return nil, "err_name_chars" end

    local lower = value:lower()
    for _, word in ipairs(id.BannedNames or {}) do
        if lower:find(word:lower(), 1, true) then return nil, "err_name_banned" end
    end

    -- primeira letra maiúscula (ASCII)
    value = value:sub(1, 1):upper() .. value:sub(2)
    return value
end

local function optionalText(value, maxLen, required, errKey)
    if value == nil or value == "" then
        if required then return nil, errKey .. "_required" end
        return ""
    end
    if type(value) ~= "string" then return nil, errKey .. "_invalid" end
    value = trim(value)
    if value == "" then
        if required then return nil, errKey .. "_required" end
        return ""
    end
    local ok, len = pcall(utf8.len, value)
    if not ok or not len or len > maxLen then return nil, errKey .. "_length" end
    -- sem caracteres de controlo nem markup
    if value:find("[%c<>]") then
        -- permite quebras de linha apenas na biografia
        local stripped = value:gsub("[\r\n]", "")
        if stripped:find("[%c<>]") then return nil, errKey .. "_invalid" end
    end
    return value
end

-- today = { year = n, month = n, day = n } (o servidor envia ao cliente)
function Validate.Age(day, month, year, today)
    local age = today.year - year
    if today.month < month or (today.month == month and today.day < day) then
        age = age - 1
    end
    return age
end

function Validate.Identity(data, today)
    if type(data) ~= "table" then return nil, "err_generic" end
    local id = Config.Identity
    local out = {}
    local err

    out.firstname, err = Validate.Name(data.firstname, false)
    if not out.firstname then return nil, err end
    out.lastname, err = Validate.Name(data.lastname, true)
    if not out.lastname then return nil, err end

    -- Data de nascimento
    local d, m, y = toInt(data.day), toInt(data.month), toInt(data.year)
    if not d or not m or not y then return nil, "err_date_invalid" end
    if m < 1 or m > 12 or d < 1 or d > Validate.DaysInMonth(m, y) then return nil, "err_date_invalid" end
    if y > today.year or (y == today.year and (m > today.month or (m == today.month and d > today.day))) then
        return nil, "err_date_future"
    end
    local age = Validate.Age(d, m, y, today)
    if age < id.MinAge then return nil, "err_age_min" end
    if age > id.MaxAge then return nil, "err_age_max" end
    out.day, out.month, out.year, out.age = d, m, y, age
    out.birthdate = ("%04d-%02d-%02d"):format(y, m, d)

    -- Género / modelo
    if data.model ~= "mp_male" and data.model ~= "mp_female" then return nil, "err_gender" end
    out.model = data.model
    out.gender = data.model == "mp_male" and "Male" or "Female"

    -- Altura
    local h = toInt(data.height)
    if not h or h < id.MinHeight or h > id.MaxHeight then return nil, "err_height" end
    out.height = h

    out.nationality, err = optionalText(data.nationality, id.NationalityMaxLength, id.RequireNationality, "err_nationality")
    if not out.nationality then return nil, err end
    out.birthplace, err = optionalText(data.birthplace, id.BirthplaceMaxLength, id.RequireBirthplace, "err_birthplace")
    if not out.birthplace then return nil, err end
    out.biography, err = optionalText(data.biography, id.BiographyMaxLength, id.RequireBiography, "err_biography")
    if not out.biography then return nil, err end

    return out
end

-- Converte a altura (cm) em escala do ped, se ativo
-- Escala exata do ped para a altura pedida (cm), em relação à altura base do modelo
function Validate.HeightToScale(height, model)
    local id = Config.Identity
    if not id.ApplyHeightScale then return 1.0 end
    height = math.max(id.MinHeight, math.min(id.MaxHeight, tonumber(height) or id.DefaultHeight))
    local base = (id.BaseHeight and id.BaseHeight[model or "mp_male"]) or 180
    return math.floor(height / base * 1000 + 0.5) / 1000
end

local function clampFloat(v, min, max, default)
    v = tonumber(v)
    if not v or v ~= v then return default end
    if v < min then return min end
    if v > max then return max end
    return v
end

local function intIn(v, min, max, default)
    v = toInt(v)
    if not v or v < min or v > max then return default end
    return v
end

-- Reconstrói a pele apenas com valores conhecidos e permitidos.
-- Devolve skin, comps ou nil, erro.
function Validate.Appearance(model, skin, comps)
    if model ~= "mp_male" and model ~= "mp_female" then return nil, "err_gender" end
    if type(skin) ~= "table" or type(comps) ~= "table" then return nil, "err_appearance" end
    local c = Catalog.Get(model)
    local s = c.sets
    local out = Appearance.DefaultSkin(model)

    local function hashIn(set, value, required)
        value = toInt(value)
        if value and set[value] then return value end
        if required then return nil end
        return 0
    end

    out.HeadType = hashIn(s.heads, skin.HeadType, true)
    out.BodyType = hashIn(s.bodies, skin.BodyType, true)
    out.Torso = hashIn(s.bodies, skin.Torso, true)
    out.LegsType = hashIn(s.legs, skin.LegsType, true)
    out.albedo = hashIn(s.albedo, skin.albedo, true)
    out.Eyes = hashIn(s.eyes, skin.Eyes, true)
    if not (out.HeadType and out.BodyType and out.Torso and out.LegsType and out.albedo and out.Eyes) then
        return nil, "err_appearance"
    end
    out.Body = hashIn(s.bodyShape, skin.Body, false)
    out.Waist = hashIn(s.waist, skin.Waist, false)
    out.Hair = hashIn(s.hair, skin.Hair, false)
    out.Beard = model == "mp_male" and hashIn(s.beard, skin.Beard, false) or 0

    for _, f in ipairs(Appearance.Features) do
        out[f.key] = clampFloat(skin[f.key], -1.0, 1.0, 0.0)
    end

    local makeupAllowed = Config.Makeup.Enabled and (not Config.Makeup.FemaleOnly or model == "mp_female")
    local makeup = { eyeliners = true, lipsticks = true, shadows = true, blush = true }

    for _, o in ipairs(Appearance.Overlays) do
        local p = o.prefix
        local count = #Appearance.OverlayIds[o.name]
        local enabled = not (makeup[o.name] and not makeupAllowed)
            and not (o.name == "beardstabble" and model ~= "mp_male")
        local tx = intIn(skin[p .. "_tx_id"], 0, count, 0)
        local opacity = clampFloat(skin[p .. "_opacity"], 0.0, 1.0, 0.0)
        local visible = enabled and tx > 0 and opacity > 0.0
        if o.fixedTexture and enabled and opacity > 0.0 then
            tx, visible = 1, true
        end
        out[p .. "_visibility"] = visible and 1 or 0
        out[p .. "_tx_id"] = visible and tx or 0
        out[p .. "_opacity"] = visible and opacity or 0.0
        if o.colorKey then
            local color = toInt(skin[o.colorKey])
            out[o.colorKey] = (color and s.palette[color]) and color or 0
        end
        if o.variantKey then
            out[o.variantKey] = intIn(skin[o.variantKey], 0, o.variants, 0)
        end
    end

    out.Scale = 1.0

    -- Roupa: só categorias da lista inicial e hashes que existam nos dados do jogo
    local cleanComps = {}
    for _, key in ipairs(Appearance.ClothingKeys) do cleanComps[key] = -1 end
    local allowedCats = {}
    for _, cat in ipairs(Catalog.StarterCategories(model)) do allowedCats[cat.key] = true end

    for key, value in pairs(comps) do
        if type(key) == "string" and allowedCats[key] then
            local hash = toInt(type(value) == "table" and value.comp or value)
            if hash and hash ~= -1 then
                local set = c.clothingSets[key]
                if not set or not set[hash] then return nil, "err_clothing" end
                -- respeitar o limite de modelos por categoria
                local gi = Catalog.FindIndex(c.clothing[key], hash)
                if gi == 0 or gi > Catalog.ClothingCount(model, key) then return nil, "err_clothing" end
                cleanComps[key] = hash
            end
        end
    end

    -- Remover combinações incompatíveis (a primeira na ordem de StarterClothing ganha)
    for _, cat in ipairs(Config.StarterClothing.Categories) do
        if cleanComps[cat.key] and cleanComps[cat.key] ~= -1 then
            for _, other in ipairs(Appearance.Incompatible[cat.key] or {}) do
                cleanComps[other] = -1
            end
        end
    end

    -- Dentes e cinturão base (como o vorp_character)
    local teeth = toInt(type(comps.Teeth) == "table" and comps.Teeth.comp or comps.Teeth)
    cleanComps.Teeth = (teeth and s.teeth[teeth]) and teeth or c.teeth[1]

    return out, cleanComps
end
