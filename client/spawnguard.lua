-- Proteção contra spawns tardios do spawnmanager.
--
-- O basic-gamemode faz, quando o mapa termina de carregar no cliente:
--     exports.spawnmanager:setAutoSpawn(true); exports.spawnmanager:forceRespawn()
-- Num cliente lento isso pode acontecer DEPOIS de a personagem já estar no mundo: o spawnmanager
-- congela o jogador (invisível), teleporta-o para o spawn do mapa e dispara "playerSpawned",
-- o que faz o vorp_core escurecer o ecrã e mudar o jogador de routing bucket.
-- Aqui: 1) impedimos esse spawn; 2) se acontecer na mesma, desfazemos os efeitos.

local inWorld = false
local lastPos = nil   -- vector4 da última posição boa no mundo

local function disableAutoSpawn()
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
end

AddEventHandler("fks-character:client:characterLoaded", function()
    inWorld = true
    disableAutoSpawn()
end)

-- mantém o spawn automático desligado e guarda a última posição boa
CreateThread(function()
    while true do
        Wait(1000)
        if inWorld or Scene.active then disableAutoSpawn() end
        if inWorld and not Scene.active then
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and not IsEntityDead(ped) and IsEntityVisible(ped) then
                local c = GetEntityCoords(ped)
                if math.abs(c.x) > 1.0 or math.abs(c.y) > 1.0 then
                    lastPos = vector4(c.x, c.y, c.z, GetEntityHeading(ped))
                end
            end
        end
    end
end)

-- o mapa acabou de carregar (basic-gamemode vai pedir um respawn): desligar já e nos frames seguintes
AddEventHandler("onClientMapStart", function()
    if not (inWorld or Scene.active) then return end
    disableAutoSpawn()
    CreateThread(function()
        for _ = 1, 30 do
            disableAutoSpawn()
            Wait(0)
        end
    end)
end)

-- O spawn tardio aconteceu mesmo assim: repor a personagem onde estava
AddEventHandler("playerSpawned", function()
    if not inWorld or not lastPos then return end
    local back = lastPos
    CreateThread(function()
        Wait(500) -- deixa o handler do vorp_core correr primeiro
        print("^3[fks-character] spawn tardio do spawnmanager detetado - a repor a personagem^7")

        -- o spawnmanager pode ter trocado o modelo: volta a aplicar a aparência guardada
        ReloadLook()

        local ped = PlayerPedId()
        RequestCollisionAtCoord(back.x, back.y, back.z)
        SetEntityCoords(ped, back.x, back.y, back.z, false, false, false, false)
        SetEntityHeading(ped, back.w)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true)
        SetEntityCanBeDamaged(ped, true)
        SetPlayerControl(PlayerId(), true, 0)
        SetPlayerInvincible(PlayerId(), false)

        -- o vorp_core escondeu o radar, mostrou o ecrã de carregamento e mudou o routing bucket
        ShutdownLoadingScreen()
        DisplayRadar(true)
        Scene.SetExternalHud(true)
        ServerCall("respawnfix")
        DoScreenFadeIn(800)
    end)
end)
