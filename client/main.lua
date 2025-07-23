-- Client-side Vehicle Loader
local LoadedVehicles = {}
local CurrentTrailer = nil
local MenuOpen = false
local PlayerPed = nil
local PlayerVehicle = nil
local LastInteractionTime = 0
local ModelNameCache = {}
local LoadingInProgress = false

-- Performance optimization
local GetEntityCoords = GetEntityCoords
local GetEntityModel = GetEntityModel
local GetVehicleClass = GetVehicleClass
local DoesEntityExist = DoesEntityExist
local GetGameTimer = GetGameTimer

-- Utility Functions
local function SafeExecute(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        if Config.Debug then
            print(string.format("[VehicleLoader] Client Error: %s", result))
        end
        return false, result
    end
    return true, result
end

local function GetCachedModelName(entity)
    local model = GetEntityModel(entity)

    if not ModelNameCache[model] then
        ModelNameCache[model] = string.lower(GetDisplayNameFromVehicleModel(model))
    end

    return ModelNameCache[model]
end

local function CanInteract()
    local currentTime = GetGameTimer()
    return currentTime - LastInteractionTime > Config.Timeouts.PLAYER_COOLDOWN
end

local function SetLastInteractionTime()
    LastInteractionTime = GetGameTimer()
end

local function ValidateEntities(vehicle, trailer)
    if not vehicle or not DoesEntityExist(vehicle) then
        return false, Config.Locales[Config.Locale]['loading_failed']
    end

    if not trailer or not DoesEntityExist(trailer) then
        return false, Config.Locales[Config.Locale]['no_trailer']
    end

    -- Check if vehicle is destroyed
    if IsEntityDead(vehicle) or GetEntityHealth(vehicle) <= 0 then
        return false, Config.Locales[Config.Locale]['vehicle_destroyed']
    end

    return true, "Valid"
end

-- Accessor functions for LoadedVehicles
function GetLoadedVehicles()
    return LoadedVehicles
end

function SetLoadedVehicleSlot(trailerId, slotIndex, data)
    if not LoadedVehicles[trailerId] then
        LoadedVehicles[trailerId] = {}
    end
    LoadedVehicles[trailerId][slotIndex] = data
end

function ClearLoadedVehicleSlot(trailerId, slotIndex)
    if LoadedVehicles[trailerId] then
        LoadedVehicles[trailerId][slotIndex] = nil

        -- Clean up empty trailer data
        local isEmpty = true
        for _ in pairs(LoadedVehicles[trailerId]) do
            isEmpty = false
            break
        end

        if isEmpty then
            LoadedVehicles[trailerId] = nil
        end
    end
end

-- Main thread
Citizen.CreateThread(function()
    -- Request sync on start
    TriggerServerEvent('vehicleloader:requestSync')

    while true do
        local sleep = 1000

        PlayerPed = PlayerPedId()
        PlayerVehicle = GetVehiclePedIsIn(PlayerPed, false)

        if not MenuOpen then
            local nearbyTrailer = GetNearbyTrailer()
            if nearbyTrailer then
                CurrentTrailer = nearbyTrailer
                sleep = 0

                -- Draw interaction text
                DrawText3D(GetEntityCoords(nearbyTrailer), Config.Locales[Config.Locale]['open_menu'])

                -- Check for menu key
                if IsControlJustPressed(0, Config.Keys.MENU) and CanInteract() then
                    OpenVehicleLoaderMenu()
                    SetLastInteractionTime()
                end
            else
                CurrentTrailer = nil
            end
        end

        -- Quick load/unload keys
        if CurrentTrailer and not MenuOpen and CanInteract() then
            if IsControlJustPressed(0, Config.Keys.LOAD) then
                LoadVehicleQuick()
                SetLastInteractionTime()
            elseif IsControlJustPressed(0, Config.Keys.UNLOAD) then
                UnloadVehicleQuick()
                SetLastInteractionTime()
            end
        end

        Citizen.Wait(sleep)
    end
end)

-- Check for nearby trailers with caching
local nearbyTrailerCache = {}
local lastTrailerCheck = 0

function GetNearbyTrailer()
    local currentTime = GetGameTimer()

    -- Use cached result if recent
    if currentTime - lastTrailerCheck < 500 and nearbyTrailerCache.result then
        return nearbyTrailerCache.result
    end

    local playerCoords = GetEntityCoords(PlayerPed)
    local closestTrailer = nil
    local closestDistance = Config.Distances.MAX_INTERACTION

    -- Get vehicles in range
    local vehicles = GetVehiclesInArea(playerCoords, Config.Distances.MAX_INTERACTION)

    for _, vehicle in pairs(vehicles) do
        local modelName = GetCachedModelName(vehicle)

        if Config.Trailers[modelName] then
            local distance = #(playerCoords - GetEntityCoords(vehicle))
            if distance < closestDistance then
                closestDistance = distance
                closestTrailer = vehicle
            end
        end
    end

    -- Cache result
    lastTrailerCheck = currentTime
    nearbyTrailerCache.result = closestTrailer

    return closestTrailer
end

-- Optimized vehicle area search
function GetVehiclesInArea(coords, maxDistance)
    local vehicles = {}
    local handle, vehicle = FindFirstVehicle()
    local success
    local count = 0

    repeat
        if count > 100 then break end -- Safety limit

        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(coords - vehicleCoords)

        if distance <= maxDistance then
            table.insert(vehicles, vehicle)
        end

        success, vehicle = FindNextVehicle(handle)
        count = count + 1
    until not success

    EndFindVehicle(handle)
    return vehicles
end

-- Menu functions
function OpenVehicleLoaderMenu()
    if not CurrentTrailer or LoadingInProgress then
        return
    end

    MenuOpen = true
    SetNuiFocus(true, true)

    -- Play menu open sound
    PlaySound(Config.Sounds.menu_open)

    local trailerModel = GetEntityModel(CurrentTrailer)
    local trailerName = GetCachedModelName(CurrentTrailer)
    local trailerConfig = Config.Trailers[trailerName]

    if not trailerConfig then
        MenuOpen = false
        SetNuiFocus(false, false)
        ShowNotification(Config.Locales[Config.Locale]['loading_failed'])
        return
    end

    local trailerData = {
        entity = CurrentTrailer,
        model = trailerName,
        config = trailerConfig,
        loadedVehicles = GetLoadedVehiclesData(CurrentTrailer),
        nearbyVehicles = GetNearbyVehiclesData()
    }

    SendNUIMessage({
        type = 'openMenu',
        trailer = trailerData,
        locale = Config.Locales[Config.Locale],
        vehicleClasses = Config.VehicleClasses
    })
end

function RequestMenuUpdate()
    if not MenuOpen or not CurrentTrailer then return end

    local trailerName = GetCachedModelName(CurrentTrailer)
    local trailerConfig = Config.Trailers[trailerName]

    if not trailerConfig then return end

    local trailerData = {
        entity = CurrentTrailer,
        model = trailerName,
        config = trailerConfig,
        loadedVehicles = GetLoadedVehiclesData(CurrentTrailer),
        nearbyVehicles = GetNearbyVehiclesData()
    }

    SendNUIMessage({
        type = 'updateTrailer',
        trailer = trailerData
    })
end

-- NUI Callbacks
RegisterNUICallback('closeMenu', function(data, cb)
    MenuOpen = false
    SetNuiFocus(false, false)
    PlaySound(Config.Sounds.menu_close)

    -- Always send a response
    cb({ status = 'ok' })
end)

RegisterNUICallback('loadVehicle', function(data, cb)
    if LoadingInProgress then
        cb({ success = false, message = Config.Locales[Config.Locale]['operation_in_progress'] })
        return
    end

    local vehicleId = tonumber(data.vehicleId)
    if not vehicleId then
        cb({ success = false, message = "Invalid vehicle ID" })
        return
    end

    LoadVehicleToTrailer(vehicleId, CurrentTrailer, function(result)
        cb(result)
        if result.success then
            Citizen.SetTimeout(1000, RequestMenuUpdate)
        end
    end)
end)

RegisterNUICallback('unloadVehicle', function(data, cb)
    if LoadingInProgress then
        cb({ success = false, message = Config.Locales[Config.Locale]['operation_in_progress'] })
        return
    end

    local slotIndex = tonumber(data.slotIndex)
    if not slotIndex then
        cb({ success = false, message = "Invalid slot index" })
        return
    end

    UnloadVehicleFromTrailer(slotIndex, CurrentTrailer, function(result)
        cb(result)
        if result.success then
            Citizen.SetTimeout(1000, RequestMenuUpdate)
        end
    end)
end)

RegisterNUICallback('requestUpdate', function(data, cb)
    RequestMenuUpdate()
    cb({ status = 'ok' })
end)

-- Get loaded vehicles data for UI
function GetLoadedVehiclesData(trailer)
    local loadedData = {}
    local trailerId = NetworkGetNetworkIdFromEntity(trailer)

    if LoadedVehicles[trailerId] then
        for i, vehicleData in pairs(LoadedVehicles[trailerId]) do
            if DoesEntityExist(vehicleData.entity) then
                local model = GetEntityModel(vehicleData.entity)
                local displayName = GetDisplayNameFromVehicleModel(model)
                local vehicleClass = GetVehicleClass(vehicleData.entity)

                table.insert(loadedData, {
                    slot = i,
                    entity = vehicleData.entity,
                    model = vehicleData.model or GetCachedModelName(vehicleData.entity),
                    displayName = displayName,
                    class = vehicleClass,
                    className = Config.VehicleClasses[vehicleClass] or "Unknown"
                })
            end
        end
    end

    -- Sort by slot number
    table.sort(loadedData, function(a, b)
        return a.slot < b.slot
    end)

    return loadedData
end

-- Get nearby vehicles data for UI
function GetNearbyVehiclesData()
    local playerCoords = GetEntityCoords(PlayerPed)
    local vehicles = GetVehiclesInArea(playerCoords, Config.Distances.MAX_INTERACTION)
    local vehiclesData = {}
    local count = 0

    for _, vehicle in pairs(vehicles) do
        if count >= Config.MaxNearbyVehicles then break end

        if vehicle ~= CurrentTrailer and not IsVehicleLoaded(vehicle) then
            local modelName = GetCachedModelName(vehicle)
            local displayName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
            local vehicleClass = GetVehicleClass(vehicle)
            local distance = #(playerCoords - GetEntityCoords(vehicle))

            -- Check if vehicle is valid for loading
            if not IsVehicleBlacklisted(modelName, vehicleClass) and
                not IsEntityDead(vehicle) and
                GetEntityHealth(vehicle) > 0 then
                table.insert(vehiclesData, {
                    entity = vehicle,
                    model = modelName,
                    displayName = displayName,
                    class = vehicleClass,
                    className = Config.VehicleClasses[vehicleClass] or "Unknown",
                    distance = distance
                })
                count = count + 1
            end
        end
    end

    -- Sort by distance
    table.sort(vehiclesData, function(a, b)
        return a.distance < b.distance
    end)

    return vehiclesData
end

-- Quick functions
function LoadVehicleQuick()
    if not CurrentTrailer or LoadingInProgress then
        ShowNotification(Config.Locales[Config.Locale]['no_trailer'])
        return
    end

    if PlayerVehicle and PlayerVehicle ~= 0 and PlayerVehicle ~= CurrentTrailer then
        LoadVehicleToTrailer(PlayerVehicle, CurrentTrailer)
    else
        ShowNotification(Config.Locales[Config.Locale]['no_vehicle'])
    end
end

function UnloadVehicleQuick()
    if not CurrentTrailer or LoadingInProgress then
        ShowNotification(Config.Locales[Config.Locale]['no_trailer'])
        return
    end

    local trailerId = NetworkGetNetworkIdFromEntity(CurrentTrailer)
    if LoadedVehicles[trailerId] and next(LoadedVehicles[trailerId]) then
        -- Find the highest slot number to unload the last loaded vehicle
        local highestSlot = 0
        for slot, _ in pairs(LoadedVehicles[trailerId]) do
            if slot > highestSlot then
                highestSlot = slot
            end
        end

        if highestSlot > 0 then
            UnloadVehicleFromTrailer(highestSlot, CurrentTrailer)
        else
            ShowNotification(Config.Locales[Config.Locale]['no_vehicle'])
        end
    else
        ShowNotification(Config.Locales[Config.Locale]['no_vehicle'])
    end
end

-- Network events
RegisterNetEvent('vehicleloader:vehicleLoaded')
AddEventHandler('vehicleloader:vehicleLoaded', function(trailerId, vehicleData, slotIndex)
    SetLoadedVehicleSlot(trailerId, slotIndex, vehicleData)

    if Config.Debug then
        print(string.format("[VehicleLoader] Vehicle loaded: %s to trailer %s slot %s",
            vehicleData.model, trailerId, slotIndex))
    end
end)

RegisterNetEvent('vehicleloader:vehicleUnloaded')
AddEventHandler('vehicleloader:vehicleUnloaded', function(trailerId, slotIndex, vehicleData)
    ClearLoadedVehicleSlot(trailerId, slotIndex)

    if Config.Debug then
        print(string.format("[VehicleLoader] Vehicle unloaded from trailer %s slot %s",
            trailerId, slotIndex))
    end
end)

RegisterNetEvent('vehicleloader:syncLoadedVehicles')
AddEventHandler('vehicleloader:syncLoadedVehicles', function(loadedVehicles)
    LoadedVehicles = loadedVehicles or {}

    if Config.Debug then
        local count = 0
        for _, vehicles in pairs(LoadedVehicles) do
            for _ in pairs(vehicles) do
                count = count + 1
            end
        end
        print(string.format("[VehicleLoader] Synced %d loaded vehicles", count))
    end
end)

RegisterNetEvent('vehicleloader:operationResult')
AddEventHandler('vehicleloader:operationResult', function(result)
    if result.success then
        ShowNotification(result.message, "success")
        PlaySound(Config.Sounds.success)
    else
        ShowNotification(result.message, "error")
        PlaySound(Config.Sounds.error)
    end
end)

RegisterNetEvent('vehicleloader:systemReset')
AddEventHandler('vehicleloader:systemReset', function()
    LoadedVehicles = {}
    CurrentTrailer = nil

    if MenuOpen then
        MenuOpen = false
        SetNuiFocus(false, false)
    end

    ShowNotification("Vehicle Loader system has been reset", "info")
end)

-- Utility functions
function DrawText3D(coords, text)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z + 1.0)
    local camCoords = GetGameplayCamCoords()
    local distance = #(coords - camCoords)

    if distance > 10.0 then return end

    local scale = (1 / distance) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov

    if onScreen then
        SetTextScale(0.0 * scale, 0.55 * scale)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

function ShowNotification(text, type)
    if type == "success" then
        SetNotificationTextEntry("STRING")
        AddTextComponentString(text)
        SetNotificationMessage("CHAR_DEFAULT", "CHAR_DEFAULT", true, 1, "Vehicle Loader", "")
        DrawNotification(false, true)
    elseif type == "error" then
        SetNotificationTextEntry("STRING")
        AddTextComponentString(text)
        SetNotificationMessage("CHAR_DEFAULT", "CHAR_DEFAULT", true, 6, "Vehicle Loader", "")
        DrawNotification(false, true)
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString(text)
        DrawNotification(false, false)
    end

    -- Also send to NUI for consistent styling
    if MenuOpen then
        SendNUIMessage({
            type = 'showNotification',
            message = text,
            notificationType = type or 'info'
        })
    end
end

function PlaySound(soundData)
    if soundData and soundData.name and soundData.set then
        PlaySoundFrontend(-1, soundData.name, soundData.set, true)
    end
end

-- Check if vehicle is loaded
function IsVehicleLoaded(vehicle)
    for trailerId, vehicles in pairs(LoadedVehicles) do
        for _, vehicleData in pairs(vehicles) do
            if vehicleData.entity == vehicle then
                return true
            end
        end
    end
    return false
end

-- Cleanup thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.Timeouts.CLEANUP_INTERVAL)
        CleanupInvalidVehicles()
    end
end)

function CleanupInvalidVehicles()
    local cleaned = 0

    for trailerId, vehicles in pairs(LoadedVehicles) do
        for slotIndex, vehicleData in pairs(vehicles) do
            if not DoesEntityExist(vehicleData.entity) or IsEntityDead(vehicleData.entity) then
                ClearLoadedVehicleSlot(trailerId, slotIndex)
                cleaned = cleaned + 1

                if Config.Debug then
                    print(string.format("[VehicleLoader] Cleaned up invalid vehicle reference in trailer %s slot %s",
                        trailerId, slotIndex))
                end
            end
        end
    end

    return cleaned
end

-- Initialize client
Citizen.CreateThread(function()
    if Config.Debug then
        print("[VehicleLoader] Client initialized successfully")
    end
end)
