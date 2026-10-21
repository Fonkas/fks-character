-- Wrappers de natives do RDR3 (metaped). Todos recebem o ped explicitamente
-- para funcionarem tanto no jogador como nos peds de pré-visualização.

N = {}

function N.WaitReady(ped, timeout)
    local deadline = GetGameTimer() + (timeout or 3000)
    repeat Wait(0) until Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) or GetGameTimer() > deadline -- IsPedReadyToRender
end

function N.UpdateVariation(ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false) -- _UPDATE_PED_VARIATION
    Citizen.InvokeNative(0xAAB86462966168CE, ped, true)                           -- refresh metaped
end

-- Hashes vindos de JSON podem chegar como float; as natives exigem inteiros
local function int(v)
    return math.tointeger(v) or math.floor(tonumber(v) or 0)
end
N.Int = int

function N.ApplyItem(ped, hash)
    if not hash or hash == 0 or hash == -1 then return end
    hash = int(hash)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, false, false, false) -- _APPLY_SHOP_ITEM_TO_PED
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, false, true, false)
end

function N.RemoveTag(ped, category)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, category, 0) -- _REMOVE_TAG_FROM_META_PED
end

function N.ResetComponents(ped)
    Citizen.InvokeNative(0x8507BCB710FA6DC0, ped)
end

function N.EquipOutfit(ped, hash)
    if not hash or hash == 0 then return end
    Citizen.InvokeNative(0x1902C4CFCC5BE57C, ped, int(hash)) -- _EQUIP_META_PED_OUTFIT
end

function N.EquipOutfitPreset(ped, preset)
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, preset, true)
end

function N.SetWearableState(ped, hash, state)
    Citizen.InvokeNative(0x66B957AAC2EAAEAB, ped, int(hash), state, 0, 1, 1)
end

function N.SetFaceFeature(ped, index, value)
    Citizen.InvokeNative(0x5653AB26C82938CF, ped, index, value) -- _SET_CHAR_EXPRESSION
end

function N.NumComponents(ped)
    return Citizen.InvokeNative(0x90403E8107B60E81, ped, Citizen.ResultAsInteger())
end

function N.ComponentCategory(ped, index)
    return Citizen.InvokeNative(0x9B90842304C938A7, ped, index, 0, Citizen.ResultAsInteger())
end

function N.ComponentAt(ped, index)
    local buffer = DataView.ArrayBuffer(6 * 8)
    return Citizen.InvokeNative(0x77BA37622E22023B, ped, index, true, buffer:Buffer(), buffer:Buffer(), Citizen.ResultAsInteger())
end

-- Composição da textura da cabeça (overlays)
function N.RequestTexture(albedo, normal, material)
    return Citizen.InvokeNative(0xC5E7204F322E49EB, int(albedo), int(normal), int(material))
end

function N.AddTextureLayer(tex, albedo, normal, material, colorType, texOpacity, unk)
    return Citizen.InvokeNative(0x86BB5FF45F193A02, tex, int(albedo), normal, material, colorType, texOpacity + 0.0, unk)
end

function N.SetLayerPalette(tex, layer, palette)
    Citizen.InvokeNative(0x1ED8588524AC9BE1, tex, layer, int(palette))
end

function N.SetLayerTint(tex, layer, c1, c2, c3)
    Citizen.InvokeNative(0x2DF59FFE6FFD6044, tex, layer, int(c1), int(c2), int(c3))
end

function N.SetLayerVariant(tex, layer, variant)
    Citizen.InvokeNative(0x3329AAE2882FC8E4, tex, layer, int(variant))
end

function N.SetLayerAlpha(tex, layer, alpha)
    Citizen.InvokeNative(0x6C76BC24F8BB709A, tex, layer, alpha)
end

function N.IsTextureValid(tex)
    return Citizen.InvokeNative(0x31DC8D3F216D8509, tex)
end

function N.UpdateTexture(tex)
    Citizen.InvokeNative(0x92DAABA2C1C10B0E, tex)
end

function N.ApplyTexture(ped, category, tex)
    Citizen.InvokeNative(0x0B46E25761519058, ped, category, tex)
end

function N.ReleaseTexture(tex)
    Citizen.InvokeNative(0xB63B9178D0F58D82, tex) -- reset
    Citizen.InvokeNative(0x6BEFAA907B076859, tex) -- remove
end

function N.LoadModel(model)
    local hash = type(model) == "string" and joaat(model) or model
    if not IsModelValid(hash) then return nil end
    if not HasModelLoaded(hash) then
        RequestModel(hash, false)
        local deadline = GetGameTimer() + 10000
        repeat Wait(0) until HasModelLoaded(hash) or GetGameTimer() > deadline
    end
    return HasModelLoaded(hash) and hash or nil
end

function N.SetFocusDistance(cam, dist)
    Citizen.InvokeNative(0x11F32BB61B756732, cam, dist)
end

function N.Spinner(text)
    Citizen.InvokeNative(0x7F78CD75CC4539E4, VarString(10, "LITERAL_STRING", text))
end
