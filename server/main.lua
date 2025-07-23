local LoadedVehicles = {}

-- Load vehicle event
RegisterNetEvent('vehicleloader:loadVehicle')
AddEventHandler('vehicleloader:loadVehicle', function(data)
    local source = source

    if not data or not data.trailerId or not data.vehicleNetId or not data.slotIndex then
        if Config.Debug then
            print(string.format("[VehicleLoader] Invalid load data from player %s", source))
        end
        return
    end

    local trailerId = data.trailerId
    local vehicleNetId = data.vehicleNetId
    local slotIndex = data.slotIndex

    -- Initialize trailer data if not exists
    if not LoadedVehicles[trailerId] then
        LoadedVehicles[trailerId] = {}
    end

    -- Get vehicle entity
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or not DoesEntityExist(vehicle) then
        if Config.Debug then
            print(string.format("[VehicleLoader] Vehicle with netId %s does not exist", vehicleNetId))
        end
        return
    end

    -- Store vehicle data
    local vehicleData = {
        entity = vehicle,
        netId = vehicleNetId,
        model = data.vehicleModel,
        owner = source,
        loadTime = os.time(),
        position = data.position
    }

    LoadedVehicles[trailerId][slotIndex] = vehicleData

    -- Sync to all clients
    TriggerClientEvent('vehicleloader:vehicleLoaded', -1, trailerId, vehicleData, slotIndex)

    if Config.Debug then
        print(string.format("[VehicleLoader] Vehicle %s loaded to trailer %s slot %s by player %s",
            data.vehicleModel, trailerId, slotIndex, source))
    end
end)

-- Unload vehicle event
RegisterNetEvent('vehicleloader:unloadVehicle')
AddEventHandler('vehicleloader:unloadVehicle', function(data)
    local source = source

    if not data or not data.trailerId or not data.slotIndex then
        if Config.Debug then
            print(string.format("[VehicleLoader] Invalid unload data from player %s", source))
        end
        return
    end

    local trailerId = data.trailerId
    local slotIndex = data.slotIndex

    -- Check if vehicle exists in slot
    if not LoadedVehicles[trailerId] or not LoadedVehicles[trailerId][slotIndex] then
        if Config.Debug then
            print(string.format("[VehicleLoader] No vehicle in trailer %s slot %s", trailerId, slotIndex))
        end
        return
    end

    local vehicleData = LoadedVehicles[trailerId][slotIndex]

    -- Remove vehicle from loaded list
    LoadedVehicles[trailerId][slotIndex] = nil

    -- Clean up empty trailer data
    if IsTableEmpty(LoadedVehicles[trailerId]) then
        LoadedVehicles[trailerId] = nil
    end

    -- Sync to all clients
    TriggerClientEvent('vehicleloader:vehicleUnloaded', -1, trailerId, slotIndex)

    if Config.Debug then
        print(string.format("[VehicleLoader] Vehicle unloaded from trailer %s slot %s by player %s",
            trailerId, slotIndex, source))
    end
end)

-- Player connecting - sync loaded vehicles
RegisterNetEvent('vehicleloader:requestSync')
AddEventHandler('vehicleloader:requestSync', function()
    local source = source
    TriggerClientEvent('vehicleloader:syncLoadedVehicles', source, LoadedVehicles)

    if Config.Debug then
        print(string.format("[VehicleLoader] Synced loaded vehicles to player %s", source))
    end
end)

-- Player dropped - cleanup their vehicles if needed
AddEventHandler('playerDropped', function(reason)
    local source = source
    CleanupPlayerVehicles(source)

    if Config.Debug then
        print(string.format("[VehicleLoader] Player %s dropped, cleaned up their vehicles", source))
    end
end)

-- Auto cleanup thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300000) -- Run every 5 minutes
        CleanupInvalidVehicles()
    end
end)

-- Admin commands
RegisterCommand('vl_debug', function(source, args, rawCommand)
    if source == 0 or IsPlayerAceAllowed(source, 'vehicleloader.admin') then
        Config.Debug = not Config.Debug
        local status = Config.Debug and "enabled" or "disabled"

        if source == 0 then
            print(string.format("[VehicleLoader] Debug mode %s", status))
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 255, 0 },
                multiline = true,
                args = { "VehicleLoader", string.format("Debug mode %s", status) }
            })
        end
    end
end, false)

RegisterCommand('vl_status', function(source, args, rawCommand)
    if source == 0 or IsPlayerAceAllowed(source, 'vehicleloader.admin') then
        local trailerCount = 0
        local vehicleCount = 0

        for trailerId, vehicles in pairs(LoadedVehicles) do
            trailerCount = trailerCount + 1
            for _, vehicleData in pairs(vehicles) do
                vehicleCount = vehicleCount + 1
            end
        end

        local statusMsg = string.format("Active trailers: %d, Loaded vehicles: %d", trailerCount, vehicleCount)

        if source == 0 then
            print(string.format("[VehicleLoader] %s", statusMsg))
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = { 0, 255, 0 },
                multiline = true,
                args = { "VehicleLoader", statusMsg }
            })
        end
    end
end, false)

RegisterCommand('vl_cleanup', function(source, args, rawCommand)
    if source == 0 or IsPlayerAceAllowed(source, 'vehicleloader.admin') then
        local cleaned = CleanupInvalidVehicles()
        local cleanupMsg = string.format("Cleaned up %d invalid vehicle references", cleaned)

        if source == 0 then
            print(string.format("[VehicleLoader] %s", cleanupMsg))
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = { 0, 255, 255 },
                multiline = true,
                args = { "VehicleLoader", cleanupMsg }
            })
        end
    end
end, false)

-- Utility functions
function IsTableEmpty(t)
    return next(t) == nil
end

function CleanupPlayerVehicles(playerId)
    local cleaned = 0

    for trailerId, vehicles in pairs(LoadedVehicles) do
        for slotIndex, vehicleData in pairs(vehicles) do
            if vehicleData.owner == playerId then
                LoadedVehicles[trailerId][slotIndex] = nil
                cleaned = cleaned + 1

                -- Sync removal to all clients
                TriggerClientEvent('vehicleloader:vehicleUnloaded', -1, trailerId, slotIndex)
            end
        end

        -- Clean up empty trailer data
        if IsTableEmpty(LoadedVehicles[trailerId]) then
            LoadedVehicles[trailerId] = nil
        end
    end

    return cleaned
end

function CleanupInvalidVehicles()
    local cleaned = 0

    for trailerId, vehicles in pairs(LoadedVehicles) do
        for slotIndex, vehicleData in pairs(vehicles) do
            local vehicle = NetworkGetEntityFromNetworkId(vehicleData.netId)

            if not vehicle or not DoesEntityExist(vehicle) then
                LoadedVehicles[trailerId][slotIndex] = nil
                cleaned = cleaned + 1

                -- Sync removal to all clients
                TriggerClientEvent('vehicleloader:vehicleUnloaded', -1, trailerId, slotIndex)

                if Config.Debug then
                    print(string.format("[VehicleLoader] Cleaned up invalid vehicle in trailer %s slot %s", trailerId,
                        slotIndex))
                end
            end
        end

        -- Clean up empty trailer data
        if IsTableEmpty(LoadedVehicles[trailerId]) then
            LoadedVehicles[trailerId] = nil
        end
    end

    return cleaned
end

-- Export functions for other resources
exports('GetLoadedVehicles', function()
    return LoadedVehicles
end)

exports('GetTrailerVehicles', function(trailerId)
    return LoadedVehicles[trailerId] or {}
end)

exports('IsVehicleLoaded', function(vehicleNetId)
    for trailerId, vehicles in pairs(LoadedVehicles) do
        for slotIndex, vehicleData in pairs(vehicles) do
            if vehicleData.netId == vehicleNetId then
                return true, trailerId, slotIndex
            end
        end
    end
    return false
end)

-- Initialize
Citizen.CreateThread(function()
    if Config.Debug then
        print("[VehicleLoader] Server initialized")
    end
end)
