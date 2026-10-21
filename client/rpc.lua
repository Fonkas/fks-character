-- Pedidos ao servidor com timeout (ver server/rpc.lua)

local pending = {}
local nextId = 0

RegisterNetEvent("fks-character:cl:reply", function(requestId, result)
    local p = pending[requestId]
    if p then
        pending[requestId] = nil
        p:resolve(result)
    end
end)

function ServerCall(name, data, timeout)
    nextId = nextId + 1
    local id = nextId
    local p = promise.new()
    pending[id] = p
    SetTimeout(timeout or Config.Session.RequestTimeout, function()
        if pending[id] then
            pending[id] = nil
            p:resolve({ ok = false, error = "err_timeout" })
        end
    end)
    TriggerServerEvent("fks-character:sv:call", id, name, data)
    return Citizen.Await(p)
end
