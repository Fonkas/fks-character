-- RPC simples cliente -> servidor com cooldown por jogador.
-- Os handlers recebem (source, data) e devolvem uma tabela.

RPC = {}

local handlers = {}
local lastCall = {}

function RPC.Register(name, handler, opts)
    handlers[name] = { fn = handler, cooldown = opts and opts.cooldown }
end

RegisterNetEvent("fks-character:sv:call", function(requestId, name, data)
    local src = source
    if type(requestId) ~= "number" or type(name) ~= "string" then return end

    local handler = handlers[name]
    if not handler then return end

    local reply = function(result)
        TriggerClientEvent("fks-character:cl:reply", src, requestId, result)
    end

    if handler.cooldown ~= false then
        local now = GetGameTimer()
        local key = src .. ":" .. name
        local cd = handler.cooldown or Config.Security.RequestCooldown
        if lastCall[key] and now - lastCall[key] < cd then
            return reply({ ok = false, error = "err_busy" })
        end
        lastCall[key] = now
    end

    local ok, result = pcall(handler.fn, src, data)
    if not ok then
        print(("^1[fks-character] erro em '%s': %s^7"):format(name, tostring(result)))
        return reply({ ok = false, error = "err_generic" })
    end
    reply(result or { ok = false, error = "err_generic" })
end)

AddEventHandler("playerDropped", function()
    local prefix = source .. ":"
    for key in pairs(lastCall) do
        if key:sub(1, #prefix) == prefix then lastCall[key] = nil end
    end
end)
