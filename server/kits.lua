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
            -- armas usam o nome em minúsculas para a imagem (vorp_inventory/html/img/items/weapon_*.png)
            local name = it.item or (it.weapon and it.weapon:lower())
            items[#items + 1] = { item = name, label = L(it.label or name), amount = it.amount }
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
            if it.weapon then
                -- armas não são itens no VORP: cada uma é criada com createWeapon (com número de série)
                for _ = 1, math.max(1, tonumber(it.amount) or 1) do
                    local ok, res = pcall(function()
                        return exports.vorp_inventory:createWeapon(src, it.weapon:upper(), it.ammo or {}, {})
                    end)
                    if not ok or not res then
                        print(("^1[fks-character] kit %s: arma '%s' não existe no vorp_inventory (config/weapons.lua)^7"):format(id, it.weapon))
                        break
                    end
                end
            else
                local ok, err = pcall(function()
                    exports.vorp_inventory:addItem(src, it.item, it.amount)
                end)
                if not ok then
                    print(("^1[fks-character] falha a dar %sx %s a %s: %s^7"):format(it.amount, tostring(it.item), src, tostring(err)))
                end
            end
        end
        Core.NotifyRightTip(src, L("kit_received", L(kit.label)), 5000)
        Characters.Log("Kit inicial", ("**%s** recebeu %s (personagem #%s)"):format(GetPlayerName(src), L(kit.label), charId))
    end)
end

-- Ao arrancar: avisa na consola sobre itens dos kits que não existem na base de dados do inventário
CreateThread(function()
    if not Kits.Enabled() then return end
    Wait(15000) -- o vorp_inventory carrega os itens da base de dados no arranque
    if GetResourceState("vorp_inventory") ~= "started" then return end
    for _, kit in ipairs(Config.StarterKits.Kits) do
        for _, it in ipairs(kit.items) do
            if it.item then
                local ok, found = pcall(function() return exports.vorp_inventory:getItemDB(it.item) end)
                if ok and not found then
                    print(("^3[fks-character] kit '%s': o item '%s' não existe na tabela items^7"):format(kit.id, it.item))
                end
            elseif not it.weapon then
                print(("^3[fks-character] kit '%s': entrada sem 'item' nem 'weapon'^7"):format(kit.id))
            end
        end
    end
end)
