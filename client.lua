local QBCore = exports['qb-core']:GetCoreObject()
local isPursuitActive = false
local pursuer = nil
local pursuitBlip = nil
local searchTimer = nil
local targetPlayer = nil
local searchArea = nil
local lastMovePos = nil
local stuckTime = 0

-- Função para criar o perseguidor
function CreatePursuer(playerPed)
    local playerCoords = GetEntityCoords(playerPed)
    local spawnPoint = FindSpawnPointBehindPlayer(playerPed)
    
    -- Carrega o modelo do veículo
    local vehicleHash = GetHashKey(Config.PursuitSettings.vehicleModel)
    RequestModel(vehicleHash)
    while not HasModelLoaded(vehicleHash) do
        Wait(1)
    end
    
    -- Cria o veículo
    local vehicle = CreateVehicle(vehicleHash, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.heading, true, false)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleForwardSpeed(vehicle, 30.0)  -- Increased from 10.0
    SetVehicleModKit(vehicle, 0)
    SetVehicleMod(vehicle, 11, 3, false) -- Melhorar motor
    SetVehicleMod(vehicle, 12, 2, false) -- Melhorar freios
    SetVehicleMod(vehicle, 13, 2, false) -- Melhorar transmissão
    SetVehicleColours(vehicle, 0, 0) -- Preto
    SetVehicleNumberPlateText(vehicle, "PURSUIT")
    SetVehicleDoorsLocked(vehicle, 2) -- Travar portas
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    -- SetVehicleEngineHealth(vehicle, Config.PursuitSettings.pursuerHealth) --esta spawnando sem life
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce", 0.5) -- Mais potência de aceleração
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveInertia", 1.0) -- Melhor resposta do motor
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax", 2.5) -- Melhor tração
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMin", 2.3) -- Evita derrapagens
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", 1.5) -- Melhor frenagem
    SetVehicleReduceGrip(vehicle, false) -- Evita perda de tração
    SetVehicleHasStrongAxles(vehicle, true) -- Melhora a robustez
    -- Se tiver sirene
    SetVehicleSiren(vehicle, true)


    -- Cria o motorista NPC
    local driverHash = GetHashKey("s_m_y_swat_01")
    RequestModel(driverHash)
    while not HasModelLoaded(driverHash) do
        Wait(1)
    end
    
    local driver = CreatePedInsideVehicle(vehicle, 26, driverHash, -1, true, false)
    SetDriverAbility(driver, Config.PursuitSettings.pursuerAccuracyDriving)
    SetDriverAggressiveness(driver, Config.PursuitSettings.pursuerAggressiveness)
    SetPedPathAvoidFire(driver, true)
    SetPedPathCanUseLadders(driver, false)
    SetPedPathCanDropFromHeight(driver, false)
    SetPedPathPreferToAvoidWater(driver, true)
    SetPedKeepTask(driver, true)
    SetPedFleeAttributes(driver, 0, true)
    SetPedCombatAttributes(driver, 2, true)
    SetPedCombatAttributes(driver, 46, true)
    SetPedCombatAttributes(driver, 1, true)
    SetBlockingOfNonTemporaryEvents(driver, true)
    SetPedCanRagdollFromPlayerImpact(driver, false)
    SetPedSuffersCriticalHits(driver, false)
    
    -- Adiciona blip ao mapa
    local blip = AddBlipForEntity(vehicle)
    SetBlipSprite(blip, 326) -- Sprite de perseguição
    SetBlipColour(blip, 1) -- Vermelho
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Perseguidor")
    EndTextCommandSetBlipName(blip)
    
    return {
        vehicle = vehicle,
        driver = driver,
        blip = blip
    }
end

-- Encontrar um ponto de spawn atrás do jogador
function FindSpawnPointBehindPlayer(playerPed)
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    local spawnHeading = (playerHeading + 180.0) % 360.0
    
    local spawnDistance = 15.0 -- Original era 80
    local spawnX = playerCoords.x - spawnDistance * math.sin(math.rad(spawnHeading))
    local spawnY = playerCoords.y - spawnDistance * math.cos(math.rad(spawnHeading))
    local z, groundFound = 0, false
    local groundCheckHeight = 100.0
    
    for i = 0, 10 do
        local foundZ, zPos = GetGroundZFor_3dCoord(spawnX, spawnY, groundCheckHeight)
        if foundZ then
            z = zPos
            groundFound = true
            break
        end
        groundCheckHeight = groundCheckHeight - 10.0
        Wait(0)
    end
    
    if not groundFound then
        z = playerCoords.z
    end
    
    return {x = spawnX, y = spawnY, z = z, heading = spawnHeading}
end

-- Função para exibir notificação na tela
function ShowNotification(text, duration)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, duration)
    
    -- Mostra texto grande na tela
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, true)
    
    -- Mensagem ainda mais visível no centro da tela
    Citizen.CreateThread(function()
        local scaleform = RequestScaleformMovie("mp_big_message_freemode")
        while not HasScaleformMovieLoaded(scaleform) do
            Citizen.Wait(0)
        end
        
        BeginScaleformMovieMethod(scaleform, "SHOW_SHARD_WASTED_MP_MESSAGE")
        PushScaleformMovieMethodParameterString("~r~" .. text)
        PushScaleformMovieMethodParameterString("")
        EndScaleformMovieMethod()
        
        local time = GetGameTimer()
        while GetGameTimer() - time < duration do
            Citizen.Wait(0)
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
        end
        SetScaleformMovieAsNoLongerNeeded(scaleform)
    end)
end

-- Função para iniciar a perseguição
function StartPursuit()
    if isPursuitActive then
        return false
    end

    local playerPed = PlayerPedId()
    
    if IsPedInAnyVehicle(playerPed, false) then
        isPursuitActive = true
        local pursuerData = CreatePursuer(playerPed)
        pursuer = pursuerData
        pursuitBlip = pursuerData.blip
        
        ShowNotification("DE A FUGA!", Config.PursuitSettings.notificationDuration)
        
        -- Thread para gerenciar a perseguição
        Citizen.CreateThread(function()
            ManagePursuit()
        end)
        
        return true
    else
        QBCore.Functions.Notify("Você precisa estar em um veículo para iniciar a perseguição!", "error")
        return false
    end
end

-- Gerenciar a perseguição
function ManagePursuit()
    while isPursuitActive and DoesEntityExist(pursuer.vehicle) and DoesEntityExist(pursuer.driver) do
        local playerPed = PlayerPedId()
        
        if IsPedInAnyVehicle(playerPed, false) then
            local playerVehicle = GetVehiclePedIsIn(playerPed, false)
            local pursuerCoords = GetEntityCoords(pursuer.vehicle)
            local playerCoords = GetEntityCoords(playerVehicle)
            local distance = #(playerCoords - pursuerCoords)
            
            -- Verificar se o jogador ainda está no veículo e vivo
            if DoesEntityExist(playerVehicle) and not IsEntityDead(playerPed) then
                -- Se estiver na distância de perseguição direta
                if distance < Config.PursuitSettings.pursuitDistance then
            --        -- Cancelar busca se estiver ativa
                    if searchTimer then
                        clearSearchTimer()
                    end
                    
                    -- Atualizar tarefa do NPC para perseguir
                    if distance > 50.0 then
                        -- Se estiver muito longe, use navegação por caminho para evitar obstáculos
                        local playerCoords = GetEntityCoords(playerPed)
                        TaskVehicleDriveToCoordLongrange(pursuer.driver, pursuer.vehicle, 
                            playerCoords.x, playerCoords.y, playerCoords.z, 
                            45.0, -- Velocidade adequada
                            786603, -- Driving style flag para comportamento mais inteligente
                           5.0) -- Distância de parada
        
            else
                        TaskVehicleChase(pursuer.driver, playerPed)
                    SetTaskVehicleChaseIdealPursuitDistance(pursuer.driver, 15.0) -- Aumentar esta distância
                    end
                    -- TaskVehicleChase(pursuer.driver, playerPed) --Sugestao de mudar
                    -- SetTaskVehicleChaseIdealPursuitDistance(pursuer.driver, 15.0) --era 15 vou mudar para 1
                    
               else --tava ativo
                    -- Se o jogador escapou da visão, iniciar busca
                    if not searchTimer then
                        startSearch(playerCoords)
                    end
                end
                
                -- Verificar dano do veículo do jogador
                local playerVehicleHealth = GetVehicleBodyHealth(playerVehicle)
                if playerVehicleHealth <= 100 then
                    EndPursuit(false, "Seu veículo foi destruído!")
                end
                
                -- Verificar dano do veículo perseguidor
                local pursuerVehicleHealth = GetVehicleBodyHealth(pursuer.vehicle)
                if pursuerVehicleHealth <= 100 then
                    EndPursuit(true, "Você destruiu o perseguidor!")
                end
            else
                EndPursuit(false, "Você saiu do veículo ou morreu!")
            end
        else
            EndPursuit(false, "Você saiu do veículo!")
        end
                local currentPursuerPos = GetEntityCoords(pursuer.vehicle)
                if lastMovePos then
                local moveDistance = #(currentPursuerPos - lastMovePos)
                if moveDistance < 0.5 and distance > 20.0 then
                stuckTime = stuckTime + 1
                if stuckTime > 3 then -- Preso por mais de 3 segundos
                -- Tentar desbloquear
                local playerCoords = GetEntityCoords(playerPed)
                -- Fazer o veículo dar um "empurrão" para sair
                SetVehicleForwardSpeed(pursuer.vehicle, -10.0)
                     Wait(500)
                SetVehicleForwardSpeed(pursuer.vehicle, 15.0)
                -- Reposicionar se continuar preso
                if stuckTime > 10 then
                -- Tentar reposicionar atrás do jogador
                local spawnPoint = FindSpawnPointBehindPlayer(playerPed)
                SetEntityCoordsNoOffset(pursuer.vehicle, 
                    spawnPoint.x, spawnPoint.y, spawnPoint.z, 
                    false, false, false)
                SetEntityHeading(pursuer.vehicle, spawnPoint.heading)
                stuckTime = 0
            end
        end
    else
        stuckTime = 0
    end
end
lastMovePos = currentPursuerPos
        Citizen.Wait(1000)
    end
end

-- Iniciar busca quando o jogador escapa - V2
function startSearch(lastKnownPosition)
    if searchTimer then
        clearSearchTimer()
    end
    
    searchArea = lastKnownPosition
    local searchBlip = AddBlipForRadius(searchArea.x, searchArea.y, searchArea.z, Config.PursuitSettings.searchRadius)
    SetBlipAlpha(searchBlip, 80)
    SetBlipColour(searchBlip, 1) -- Vermelho
    
    -- Fazer o NPC patrulhar a área de busca específica, não a cidade inteira
    -- Em vez de usar TaskVehicleDriveWander, vamos fazer ele procurar em padrão
    -- de quadrícula na última localização conhecida
    
    ShowNotification("~y~O perseguidor perdeu você de vista! Buscando por 2 minutos...", 3000)
    
    searchTimer = {
        timeRemaining = Config.PursuitSettings.searchTime,
        blip = searchBlip,
        lastSearchPoint = vector3(searchArea.x, searchArea.y, searchArea.z),
        searchGrid = {
            {x = 1, y = 1},
            {x = 1, y = -1},
            {x = -1, y = 1},
            {x = -1, y = -1},
            {x = 0, y = 1},
            {x = 1, y = 0},
            {x = 0, y = -1},
            {x = -1, y = 0}
        },
        currentGridIndex = 1,
        thread = Citizen.CreateThread(function()
            local startTime = GetGameTimer()
            local searchPointUpdateTime = 0
            
            while GetGameTimer() - startTime < Config.PursuitSettings.searchTime and isPursuitActive do
                Citizen.Wait(1000)
                
                local playerPed = PlayerPedId()
                if IsPedInAnyVehicle(playerPed, false) then
                    local playerVehicle = GetVehiclePedIsIn(playerPed, false)
                    local playerCoords = GetEntityCoords(playerVehicle)
                    local pursuerCoords = GetEntityCoords(pursuer.vehicle)
                    local distance = #(playerCoords - pursuerCoords)
                    
                    -- Se o perseguidor encontrar o jogador novamente
                    if distance < Config.PursuitSettings.pursuitDistance then
                        ShowNotification("~r~O perseguidor te encontrou novamente!", 3000)
                        clearSearchTimer()
                        return
                    end
                    
                    -- Atualizar ponto de busca a cada 5 segundos para simular uma busca em padrão
                    if GetGameTimer() - searchPointUpdateTime > 5000 then
                        searchPointUpdateTime = GetGameTimer()
                        
                        -- Obter próximo ponto no padrão de busca
                        local grid = searchTimer.searchGrid[searchTimer.currentGridIndex]
                        searchTimer.currentGridIndex = searchTimer.currentGridIndex % #searchTimer.searchGrid + 1
                        
                        -- Calcular novo ponto de busca baseado no padrão
                        local searchOffset = 100.0 -- 100 unidades em cada direção
                        local newSearchPoint = vector3(
                            searchArea.x + (grid.x * searchOffset),
                            searchArea.y + (grid.y * searchOffset),
                            searchArea.z
                        )
                        
                        -- Direcionar o perseguidor para esse ponto
                        TaskVehicleDriveToCoord(
                            pursuer.driver, 
                            pursuer.vehicle, 
                            newSearchPoint.x, 
                            newSearchPoint.y, 
                            newSearchPoint.z, 
                            100.0, -- Velocidade
                            0, -- Normal driving
                            GetEntityModel(pursuer.vehicle), 
                            786603, -- Driving style
                            15.0, -- Stopping range
                            2.0 -- p13
                        )
                        
                        searchTimer.lastSearchPoint = newSearchPoint
                    end
                end
            end
            
            -- Se o temporizador expirar sem encontrar o jogador
            if isPursuitActive then
                EndPursuit(true, "Você conseguiu escapar da perseguição!")
            end
        end)
    }
end
-- Iniciar busca quando o jogador escapa
--function startSearch(lastKnownPosition)
--    if searchTimer then
--        clearSearchTimer()
--    end
--    
--    searchArea = lastKnownPosition
--    local searchBlip = AddBlipForRadius(searchArea.x, searchArea.y, searchArea.z, Config.PursuitSettings.searchRadius)
--    SetBlipAlpha(searchBlip, 80)
--    SetBlipColour(searchBlip, 1) -- Vermelho
--    
--    -- Fazer o NPC patrulhar a área de busca
--    TaskVehicleDriveWander(pursuer.driver, pursuer.vehicle, 30.0, 447)
--    
--    ShowNotification("~y~O perseguidor perdeu você de vista! Buscando por 2 minutos...", 3000)
--    
--
--    --    searchTimer = {
--        timeRemaining = Config.PursuitSettings.searchTime,
--        blip = searchBlip,
--        thread = Citizen.CreateThread(function()
--            local startTime = GetGameTimer()
--            
--            while GetGameTimer() - startTime < Config.PursuitSettings.searchTime and isPursuitActive do
--                Citizen.Wait(1000)
--                
--                local playerPed = PlayerPedId()
--                if IsPedInAnyVehicle(playerPed, false) then
--                    local playerVehicle = GetVehiclePedIsIn(playerPed, false)
--                    local playerCoords = GetEntityCoords(playerVehicle)
--                    local pursuerCoords = GetEntityCoords(pursuer.vehicle)
--                    local distance = #(playerCoords - pursuerCoords)
--                    
--                    -- Se o perseguidor encontrar o jogador novamente
--                    if distance < Config.PursuitSettings.pursuitDistance then
--                        ShowNotification("~r~O perseguidor te encontrou novamente!", 3000)
--                        clearSearchTimer()
--                        return
--                    end
--                end
--            end
--            
--            -- Se o temporizador expirar sem encontrar o jogador
--            if isPursuitActive then
--                EndPursuit(true, "Você conseguiu escapar da perseguição!")
--            end
--        end)
--    }
-- end

-- Limpar temporizador de busca
function clearSearchTimer()
    if searchTimer then
        if searchTimer.blip and DoesBlipExist(searchTimer.blip) then
            RemoveBlip(searchTimer.blip)
        end
        searchTimer = nil
        searchArea = nil
    end
end

-- Finalizar perseguição
function EndPursuit(success, message)
    if not isPursuitActive then return end
    
    isPursuitActive = false
    
    -- Mostrar mensagem de resultado
    if message then
        if success then
            ShowNotification("~g~" .. message, 5000)
        else
            ShowNotification("~r~" .. message, 5000)
        end
    end
    
    -- Limpar temporizador de busca se estiver ativo
    if searchTimer then
        clearSearchTimer()
    end
    
    -- Remover entidades
    if pursuer then
    -- MUdanca para deletar entidade V3
        if DoesEntityExist(pursuer.vehicle) then
            -- Deixar o perseguidor ir embora antes de deletar
            SetVehicleSiren(vehicle, false) -- tentei desligar a porra da sirene
            TaskVehicleDriveWander(pursuer.driver, pursuer.vehicle, 40.0, 447)
            SetTimeout(10000, function()
                DeleteEntity(pursuer.vehicle)
                DeleteEntity(pursuer.driver)
            end)
        end
    
        if pursuitBlip and DoesBlipExist(pursuitBlip) then
            RemoveBlip(pursuitBlip)
        end
        
        pursuer = nil
        pursuitBlip = nil
    end
end

-- Registrar comando para iniciar perseguição (para testes)
RegisterCommand("iniciar_perseguicao", function()
    StartPursuit()
end, false)

-- Evento para iniciar perseguição
RegisterNetEvent('qb-chase:startPursuit')
AddEventHandler('qb-chase:startPursuit', function()
    StartPursuit()
end)

exports('IniciarPerseguicao', function()
    return StartPursuit()
end)