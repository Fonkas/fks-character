-- Kits iniciais: escolhidos na criação, entregues uma única vez por personagem.

Kits = {}

local byId = {}
for _, kit in ipairs(Config.StarterKits.Kits or {}) do byId[kit.id] = kit end

function Kits.Enabled()
    return Config.StarterKits.Enabled and next(byId) ~= nil
end

function Kits.IsValid(id)
    return type(id) == "string" and byId[id] ~= nil
end

-- Dados para a NUI (sem nada que o cliente possa usar para pedir itens)
function Kits.ForUI()
    if not Kits.Enabled() then return nil end
    local out = {}
    for _, kit in ipairs(Config.StarterKits.Kits) do
        local items = {}
        for _, it in ipairs(kit.items) do
            items[#items + 1] = { item = it.item, label = L(it.label or it.item), amount = it.amount }
        end
        -- label/description podem ser chaves de tradução (locales/*.lua) ou texto direto
        out[#out + 1] = { id = kit.id, label = L(kit.label), description = kit.description and L(kit.description) or "", icon = kit.icon, items = items }
    end
    return { list = out, imagePath = Config.StarterKits.ImagePath }
end

function Kits.Give(src, charId, id)
    local kit = byId[id]
    if not kit then return end
    SetTimeout(Config.StarterKits.GiveDelay, function()
        if GetPlayerName(src) == nil then return end
        -- garante que o mesmo personagem nunca recebe dois kits
        if not DB.SetStarterKit(charId, id) then return end
        for _, it in ipairs(kit.items) do
            local ok, err = pcall(function()
                exports.vorp_inventory:addItem(src, it.item, it.amount)
            end)
            if not ok then
                print(("^1[fks-character] falha a dar %sx %s a %s: %s^7"):format(it.amount, it.item, src, tostring(err)))
            end
        end
        Core.NotifyRightTip(src, L("kit_received", L(kit.label)), 5000)
        Characters.Log("Kit inicial", ("**%s** recebeu %s (personagem #%s)"):format(GetPlayerName(src), L(kit.label), charId))
    end)
end
