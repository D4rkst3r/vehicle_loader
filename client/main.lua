local LoadedVehicles = {}
local CurrentTrailer = nil
local MenuOpen = false
local PlayerPed = nil
local PlayerVehicle = nil

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

-- Initialize
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        PlayerPed = PlayerPedId()
        PlayerVehicle = GetVehiclePedIsIn(PlayerPed, false)

        if not MenuOpen then
            local nearbyTrailer = GetNearbyTrailer()
            if nearbyTrailer then
                CurrentTrailer = nearbyTrailer
                DrawText3D(GetEntityCoords(nearbyTrailer), Config.Locales[Config.Locale]['open_menu'])

                if IsControlJustPressed(0, Config.MenuKey) then
                    OpenVehicleLoaderMenu()
                end
            else
                CurrentTrailer = nil
            end
        end

        -- Quick load/unload keys
        if CurrentTrailer and not MenuOpen then
            if IsControlJustPressed(0, Config.LoadKey) then
                LoadVehicleQuick()
            elseif IsControlJustPressed(0, Config.UnloadKey) then
                UnloadVehicleQuick()
            end
        end
    end
end)

-- Check for nearby trailers
function GetNearbyTrailer()
    local playerCoords = GetEntityCoords(PlayerPed)
    local vehicles = GetVehiclesInArea(playerCoords, Config.MaxDistance)

    for _, vehicle in pairs(vehicles) do
        local model = GetEntityModel(vehicle)
        local modelName = string.lower(GetDisplayNameFromVehicleModel(model))

        if Config.Trailers[modelName] then
            local distance = #(playerCoords - GetEntityCoords(vehicle))
            if distance <= Config.MaxDistance then
                return vehicle
            end
        end
    end
    return nil
end

-- Get vehicles in area
function GetVehiclesInArea(coords, maxDistance)
    local vehicles = {}
    local handle, vehicle = FindFirstVehicle()
    local success

    repeat
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(coords - vehicleCoords)

        if distance <= maxDistance then
            table.insert(vehicles, vehicle)
        end

        success, vehicle = FindNextVehicle(handle)
    until not success

    EndFindVehicle(handle)
    return vehicles
end

-- Open menu
function OpenVehicleLoaderMenu()
    if not CurrentTrailer then return end

    MenuOpen = true
    SetNuiFocus(true, true)

    local trailerModel = GetEntityModel(CurrentTrailer)
    local trailerName = string.lower(GetDisplayNameFromVehicleModel(trailerModel))
    local trailerConfig = Config.Trailers[trailerName]

    if not trailerConfig then
        MenuOpen = false
        SetNuiFocus(false, false)
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

-- Close menu
RegisterNUICallback('closeMenu', function(data, cb)
    MenuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Load vehicle via NUI
RegisterNUICallback('loadVehicle', function(data, cb)
    local vehicleId = tonumber(data.vehicleId)
    local result = LoadVehicleToTrailer(vehicleId, CurrentTrailer)
    cb(result)
end)

-- Unload vehicle via NUI
RegisterNUICallback('unloadVehicle', function(data, cb)
    local slotIndex = tonumber(data.slotIndex)
    local result = UnloadVehicleFromTrailer(slotIndex, CurrentTrailer)
    cb(result)
end)

-- Get loaded vehicles data
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
                    model = string.lower(GetEntityModel(vehicleData.entity)),
                    displayName = displayName,
                    class = vehicleClass,
                    className = Config.VehicleClasses[vehicleClass] or "Unknown"
                })
            end
        end
    end

    return loadedData
end

-- Get nearby vehicles data
function GetNearbyVehiclesData()
    local playerCoords = GetEntityCoords(PlayerPed)
    local vehicles = GetVehiclesInArea(playerCoords, Config.MaxDistance)
    local vehiclesData = {}

    for _, vehicle in pairs(vehicles) do
        if vehicle ~= CurrentTrailer and not IsVehicleLoaded(vehicle) then
            local model = GetEntityModel(vehicle)
            local modelName = string.lower(GetDisplayNameFromVehicleModel(model))
            local displayName = GetDisplayNameFromVehicleModel(model)
            local vehicleClass = GetVehicleClass(vehicle)

            -- Check if vehicle is blacklisted
            if not IsVehicleBlacklisted(modelName, vehicleClass) then
                table.insert(vehiclesData, {
                    entity = vehicle,
                    model = modelName,
                    displayName = displayName,
                    class = vehicleClass,
                    className = Config.VehicleClasses[vehicleClass] or "Unknown",
                    distance = #(playerCoords - GetEntityCoords(vehicle))
                })
            end
        end
    end

    -- Sort by distance
    table.sort(vehiclesData, function(a, b)
        return a.distance < b.distance
    end)

    return vehiclesData
end

-- Quick load function
function LoadVehicleQuick()
    if not CurrentTrailer then
        ShowNotification(Config.Locales[Config.Locale]['no_trailer'])
        return
    end

    if PlayerVehicle and PlayerVehicle ~= 0 and PlayerVehicle ~= CurrentTrailer then
        LoadVehicleToTrailer(PlayerVehicle, CurrentTrailer)
    else
        ShowNotification(Config.Locales[Config.Locale]['no_vehicle'])
    end
end

-- Quick unload function
function UnloadVehicleQuick()
    if not CurrentTrailer then
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
    if not LoadedVehicles[trailerId] then
        LoadedVehicles[trailerId] = {}
    end
    LoadedVehicles[trailerId][slotIndex] = vehicleData

    if Config.Debug then
        print(string.format("[VehicleLoader] Vehicle loaded: %s to trailer %s slot %s", vehicleData.model, trailerId,
            slotIndex))
    end
end)

RegisterNetEvent('vehicleloader:vehicleUnloaded')
AddEventHandler('vehicleloader:vehicleUnloaded', function(trailerId, slotIndex)
    if LoadedVehicles[trailerId] and LoadedVehicles[trailerId][slotIndex] then
        LoadedVehicles[trailerId][slotIndex] = nil

        if Config.Debug then
            print(string.format("[VehicleLoader] Vehicle unloaded from trailer %s slot %s", trailerId, slotIndex))
        end
    end
end)

RegisterNetEvent('vehicleloader:syncLoadedVehicles')
AddEventHandler('vehicleloader:syncLoadedVehicles', function(loadedVehicles)
    LoadedVehicles = loadedVehicles or {}
end)

-- Utility functions
function DrawText3D(coords, text)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z + 1.0)
    local camCoords = GetGameplayCamCoords()
    local distance = #(coords - camCoords)

    local scale = (1 / distance) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov

    if onScreen then
        SetTextScale(0.0 * scale, 0.55 * scale)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
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

function ShowNotification(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, false)
end

function PlaySound(soundData)
    PlaySoundFrontend(-1, soundData.name, soundData.set, true)
end
