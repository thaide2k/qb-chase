local QBCore = exports['qb-core']:GetCoreObject()

-- Evento para iniciar perseguição
RegisterNetEvent('qb-chase:server:startPursuit')
AddEventHandler('qb-chase:server:startPursuit', function(playerId)
    if not playerId then
        playerId = source
    end
    TriggerClientEvent('qb-chase:startPursuit', playerId)
end)

-- Comando para administradores iniciarem perseguição em qualquer jogador
QBCore.Commands.Add('inicia_perseguicao_admin', 'Iniciar perseguição em um jogador (Admin)', {{name = 'id', help = 'ID do jogador'}}, true, function(source, args)
    local playerId = tonumber(args[1])
    if playerId then
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            TriggerClientEvent('qb-chase:startPursuit', playerId)
            TriggerClientEvent('QBCore:Notify', source, 'Perseguição iniciada no jogador ID: ' .. playerId, 'success')
        else
            TriggerClientEvent('QBCore:Notify', source, 'Jogador não encontrado', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'ID inválido', 'error')
    end
end, 'admin')

-- Exemplo de gatilho após uma ação (isto é apenas um exemplo - você deve adaptar ao seu sistema)
-- AddEventHandler('qb-jewelery:server:setVitrineState', function()
--     local playerId = source
--     local chance = math.random(1, 100)
--     if chance <= 30 then -- 30% de chance de iniciar perseguição
--         TriggerClientEvent('qb-chase:startPursuit', playerId)
--     end
-- end)