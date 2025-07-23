-- Load vehicle to trailer
function LoadVehicleToTrailer(vehicle, trailer)
    if not DoesEntityExist(vehicle) or not DoesEntityExist(trailer) then
        ShowNotification(Config.Locales[Config.Locale]['loading_failed'])
        PlaySound(Config.Sounds.error)
        return { success = false, message = 'Vehicle or trailer does not exist' }
    end

    local vehicleModel = GetEntityModel(vehicle)
    local vehicleModelName = string.lower(GetDisplayNameFromVehicleModel(vehicleModel))
    local vehicleClass = GetVehicleClass(vehicle)

    local trailerModel = GetEntityModel(trailer)
    local trailerModelName = string.lower(GetDisplayNameFromVehicleModel(trailerModel))
    local trailerConfig = Config.Trailers[trailerModelName]

    if not trailerConfig then
        ShowNotification(Config.Locales[Config.Locale]['loading_failed'])
        PlaySound(Config.Sounds.error)
        return { success = false, message = 'Invalid trailer type' }
    end

    -- Check if vehicle is blacklisted
    if IsVehicleBlacklisted(vehicleModelName, vehicleClass) then
        ShowNotification(Config.Locales[Config.Locale]['blacklisted_vehicle'])
        PlaySound(Config.Sounds.error)
        return { success = false, message = 'Vehicle is blacklisted' }
    end

    -- Check if vehicle class is allowed for this trailer
    if not table.contains(trailerConfig.allowedClasses, vehicleClass) then
        ShowNotification(Config.Locales[Config.Locale]['blacklisted_vehicle'])
        PlaySound(Config.Sounds.error)
        return { success = false, message = 'Vehicle class not allowed on this trailer' }
    end

    -- Check if vehicle is already loaded
    if IsVehicleLoaded(vehicle) then
        ShowNotification(Config.Locales[Config.Locale]['loading_failed'])
        PlaySound(Config.Sounds.error)
        return { success = false, message = 'Vehicle is already loaded' }
    end

    -- Check trailer capacity
    local trailerId = NetworkGetNetworkIdFromEntity(trailer)
    local loadedCount = GetLoadedVehicleCount(trailerId)

    if loadedCount >= trailerConfig.maxVehicles then
        ShowNotification(Config.Locales[Config.Locale]['trailer_full'])
        PlaySound(Config.Sounds.error)
        return { success = false, message = 'Trailer is full' }
    end

    -- Find available slot
    local slotIndex = GetAvailableSlot(trailerId, trailerConfig.maxVehicles)
    if not slotIndex then
        ShowNotification(Config.Locales[Config.Locale]['trailer_full'])
        PlaySound(Config.Sounds.error)
        return { success = false, message = 'No available slots' }
    end

    -- Play loading animation
    PlayLoadingAnimation(Config.Animations.loading)

    -- Wait for animation
    Citizen.Wait(Config.Animations.loading.duration)

    -- Get load position
    local loadPos = trailerConfig.loadPositions[slotIndex]
    local trailerCoords = GetEntityCoords(trailer)
    local trailerHeading = GetEntityHeading(trailer)

    -- Calculate world position
    local offsetCoords = GetOffsetFromEntityInWorldCoords(trailer, loadPos.x, loadPos.y, loadPos.z)
    local finalHeading = trailerHeading + loadPos.heading

    -- Move vehicle to trailer
    SetEntityCoords(vehicle, offsetCoords.x, offsetCoords.y, offsetCoords.z, false, false, false, true)
    SetEntityHeading(vehicle, finalHeading)

    -- Attach vehicle to trailer
    AttachEntityToEntity(vehicle, trailer, 0, loadPos.x, loadPos.y, loadPos.z, 0.0, 0.0, loadPos.heading, false, false,
        false, false, 2, true)

    -- Freeze vehicle
    FreezeEntityPosition(vehicle, true)
    SetEntityCollision(vehicle, false, true)

    -- Trigger server event
    TriggerServerEvent('vehicleloader:loadVehicle', {
        trailerId = trailerId,
        vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle),
        vehicleModel = vehicleModelName,
        slotIndex = slotIndex,
        position = loadPos
    })

    ShowNotification(Config.Locales[Config.Locale]['vehicle_loaded'])
    PlaySound(Config.Sounds.loading)

    return { success = true, message = 'Vehicle loaded successfully' }
end

-- Unload vehicle from trailer
function UnloadVehicleFromTrailer(slotIndex, trailer)
    if not DoesEntityExist(trailer) then
        ShowNotification(Config.Locales[Config.Locale]['unloading_failed'])
        PlaySound(Config.Sounds.error)
        return { success = false, message = 'Trailer does not exist' }
    end

    local trailerId = NetworkGetNetworkIdFromEntity(trailer)

    if not LoadedVehicles[trailerId] or not LoadedVehicles[trailerId][slotIndex] then
        ShowNotification(Config.Locales[Config.Locale]['unloading_failed'])
        PlaySound(Config.Sounds.error)
        return { success = false, message = 'No vehicle in this slot' }
    end

    local vehicleData = LoadedVehicles[trailerId][slotIndex]
    local vehicle = vehicleData.entity

    if not DoesEntityExist(vehicle) then
        -- Clean up invalid vehicle reference
        LoadedVehicles[trailerId][slotIndex] = nil
        ShowNotification(Config.Locales[Config.Locale]['unloading_failed'])
        PlaySound(Config.Sounds.error)
        return { success = false, message = 'Vehicle no longer exists' }
    end

    -- Play unloading animation
    PlayLoadingAnimation(Config.Animations.unloading)

    -- Wait for animation
    Citizen.Wait(Config.Animations.unloading.duration)

    -- Detach vehicle
    DetachEntity(vehicle, true, true)

    -- Find safe unload position
    local unloadPos = GetSafeUnloadPosition(trailer)

    -- Move vehicle to unload position
    SetEntityCoords(vehicle, unloadPos.x, unloadPos.y, unloadPos.z, false, false, false, true)
    SetEntityHeading(vehicle, GetEntityHeading(trailer))

    -- Unfreeze vehicle
    FreezeEntityPosition(vehicle, false)
    SetEntityCollision(vehicle, true, true)

    -- Trigger server event
    TriggerServerEvent('vehicleloader:unloadVehicle', {
        trailerId = trailerId,
        slotIndex = slotIndex
    })

    ShowNotification(Config.Locales[Config.Locale]['vehicle_unloaded'])
    PlaySound(Config.Sounds.unloading)

    return { success = true, message = 'Vehicle unloaded successfully' }
end

-- Check if vehicle is blacklisted
function IsVehicleBlacklisted(modelName, vehicleClass)
    -- Check blacklisted vehicles
    for _, blacklistedModel in pairs(Config.BlacklistedVehicles) do
        if string.lower(blacklistedModel) == string.lower(modelName) then
            return true
        end
    end

    -- Check blacklisted classes
    for _, blacklistedClass in pairs(Config.BlacklistedClasses) do
        if blacklistedClass == vehicleClass then
            return true
        end
    end

    return false
end

-- Check if vehicle is already loaded
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

-- Get loaded vehicle count for trailer
function GetLoadedVehicleCount(trailerId)
    if not LoadedVehicles[trailerId] then
        return 0
    end

    local count = 0
    for _, vehicleData in pairs(LoadedVehicles[trailerId]) do
        if DoesEntityExist(vehicleData.entity) then
            count = count + 1
        end
    end

    return count
end

-- Get available slot index
function GetAvailableSlot(trailerId, maxSlots)
    if not LoadedVehicles[trailerId] then
        return 1
    end

    for i = 1, maxSlots do
        if not LoadedVehicles[trailerId][i] then
            return i
        end
    end

    return nil
end

-- Get safe unload position
function GetSafeUnloadPosition(trailer)
    local trailerCoords = GetEntityCoords(trailer)
    local trailerHeading = GetEntityHeading(trailer)

    -- Try positions around the trailer
    local positions = {
        { x = 3.0,  y = 0.0,  z = 0.0 },
        { x = -3.0, y = 0.0,  z = 0.0 },
        { x = 0.0,  y = 5.0,  z = 0.0 },
        { x = 0.0,  y = -8.0, z = 0.0 }
    }

    for _, pos in pairs(positions) do
        local testPos = GetOffsetFromEntityInWorldCoords(trailer, pos.x, pos.y, pos.z)
        local groundZ = GetGroundZFor_3dCoord(testPos.x, testPos.y, testPos.z + 1.0, true)

        if groundZ then
            return vector3(testPos.x, testPos.y, groundZ + 0.5)
        end
    end

    -- Fallback to trailer position with offset
    return vector3(trailerCoords.x + 3.0, trailerCoords.y, trailerCoords.z + 0.5)
end

-- Play loading animation
function PlayLoadingAnimation(animConfig)
    local playerPed = PlayerPedId()

    RequestAnimDict(animConfig.dict)
    while not HasAnimDictLoaded(animConfig.dict) do
        Citizen.Wait(10)
    end

    TaskPlayAnim(playerPed, animConfig.dict, animConfig.anim, 8.0, -8.0, animConfig.duration, 0, 0, false, false, false)
end

-- Utility function to check if table contains value
function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- Get entity from network ID safely
function GetEntityFromNetId(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and DoesEntityExist(entity) then
        return entity
    end
    return nil
end

-- Clean up invalid vehicle references
function CleanupInvalidVehicles()
    for trailerId, vehicles in pairs(LoadedVehicles) do
        for slotIndex, vehicleData in pairs(vehicles) do
            if not DoesEntityExist(vehicleData.entity) then
                LoadedVehicles[trailerId][slotIndex] = nil
                if Config.Debug then
                    print(string.format("[VehicleLoader] Cleaned up invalid vehicle reference in trailer %s slot %s",
                        trailerId, slotIndex))
                end
            end
        end
    end
end

-- Cleanup thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000) -- Run every 30 seconds
        CleanupInvalidVehicles()
    end
end)
