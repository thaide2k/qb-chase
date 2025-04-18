Config = {}

Config.PursuitSettings = {
    vehicleModel = "sultanrs", -- Modelo do carro perseguidor
    -- vehicleModel = "sultanrs", -- Modelo do carro perseguidor - melhor atm
    searchTime = 20000, -- Tempo de busca em milissegundos (2 minutos)
    notificationDuration = 5000, -- Duração da notificação na tela
    pursuitDistance = 150.0, -- Distância máxima antes de iniciar busca
    searchRadius = 250.0, -- Raio de busca quando o alvo é perdido
    pursuerHealth = 1000, -- Vida do veículo perseguidor
    pursuerAccuracyDriving = 1.0, -- Habilidade de direção do NPC (0.0 a 1.0)
    pursuerAggressiveness = 1.0 -- Agressividade do NPC (0.0 a 1.0)
}