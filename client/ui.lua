-- Interface: desenhada pelo fks-core (tabela `UI` de @fks-core/import.lua, ver docs/UI-API.md do fks-core).
-- Aqui ficam só as ajudas partilhadas pela seleção e pelo criador.

-- Os handlers devolvem chaves de erro ("err_busy"); o fks-core mostra `message`, por isso traduzimos aqui.
local on = UI.On
function UI.On(name, handler)
    on(name, function(data)
        local res = handler(type(data) == "table" and data or {})
        if type(res) == "table" and res.error and not res.message then res.message = L(res.error) end
        return res
    end)
end

function UI.Error(key)
    UI.Toast(L(key), "error")
end

-- Rail da câmara do criador (presets + ferramentas + atalhos)
function UI.CameraRail(preset)
    local presets = {}
    for _, name in ipairs({ "general", "face", "upper", "body", "lower" }) do
        presets[#presets + 1] = { id = name, label = L("cam_" .. name) }
    end
    return {
        drag = true, wheel = true, keys = true,
        rail = {
            presets = presets,
            preset = preset,
            hints = {
                { "A / D", L("hint_rotate") }, { "W / S", L("hint_zoom") },
                { "Q / E", L("hint_height") }, { "Z / C", L("hint_side") },
            },
        },
    }
end

-- Entrada da câmara (palco, rail e teclas), na seleção e no criador
local STEP = { key = 12, button = 30 }
UI.On("camera", function(d)
    if not Cam.IsActive() then return end
    local v = tonumber(d.value) or 0
    if d.kind == "drag" then
        Cam.Rotate(math.max(-90, math.min(90, (tonumber(d.dx) or 0) * 0.45)))
    elseif d.kind == "wheel" or d.kind == "zoom" then
        Cam.Zoom(v > 0 and 1 or -1)
    elseif d.kind == "rotate" then
        Cam.Rotate(v * (STEP[d.source] or 12))
    elseif d.kind == "lift" then
        Cam.Lift(v > 0 and 1 or -1)
    elseif d.kind == "pan" then
        Cam.Pan(v > 0 and 1 or -1)
    elseif d.kind == "reset" then
        Cam.Reset()
    elseif d.kind == "preset" then
        Cam.SetPreset(d.value)
    end
end)
