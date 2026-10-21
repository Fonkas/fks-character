-- Câmara orbital suave em torno do ped (seleção e criador).
-- A câmara fica fixa na direção "de palco"; é o ped que roda.
-- O alvo de cada preset é um osso do esqueleto (cabeça, peito, bacia, joelhos...),
-- por isso o enquadramento acompanha a altura, a escala e a pose da personagem.

Cam = {}

local state = {
    cam = nil,
    ped = nil,
    target = nil,          -- ponto para onde a câmara olha (suavizado)
    fallback = nil,        -- coords do palco, se o ped ainda não existir
    stageHeading = 0.0,    -- direção para onde o ped olha por defeito (e onde está a câmara)
    heading = 0.0, targetHeading = 0.0,
    dist = 3.0, targetDist = 3.0,
    camZ = 0.0, targetCamZ = 0.0,
    lift = 0.0, targetLift = 0.0,  -- altura extra escolhida pelo jogador
    pan = 0.0, targetPan = 0.0,    -- deslocamento lateral escolhido pelo jogador (metros)
    side = 0.0, targetSide = 0.0,  -- deslocamento de enquadramento do preset (fração do ecrã)
    fov = 40.0, targetFov = 40.0,
    preset = "general",
    bones = {},            -- cache: nome lógico -> lista de índices de osso
    running = false,
    rotatePed = true,      -- false: rodar move a câmara à volta do ped (ex.: sentado na seleção)
}

-- nomes lógicos -> ossos do RDR3 e desvio de recurso a partir das coords da entidade
local BONES = {
    head   = { names = { "skel_head" },                   fallback = 0.62 },
    neck   = { names = { "skel_neck1", "skel_neck0" },    fallback = 0.50 },
    chest  = { names = { "skel_spine4", "skel_spine3" },  fallback = 0.35 },
    spine  = { names = { "skel_spine2", "skel_spine1" },  fallback = 0.20 },
    pelvis = { names = { "skel_pelvis" },                 fallback = 0.0 },
    knee   = { names = { "skel_l_calf", "skel_r_calf" },  fallback = -0.45, average = true },
    feet   = { names = { "skel_l_foot", "skel_r_foot" },  fallback = -0.95, average = true },
}

local function lerp(a, b, t) return a + (b - a) * t end

local function lerpVec(a, b, t)
    return vector3(lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.z, b.z, t))
end

local function angleLerp(a, b, t)
    local diff = (b - a + 180.0) % 360.0 - 180.0
    return a + diff * t
end

local function forward(heading)
    local r = math.rad(heading)
    return vector3(-math.sin(r), math.cos(r), 0.0)
end

local function preset()
    return Config.Cameras.Presets[state.preset] or Config.Cameras.Presets.general
end

local function boneIndices(key)
    if state.bones[key] then return state.bones[key] end
    local def = BONES[key] or BONES.pelvis
    local found = {}
    for _, name in ipairs(def.names) do
        local idx = GetEntityBoneIndexByName(state.ped, name)
        if idx and idx ~= -1 then
            found[#found + 1] = idx
            if not def.average then break end
        end
    end
    state.bones[key] = found
    return found
end

-- Ponto do corpo para onde o preset atual aponta
local function desiredTarget()
    local p = preset()
    local key = BONES[p.bone] and p.bone or "pelvis"
    if not (state.ped and DoesEntityExist(state.ped)) then
        return state.fallback + vector3(0.0, 0.0, 1.0 + BONES[key].fallback + (p.z or 0.0))
    end

    local base = GetEntityCoords(state.ped)
    local list = boneIndices(key)
    local pos
    if #list > 0 then
        local sx, sy, sz = 0.0, 0.0, 0.0
        for _, idx in ipairs(list) do
            local b = GetWorldPositionOfEntityBone(state.ped, idx)
            sx, sy, sz = sx + b.x, sy + b.y, sz + b.z
        end
        pos = vector3(sx / #list, sy / #list, sz / #list)
        -- se o osso devolver lixo (ped ainda a carregar), usa o desvio de recurso
        if #(pos - base) > 2.5 then pos = nil end
    end
    pos = pos or (base + vector3(0.0, 0.0, BONES[key].fallback))
    -- centrar horizontalmente no ped (a cabeça oscila com as animações)
    return vector3(base.x, base.y, pos.z + (p.z or 0.0))
end

-- Largura do plano visível (metros) à distância atual, para converter fração do ecrã em metros
local function viewWidth()
    local w, h = GetCurrentScreenResolution()
    local aspect = (w and h and h > 0) and (w / h) or (16 / 9)
    local hfov = 2.0 * math.atan(math.tan(math.rad(state.fov) / 2.0) * aspect)
    return 2.0 * state.dist * math.tan(hfov / 2.0)
end

local function place()
    local o, fwd = state.target, forward(state.rotatePed and state.stageHeading or state.heading)
    -- direita da câmara (que olha na direção -fwd)
    local right = vector3(-fwd.y, fwd.x, 0.0)
    -- side > 0 => personagem aparece mais à direita do ecrã (câmara desloca-se para a esquerda)
    local shift = state.pan - state.side * viewWidth()
    local ox, oy = o.x + right.x * shift, o.y + right.y * shift
    local tz = o.z + state.lift
    SetCamCoord(state.cam, ox + fwd.x * state.dist, oy + fwd.y * state.dist, tz + state.camZ)
    PointCamAtCoord(state.cam, ox, oy, tz)
    SetCamFov(state.cam, state.fov)
end

local function loop()
    local last = GetGameTimer()
    while state.running do
        local now = GetGameTimer()
        local dt = math.min((now - last) / 1000.0, 0.1)
        last = now
        local t = 1.0 - math.exp(-Config.Cameras.InterpolationSpeed * dt)

        state.dist = lerp(state.dist, state.targetDist, t)
        state.camZ = lerp(state.camZ, state.targetCamZ, t)
        state.lift = lerp(state.lift, state.targetLift, t)
        state.pan = lerp(state.pan, state.targetPan, t)
        state.side = lerp(state.side, state.targetSide, t)
        state.fov = lerp(state.fov, state.targetFov, t)
        state.heading = angleLerp(state.heading, state.targetHeading, t)
        state.target = lerpVec(state.target, desiredTarget(), t)

        if state.ped and DoesEntityExist(state.ped) then
            if state.rotatePed then SetEntityHeading(state.ped, state.heading) end
        end
        place()
        Wait(0)
    end
end

local function applyPreset(name, instant)
    local p = Config.Cameras.Presets[name]
    if not p then return end
    state.preset = name
    state.targetDist, state.targetFov, state.targetCamZ = p.dist, p.fov, p.camZ or 0.0
    state.targetSide = p.side or 0.0
    if instant then
        state.dist, state.fov, state.camZ, state.side = p.dist, p.fov, p.camZ or 0.0, p.side or 0.0
        state.target = desiredTarget()
    end
    if state.cam then N.SetFocusDistance(state.cam, p.dist) end
end

-- origin: vector3 / vector4 do palco (usado só se o ped não existir). heading: direção do palco.
function Cam.Start(ped, origin, heading, presetName, opts)
    state.ped = ped
    state.bones = {}
    state.rotatePed = not (opts and opts.rotatePed == false)
    state.fallback = vector3(origin.x, origin.y, origin.z)
    state.stageHeading = heading
    state.heading, state.targetHeading = heading, heading
    state.lift, state.targetLift = 0.0, 0.0
    state.pan, state.targetPan = 0.0, 0.0

    if not state.cam then
        state.cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    end
    applyPreset(Config.Cameras.Presets[presetName or ""] and presetName or "general", true)
    place()
    SetCamActive(state.cam, true)
    RenderScriptCams(true, false, 0, true, true, 0)

    if not state.running then
        state.running = true
        CreateThread(loop)
    end
end

-- Troca o ped seguido (ex.: outra personagem na seleção, troca de género) mantendo a câmara
function Cam.SetPed(ped)
    state.ped = ped
    state.bones = {}
    if ped and DoesEntityExist(ped) and state.rotatePed then
        state.heading = GetEntityHeading(ped)
        state.targetHeading = state.stageHeading
    end
end

-- Câmara viaja suavemente até outro ped que não roda (ex.: sentado). heading = para onde o ped olha.
function Cam.Focus(ped, heading, presetName)
    state.ped = ped
    state.bones = {}
    state.rotatePed = false
    state.stageHeading = heading
    state.targetHeading = heading
    state.targetPan, state.targetLift = 0.0, 0.0
    if presetName then applyPreset(presetName, false) end
end

-- Escolher um preset volta sempre ao enquadramento dele (anula subir/descer e esquerda/direita)
function Cam.SetPreset(name)
    state.targetLift, state.targetPan = 0.0, 0.0
    applyPreset(name, false)
end

function Cam.Zoom(direction)
    local c = Config.Cameras
    state.targetDist = math.max(c.MinDistance, math.min(c.MaxDistance, state.targetDist + direction * c.ZoomStep))
end

function Cam.Rotate(degrees)
    state.targetHeading = state.targetHeading + degrees
end

-- Subir (+1) / descer (-1) a câmara, dentro dos limites do config
function Cam.Lift(direction)
    local c = Config.Cameras
    state.targetLift = math.max(c.MinLift, math.min(c.MaxLift, state.targetLift + direction * c.LiftStep))
end

-- Mover a câmara para a direita (+1) / esquerda (-1)
function Cam.Pan(direction)
    local c = Config.Cameras
    state.targetPan = math.max(-c.MaxPan, math.min(c.MaxPan, state.targetPan + direction * c.PanStep))
end

function Cam.Reset()
    state.targetHeading = state.stageHeading
    state.targetLift = 0.0
    state.targetPan = 0.0
    applyPreset(state.preset, false)
end

-- Pequeno "empurrão" de câmara para transições entre personagens
function Cam.Pulse()
    state.dist = state.targetDist + 0.6
    state.fov = state.targetFov + 6.0
end

function Cam.Stop(ease)
    state.running = false
    if state.cam then
        RenderScriptCams(false, ease and true or false, ease or 0, true, true, 0)
        SetCamActive(state.cam, false)
        DestroyCam(state.cam, false)
        state.cam = nil
    end
    state.ped = nil
end

function Cam.GetCoord()
    if state.cam then return GetCamCoord(state.cam) end
    return nil
end

function Cam.IsActive()
    return state.running
end
