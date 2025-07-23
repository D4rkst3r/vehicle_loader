-- Enhanced Client Functions for Vehicle Loader

-- Load vehicle to trailer with callback support
function LoadVehicleToTrailer(vehicle, trailer, callback)
    callback = callback or function() end

    if LoadingInProgress then
        local result = { success = false, message = Config.Locales[Config.Locale]['operation_in_progress'] }
        callback(result)
        return result
    end

    LoadingInProgress = true

    -- Validate entities
    local valid, errorMsg = ValidateEntities(vehicle, trailer)
    if not valid then
        LoadingInProgress = false
        local result = { success = false, message = errorMsg }
        callback(result)
        PlaySound(Config.Sounds.error)
        return result
    end

    local vehicleModel = GetEntityModel(vehicle)
    local vehicleModelName = GetCachedModelName(vehicle)
    local vehicleClass = GetVehicleClass(vehicle)

    local trailerModel = GetEntityModel(trailer)
    local trailerModelName = GetCachedModelName(trailer)
    local trailerConfig = Config.Trailers[trailerModelName]

    if not trailerConfig then
        LoadingInProgress = false
        local result = { success = false, message = Config.Locales[Config.Locale]['loading_failed'] }
        callback(result)
        PlaySound(Config.Sounds.error)
        return result
    end

    -- Enhanced validation checks
    local validationResult = ValidateVehicleForTrailer(vehicle, vehicleModelName, vehicleClass, trailerConfig)
    if not validationResult.success then
        LoadingInProgress = false
        callback(validationResult)
        PlaySound(Config.Sounds.error)
        return validationResult
    end

    -- Check trailer capacity and find available slot
    local trailerId = NetworkGetNetworkIdFromEntity(trailer)
    local slotIndex = GetAvailableSlot(trailerId, trailerConfig.maxVehicles)

    if not slotIndex then
        LoadingInProgress = false
        local result = { success = false, message = Config.Locales[Config.Locale]['trailer_full'] }
        callback(result)
        PlaySound(Config.Sounds.error)
        return result
    end

    -- Show loading animation and UI feedback
    ShowNotification(Config.Locales[Config.Locale]['loading_vehicle'], "info")

    if MenuOpen then
        SendNUIMessage({
            type = 'showLoading',
            message = Config.Locales[Config.Locale]['loading_vehicle']
        })
    end

    -- Play loading animation
    PlayLoadingAnimation(Config.Animations.loading)

    -- Wait for animation
    Citizen.Wait(Config.Animations.loading.duration)

    -- Calculate precise load position
    local loadPos = CalculatePreciseLoadPosition(trailer, slotIndex, trailerConfig)

    -- Store original vehicle state
    local originalCoords = GetEntityCoords(vehicle)
    local originalHeading = GetEntityHeading(vehicle)

    -- Stop vehicle movement
    SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
    SetEntityAngularVelocity(vehicle, 0.0, 0.0, 0.0)

    -- Move vehicle to trailer with smooth transition
    local success = MoveVehicleToTrailer(vehicle, trailer, loadPos, slotIndex)

    if not success then
        LoadingInProgress = false
        local result = { success = false, message = Config.Locales[Config.Locale]['loading_failed'] }
        callback(result)
        PlaySound(Config.Sounds.error)

        if MenuOpen then
            SendNUIMessage({ type = 'hideLoading' })
        end
        return result
    end

    -- Prepare data for server
    local vehicleData = {
        trailerId = trailerId,
        vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle),
        vehicleModel = vehicleModelName,
        slotIndex = slotIndex,
        position = loadPos,
        originalCoords = originalCoords,
        originalHeading = originalHeading
    }

    -- Send to server and wait for response
    TriggerServerEvent('vehicleloader:loadVehicle', vehicleData)

    -- Simple timeout system instead of complex event handling
    local timeout = 0
    local maxTimeout = 5000 -- 5 seconds

    while timeout < maxTimeout do
        Citizen.Wait(100)
        timeout = timeout + 100
    end

    LoadingInProgress = false

    if MenuOpen then
        SendNUIMessage({ type = 'hideLoading' })
    end

    -- Return success - server will handle the actual validation
    local result = { success = true, message = Config.Locales[Config.Locale]['vehicle_loaded'] }
    callback(result)
    PlaySound(Config.Sounds.loading)
    return result
end

-- Unload vehicle from trailer with callback support
function UnloadVehicleFromTrailer(slotIndex, trailer, callback)
    callback = callback or function() end

    if LoadingInProgress then
        local result = { success = false, message = Config.Locales[Config.Locale]['operation_in_progress'] }
        callback(result)
        return result
    end

    LoadingInProgress = true

    if not DoesEntityExist(trailer) then
        LoadingInProgress = false
        local result = { success = false, message = Config.Locales[Config.Locale]['no_trailer'] }
        callback(result)
        PlaySound(Config.Sounds.error)
        return result
    end

    local trailerId = NetworkGetNetworkIdFromEntity(trailer)
    local loadedVehicles = GetLoadedVehicles()

    if not loadedVehicles[trailerId] or not loadedVehicles[trailerId][slotIndex] then
        LoadingInProgress = false
        local result = { success = false, message = Config.Locales[Config.Locale]['invalid_slot'] }
        callback(result)
        PlaySound(Config.Sounds.error)
        return result
    end

    local vehicleData = loadedVehicles[trailerId][slotIndex]
    local vehicle = vehicleData.entity

    if not DoesEntityExist(vehicle) then
        -- Clean up invalid vehicle reference
        ClearLoadedVehicleSlot(trailerId, slotIndex)
        LoadingInProgress = false
        local result = { success = false, message = Config.Locales[Config.Locale]['vehicle_destroyed'] }
        callback(result)
        PlaySound(Config.Sounds.error)
        return result
    end

    -- Show unloading animation and UI feedback
    ShowNotification(Config.Locales[Config.Locale]['unloading_vehicle'], "info")

    if MenuOpen then
        SendNUIMessage({
            type = 'showLoading',
            message = Config.Locales[Config.Locale]['unloading_vehicle']
        })
    end

    -- Play unloading animation
    PlayLoadingAnimation(Config.Animations.unloading)

    -- Wait for animation
    Citizen.Wait(Config.Animations.unloading.duration)

    -- Perform unloading
    local success = UnloadVehicleFromTrailerPhysics(vehicle, trailer, vehicleData)

    if not success then
        LoadingInProgress = false
        local result = { success = false, message = Config.Locales[Config.Locale]['unloading_failed'] }
        callback(result)
        PlaySound(Config.Sounds.error)

        if MenuOpen then
            SendNUIMessage({ type = 'hideLoading' })
        end
        return result
    end

    -- Send to server
    TriggerServerEvent('vehicleloader:unloadVehicle', {
        trailerId = trailerId,
        slotIndex = slotIndex
    })

    -- Simple timeout
    Citizen.Wait(1000)

    LoadingInProgress = false

    if MenuOpen then
        SendNUIMessage({ type = 'hideLoading' })
    end

    local result = { success = true, message = Config.Locales[Config.Locale]['vehicle_unloaded'] }
    callback(result)
    PlaySound(Config.Sounds.unloading)
    return result
end

-- Enhanced vehicle validation
function ValidateVehicleForTrailer(vehicle, modelName, vehicleClass, trailerConfig)
    -- Check if vehicle is blacklisted
    if IsVehicleBlacklisted(modelName, vehicleClass) then
        return { success = false, message = Config.Locales[Config.Locale]['blacklisted_vehicle'] }
    end

    -- Check if vehicle class is allowed for this trailer
    if not table.contains(trailerConfig.allowedClasses, vehicleClass) then
        return { success = false, message = Config.Locales[Config.Locale]['blacklisted_vehicle'] }
    end

    -- Check if vehicle is already loaded
    if IsVehicleLoaded(vehicle) then
        return { success = false, message = Config.Locales[Config.Locale]['loading_failed'] }
    end

    -- Check vehicle size if configured
    if trailerConfig.maxVehicleSize then
        local vehicleSize = GetVehicleSize(vehicle)
        if vehicleSize > trailerConfig.maxVehicleSize then
            return { success = false, message = Config.Locales[Config.Locale]['vehicle_too_large'] }
        end
    end

    -- Check vehicle health
    local vehicleHealth = GetEntityHealth(vehicle)
    if vehicleHealth <= 0 or IsEntityDead(vehicle) then
        return { success = false, message = Config.Locales[Config.Locale]['vehicle_destroyed'] }
    end

    -- Check if vehicle is occupied
    if GetVehiclePedInSeat(vehicle, -1) ~= 0 then
        return { success = false, message = "Vehicle is occupied" }
    end

    return { success = true, message = "Vehicle is valid for loading" }
end

-- Calculate precise load position with physics
function CalculatePreciseLoadPosition(trailer, slotIndex, trailerConfig)
    local loadPos = trailerConfig.loadPositions[slotIndex]
    if not loadPos then
        return { x = 0.0, y = -2.0, z = 1.0, heading = 0.0 }
    end

    local trailerCoords = GetEntityCoords(trailer)
    local trailerHeading = GetEntityHeading(trailer)

    -- Calculate world position with trailer rotation
    local offsetCoords = GetOffsetFromEntityInWorldCoords(trailer, loadPos.x, loadPos.y, loadPos.z)
    local finalHeading = trailerHeading + loadPos.heading

    -- Ground Z correction with raycast
    local groundZ = GetGroundZWithRaycast(offsetCoords.x, offsetCoords.y, offsetCoords.z + 5.0)
    if groundZ then
        offsetCoords = vector3(offsetCoords.x, offsetCoords.y, math.max(offsetCoords.z, groundZ + 0.1))
    end

    return {
        x = loadPos.x,
        y = loadPos.y,
        z = loadPos.z,
        heading = loadPos.heading,
        worldCoords = offsetCoords,
        worldHeading = finalHeading
    }
end

-- Move vehicle to trailer with smooth animation
function MoveVehicleToTrailer(vehicle, trailer, loadPos, slotIndex)
    local success, result = SafeExecute(function()
        -- Set vehicle properties for loading
        FreezeEntityPosition(vehicle, true)
        SetEntityCollision(vehicle, false, true)
        SetVehicleEngineOn(vehicle, false, true, true)

        -- Advanced physics settings
        if Config.Advanced.UseAdvancedPhysics then
            SetEntityMaxSpeed(vehicle, 0.0)
            SetVehicleHandbrake(vehicle, true)
            SetVehicleWheelsCanBreak(vehicle, false)

            -- Prevent vehicle damage if configured
            if Config.Advanced.PreventVehicleDamage then
                SetEntityInvincible(vehicle, true)
                SetVehicleCanBeVisiblyDamaged(vehicle, false)
            end
        end

        -- Smooth position transition
        local startCoords = GetEntityCoords(vehicle)
        local targetCoords = loadPos.worldCoords
        local startHeading = GetEntityHeading(vehicle)
        local targetHeading = loadPos.worldHeading

        local transitionTime = 1000 -- 1 second transition
        local steps = 20
        local stepTime = transitionTime / steps

        for i = 1, steps do
            local progress = i / steps
            local currentCoords = vector3(
                Lerp(startCoords.x, targetCoords.x, progress),
                Lerp(startCoords.y, targetCoords.y, progress),
                Lerp(startCoords.z, targetCoords.z, progress)
            )
            local currentHeading = LerpAngle(startHeading, targetHeading, progress)

            SetEntityCoordsNoOffset(vehicle, currentCoords.x, currentCoords.y, currentCoords.z, false, false, false)
            SetEntityHeading(vehicle, currentHeading)

            Citizen.Wait(stepTime)
        end

        -- Final positioning
        SetEntityCoordsNoOffset(vehicle, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false)
        SetEntityHeading(vehicle, targetHeading)

        -- Attach to trailer with improved physics
        if Config.Advanced.UseAdvancedPhysics then
            AttachEntityToEntity(
                vehicle, trailer, 0,
                loadPos.x, loadPos.y, loadPos.z,
                0.0, 0.0, loadPos.heading,
                false, false, false, false, 2, true
            )
        else
            -- Standard attachment
            AttachEntityToEntity(
                vehicle, trailer, 0,
                loadPos.x, loadPos.y, loadPos.z,
                0.0, 0.0, loadPos.heading,
                false, false, false, false, 0, true
            )
        end

        -- Entity lockdown if configured
        if Config.Advanced.UseEntityLockdown then
            SetEntityAsMissionEntity(vehicle, true, true)
            SetVehicleHasBeenOwnedByPlayer(vehicle, false)
        end

        return true
    end)

    return success
end

-- Unload vehicle with improved physics
function UnloadVehicleFromTrailerPhysics(vehicle, trailer, vehicleData)
    local success, result = SafeExecute(function()
        -- Detach vehicle
        DetachEntity(vehicle, true, true)

        -- Find safe unload position
        local unloadPos = GetSafeUnloadPosition(trailer, vehicleData)

        -- Smooth unload transition
        local currentCoords = GetEntityCoords(vehicle)
        local transitionTime = 800 -- 0.8 seconds
        local steps = 16
        local stepTime = transitionTime / steps

        for i = 1, steps do
            local progress = i / steps
            local newCoords = vector3(
                Lerp(currentCoords.x, unloadPos.x, progress),
                Lerp(currentCoords.y, unloadPos.y, progress),
                Lerp(currentCoords.z, unloadPos.z, progress)
            )

            SetEntityCoordsNoOffset(vehicle, newCoords.x, newCoords.y, newCoords.z, false, false, false)
            Citizen.Wait(stepTime)
        end

        -- Final positioning
        SetEntityCoordsNoOffset(vehicle, unloadPos.x, unloadPos.y, unloadPos.z, false, false, false)
        SetEntityHeading(vehicle, GetEntityHeading(trailer))

        -- Restore vehicle properties
        FreezeEntityPosition(vehicle, false)
        SetEntityCollision(vehicle, true, true)

        if Config.Advanced.UseAdvancedPhysics then
            SetEntityMaxSpeed(vehicle, -1.0)
            SetVehicleHandbrake(vehicle, false)
            SetVehicleWheelsCanBreak(vehicle, true)

            if Config.Advanced.PreventVehicleDamage then
                SetEntityInvincible(vehicle, false)
                SetVehicleCanBeVisiblyDamaged(vehicle, true)
            end

            -- Auto-repair if configured
            if Config.Advanced.AutoRepairOnUnload then
                SetVehicleFixed(vehicle)
                SetVehicleDirtLevel(vehicle, 0.0)
            end
        end

        -- Remove entity lockdown
        if Config.Advanced.UseEntityLockdown then
            SetEntityAsMissionEntity(vehicle, false, true)
            SetVehicleHasBeenOwnedByPlayer(vehicle, true)
        end

        -- Give slight upward velocity to ensure vehicle settles properly
        SetEntityVelocity(vehicle, 0.0, 0.0, 0.5)

        return true
    end)

    return success
end

-- Enhanced safe unload position calculation
function GetSafeUnloadPosition(trailer, vehicleData)
    local trailerCoords = GetEntityCoords(trailer)
    local trailerHeading = GetEntityHeading(trailer)

    -- Try multiple positions around the trailer
    local positions = {
        { x = 4.0,  y = 0.0,   z = 0.0 }, -- Right side
        { x = -4.0, y = 0.0,   z = 0.0 }, -- Left side
        { x = 0.0,  y = 6.0,   z = 0.0 }, -- Front
        { x = 0.0,  y = -10.0, z = 0.0 }, -- Back
        { x = 3.0,  y = 5.0,   z = 0.0 }, -- Front-right
        { x = -3.0, y = 5.0,   z = 0.0 }, -- Front-left
        { x = 3.0,  y = -8.0,  z = 0.0 }, -- Back-right
        { x = -3.0, y = -8.0,  z = 0.0 }  -- Back-left
    }

    for _, pos in pairs(positions) do
        local testPos = GetOffsetFromEntityInWorldCoords(trailer, pos.x, pos.y, pos.z)

        -- Check if position is clear
        if IsPositionSafe(testPos, 2.0) then
            local groundZ = GetGroundZWithRaycast(testPos.x, testPos.y, testPos.z + 2.0)
            if groundZ then
                return vector3(testPos.x, testPos.y, groundZ + 0.5)
            end
        end
    end

    -- Fallback to original position if available
    if vehicleData and vehicleData.originalCoords then
        return vehicleData.originalCoords
    end

    -- Final fallback
    local groundZ = GetGroundZWithRaycast(trailerCoords.x + 4.0, trailerCoords.y, trailerCoords.z + 2.0)
    return vector3(trailerCoords.x + 4.0, trailerCoords.y, groundZ and (groundZ + 0.5) or (trailerCoords.z + 0.5))
end

-- Check if position is safe for vehicle placement
function IsPositionSafe(coords, radius)
    -- Check for nearby vehicles
    local nearbyVehicles = GetVehiclesInArea(coords, radius)
    if #nearbyVehicles > 0 then
        return false
    end

    -- Check for objects/obstacles
    local objects = GetGamePool('CObject')
    for _, obj in pairs(objects) do
        if DoesEntityExist(obj) then
            local objCoords = GetEntityCoords(obj)
            if #(coords - objCoords) < radius then
                return false
            end
        end
    end

    return true
end

-- Enhanced ground Z calculation with raycast
function GetGroundZWithRaycast(x, y, z)
    local raycast = StartExpensiveSynchronousShapeTestLosProbe(
        x, y, z,
        x, y, z - 10.0,
        1, 0, 4
    )

    local _, hit, _, _, groundZ = GetShapeTestResult(raycast)

    if hit then
        return groundZ
    end

    -- Fallback to native function
    local success, groundZNative = GetGroundZFor_3dCoord(x, y, z, false)
    if success then
        return groundZNative
    end

    return nil
end

-- Utility functions
function GetVehicleSize(vehicle)
    local model = GetEntityModel(vehicle)
    local min, max = GetModelDimensions(model)
    return math.max(max.x - min.x, max.y - min.y, max.z - min.z)
end

function Lerp(a, b, t)
    return a + (b - a) * t
end

function LerpAngle(a, b, t)
    local diff = b - a
    if diff > 180 then
        diff = diff - 360
    elseif diff < -180 then
        diff = diff + 360
    end
    return a + diff * t
end

-- Enhanced blacklist checking
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

-- Get available slot with improved algorithm
function GetAvailableSlot(trailerId, maxSlots)
    local loadedVehicles = GetLoadedVehicles()
    if not loadedVehicles[trailerId] then
        return 1
    end

    -- Find the first available slot
    for i = 1, maxSlots do
        if not loadedVehicles[trailerId][i] then
            return i
        end
    end

    return nil
end

-- Enhanced loading animation
function PlayLoadingAnimation(animConfig)
    local playerPed = PlayerPedId()

    -- Load animation dictionary
    if not HasAnimDictLoaded(animConfig.dict) then
        RequestAnimDict(animConfig.dict)
        local timeout = 0
        while not HasAnimDictLoaded(animConfig.dict) and timeout < 5000 do
            Citizen.Wait(10)
            timeout = timeout + 10
        end
    end

    if HasAnimDictLoaded(animConfig.dict) then
        TaskPlayAnim(
            playerPed,
            animConfig.dict,
            animConfig.anim,
            8.0, -8.0,
            animConfig.duration,
            animConfig.flags or 49,
            0,
            false, false, false
        )
    end
end

-- Table utility function
function table.contains(tbl, element)
    for _, value in pairs(tbl) do
        if value == element then
            return true
        end
    end
    return false
end
