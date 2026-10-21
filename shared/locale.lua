-- Carregado depois de locales/*.lua

local active = Locales[Config.Locale] or Locales.en

-- Parâmetros que acompanham certas mensagens de erro
local errorArgs = {
    err_name_length = function() return Config.Identity.NameMinLength, Config.Identity.NameMaxLength end,
    err_age_min = function() return Config.Identity.MinAge end,
    err_age_max = function() return Config.Identity.MaxAge end,
    err_height = function() return Config.Identity.MinHeight, Config.Identity.MaxHeight end,
}

function L(key, ...)
    local str = active[key] or (Locales.en and Locales.en[key]) or key
    local args = { ... }
    if #args == 0 and errorArgs[key] then
        args = { errorArgs[key]() }
    end
    if #args > 0 then
        local ok, res = pcall(string.format, str, table.unpack(args))
        if ok then return res end
    end
    return str
end

function GetLocaleTable()
    local out = {}
    for k, v in pairs(Locales.en or {}) do out[k] = v end
    for k, v in pairs(active) do out[k] = v end
    return out
end
