UI = { open = false }

function UI.Send(action, data)
    SendNUIMessage({ action = action, data = data })
end

function UI.Focus(state)
    UI.open = state
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)
end

-- Regista um callback NUI que corre numa thread e responde sempre
function UI.On(name, handler)
    RegisterNUICallback(name, function(data, cb)
        CreateThread(function()
            local ok, result = pcall(handler, type(data) == "table" and data or {})
            if not ok then
                print(("^1[fks-character] NUI '%s': %s^7"):format(name, tostring(result)))
                result = { ok = false, error = "err_generic" }
            end
            result = result or { ok = true }
            if result.error and not result.message then result.message = L(result.error) end
            cb(result)
        end)
    end)
end

function UI.Error(key)
    UI.Send("toast", { type = "error", text = L(key) })
end
