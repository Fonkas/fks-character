-- Proteção contra spawns tardios do spawnmanager.
--
-- O basic-gamemode faz, quando o mapa termina de carregar no cliente:
--     exports.spawnmanager:setAutoSpawn(true); exports.spawnmanager:forceRespawn()
-- Num cliente lento isso pode acontecer DEPOIS de a seleção abrir ou de a personagem já estar no mundo:
-- o spawnmanager congela o jogador (invisível), teleporta-o para o spawn do mapa e dispara "playerSpawned";
-- o vorp_core escurece o ecrã, muda o jogador de routing bucket e volta a pedir a seleção ao servidor.
-- Aqui: 1) o spawn automático passa por nós e é ignorado com a personagem carregada;
--       2) se um spawn acontecer na mesma, desfazemos os efeitos (posição, aparência, visibilidade, bucket).

SpawnGuard = { inWorld = false, loading = false }

local lastPos = nil       -- vector4 da última posição boa no mundo
local pendingFix = false  -- spawn durante o carregamento: repor quando a personagem entrar no mundo
local recovering = false
local visibilityToken = 0 -- só um guarda de visibilidade ativo de cada vez

-- tempo desde que a personagem foi escolhida (para os logs)
local function sinceSelection()
    return SpawnGuard.selectedAt and (" +%dms"):format(GetGameTimer() - SpawnGuard.selectedAt) or ""
end

local function log(...)
    if Config.Debug then print(("^5[fks-character:spawn %d%s]^7"):format(GetGameTimer(), sinceSelection()), ...) end
end
SpawnGuard.Log = log

-- há uma personagem (ou a seleção/criador) em curso: um spawn do spawnmanager só estraga
local function busy()
    return SpawnGuard.inWorld or SpawnGuard.loading or Scene.active ~= nil or Selection.payload ~= nil
end

local function disableAutoSpawn()
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
end

-- Com um callback, o spawnmanager chama-nos em vez de fazer o spawn. Assim o forceRespawn do
-- basic-gamemode é consumido sem efeito quando não é preciso (não depende de ganhar uma corrida).
local function hookAutoSpawn()
    pcall(function()
        exports.spawnmanager:setAutoSpawnCallback(function()
            if busy() then
                log("spawn automático bloqueado", "inWorld", SpawnGuard.inWorld, "scene", Scene.active)
                return disableAutoSpawn()
            end
            log("spawn automático (entrada no servidor)")
            exports.spawnmanager:spawnPlayer()
        end)
    end)
end

-- Posição onde a personagem vai aparecer (vinda da base de dados / estação): permite repor mesmo
-- que o spawn tardio aconteça antes da primeira gravação de posição.
function SpawnGuard.SetPosition(x, y, z, heading)
    if math.abs(x) > 1.0 or math.abs(y) > 1.0 then
        lastPos = vector4(x + 0.0, y + 0.0, z + 0.0, (heading or 0.0) + 0.0)
        log("posição inicial", lastPos)
    end
end

-- A seleção vai reabrir (relog / /fkschars): esquecer a personagem anterior
function SpawnGuard.Reset()
    SpawnGuard.inWorld, SpawnGuard.loading = false, false
    SpawnGuard.selectedAt = nil
    lastPos, pendingFix = nil, false
    visibilityToken = visibilityToken + 1
end

-- =====================================================================
--  REPOR A PERSONAGEM
-- =====================================================================

local function restoreTo(back)
    -- o spawnmanager pode ter trocado o modelo ou recriado o ped: volta a aplicar a aparência guardada
    ReloadLook()

    local ped = PlayerPedId()
    if back then
        FreezeEntityPosition(ped, true)
        RequestCollisionAtCoord(back.x, back.y, back.z)
        SetEntityCoords(ped, back.x, back.y, back.z, false, false, false, false)
        SetEntityHeading(ped, back.w)
        local deadline = GetGameTimer() + 5000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do
            RequestCollisionAtCoord(back.x, back.y, back.z)
            Wait(0)
        end
    end
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)
    SetEntityCanBeDamaged(ped, true)
    SetEntityInvincible(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    SetPlayerInvincible(PlayerId(), false)
end

local function invoke(hash, ...)
    local ok, res = pcall(Citizen.InvokeNative, hash, ...)
    if ok then return res end
end

-- o que se sabe sobre o jogador escondido (para os logs)
local function hiddenState(ped)
    local control = invoke(0x7964097FCE4C244B, PlayerId(), Citizen.ResultAsInteger())       -- IsPlayerControlOn
    local concealed = invoke(0x919B3C98ED8292F9, PlayerId(), Citizen.ResultAsInteger())     -- NetworkIsPlayerConcealed
    local alpha = invoke(0x1BB501624FAF2BEA, ped, Citizen.ResultAsInteger())                -- GetEntityAlpha
    return {
        control = control == nil and nil or control ~= 0,
        concealed = concealed == nil and nil or concealed ~= 0,
        alpha = alpha,
        modelOk = not CurrentSkin or GetEntityModel(ped) == joaat(CurrentSkin.sex),
    }
end

-- há sinais claros de que algo escondeu o jogador (não é só o IsEntityVisible)
local function strongSigns(st)
    return st.control == false or st.concealed == true or (st.alpha and st.alpha < 255) or not st.modelOk
end

-- o que se sabe sobre o jogador escondido (para os logs)
local function hiddenInfo(st)
    return ("controlo %s, escondido na rede %s, alpha %s, modelo %s"):format(
        st.control == nil and "?" or tostring(st.control), st.concealed == nil and "?" or tostring(st.concealed),
        tostring(st.alpha), st.modelOk and "ok" or "errado")
end

local function showPlayer(ped, st)
    SetEntityVisible(ped, true)
    -- só mexer no que está mesmo mal (repor sempre o alpha / a rede também faz piscar)
    if st.alpha and st.alpha < 255 then invoke(0x744B9EF44779D9AB, ped) end           -- ResetEntityAlpha
    if st.concealed then invoke(0xBBDF066252829606, PlayerId(), false, false) end     -- NetworkConcealPlayer
    -- o spawnmanager, quando esconde, também congela e tira a colisão e o controlo
    if st.control == false then
        FreezeEntityPosition(ped, false)
        SetEntityCollision(ped, true, true)
        SetPlayerControl(PlayerId(), true, 0)
        SetPlayerInvincible(PlayerId(), false)
    end
end

local function recover(reason)
    if recovering then return end
    recovering = true
    local back = lastPos
    CreateThread(function()
        print(("^3[fks-character] spawn tardio detetado (%s) - a repor a personagem%s^7"):format(
            reason, back and "" or " (sem posição guardada)"))

        -- O handler "playerSpawned" do vorp_core escurece o ecrã e pede o spawn ao servidor; esperar
        -- que acabe (e que o spawnmanager largue o jogador) antes de repor o estado.
        local deadline = GetGameTimer() + 4000
        Wait(1000)
        while GetGameTimer() < deadline and not IsEntityVisible(PlayerPedId()) do Wait(100) end

        for attempt = 1, 3 do
            restoreTo(back)
            Wait(750)
            local ped = PlayerPedId()
            local okPos = not back or #(GetEntityCoords(ped) - vector3(back.x, back.y, back.z)) < 30.0
            log("reposição", attempt, "posição ok", okPos, "visível", IsEntityVisible(ped))
            if okPos and IsEntityVisible(ped) then break end
        end

        -- o vorp_core escondeu o radar e mostrou o ecrã de carregamento
        ShutdownLoadingScreen()
        DisplayRadar(true)
        Scene.SetExternalHud(true)
        if not IsScreenFadedIn() and not IsScreenFadingIn() then DoScreenFadeIn(800) end

        -- routing bucket: o servidor também o repõe sozinho; confirmar e tentar outra vez se falhar
        for attempt = 1, 3 do
            local res = ServerCall("respawnfix")
            log("respawnfix", attempt, res and res.ok, res and res.bucket)
            if res and res.ok then break end
            Wait(2000)
        end
        recovering = false
    end)
end

-- Spawn durante a seleção / criador: voltar ao palco e reabrir o ecrã que o vorp_core escureceu
local function recoverScene()
    local kind = Scene.active
    CreateThread(function()
        print(("^3[fks-character] spawn tardio durante '%s' - a repor o palco^7"):format(tostring(kind)))
        Wait(1500)
        if Scene.active ~= kind or SpawnGuard.loading then return end
        local sp = Config.CreatorScene.stage
        local ped = PlayerPedId()
        SetEntityCoords(ped, sp.x, sp.y, sp.z, false, false, false, false)
        SetEntityHeading(ped, sp.w)
        if kind == "selection" then
            Scene.HidePlayer()
        else
            SetEntityVisible(ped, true)
            SetEntityCollision(ped, true, true)
        end
        ShutdownLoadingScreen()
        if not IsScreenFadedIn() and not IsScreenFadingIn() then DoScreenFadeIn(800) end
    end)
end

-- =====================================================================
--  EVENTOS
-- =====================================================================

-- reinício do recurso com a personagem já no mundo
if LocalPlayer.state.IsInSession then
    SpawnGuard.inWorld = true
    local c = GetEntityCoords(PlayerPedId())
    SpawnGuard.SetPosition(c.x, c.y, c.z, GetEntityHeading(PlayerPedId()))
    hookAutoSpawn()
    disableAutoSpawn()
end

AddEventHandler("fks-character:client:characterLoaded", function()
    SpawnGuard.inWorld = true
    SpawnGuard.loading = false
    -- um forceRespawn que tenha ficado pendente é consumido pelo callback (e o spawn automático desligado)
    hookAutoSpawn()
    log("personagem no mundo", "spawn pendente", pendingFix)
    if pendingFix then
        pendingFix = false
        recover("durante o carregamento")
    end

    -- vigilância nos primeiros segundos: num PC lento a aparência pode não ter ficado aplicada
    CreateThread(function()
        local untilTime = GetGameTimer() + 20000
        local fixes = 0
        while GetGameTimer() < untilTime and SpawnGuard.inWorld and fixes < 3 do
            Wait(1000)
            local ped = PlayerPedId()
            if not Scene.active and not recovering and DoesEntityExist(ped) and not IsEntityDead(ped) and CurrentSkin then
                local wrongModel = GetEntityModel(ped) ~= joaat(CurrentSkin.sex)
                local naked = N.NumComponents(ped) == 0
                if wrongModel or naked then
                    fixes = fixes + 1
                    print(("^3[fks-character] aparência em falta depois de entrar (modelo %s, componentes %s) - a reaplicar^7")
                        :format(wrongModel and "errado" or "ok", naked and "0" or "ok"))
                    ReloadLook()
                end
            end
        end
    end)

    -- visibilidade: há servidores onde algo volta a esconder o jogador depois de entrar
    -- (ex.: um spawn do spawnmanager a meio, que congela e esconde). Enquanto durar a janela,
    -- o jogador é mostrado quando fique invisível, e fica registado o que se viu.
    visibilityToken = visibilityToken + 1
    local token = visibilityToken
    CreateThread(function()
        -- Só depois de o vorp_core acabar o spawn: enquanto carrega o mundo, o jogador pode estar
        -- escondido de propósito e mostrá-lo aí fazia-o piscar. Sem sinal do VORP, arranca aos 15 s.
        local deadline = GetGameTimer() + 15000
        while GetGameTimer() < deadline and token == visibilityToken
            and not (LocalPlayer.state.IsInSession and IsScreenFadedIn()) do
            Wait(250)
        end
        Wait(1000)
        if token ~= visibilityToken then return end
        log("guarda de visibilidade ativo", "sinal do VORP", LocalPlayer.state.IsInSession and IsScreenFadedIn())

        local untilTime = GetGameTimer() + (Config.Session.VisibilityGuard or 60000)
        local count, checkedBucket, hiddenSince = 0, false, nil
        while GetGameTimer() < untilTime and SpawnGuard.inWorld and token == visibilityToken do
            Wait(250)
            local ped = PlayerPedId()
            if not Scene.active and not recovering and DoesEntityExist(ped) and not IsEntityDead(ped)
                and IsScreenFadedIn() and not IsEntityVisible(ped) then
                local now = GetGameTimer()
                hiddenSince = hiddenSince or now
                local st = hiddenState(ped)
                -- invisível por pouco tempo e sem outros sinais (alpha 255, não escondido na rede,
                -- com controlo, modelo ok) não conta: só se age se durar 5 s seguidos
                if now - hiddenSince >= (strongSigns(st) and 1000 or 5000) then
                    count = count + 1
                    if count <= 5 or count % 20 == 0 then
                        print(("^3[fks-character] personagem invisível depois de entrar (%dx,%s %s) - a mostrar^7")
                            :format(count, sinceSelection(), hiddenInfo(st)))
                    end
                    showPlayer(ped, st)
                    hiddenSince = nil
                    if not checkedBucket then
                        checkedBucket = true
                        CreateThread(function()
                            local res = ServerCall("respawnfix")
                            print(("^3[fks-character] routing bucket confirmado: %s^7"):format(res and tostring(res.bucket) or "sem resposta"))
                        end)
                    end
                end
            else
                hiddenSince = nil
            end
        end
        if count > 1 then
            print(("^1[fks-character] a personagem foi escondida %d vezes depois de entrar: outro recurso está a esconder o jogador (SetEntityVisible / spawnmanager).^7"):format(count))
        end
    end)
end)

-- mantém o spawn automático desligado e guarda a última posição boa
CreateThread(function()
    while true do
        Wait(1000)
        if SpawnGuard.inWorld or Scene.active then disableAutoSpawn() end
        if SpawnGuard.inWorld and not Scene.active and not recovering then
            local ped = PlayerPedId()
            -- o spawnmanager deixa o jogador invisível e sem colisão enquanto o muda de sítio
            if DoesEntityExist(ped) and not IsEntityDead(ped) and IsEntityVisible(ped) then
                local c = GetEntityCoords(ped)
                if math.abs(c.x) > 1.0 or math.abs(c.y) > 1.0 then
                    lastPos = vector4(c.x, c.y, c.z, GetEntityHeading(ped))
                end
            end
        end
    end
end)

-- o mapa acabou de carregar: o basic-gamemode vai ligar o spawn automático e pedir um respawn.
-- O callback é registado no mesmo evento, antes de o spawnmanager voltar a correr.
-- Na primeira entrada (nada carregado) não mexemos: o spawn normal segue como sempre.
AddEventHandler("onClientMapStart", function()
    log("onClientMapStart", "busy", busy())
    if busy() then hookAutoSpawn() end
end)

-- Um spawn aconteceu mesmo assim (ex.: outro recurso chamou spawnPlayer diretamente)
AddEventHandler("playerSpawned", function()
    log("playerSpawned", "inWorld", SpawnGuard.inWorld, "loading", SpawnGuard.loading, "scene", Scene.active)
    if SpawnGuard.loading then
        pendingFix = true
    elseif SpawnGuard.inWorld then
        recover("playerSpawned")
    elseif Scene.active == "selection" or (Scene.active == "creator" and Creator.active) then
        recoverScene()
    end
end)

RegisterNetEvent("vorp_core:instanceChanged", function(bucket)
    log("routing bucket mudou para", bucket)
end)
