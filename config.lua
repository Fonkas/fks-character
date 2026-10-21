Config = {}

-- =====================================================================
--  GERAL
-- =====================================================================
-- Aviso na consola do servidor quando existe uma versão mais recente no GitHub
Config.VersionCheck = {
    enabled  = true,
    repo     = "Fonkas/fks-character",  -- GitHub "utilizador/repositório"
    interval = 12,                      -- volta a verificar a cada X horas (0 = só ao arrancar)
}

Config.Locale = "en"   -- "pt" | "en" (ficheiros em locales/)
Config.Debug  = false  -- prints de diagnóstico no cliente e servidor

-- Ferramentas de configuração: /fks_coords, /fks_aim, /fks_camcoords, /fks_arrival e /fkschars.
-- Liga só enquanto ajustas coordenadas; em produção deixa false.
Config.DevMode = false

-- Comando para reaplicar a aparência guardada (corrige peds "partidos"). nil = desativado
Config.ReloadCommand = "rc"

-- HUDs de outros recursos escondidos durante seleção / criação / foto / comboio.
-- exports = { recurso, função(show) } | events = eventos de cliente que recebem (show)
Config.ExternalHud = {
    exports = { { "fks-hud", "ToggleHud" } },
    events = { "vorp:showUi" },
}

-- Comando de admin que reabre o criador de aparência a um jogador: /skinmenu [id]
Config.SkinMenuCommand = "skinmenu"

-- =====================================================================
--  SLOTS / MULTICHARACTER
-- =====================================================================
Config.DefaultCharacterSlots  = 3      -- slots grátis no modo "free"
Config.MaximumCharacterSlots  = 4      -- limite absoluto (grátis + comprados + extra) = nº de cadeiras da mesa

-- Como se obtêm slots:
--   "free"  -> cada jogador tem DefaultCharacterSlots livres (+ extra dados por admin / ACE)
--   "tebex" -> só Tebex.FreeSlots são livres; os restantes desbloqueiam-se com uma compra na Tebex.
--              O jogador cola o ID/link da transação (tbx-...) no menu e, se for válido, ganha o slot.
--   A chave secreta NÃO vai aqui (este ficheiro chega aos clientes). No server.cfg:
--      set fks_tebex_secret "a_tua_chave_secreta_da_tebex"
Config.Slots = {
    Mode = "tebex",
    Tebex = {
        FreeSlots = 1,
        StoreUrl = "https://a-tua-loja.tebex.io/",
        -- ID do pacote na Tebex => nº de slots que desbloqueia (multiplicado pela quantidade comprada)
        Packages = {
            -- [1234567] = 1,
        },
    },
}
Config.AllowCharacterDeletion = true
Config.AllowCharacterRenaming = false

-- Se true, usa também o valor `char` da tabela `users` do VORP como base
-- (o maior entre esse valor e DefaultCharacterSlots).
Config.UseVorpCharPerm = true

-- Slots extra atribuídos por ACE (server.cfg: add_ace group.vip fks.slots.vip allow)
Config.SlotPermissions = {
    -- ["fks.slots.vip"] = 2,
}

-- Grupos VORP / ACE autorizados a usar os comandos administrativos
Config.AdminGroups = { "admin", "superadmin" }
Config.AdminAce    = "fks.characters.admin"

-- "soft": marca a personagem como eliminada (recuperável com /fks_restorechar)
-- "hard": remove definitivamente através do VORP Core
Config.DeletionMode = "soft"

-- Ao entrar com 1 só slot e 1 personagem, entrar diretamente (estilo vorp)
Config.AutoSpawnSingleCharacter = false

-- Mostrar dinheiro/ouro nos cartões de seleção
Config.Selection = {
    ShowMoney = true,
    ShowGold  = false,
    ShowJob   = true,
    ShowCharId = true,
}

-- =====================================================================
--  IDENTIDADE
-- =====================================================================
Config.Identity = {
    MinAge = 18,
    MaxAge = 90,
    MinHeight = 130,          -- cm
    MaxHeight = 210,          -- cm
    DefaultHeight = 178,
    RequireNationality = false,
    RequireBirthplace = false,
    RequireBiography = false,

    NameMinLength = 2,
    NameMaxLength = 20,
    BiographyMaxLength = 500,
    NationalityMaxLength = 40,
    BirthplaceMaxLength = 40,

    -- Ano "atual" do roleplay usado para calcular idades. nil = ano real do servidor.
    -- Ex.: 1899 faz com que o calendário só aceite datas do século XIX.
    RoleplayYear = 1899,

    -- Palavras proibidas no nome (comparação sem maiúsculas)
    BannedNames = { "arthur", "marston", "admin", "staff" },

    -- A altura escolhida é a altura real da personagem: escala = altura / BaseHeight do modelo.
    -- Ex.: 200 cm num homem => escala 200/180 = 1.11 | 130 cm => 0.72 (anão).
    -- Se ao medir em jogo a personagem ficar maior/menor, ajusta BaseHeight
    -- (altura que o modelo tem com escala 1.0).
    ApplyHeightScale = true,
    BaseHeight = { mp_male = 180, mp_female = 170 },
}

-- =====================================================================
--  ROUPA INICIAL
-- =====================================================================
Config.StarterClothing = {
    Enabled = true,
    AllowHats = true,
    AllowCoats = true,
    AllowAccessories = true,

    -- Categorias mostradas no criador (chaves do formato vorp_character)
    -- `allow` referencia uma das flags acima (opcional).
    Categories = {
        { key = "Hat",         label = "hats",        allow = "AllowHats" },
        { key = "Shirt",       label = "shirts" },
        { key = "Vest",        label = "vests" },
        { key = "Coat",        label = "coats",       allow = "AllowCoats" },
        { key = "CoatClosed",  label = "coatsclosed", allow = "AllowCoats" },
        { key = "Pant",        label = "pants" },
        { key = "Skirt",       label = "skirts",      gender = "female" },
        { key = "Dress",       label = "dresses",     gender = "female" },
        { key = "Boots",       label = "boots" },
        { key = "Glove",       label = "gloves" },
        { key = "NeckWear",    label = "neckwear" },
        { key = "NeckTies",    label = "neckties" },
        { key = "Suspender",   label = "suspenders" },
        { key = "Belt",        label = "belts" },
        { key = "EyeWear",     label = "eyewear",     allow = "AllowAccessories" },
        { key = "Accessories", label = "accessories", allow = "AllowAccessories" },
    },

    -- Limitar o nº de modelos por categoria (nil = todos os existentes nos dados do jogo)
    MaxItemsPerCategory = nil,
}

-- =====================================================================
--  KITS INICIAIS (escolhidos logo após criar a personagem)
-- =====================================================================
-- Enabled = false => o ecrã de kits não aparece e não se recebe nada.
-- item = nome do item na tabela `items` do vorp_inventory.
-- label / description = chave em locales/*.lua (traduz conforme Config.Locale) ou texto direto.
Config.StarterKits = {
    Enabled = true,
    GiveDelay = 8000,  -- ms após criar até entregar (o inventário tem de estar carregado)
    ImagePath = "nui://vorp_inventory/html/img/items/%s.png",
    Kits = {
        {
            id = "lumberjack", label = "kit_lumberjack", icon = "hatchet",
            description = "kit_lumberjack_desc",
            items = {
                { item = "hatchet", label = "item_hatchet", amount = 1 },
                { item = "consumable_water", label = "item_water", amount = 10 },
                { item = "bread", label = "item_bread", amount = 10 },
            },
        },
        {
            id = "miner", label = "kit_miner", icon = "pickaxe",
            description = "kit_miner_desc",
            items = {
                { item = "pickaxe", label = "item_pickaxe", amount = 1 },
                { item = "consumable_water", label = "item_water", amount = 10 },
                { item = "bread", label = "item_bread", amount = 10 },
            },
        },
        {
            id = "farmer", label = "kit_farmer", icon = "hoe",
            description = "kit_farmer_desc",
            items = {
                { item = "hoe", label = "item_hoe", amount = 1 },
                { item = "consumable_water", label = "item_water", amount = 10 },
                { item = "bread", label = "item_bread", amount = 10 },
            },
        },
        {
            id = "civil", label = "kit_civil", icon = "mapa",
            description = "kit_civil_desc",
            items = {
                { item = "mapa", label = "item_map", amount = 1 },
                { item = "pocket_compass", label = "item_compass", amount = 1 },
                { item = "consumable_water", label = "item_water", amount = 10 },
                { item = "bread", label = "item_bread", amount = 10 },
            },
        },
    },
}

-- =====================================================================
--  MAQUILHAGEM
-- =====================================================================
Config.Makeup = {
    Enabled = true,
    FemaleOnly = false,  -- true = só aparece para mp_female
}

-- =====================================================================
--  SPAWN
-- =====================================================================
Config.FirstSpawn = {
    Enabled = true,             -- jogador escolhe a cidade inicial
    -- coords = ponto na PLATAFORMA da estação, junto à linha (é aí que a personagem termina).
    -- Com a chegada de comboio ativa, o comboio é criado na linha mais próxima destas coords.
    -- trainCam = posição da câmara que filma o comboio a chegar (opcional; sem ela é calculada).
    -- train = false desativa a chegada de comboio só para essa localização.
    -- Afinar com /fks_coords e /fks_arrival (Config.DevMode).
    Locations = {
        { label = "Valentine",   coords = vector4(-170.52, 625.6, 114.03, 326.67),   trainCam = vector4(-185.48, 609.43, 121.2, 312.54) },
        { label = "Rhodes",      coords = vector4(1222.9, -1299.78, 76.9, 321.46),   trainCam = vector4(1213.99, -1289.46, 81.83, 214.82) },
        { label = "Saint Denis", coords = vector4(2685.06, -1462.14, 46.27, 18.14),  trainCam = vector4(2685.09, -1463.82, 49.38, 288.46) },
        -- sem câmara definida (aproximadas — por afinar)
        { label = "Blackwater",  coords = vector4(-875.1, -1328.6, 43.9, 90.0) },
        { label = "Annesburg",   coords = vector4(2933.5, 1282.4, 44.7, 70.0) },
    },
}

-- =====================================================================
--  CHEGADA DE COMBOIO (sequência cinematográfica após criar a personagem)
-- =====================================================================
Config.Arrival = {
    Enabled = true,
    Year = "1899",                -- subtítulo do cartão de título
    -- Configuração do comboio (hash de "train config" do RDR2). Se o comboio não aparecer
    -- ou não tiver carruagens de passageiros, experimenta outra desta lista:
    -- "gunslinger3_config", "gunslinger4_config", "bountyhunter_config", "industry2_config", "appleseed_config"
    TrainConfig = "gunslinger3_config",
    ReverseTime = 9000,           -- ms a recuar (ecrã preto) antes de entrar na estação
    ReverseSpeed = 14.0,
    MaxSpeed = 12.0,              -- velocidade máxima na aproximação (m/s)
    Braking = 0.35,               -- velocidade = distância à paragem × Braking
    StopRadius = 1.5,             -- metros da paragem para considerar parado
    Timeout = 60000,              -- ms máximos de sequência (proteção)
    AllowSkip = true,             -- ENTER / ESPAÇO salta a sequência
    WalkTime = 4500,              -- ms a ver a personagem sair da carruagem
}

-- Para personagens existentes
Config.Spawn = {
    UseLastPosition = true,     -- usa as coords guardadas pelo VORP
    -- usado quando não existe posição válida
    Fallback = vector4(-170.52, 625.6, 114.03, 326.67),
}

-- =====================================================================
--  SESSÃO ISOLADA / CENÁRIOS
-- =====================================================================
Config.Session = {
    RoutingBucketOffset = 5000,  -- bucket = offset + serverId enquanto está no menu
    LoadTimeout = 20000,         -- ms até desistir de carregar personagem
    RequestTimeout = 15000,      -- ms para pedidos ao servidor
}

-- ---------------------------------------------------------------------
--  INTERIOR (seleção + criação): destilaria "hunter" de Lemoyne (moonshine_interiors)
-- ---------------------------------------------------------------------
-- Coordenadas medidas em jogo com /fks_coords (Config.DevMode).
Config.Interior = {
    anchor = vector3(1774.06, -812.08, 189.96),   -- ponto dentro do interior (usado para o carregar)
    imaps = {
        "MP006_A3SUPP_MOONSHINE01", "MP006_A3SUPP_MOONSHINE01_PLUG",
        "MP006_A2SUPP_MOONSHINE02", "MP006_A2SUPP_MOONSHINE02_PLUG",
        "MP006_A4SUPP_MOONSHINE03", "MP006_A4SUPP_MOONSHINE03_PLUG",
        "MP006_A1SUPP_MOONSHINE04", "MP006_A1SUPP_MOONSHINE04_PLUG",
        "MP006_A4SUPP_MOONSHINE05", "MP006_A4SUPP_MOONSHINE05_PLUG",
    },
    entitySets = {
        "mp006_mshine_band2", "mp006_mshine_bar_benchAndFrame", "mp006_mshine_dressing_3",
        "mp006_mshine_hidden_door_open", "mp006_mshine_location2", "mp006_mshine_pic_04",
        "mp006_mshine_shelfwall1", "mp006_mshine_shelfwall2", "mp006_mshine_Still_03",
        "mp006_mshine_still_hatch", "mp006_mshine_theme_hunter",
    },
    hour = 21,          -- noite: o bar fica iluminado só pelas velas/candeeiros
    weather = "sunny",
}

-- Seleção: as personagens do jogador aparecem sentadas à mesa
Config.SelectionScene = {
    -- Uma cadeira por personagem. Para medir: Config.DevMode = true, aponta a câmara ao ASSENTO de
    -- cada cadeira e escreve /fks_aim — cola aqui a linha (vector3). A personagem fica virada para
    -- o centro da mesa (autoChairs.table). Também aceita vector4 se quiseres forçar a orientação.
    seats = {
        vector3(1776.29, -808.57, 188.42),
        vector3(1775.23, -808.41, 188.42),
        vector3(1775.65, -806.96, 188.42),  -- medição deu 187.96 (chão); igualado ao assento das outras
        vector3(1776.63, -807.46, 188.42),
    },
    -- animação sentada (o primeiro que funcionar no modelo é usado)
    seatScenarios = {
        mp_male   = { "PROP_HUMAN_SEAT_CHAIR_GENERIC", "PROP_HUMAN_SEAT_CHAIR" },
        mp_female = { "PROP_HUMAN_SEAT_CHAIR_GENERIC", "PROP_HUMAN_SEAT_CHAIR" },
    },
    seatSearchRadius = 0.6,  -- metros; 0 = ignora os pontos do jogo e usa só as coordenadas
    -- Deteção automática das cadeiras como objetos. Desligada: nesta destilaria as cadeiras fazem
    -- parte do mapa e não são encontradas. `table` continua a ser usado para orientar as personagens.
    autoChairs = {
        enabled = false,
        table = vector3(1775.95, -807.85, 188.42),  -- centro da mesa (média das 4 cadeiras)
        minDistance = 0.45,  -- ignora objetos colados ao centro (a própria mesa)
        maxDistance = 1.6,   -- raio onde procurar cadeiras
        maxHeight = 0.5,     -- só objetos assentes no chão (exclui velas/garrafas em cima da mesa)
    },
    -- câmara fixa que vê as 4 cadeiras ao mesmo tempo.
    -- Para a acertar: Config.DevMode = true, enquadra a mesa com a câmara do jogo e escreve
    -- /fks_camcoords — cola aqui a linha que aparece (posição + rotação + zoom exatos).
    -- à altura dos olhos de quem está sentado (~1.2 m acima do chão), por baixo do candeeiro
    camera = { pos = vector3(1775.88, -812.47, 190.15), rot = vector3(-7.0, 0.0, 1.17), fov = 50.0 },
    -- se houver mais personagens do que cadeiras, as restantes aparecem de pé aqui
    standing = vector4(1774.06, -812.08, 189.96, 312.97),
}

-- Criação de personagem
Config.CreatorScene = {
    -- onde a personagem fica durante a personalização (heading = para onde olha)
    stage = vector4(1774.06, -812.08, 189.96, 312.97),
    -- luz por cima da personagem (segue a cabeça)
    light = { height = 1.2, color = { 255, 228, 190 }, range = 4.0, intensity = 18.0 },

    -- Cutscene inicial antes da personalização (estilo vorp_character)
    Intro = {
        Enabled = true,
        Skippable = true,                                   -- ENTER salta as falas
        eyeHeight = 0.65,                                   -- altura da câmara acima dos pontos de visão abaixo

        -- Plano 1: o jogador olha para o NPC enquanto ele fala (heading = direção do olhar)
        talkCam = vector4(1781.78, -805.45, 189.02, 41.8),
        -- Plano 2: a câmara vira-se para a porta para ver o homem e a mulher entrar
        coupleCam = vector4(1781.64, -805.4, 188.99, 224.86),
        turnTime = 1800,                                    -- ms da rotação entre os dois planos
        chooseFov = 30.0,                                   -- zoom ao escolher entre homem e mulher
        -- homem e mulher: parados lado a lado neste ponto, virados para a câmara (spread = distância entre eles)
        coupleStand = vector4(1786.99, -810.93, 189.4, 46.24),
        coupleSpread = 0.9,
        settleTime = 800,                                   -- ms para os peds assentarem no chão antes de abrir o ecrã

        npc = {                                             -- quem fala (ex.: o dono da destilaria)
            -- usa o primeiro modelo que existir no jogo
            model = { "U_M_M_VALBARTENDER_01", "U_M_M_NBXBARTENDER_01", "A_M_M_VALTOWNFOLK_01" },
            coords = vector4(1779.05, -802.18, 189.96, 214.2),
            scenario = nil,                                  -- ex.: "WORLD_HUMAN_LEAN_BAR"
        },
        -- legendas: text = chave em locales/*.lua (traduz conforme Config.Locale) ou texto direto
        -- speech = fala ambiente do jogo (opcional, depende da voz do modelo)
        lines = {
            { text = "intro_line1", time = 4500, speech = "GREET_GENERAL_STRANGER" },
            { text = "intro_line2", time = 4200 },
            { text = "intro_line3", time = 3500 },
        },
    },

    -- Momento final: senta-se, pose, preto e branco, "tira um printscreen"
    Photo = {
        Enabled = true,
        -- banco da foto. Se a personagem ficar virada para o banco em vez de sentada nele, soma 180 ao heading.
        seat = vector4(1772.42, -806.33, 188.96, 219.67),
        -- "stand" = de pé no sítio, virada para a câmara (a cara vê-se sempre)
        -- "sit"   = sentada no banco (a animação do banco põe a cabeça um pouco para baixo)
        pose = "stand",
        frontLight = true,                   -- luz à frente da cara (a de cima faz sombra com o chapéu)
        lookAtCamera = true,                 -- a personagem vira a cabeça para a lente
        -- usa o ponto de "sentar" real do banco (põe a personagem no sítio e à altura certos)
        searchRadius = 1.0,
        -- só usados se o banco não tiver ponto de sentar
        scenarios = {
            mp_male   = { "PROP_HUMAN_SEAT_BENCH", "PROP_HUMAN_SEAT_CHAIR_GENERIC" },
            mp_female = { "PROP_HUMAN_SEAT_BENCH", "PROP_HUMAN_SEAT_CHAIR_GENERIC" },
        },
        effect = "PhotoMode_FilterGame06",  -- efeito de ecrã (preto e branco / sépia)
        time = 20000,                        -- ms até continuar sozinho (ENTER continua antes)
    },
}

-- =====================================================================
--  CÂMARAS
-- =====================================================================
-- Cada câmara aponta para um osso do esqueleto do ped, por isso acompanha a altura,
-- a escala e a pose da personagem.
--   bone  = "head" | "neck" | "chest" | "spine" | "pelvis" | "knee" | "feet"
--   z     = ajuste fino da altura do alvo (metros, + sobe / - desce)
--   camZ  = altura da câmara relativa ao alvo (+ olha de cima / - olha de baixo)
--   dist  = distância da câmara | fov = abertura da lente (menor = mais "zoom")
--   side  = desloca a personagem no ecrã, em fração da largura (+ direita / - esquerda).
--           Serve para a personagem não ficar por baixo do painel (que está à esquerda).
Config.Cameras = {
    MinDistance = 0.55,
    MaxDistance = 4.0,
    ZoomStep = 0.15,
    RotateStep = 6.0,          -- graus por tecla / evento
    LiftStep = 0.06,           -- quanto sobe/desce por clique ou tecla (Q / E)
    MinLift = -0.8,
    MaxLift = 0.8,
    PanStep = 0.06,            -- quanto move para os lados por clique ou tecla (Z / C)
    MaxPan = 0.8,
    InterpolationSpeed = 6.0,  -- maior = mais rápido
    Presets = {
        general = { bone = "pelvis", z = 0.12,  camZ = 0.10, dist = 3.1,  fov = 40.0, side = 0.05 },  -- corpo inteiro
        face    = { bone = "head",   z = 0.02,  camZ = 0.0,  dist = 0.75, fov = 30.0, side = 0.13 },  -- rosto
        upper   = { bone = "head",   z = 0.06,  camZ = 0.03, dist = 1.05, fov = 32.0, side = 0.12 },  -- cabeça e cabelo
        body    = { bone = "chest",  z = -0.08, camZ = 0.05, dist = 1.55, fov = 38.0, side = 0.10 },  -- tronco
        lower   = { bone = "knee",   z = -0.05, camZ = 0.15, dist = 1.55, fov = 40.0, side = 0.08 },  -- pernas e botas
        seated  = { bone = "head",   z = -0.10, camZ = 0.12, dist = 1.50, fov = 36.0, side = 0.12 },  -- seleção (sentado)
        photo   = { bone = "head",   z = -0.10, camZ = -0.04, dist = 1.45, fov = 32.0, side = 0.0 },  -- foto final (retrato, à altura da cara)
    },
    -- Câmara usada por defeito em cada separador do criador
    TabPresets = {
        identity = "general",
        face = "face",
        skin = "face",
        eyes = "face",
        hair = "upper",
        body = "body",
        makeup = "face",
        clothing = "general",
        finish = "general",
    },
}

-- =====================================================================
--  LOGS
-- =====================================================================
Config.Logs = {
    Webhook = "",  -- URL Discord (vazio = desativado)
}

-- =====================================================================
--  ANTI-ABUSO
-- =====================================================================
Config.Security = {
    RequestCooldown = 750,   -- ms entre pedidos sensíveis por jogador
}
