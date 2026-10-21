-- Desbloqueio de slots com compras Tebex (Config.Slots.Mode = "tebex").
-- Valida a transação na Plugin API da Tebex com a chave secreta do servidor:
--   server.cfg ->  set fks_tebex_secret "..."

Tebex = {}

local API = "https://plugin.tebex.io/payments/%s"

-- Aceita "tbx-xxxx", o link completo ou texto com o ID lá dentro
function Tebex.ExtractTransaction(input)
    if type(input) ~= "string" then return nil end
    local tx = input:lower():match("(tbx%-[%w%-]+)")
    if tx and #tx <= 80 then return tx end
    return nil
end

local function fetchPayment(tx, secret)
    local p = promise.new()
    PerformHttpRequest(API:format(tx), function(code, body)
        p:resolve({ code = code, body = body })
    end, "GET", "", { ["X-Tebex-Secret"] = secret, ["Accept"] = "application/json" })
    SetTimeout(15000, function() p:resolve({ code = 0 }) end)
    return Citizen.Await(p)
end

-- Devolve nº de slots que a transação dá, ou nil + chave de erro
local function slotsFromPayment(data)
    if type(data) ~= "table" then return nil, "err_tebex_invalid" end
    local status = tostring(data.status or ""):lower()
    if status ~= "complete" then return nil, "err_tebex_status" end
    local total = 0
    for _, pkg in ipairs(data.packages or {}) do
        local per = Config.Slots.Tebex.Packages[tonumber(pkg.id)]
        if per then total = total + per * math.max(1, tonumber(pkg.quantity) or 1) end
    end
    if total <= 0 then return nil, "err_tebex_package" end
    return total
end

RPC.Register("tebex:redeem", function(src, data)
    if not Characters.TebexMode() then return { ok = false, error = "err_tebex_disabled" } end
    local secret = GetConvar("fks_tebex_secret", "")
    if secret == "" then
        print("^1[fks-character] falta 'set fks_tebex_secret' no server.cfg^7")
        return { ok = false, error = "err_tebex_unavailable" }
    end

    local tx = Tebex.ExtractTransaction(type(data) == "table" and data.code)
    if not tx then return { ok = false, error = "err_tebex_format" } end

    local user, identifier = Characters.GetUser(src)
    if not user then return { ok = false, error = "err_generic" } end
    if DB.IsRedeemed(tx) then return { ok = false, error = "err_tebex_used" } end

    local res = fetchPayment(tx, secret)
    if res.code == 404 then return { ok = false, error = "err_tebex_invalid" } end
    if res.code ~= 200 or not res.body then
        print(("^3[fks-character] Tebex respondeu %s para %s^7"):format(tostring(res.code), tx))
        return { ok = false, error = "err_tebex_unavailable" }
    end

    local ok, payment = pcall(json.decode, res.body)
    local slots, err = slotsFromPayment(ok and payment or nil)
    if not slots then return { ok = false, error = err } end

    if not DB.Redeem(tx, identifier, slots) then return { ok = false, error = "err_tebex_used" } end
    local extra = DB.GetExtraSlots(identifier) + slots
    DB.SetExtraSlots(identifier, math.min(extra, Config.MaximumCharacterSlots))

    Characters.Log("Slot Tebex", ("**%s** (%s)\nTransação: %s\nSlots: +%s"):format(GetPlayerName(src), identifier, tx, slots))
    return { ok = true, slots = slots, payload = BuildSelectionPayload(src) }
end, { cooldown = 5000 })
