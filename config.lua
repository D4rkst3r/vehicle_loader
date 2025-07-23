Config = {}

-- Debug Mode
Config.Debug = false

-- Performance Settings
Config.CheckInterval = 1000 -- ms between checks
Config.MaxDistance = 10.0   -- Maximum distance to interact with trailer

-- Key Bindings
Config.MenuKey = 38   -- E Key (Default: 38)
Config.LoadKey = 47   -- G Key (Default: 47)
Config.UnloadKey = 74 -- H Key (Default: 74)

-- Trailer Configurations
Config.Trailers = {
    ['tr2'] = { -- Car Trailer
        maxVehicles = 1,
        loadPositions = {
            { x = 0.0, y = -2.5, z = 1.0, heading = 0.0 }
        },
        allowedClasses = { 0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12 } -- Most vehicle classes
    },
    ['tr4'] = {                                                  -- Large Trailer
        maxVehicles = 2,
        loadPositions = {
            { x = 0.0, y = -1.5, z = 1.0, heading = 0.0 },
            { x = 0.0, y = -4.5, z = 1.0, heading = 0.0 }
        },
        allowedClasses = { 0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12 }
    },
    ['trflat'] = { -- Flat Trailer
        maxVehicles = 3,
        loadPositions = {
            { x = 0.0, y = -1.0, z = 1.2, heading = 0.0 },
            { x = 0.0, y = -3.0, z = 1.2, heading = 0.0 },
            { x = 0.0, y = -5.0, z = 1.2, heading = 0.0 }
        },
        allowedClasses = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 }
    },
    ['trailers'] = { -- Standard Trailer
        maxVehicles = 1,
        loadPositions = {
            { x = 0.0, y = -2.0, z = 1.0, heading = 0.0 }
        },
        allowedClasses = { 0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12 }
    }
}

-- Vehicle Class Names for UI
Config.VehicleClasses = {
    [0] = "Compacts",
    [1] = "Sedans",
    [2] = "SUVs",
    [3] = "Coupes",
    [4] = "Muscle",
    [5] = "Sports Classics",
    [6] = "Sports",
    [7] = "Super",
    [8] = "Motorcycles",
    [9] = "Off-road",
    [10] = "Industrial",
    [11] = "Utility",
    [12] = "Vans",
    [13] = "Cycles",
    [14] = "Boats",
    [15] = "Helicopters",
    [16] = "Planes",
    [17] = "Service",
    [18] = "Emergency",
    [19] = "Military",
    [20] = "Commercial",
    [21] = "Trains"
}

-- Blacklisted Vehicles (by model name)
Config.BlacklistedVehicles = {
    'rhino',      -- Tank
    'lazer',      -- Military Jet
    'hydra',      -- Military VTOL
    'savage',     -- Attack Helicopter
    'insurgent',  -- Armored Vehicle
    'technical',  -- Weaponized Vehicle
    'halftrack',  -- Armored Halftrack
    'apc',        -- APC
    'khanjali',   -- Tank
    'chernobog',  -- Missile Launcher
    'thruster',   -- Jetpack
    'oppressor',  -- Flying Motorcycle
    'oppressor2', -- Flying Motorcycle MK2
    'deluxo',     -- Flying Car
    'stromberg',  -- Submarine Car
    'ruiner2',    -- Weaponized Ruiner
    'tampa3',     -- Weaponized Tampa
    'technical3', -- Weaponized Technical
}

-- Blacklisted Vehicle Classes
Config.BlacklistedClasses = {
    14, -- Boats
    15, -- Helicopters
    16, -- Planes
    21  -- Trains
}

-- Language Settings
Config.Locale = 'en'

Config.Locales = {
    ['en'] = {
        ['open_menu'] = 'Press ~INPUT_CONTEXT~ to open vehicle loader menu',
        ['no_trailer'] = 'No trailer nearby',
        ['trailer_full'] = 'Trailer is full',
        ['vehicle_loaded'] = 'Vehicle loaded successfully',
        ['vehicle_unloaded'] = 'Vehicle unloaded successfully',
        ['no_vehicle'] = 'No vehicle to load',
        ['blacklisted_vehicle'] = 'This vehicle cannot be loaded',
        ['not_vehicle_owner'] = 'You are not the owner of this vehicle',
        ['loading_failed'] = 'Failed to load vehicle',
        ['unloading_failed'] = 'Failed to unload vehicle',
        ['menu_title'] = 'Vehicle Loader',
        ['load_vehicle'] = 'Load Vehicle',
        ['unload_vehicle'] = 'Unload Vehicle',
        ['vehicle_info'] = 'Vehicle Information',
        ['trailer_capacity'] = 'Trailer Capacity',
        ['close'] = 'Close'
    },
    ['de'] = {
        ['open_menu'] = 'Drücke ~INPUT_CONTEXT~ um das Fahrzeug-Lader Menü zu öffnen',
        ['no_trailer'] = 'Kein Trailer in der Nähe',
        ['trailer_full'] = 'Trailer ist voll',
        ['vehicle_loaded'] = 'Fahrzeug erfolgreich geladen',
        ['vehicle_unloaded'] = 'Fahrzeug erfolgreich entladen',
        ['no_vehicle'] = 'Kein Fahrzeug zum Laden',
        ['blacklisted_vehicle'] = 'Dieses Fahrzeug kann nicht geladen werden',
        ['not_vehicle_owner'] = 'Du bist nicht der Besitzer dieses Fahrzeugs',
        ['loading_failed'] = 'Laden des Fahrzeugs fehlgeschlagen',
        ['unloading_failed'] = 'Entladen des Fahrzeugs fehlgeschlagen',
        ['menu_title'] = 'Fahrzeug Lader',
        ['load_vehicle'] = 'Fahrzeug Laden',
        ['unload_vehicle'] = 'Fahrzeug Entladen',
        ['vehicle_info'] = 'Fahrzeug Information',
        ['trailer_capacity'] = 'Trailer Kapazität',
        ['close'] = 'Schließen'
    }
}

-- Animation Settings
Config.Animations = {
    loading = {
        dict = "mini@repair",
        anim = "fixing_a_player",
        duration = 3000
    },
    unloading = {
        dict = "mini@repair",
        anim = "fixing_a_player",
        duration = 2000
    }
}

-- Sound Settings
Config.Sounds = {
    loading = {
        name = "PICK_UP",
        set = "HUD_FRONTEND_DEFAULT_SOUNDSET"
    },
    unloading = {
        name = "PUT_DOWN",
        set = "HUD_FRONTEND_DEFAULT_SOUNDSET"
    },
    error = {
        name = "ERROR",
        set = "HUD_FRONTEND_DEFAULT_SOUNDSET"
    }
}
