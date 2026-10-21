local function reply(src, msg)
    if src == 0 then
        print("[fks-character] " .. msg)
    else
        Core.NotifyRightTip(src, msg, 5000)
    end
end

local function resolveIdentifier(target)
    if not target then return nil end
    local id = tonumber(target)
    if id then
        if GetPlayerName(id) == nil then return nil end
        return GetPlayerIdentifierByType(id, "steam")
    end
    if target:match("^steam:%x+$") then return target end
    return nil
end

local function guard(src)
    if not Characters.IsAdmin(src) then
        reply(src, L("adm_no_perm"))
        return false
    end
    return true
end

-- Define o nº de slots extra de um jogador (soma aos slots base)
RegisterCommand("fks_addslots", function(src, args)
    if not guard(src) then return end
    local identifier = resolveIdentifier(args[1])
    local amount = tonumber(args[2])
    if not identifier or not amount then return reply(src, L("adm_usage_slots")) end
    amount = math.max(0, math.min(math.floor(amount), Config.MaximumCharacterSlots))
    DB.SetExtraSlots(identifier, amount)
    reply(src, L("adm_slots_set", identifier, amount))
end, false)

-- Recupera uma personagem eliminada em modo soft
RegisterCommand("fks_restorechar", function(src, args)
    if not guard(src) then return end
    local charId = tonumber(args[1])
    if not charId then return reply(src, L("adm_usage_restore")) end
    if DB.Restore(charId) then
        reply(src, L("adm_restored", charId))
        Characters.Log("Personagem restaurada", ("Personagem #%s restaurada por %s"):format(charId, src == 0 and "consola" or GetPlayerName(src)))
    else
        reply(src, L("adm_not_found"))
    end
end, false)

-- Lista personagens eliminadas (soft) de um jogador
RegisterCommand("fks_deletedchars", function(src, args)
    if not guard(src) then return end
    local identifier = resolveIdentifier(args[1])
    if not identifier then return reply(src, L("adm_not_found")) end
    local rows = DB.ListDeleted(identifier)
    local parts = {}
    for _, r in ipairs(rows) do
        parts[#parts + 1] = ("#%s %s %s (%s)"):format(r.charidentifier, r.firstname or "?", r.lastname or "?", r.deleted_at)
    end
    reply(src, L("adm_deleted_list", identifier, #parts > 0 and table.concat(parts, ", ") or "-"))
end, false)
