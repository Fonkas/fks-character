-- Dados de aparência dos modelos mp_male / mp_female (hashes do jogo RDR2).
-- O formato de `skin` e `comps` é idêntico ao do vorp_character para manter
-- compatibilidade com vorp_barbershop, lojas de roupa e restantes recursos.

Appearance = {}

Appearance.Models = { "mp_male", "mp_female" }

-- Tons de pele: cada um define as cabeças, troncos, pernas e albedo disponíveis.
-- %s = "M" ou "F"
local function skinTone(variant, albedoCode)
    local heads, bodies, legs = {}, {}, {}
    for _, n in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 18, 21, 22, 25, 28 }) do
        heads[#heads + 1] = ("CLOTHING_ITEM_%%s_HEAD_%03d_V_%03d"):format(n, variant)
    end
    for n = 1, 5 do
        bodies[#bodies + 1] = ("CLOTHING_ITEM_%%s_BODIES_UPPER_%03d_V_%03d"):format(n, variant)
        legs[#legs + 1] = ("CLOTHING_ITEM_%%s_BODIES_LOWER_%03d_V_%03d"):format(n, variant)
    end
    return { heads = heads, bodies = bodies, legs = legs, albedo = ("MP_HEAD_%%sR1_%s_C0_000_AB"):format(albedoCode) }
end

Appearance.SkinTones = {
    skinTone(1, "SC08"),
    skinTone(2, "SC01"),
    skinTone(3, "SC02"),
    skinTone(4, "SC03"),
    skinTone(5, "SC04"),
    skinTone(6, "SC05"),
}

Appearance.Eyes = {}
for i = 1, 14 do
    Appearance.Eyes[i] = ("CLOTHING_ITEM_%%s_EYES_001_TINT_%03d"):format(i)
end

Appearance.Teeth = {}
for i = 0, 6 do
    Appearance.Teeth[#Appearance.Teeth + 1] = ("CLOTHING_ITEM_%%s_TEETH_%03d"):format(i)
end

-- Constituição (meta ped outfits)
Appearance.BodyShapes = { 61606861, -1241887289, -369348190, 32611963, -20262001 }
Appearance.Waists = {
    -2045421226, -1745814259, -325933489, -1065791927, -844699484, -1273449080, 927185840,
    149872391, 399015098, -644349862, 1745919061, 1004225511, 1278600348, 502499352,
    -2093198664, -1837436619, 1736416063, 2040610690, -1173634986, -867801909, 1960266524,
}

-- Morfologia facial / corporal (SetCharExpression). Valores -1.0 .. 1.0
-- group = separador da NUI onde o slider aparece
Appearance.Features = {
    -- Cabeça e rosto
    { key = "HeadSize",    hash = 0x84D6, group = "face", section = "head" },
    { key = "FaceW",       hash = 41396,  group = "face", section = "head" },
    { key = "FaceD",       hash = 12281,  group = "face", section = "head" },
    { key = "FaceS",       hash = 13059,  group = "face", section = "head" },
    { key = "NeckW",       hash = 36277,  group = "face", section = "head" },
    { key = "NeckD",       hash = 60890,  group = "face", section = "head" },
    -- Maxilar e queixo
    { key = "JawH",        hash = 0x8D0A, group = "face", section = "jaw" },
    { key = "JawW",        hash = 0xEBAE, group = "face", section = "jaw" },
    { key = "JawD",        hash = 0x1DF6, group = "face", section = "jaw" },
    { key = "ChinH",       hash = 0x3C0F, group = "face", section = "chin" },
    { key = "ChinW",       hash = 0xC3B2, group = "face", section = "chin" },
    { key = "ChinD",       hash = 0xE323, group = "face", section = "chin" },
    -- Maçãs do rosto
    { key = "CheekBonesH", hash = 0x6A0B, group = "face", section = "cheek" },
    { key = "CheekBonesW", hash = 0xABCF, group = "face", section = "cheek" },
    { key = "CheekBonesD", hash = 0x358D, group = "face", section = "cheek" },
    -- Nariz
    { key = "NoseW",       hash = 0x6E7F, group = "face", section = "nose" },
    { key = "NoseS",       hash = 0x3471, group = "face", section = "nose" },
    { key = "NoseH",       hash = 0x03F5, group = "face", section = "nose" },
    { key = "NoseAng",     hash = 0x34B1, group = "face", section = "nose" },
    { key = "NoseC",       hash = 0xF156, group = "face", section = "nose" },
    { key = "NoseDis",     hash = 0x561E, group = "face", section = "nose" },
    -- Boca e lábios
    { key = "MouthW",      hash = 0xF065, group = "face", section = "mouth" },
    { key = "MouthD",      hash = 0xAA69, group = "face", section = "mouth" },
    { key = "MouthX",      hash = 0x7AC3, group = "face", section = "mouth" },
    { key = "MouthY",      hash = 0x410D, group = "face", section = "mouth" },
    { key = "ULiphH",      hash = 0x1A00, group = "face", section = "mouth" },
    { key = "ULiphW",      hash = 0x91C1, group = "face", section = "mouth" },
    { key = "ULiphD",      hash = 0xC375, group = "face", section = "mouth" },
    { key = "LLiphH",      hash = 0xBB4D, group = "face", section = "mouth" },
    { key = "LLiphW",      hash = 0xB0B0, group = "face", section = "mouth" },
    { key = "LLiphD",      hash = 0x5D16, group = "face", section = "mouth" },
    { key = "MouthCLW",    hash = 57350,  group = "face", section = "mouth" },
    { key = "MouthCRW",    hash = 60292,  group = "face", section = "mouth" },
    { key = "MouthCLD",    hash = 40950,  group = "face", section = "mouth" },
    { key = "MouthCRD",    hash = 49299,  group = "face", section = "mouth" },
    { key = "MouthCLH",    hash = 46661,  group = "face", section = "mouth" },
    { key = "MouthCRH",    hash = 55718,  group = "face", section = "mouth" },
    { key = "MouthCLLD",   hash = 22344,  group = "face", section = "mouth" },
    { key = "MouthCRLD",   hash = 9423,   group = "face", section = "mouth" },
    -- Orelhas
    { key = "EarsW",       hash = 0xC04F, group = "face", section = "ears" },
    { key = "EarsA",       hash = 0xB6CE, group = "face", section = "ears" },
    { key = "EarsH",       hash = 0x2844, group = "face", section = "ears" },
    { key = "EarsD",       hash = 0xED30, group = "face", section = "ears" },
    -- Olhos e sobrancelhas
    { key = "EyeBrowH",    hash = 0x3303, group = "eyes", section = "brows" },
    { key = "EyeBrowW",    hash = 0x2FF9, group = "eyes", section = "brows" },
    { key = "EyeBrowD",    hash = 0x4AD1, group = "eyes", section = "brows" },
    { key = "EyeD",        hash = 0xEE44, group = "eyes", section = "eyes" },
    { key = "EyeAng",      hash = 0xD266, group = "eyes", section = "eyes" },
    { key = "EyeDis",      hash = 0xA54E, group = "eyes", section = "eyes" },
    { key = "EyeH",        hash = 0xDDFB, group = "eyes", section = "eyes" },
    { key = "EyeLidH",     hash = 0x8B2B, group = "eyes", section = "eyes" },
    { key = "EyeLidW",     hash = 0x1B6B, group = "eyes", section = "eyes" },
    { key = "EyeLidL",     hash = 52902,  group = "eyes", section = "eyes" },
    { key = "EyeLidR",     hash = 22421,  group = "eyes", section = "eyes" },
    -- Corpo
    { key = "ArmsS",       hash = 46032,  group = "body", section = "upper" },
    { key = "ShouldersS",  hash = 50039,  group = "body", section = "upper" },
    { key = "ShouldersT",  hash = 7010,   group = "body", section = "upper" },
    { key = "ShouldersM",  hash = 18046,  group = "body", section = "upper" },
    { key = "ChestS",      hash = 27779,  group = "body", section = "upper" },
    { key = "WaistW",      hash = 50460,  group = "body", section = "upper" },
    { key = "HipsS",       hash = 49787,  group = "body", section = "upper" },
    { key = "LegsS",       hash = 64834,  group = "body", section = "lower" },
    { key = "CalvesS",     hash = 42067,  group = "body", section = "lower" },
}

Appearance.FeatureHash = {}
for _, f in ipairs(Appearance.Features) do Appearance.FeatureHash[f.key] = f.hash end

-- Paletas de cor (METAPED_TINT_*) utilizadas nos overlays
local palettes = {}
for _, name in ipairs({
    "METAPED_TINT_MAKEUP", "METAPED_TINT_SKIRT_CLEAN", "METAPED_TINT_HAT_WORN", "METAPED_TINT_SWATCH_002",
    "METAPED_TINT_HAT_CLEAN", "METAPED_TINT_SWATCH_003", "METAPED_TINT_GENERIC_CLEAN", "METAPED_TINT_HAT_WEATHERED",
    "METAPED_TINT_COMBINED", "METAPED_TINT_HORSE_LEATHER", "METAPED_TINT_ANIMAL", "METAPED_TINT_SWATCH_001",
    "METAPED_TINT_HORSE", "METAPED_TINT_EYE", "METAPED_TINT_EYES_UI", "METAPED_TINT_GENERIC_CLEAN",
    "METAPED_TINT_GENERIC_WORN", "METAPED_TINT_SKIRT_WEATHERED", "METAPED_TINT_SWATCH_000", "METAPED_TINT_LEATHER",
    "METAPED_TINT_COMBINED_LEATHER1", "METAPED_TINT_COMBINED_LEATHER2", "METAPED_TINT_COMBINED_LEATHER3",
    "METAPED_TINT_COMBINED_LEATHER4", "METAPED_TINT_COMBINED_LEATHER5", "METAPED_TINT_COMBINED_LEATHER6",
    "METAPED_TINT_MPADV", "METAPED_TINT_SKIRT_WORN", "METAPED_TINT_HAIR", "METAPED_TINT_HAIR1", "METAPED_TINT_HAIR2",
    "METAPED_TINT_HAIR_BED", "METAPED_TINT_HAIR_UI", "METAPED_TINT_COMBINED_LEATHER", "METAPED_TINT_GENERIC_WEATHERED",
    "METAPED_TINT_HAT", "METAPED_TINT_MPADV_DEUTERANOPIA", "METAPED_TINT_TEETH", "METAPED_TINT_MPADV_PROTANOPIA",
    "METAPED_TINT_MPADV_TRITANOPIA", "METAPED_TINT_SI_TEMPLATE", "WEAPON_TINT_WOOD", "WEAPON_TINT_WOOD_WORKING",
}) do
    palettes[#palettes + 1] = joaat(name)
end
Appearance.Palettes = palettes
Appearance.DefaultOverlayColor = 0x3F6E70FF

-- Overlays de textura da cabeça (ids extraídos dos ficheiros do jogo)
-- Apenas o `id` é necessário para compor a textura.
Appearance.OverlayIds = {
    eyebrows = { 0x07844317, 0x0A83CA6E, 0x139A5CA3, 0x1832E474, 0x216EF84C, 0x2594304D, 0x33C39BC5, 0x443E3CBA, 0x4F5052DE, 0x5C049D35, 0x77A1546E, 0x8A4B79C2, 0x9728137B, 0xA6DE8325, 0xA8CCB6C4, 0xB3F74D19, 0xBD38AFD9, 0xCD0A4F7C, 0xD0EC86FF, 0xEB088A20, 0xF0CA96FC, 0xF3351BD9, 0xF9052779, 0xFE183197 },
    scars = { 0xC8E45B5B, 0x90D86B44, 0x23190FC3, 0x7574B47D, 0x7FE8C965, 0x083059FE, 0x19E9FD71, 0x4CAF62FB, 0xDE650668, 0xC648562B, 0x484BAEF8, 0x190F5080, 0x2B5DF51D, 0xE490E784, 0x0ED23C06, 0x5712CCB6 },
    eyeliners = { 0x29A2E58F },
    lipsticks = { 0x887E11E0 },
    acne = { 0x96DD8F42 },
    shadows = { 0x47BD7289 },
    beardstabble = { 0x375D4807 },
    paintedmasks = { 0x5995AA6F },
    ageing = { 0x96DD8F42, 0x6D9DC405, 0x2761B792, 0x19009AD0, 0xC29F6E07, 0xA45F3187, 0x5E21250C, 0x4FFE08C6, 0x2DAD4485, 0x3F70680B, 0xD3310F8E, 0xF27A4C84, 0x0044E819, 0xA648348D, 0x94F991F0, 0xCAACFD56, 0xB9675ACB, 0x3C2CE03C, 0xF2D64D90, 0xE389AEF7, 0x89317A44, 0x64B3347C, 0x9FFDAB10, 0x91D40EBD, 0x6B94C23F },
    blush = { 0x6DB440FA, 0x47617455, 0x114D082D, 0xEC6F3E72 },
    complex = { 0xF679EDE7, 0x3FFB80ED, 0x31C0E478, 0x2457C9A6, 0x16262D43, 0x88F312DB, 0x785C71AE, 0x6D7D5BF0, 0x5F2FBF55, 0xBF38FF6A, 0xF5656C26, 0x03A408A3, 0x293453C3, 0x43150800 },
    disc = { 0xD44A5ABA, 0xE2CF77C4, 0xCF57D0E9, 0xE0A8738A, 0xABD109DC, 0xB91C2472, 0x894844B7, 0x96FAE01C, 0x86D3BFCE, 0x5488DB39, 0x7DA5A5AE, 0xE73778DC, 0xD83EDADF, 0xE380F163, 0xB4611324, 0xC6ABB7B9 },
    foundation = { 0xEF5AB280 },
    freckles = { 0x1B794C51, 0x29BFE8DE, 0x0EF6B34C, 0x64925E7E, 0xF5F280FC, 0x33B0FC78, 0x25675FE5, 0xD10F3736, 0x5126B75F, 0x6B8EEC2F, 0x0A9A26F7, 0xFDE40D8B, 0x7E338E44, 0x70F273C2, 0x61C7D56D },
    grime = { 0xA2F30923, 0xD5B1EEA0, 0x7EC740CC, 0xB08F245B, 0x1A5E77F8, 0xE81B9373, 0x3CFA3D2F, 0x0B865A48, 0x506DE416, 0x1F250185, 0xE71930B0, 0xDE571F2C, 0x0CA6FBCB, 0x21F62669, 0xFB09D881, 0x11530513 },
    hair = { 0x39051515, 0x5E71DFEE, 0xDD735DEF, 0x69622EAD },
    moles = { 0x821FD077, 0xCD38E6A8, 0x9F9D8B72, 0xE7179A39, 0xBB094249, 0x03AC5362, 0x154FF6A9, 0x1E23084F, 0x31DBAFC0, 0x3AC5C194, 0x4500D516, 0x3695B840, 0x286C1BED, 0x934BF1AF, 0x84F55502, 0xBD9A464B },
    spots = { 0x5BBFF5F7, 0x65EC0A4F, 0x3F143CA0, 0x49675146, 0x07504D2D, 0xF161214F, 0xE43286F2, 0xDDDC7A46, 0xD086DF9B, 0xBA51B331, 0xE4CF097B, 0xF70CADF6, 0xC07F40DC, 0xD3B1E741, 0xB494A903, 0xC6EE4DB6 },
}

-- Ordem de composição das camadas (a de baixo é desenhada primeiro)
-- prefix = prefixo das chaves em `skin` (formato vorp)
-- colored = usa paleta de cor | variants = nº de variações (usa <prefix>_palette_id como variante)
-- fixedTexture = só existe uma textura (o tx_id é ignorado)
Appearance.Overlays = {
    { name = "eyebrows",     prefix = "eyebrows",     colored = true,  colorKey = "eyebrows_color" },
    { name = "scars",        prefix = "scars" },
    { name = "eyeliners",    prefix = "eyeliner",     colored = true,  colorKey = "eyeliner_color_primary", variants = 15, variantKey = "eyeliner_palette_id", fixedTexture = true },
    { name = "lipsticks",    prefix = "lipsticks",    colored = true,  colorKey = "lipsticks_palette_color_primary", variants = 7, variantKey = "lipsticks_palette_id", fixedTexture = true },
    { name = "acne",         prefix = "acne" },
    { name = "shadows",      prefix = "shadows",      colored = true,  colorKey = "shadows_palette_color_primary", variants = 5, variantKey = "shadows_palette_id", fixedTexture = true },
    { name = "beardstabble", prefix = "beardstabble", colored = true,  colorKey = "beardstabble_color_primary", fixedTexture = true },
    { name = "hair",         prefix = "hair",         colored = true,  colorKey = "hair_color_primary" },
    { name = "ageing",       prefix = "ageing" },
    { name = "blush",        prefix = "blush",        colored = true,  colorKey = "blush_palette_color_primary" },
    { name = "complex",      prefix = "complex" },
    { name = "disc",         prefix = "disc" },
    { name = "freckles",     prefix = "freckles" },
    { name = "moles",        prefix = "moles" },
    { name = "spots",        prefix = "spots" },
}

Appearance.TextureTypes = {
    mp_male   = { normal = joaat("mp_head_mr1_008_nm"), material = joaat("mp_head_mr1_000_m") },
    mp_female = { normal = joaat("mp_head_fr1_008_nm"), material = joaat("mp_head_fr1_000_m") },
}

-- Categorias de componentes (meta ped tags)
Appearance.Categories = {
    BeardsMustache = `BEARDS_MUSTACHE`, Blouses = `BLOUSES`, Scarves = `SCARVES`, EyeBrows = `EYEBROWS`,
    Eyes = `EYES`, CoatsHeavy = `COATS_HEAVY`, Heads = `HEADS`, BodiesUpper = `BODIES_UPPER`, BodiesLower = `BODIES_LOWER`,
    Gunbelt = `GUNBELTS`, AmmoPistol = `AMMO_PISTOLS`, Mask = `MASKS`, Holster = `HOLSTERS_LEFT`, Loadouts = `LOADOUTS`,
    Coat = `COATS`, Cloak = `CLOAKS`, EyeWear = `EYEWEAR`, Bracelet = `JEWELRY_BRACELETS`, Skirt = `SKIRTS`,
    Poncho = `PONCHOS`, Spats = `SPATS`, NeckTies = `NECKTIES`, Pant = `PANTS`, Suspender = `SUSPENDERS`, Glove = `GLOVES`,
    Satchels = `SATCHELS`, GunbeltAccs = `GUNBELT_ACCS`, CoatClosed = `COATS_CLOSED`, Buckle = `BELT_BUCKLES`,
    RingRh = `JEWELRY_RINGS_RIGHT`, Belt = `BELTS`, Accessories = `ACCESSORIES`, Shirt = `SHIRTS_FULL`,
    Gauntlets = `GAUNTLETS`, Chap = `CHAPS`, NeckWear = `NECKWEAR`, Boots = `BOOTS`, Spurs = `BOOT_ACCESSORIES`,
    Vest = `VESTS`, RingLh = `JEWELRY_RINGS_LEFT`, Hat = `HATS`, Dress = `DRESSES`, Badge = `BADGES`, Armor = `ARMOR`,
    Hair = `HAIR`, Beard = `BEARDS_COMPLETE`, Bow = `HAIR_ACCESSORIES`, Teeth = `TEETH`,
}

-- Combinações que o motor não renderiza bem: ao equipar a chave, remover as da lista
Appearance.Incompatible = {
    Coat       = { "CoatClosed" },
    CoatClosed = { "Coat", "Vest" },
    Cloak      = { "Poncho" },
    Poncho     = { "Cloak" },
    Dress      = { "Shirt", "Pant", "Skirt", "Vest" },
    Pant       = { "Skirt", "Dress" },
    Skirt      = { "Pant", "Dress" },
    Shirt      = { "Dress" },
    Vest       = { "CoatClosed", "Dress" },
}

-- Chaves de vestuário (formato vorp) que são guardadas em `compPlayer`
Appearance.ClothingKeys = {
    "Poncho", "Glove", "RingRh", "Gauntlets", "Spats", "GunbeltAccs", "NeckTies", "Bow", "RingLh", "Loadouts",
    "Boots", "Suspender", "NeckWear", "Holster", "CoatClosed", "EyeWear", "Shirt", "Gunbelt", "Hat", "Spurs",
    "Cloak", "Vest", "Belt", "Pant", "Skirt", "Coat", "Mask", "Accessories", "Buckle", "Bracelet", "Satchels",
    "Dress", "Badge", "Armor", "Teeth", "Chap",
}

-- Pele por defeito (todas as chaves que o vorp_character conhece)
function Appearance.DefaultSkin(model)
    local skin = {
        sex = model or "mp_male", albedo = 0, HeadType = 0, BodyType = 0, LegsType = 0, Torso = 0,
        Beard = 0, Hair = 0, Body = 0, Waist = 0, Eyes = 0, Scale = 1.0,
    }
    for _, f in ipairs(Appearance.Features) do skin[f.key] = 0.0 end
    for _, o in ipairs(Appearance.Overlays) do
        skin[o.prefix .. "_visibility"] = 0
        skin[o.prefix .. "_tx_id"] = 0
        skin[o.prefix .. "_opacity"] = 0.0
        if o.colorKey then skin[o.colorKey] = 0 end
        if o.variantKey then skin[o.variantKey] = 0 end
    end
    -- chaves extra do formato vorp (mantidas para compatibilidade)
    for _, k in ipairs({
        "grime_visibility", "grime_tx_id", "grime_opacity",
        "lipsticks_palette_color_secondary", "lipsticks_palette_color_tertiary",
        "shadows_palette_color_secondary", "shadows_palette_color_tertiary",
        "blush_palette_id", "foundation_tx_id", "foundation_visibility", "foundation_palette_id",
        "foundation_palette_color_primary", "foundation_palette_color_secondary", "foundation_palette_color_tertiary",
        "foundation_opacity", "paintedmasks_tx_id", "paintedmasks_visibility", "paintedmasks_palette_id",
        "paintedmasks_palette_color_primary", "paintedmasks_palette_color_secondary",
        "paintedmasks_palette_color_tertiary", "paintedmasks_opacity",
    }) do
        if skin[k] == nil then skin[k] = 0 end
    end
    return skin
end

function Appearance.GenderLetter(model)
    return model == "mp_male" and "M" or "F"
end

function Appearance.DataGender(model)
    return model == "mp_male" and "male" or "female"
end

function Appearance.HairGender(model)
    return model == "mp_male" and "Male" or "Female"
end
