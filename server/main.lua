-- Server-side Vehicle Loader
local LoadedVehicles = {}
local PlayerCooldowns = {}
local Statistics = {
    totalLoads = 0,
    totalUnloads = 0,
    activeTrailers = 0,
    startTime = os.time()
}

-- Utility Functions
local function SafeExecute(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        if Config.Debug then
            print(string.format("[VehicleLoader] Error: %s", result))
        end
        return false, result
    end
    return true, result
end

local function IsTableEmpty(t)
    return next(t) == nil
end

local function GetCurrentTime()
    return GetGameTimer()
end

local function LogOperation(playerId, operation, details)
    if not Config.Advanced.LogOperations then return end

    local playerName = GetPlayerName(playerId) or "Unknown"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    print(string.format("[VehicleLoader] %s | Player: %s (%s) | Operation: %s | Details: %s",
        timestamp, playerName, playerId, operation, details or "None"))
end

-- Validation Functions
local function ValidatePlayer(source)
    if not source or source == 0 then
        return false, "Invalid player source"
    end

    local player = GetPlayerPed(source)
    if not player or not DoesEntityExist(player) then
        return false, "Player does not exist"
    end

    return true, "Valid player"
end

local function ValidateDistance(source, trailerId)
    local success, player = SafeExecute(GetPlayerPed, source)
    if not success then return false, "Cannot get player" end

    local playerCoords = GetEntityCoords(player)
    local trailer = NetworkGetEntityFromNetworkId(trailerId)

    if not trailer or not DoesEntityExist(trailer) then
        return false, "Trailer does not exist"
    end

    local trailerCoords = GetEntityCoords(trailer)
    local distance = #(playerCoords - trailerCoords)

    if distance > Config.Distances.MAX_INTERACTION then
        return false, "Player too far from trailer"
    end

    return true, "Distance valid"
end

local function ValidateVehicle(vehicleNetId)
    if not vehicleNetId then
        return false, "Invalid vehicle network ID"
    end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or not DoesEntityExist(vehicle) then
        return false, "Vehicle does not exist"
    end

    -- Check if vehicle is destroyed
    if IsEntityDead(vehicle) or GetEntityHealth(vehicle) <= 0 then
        return false, "Vehicle is destroyed"
    end

    return true, "Valid vehicle"
end

local function ValidateLoadRequest(source, data)
    -- Basic data validation
    if not data or not data.trailerId or not data.vehicleNetId or not data.slotIndex then
        return false, "Invalid request data"
    end

    -- Player validation
    local valid, msg = ValidatePlayer(source)
    if not valid then return false, msg end

    -- Distance validation
    valid, msg = ValidateDistance(source, data.trailerId)
    if not valid then return false, msg end

    -- Vehicle validation
    valid, msg = ValidateVehicle(data.vehicleNetId)
    if not valid then return false, msg end

    -- Slot validation
    if data.slotIndex < 1 or data.slotIndex > 10 then -- Max 10 slots
        return false, "Invalid slot index"
    end

    -- Check if slot is already occupied
    if LoadedVehicles[data.trailerId] and LoadedVehicles[data.trailerId][data.slotIndex] then
        return false, "Slot already occupied"
    end

    -- Ownership check (if enabled)
    if Config.CheckOwnership then
        -- Add your ownership check logic here
        -- local isOwner = YourOwnershipSystem.IsOwner(source, data.vehicleNetId)
        -- if not isOwner then return false, "Not vehicle owner" end
    end

    return true, "Valid load request"
end

local function ValidateUnloadRequest(source, data)
    -- Basic data validation
    if not data or not data.trailerId or not data.slotIndex then
        return false, "Invalid request data"
    end

    -- Player validation
    local valid, msg = ValidatePlayer(source)
    if not valid then return false, msg end

    -- Distance validation
    valid, msg = ValidateDistance(source, data.trailerId)
    if not valid then return false, msg end

    -- Check if vehicle exists in slot
    if not LoadedVehicles[data.trailerId] or not LoadedVehicles[data.trailerId][data.slotIndex] then
        return false, "No vehicle in specified slot"
    end

    local vehicleData = LoadedVehicles[data.trailerId][data.slotIndex]

    -- Validate stored vehicle
    valid, msg = ValidateVehicle(vehicleData.netId)
    if not valid then
        -- Clean up invalid reference
        LoadedVehicles[data.trailerId][data.slotIndex] = nil
        return false, msg
    end

    return true, "Valid unload request"
end

-- Cooldown Management
local function IsPlayerOnCooldown(source)
    local currentTime = GetCurrentTime()
    local lastAction = PlayerCooldowns[source] or 0

    if currentTime - lastAction < Config.Timeouts.PLAYER_COOLDOWN then
        return true
    end

    return false
end

local function SetPlayerCooldown(source)
    PlayerCooldowns[source] = GetCurrentTime()
end

-- Statistics Management
local function UpdateStatistics(operation)
    if not Config.Advanced.EnableStatistics then return end

    if operation == "load" then
        Statistics.totalLoads = Statistics.totalLoads + 1
    elseif operation == "unload" then
        Statistics.totalUnloads = Statistics.totalUnloads + 1
    end

    -- Update active trailers count
    local count = 0
    for _ in pairs(LoadedVehicles) do
        count = count + 1
    end
    Statistics.activeTrailers = count
end

-- Main Event Handlers
RegisterNetEvent('vehicleloader:loadVehicle')
AddEventHandler('vehicleloader:loadVehicle', function(data)
    local source = source

    -- Cooldown check
    if IsPlayerOnCooldown(source) then
        TriggerClientEvent('vehicleloader:operationResult', source, {
            success = false,
            message = Config.Locales[Config.Locale]['cooldown_active']
        })
        return
    end

    -- Validate request
    local valid, errorMsg = ValidateLoadRequest(source, data)
    if not valid then
        TriggerClientEvent('vehicleloader:operationResult', source, {
            success = false,
            message = errorMsg
        })
        LogOperation(source, "LOAD_FAILED", errorMsg)
        return
    end

    -- Set cooldown
    SetPlayerCooldown(source)

    local trailerId = data.trailerId
    local vehicleNetId = data.vehicleNetId
    local slotIndex = data.slotIndex

    -- Get vehicle entity
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)

    -- Initialize trailer data if not exists
    if not LoadedVehicles[trailerId] then
        LoadedVehicles[trailerId] = {}
    end

    -- Store vehicle data
    local vehicleData = {
        entity = vehicle,
        netId = vehicleNetId,
        model = data.vehicleModel,
        owner = source,
        loadTime = os.time(),
        position = data.position,
        originalCoords = GetEntityCoords(vehicle),
        originalHeading = GetEntityHeading(vehicle)
    }

    LoadedVehicles[trailerId][slotIndex] = vehicleData

    -- Update statistics
    UpdateStatistics("load")

    -- Sync to all clients
    TriggerClientEvent('vehicleloader:vehicleLoaded', -1, trailerId, vehicleData, slotIndex)

    -- Send success response
    TriggerClientEvent('vehicleloader:operationResult', source, {
        success = true,
        message = Config.Locales[Config.Locale]['vehicle_loaded']
    })

    LogOperation(source, "LOAD_SUCCESS", string.format("Vehicle %s loaded to trailer %s slot %s",
        data.vehicleModel, trailerId, slotIndex))

    if Config.Debug then
        print(string.format("[VehicleLoader] Vehicle %s loaded to trailer %s slot %s by player %s",
            data.vehicleModel, trailerId, slotIndex, source))
    end
end)

RegisterNetEvent('vehicleloader:unloadVehicle')
AddEventHandler('vehicleloader:unloadVehicle', function(data)
    local source = source

    -- Cooldown check
    if IsPlayerOnCooldown(source) then
        TriggerClientEvent('vehicleloader:operationResult', source, {
            success = false,
            message = Config.Locales[Config.Locale]['cooldown_active']
        })
        return
    end

    -- Validate request
    local valid, errorMsg = ValidateUnloadRequest(source, data)
    if not valid then
        TriggerClientEvent('vehicleloader:operationResult', source, {
            success = false,
            message = errorMsg
        })
        LogOperation(source, "UNLOAD_FAILED", errorMsg)
        return
    end

    -- Set cooldown
    SetPlayerCooldown(source)

    local trailerId = data.trailerId
    local slotIndex = data.slotIndex
    local vehicleData = LoadedVehicles[trailerId][slotIndex]

    -- Remove vehicle from loaded list
    LoadedVehicles[trailerId][slotIndex] = nil

    -- Clean up empty trailer data
    if IsTableEmpty(LoadedVehicles[trailerId]) then
        LoadedVehicles[trailerId] = nil
    end

    -- Update statistics
    UpdateStatistics("unload")

    -- Sync to all clients
    TriggerClientEvent('vehicleloader:vehicleUnloaded', -1, trailerId, slotIndex, vehicleData)

    -- Send success response
    TriggerClientEvent('vehicleloader:operationResult', source, {
        success = true,
        message = Config.Locales[Config.Locale]['vehicle_unloaded']
    })

    LogOperation(source, "UNLOAD_SUCCESS", string.format("Vehicle unloaded from trailer %s slot %s",
        trailerId, slotIndex))

    if Config.Debug then
        print(string.format("[VehicleLoader] Vehicle unloaded from trailer %s slot %s by player %s",
            trailerId, slotIndex, source))
    end
end)

-- Player connection handling
RegisterNetEvent('vehicleloader:requestSync')
AddEventHandler('vehicleloader:requestSync', function()
    local source = source

    -- Send loaded vehicles data to client
    TriggerClientEvent('vehicleloader:syncLoadedVehicles', source, LoadedVehicles)

    if Config.Debug then
        print(string.format("[VehicleLoader] Synced loaded vehicles to player %s", source))
    end
end)

-- Player disconnection cleanup
AddEventHandler('playerDropped', function(reason)
    local source = source

    -- Remove player cooldown
    PlayerCooldowns[source] = nil

    -- Cleanup player vehicles if needed
    local cleaned = CleanupPlayerVehicles(source)

    LogOperation(source, "DISCONNECT", string.format("Cleaned up %d vehicles", cleaned))

    if Config.Debug then
        print(string.format("[VehicleLoader] Player %s dropped, cleaned up %d vehicles", source, cleaned))
    end
end)

-- Cleanup Functions
function CleanupPlayerVehicles(playerId)
    local cleaned = 0

    for trailerId, vehicles in pairs(LoadedVehicles) do
        for slotIndex, vehicleData in pairs(vehicles) do
            if vehicleData.owner == playerId then
                LoadedVehicles[trailerId][slotIndex] = nil
                cleaned = cleaned + 1

                -- Sync removal to all clients
                TriggerClientEvent('vehicleloader:vehicleUnloaded', -1, trailerId, slotIndex, vehicleData)
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

            if not vehicle or not DoesEntityExist(vehicle) or IsEntityDead(vehicle) then
                LoadedVehicles[trailerId][slotIndex] = nil
                cleaned = cleaned + 1

                -- Sync removal to all clients
                TriggerClientEvent('vehicleloader:vehicleUnloaded', -1, trailerId, slotIndex, vehicleData)

                if Config.Debug then
                    print(string.format("[VehicleLoader] Cleaned up invalid vehicle in trailer %s slot %s",
                        trailerId, slotIndex))
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

-- Admin Commands
RegisterCommand('vl_debug', function(source, args, rawCommand)
    if source ~= 0 and not IsPlayerAceAllowed(source, Config.Permissions.ADMIN) then
        return
    end

    Config.Debug = not Config.Debug
    local status = Config.Debug and "enabled" or "disabled"
    local message = string.format("Debug mode %s", status)

    if source == 0 then
        print(string.format("[VehicleLoader] %s", message))
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 255, 0 },
            multiline = true,
            args = { "VehicleLoader", message }
        })
    end

    LogOperation(source, "ADMIN_DEBUG", status)
end, false)

RegisterCommand('vl_status', function(source, args, rawCommand)
    if source ~= 0 and not IsPlayerAceAllowed(source, Config.Permissions.ADMIN) then
        return
    end

    local trailerCount = 0
    local vehicleCount = 0

    for trailerId, vehicles in pairs(LoadedVehicles) do
        trailerCount = trailerCount + 1
        for _, vehicleData in pairs(vehicles) do
            vehicleCount = vehicleCount + 1
        end
    end

    local uptime = os.time() - Statistics.startTime
    local statusMsg = string.format(
        "Active trailers: %d | Loaded vehicles: %d | Total loads: %d | Total unloads: %d | Uptime: %ds",
        trailerCount, vehicleCount, Statistics.totalLoads, Statistics.totalUnloads, uptime
    )

    if source == 0 then
        print(string.format("[VehicleLoader] %s", statusMsg))
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 255, 0 },
            multiline = true,
            args = { "VehicleLoader", statusMsg }
        })
    end
end, false)

RegisterCommand('vl_cleanup', function(source, args, rawCommand)
    if source ~= 0 and not IsPlayerAceAllowed(source, Config.Permissions.ADMIN) then
        return
    end

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

    LogOperation(source, "ADMIN_CLEANUP", string.format("%d vehicles", cleaned))
end, false)

RegisterCommand('vl_reload', function(source, args, rawCommand)
    if source ~= 0 and not IsPlayerAceAllowed(source, Config.Permissions.ADMIN) then
        return
    end

    -- Clear all loaded vehicles
    LoadedVehicles = {}
    PlayerCooldowns = {}

    -- Reset statistics
    Statistics = {
        totalLoads = 0,
        totalUnloads = 0,
        activeTrailers = 0,
        startTime = os.time()
    }

    -- Notify all clients to reset
    TriggerClientEvent('vehicleloader:systemReset', -1)

    local message = "Vehicle Loader system reloaded"
    if source == 0 then
        print(string.format("[VehicleLoader] %s", message))
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 255, 0, 255 },
            multiline = true,
            args = { "VehicleLoader", message }
        })
    end

    LogOperation(source, "ADMIN_RELOAD", "System reset")
end, false)

-- Auto cleanup thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.Timeouts.SERVER_CLEANUP)

        local cleaned = CleanupInvalidVehicles()
        if cleaned > 0 and Config.Debug then
            print(string.format("[VehicleLoader] Auto cleanup removed %d invalid vehicles", cleaned))
        end
    end
end)

-- Database save thread (if enabled)
if Config.Database.Enabled then
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(Config.Database.SaveInterval)
            SaveLoadedVehiclesToDatabase()
        end
    end)
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

exports('GetStatistics', function()
    return Statistics
end)

exports('ForceUnloadVehicle', function(trailerId, slotIndex)
    if LoadedVehicles[trailerId] and LoadedVehicles[trailerId][slotIndex] then
        local vehicleData = LoadedVehicles[trailerId][slotIndex]
        LoadedVehicles[trailerId][slotIndex] = nil

        if IsTableEmpty(LoadedVehicles[trailerId]) then
            LoadedVehicles[trailerId] = nil
        end

        TriggerClientEvent('vehicleloader:vehicleUnloaded', -1, trailerId, slotIndex, vehicleData)
        return true
    end
    return false
end)

-- Database functions (if enabled)
function SaveLoadedVehiclesToDatabase()
    if not Config.Database.Enabled then return end

    -- Add your database saving logic here
    -- Example with MySQL:
    -- MySQL.Async.execute('DELETE FROM ' .. Config.Database.Table)
    --
    -- for trailerId, vehicles in pairs(LoadedVehicles) do
    --     for slotIndex, vehicleData in pairs(vehicles) do
    --         MySQL.Async.execute(
    --             'INSERT INTO ' .. Config.Database.Table .. ' (trailer_id, slot_index, vehicle_data) VALUES (?, ?, ?)',
    --             {trailerId, slotIndex, json.encode(vehicleData)}
    --         )
    --     end
    -- end
end

function LoadVehiclesFromDatabase()
    if not Config.Database.Enabled then return end

    -- Add your database loading logic here
    -- Example with MySQL:
    -- MySQL.Async.fetchAll('SELECT * FROM ' .. Config.Database.Table, {}, function(results)
    --     for _, row in pairs(results) do
    --         local vehicleData = json.decode(row.vehicle_data)
    --         if not LoadedVehicles[row.trailer_id] then
    --             LoadedVehicles[row.trailer_id] = {}
    --         end
    --         LoadedVehicles[row.trailer_id][row.slot_index] = vehicleData
    --     end
    -- end)
end

-- Initialize server
Citizen.CreateThread(function()
    -- Load from database if enabled
    LoadVehiclesFromDatabase()

    if Config.Debug then
        print("[VehicleLoader] Server initialized successfully")
        print(string.format("[VehicleLoader] Config: Debug=%s, CheckOwnership=%s, Database=%s",
            tostring(Config.Debug), tostring(Config.CheckOwnership), tostring(Config.Database.Enabled)))
    end
end)
