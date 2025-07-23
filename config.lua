Config = {}

-- Debug Mode
Config.Debug = false

-- Performance Settings
Config.CheckInterval = 1000   -- ms between checks
Config.MaxDistance = 10.0     -- Maximum distance to interact with trailer
Config.MaxNearbyVehicles = 20 -- Limit nearby vehicles for performance

-- Security Settings
Config.CheckOwnership = false    -- Enable vehicle ownership checks
Config.AllowAdminOverride = true -- Allow admins to bypass restrictions

-- Timeouts & Intervals
Config.Timeouts = {
    ANIMATION_LOAD = 3000,    -- Loading animation duration
    ANIMATION_UNLOAD = 2000,  -- Unloading animation duration
    CLEANUP_INTERVAL = 30000, -- Client cleanup interval
    SERVER_CLEANUP = 300000,  -- Server cleanup interval (5 minutes)
    PLAYER_COOLDOWN = 2000,   -- Cooldown between actions
    UI_REFRESH = 5000,        -- Auto-refresh interval for UI
    NETWORK_TIMEOUT = 10000   -- Network operation timeout
}

-- Distance Settings
Config.Distances = {
    MAX_INTERACTION = 10.0,     -- Max interaction distance
    SAFE_UNLOAD_OFFSET = 3.0,   -- Safe unload distance
    GROUND_CHECK_HEIGHT = 5.0,  -- Height for ground checks
    ATTACHMENT_PRECISION = 0.01 -- Attachment precision
}

-- Key Bindings
Config.Keys = {
    MENU = 38,  -- E Key
    LOAD = 47,  -- G Key
    UNLOAD = 74 -- H Key
}

-- Trailer Configurations
Config.Trailers = {
    ['tr2'] = { -- Car Trailer
        maxVehicles = 1,
        loadPositions = {
            { x = 0.0, y = -2.5, z = 1.0, heading = 0.0 }
        },
        allowedClasses = { 0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12 },
        maxVehicleSize = 5.0, -- Max vehicle length
        displayName = "Car Trailer"
    },
    ['tr4'] = { -- Large Trailer
        maxVehicles = 2,
        loadPositions = {
            { x = 0.0, y = -1.5, z = 1.0, heading = 0.0 },
            { x = 0.0, y = -4.5, z = 1.0, heading = 0.0 }
        },
        allowedClasses = { 0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12 },
        maxVehicleSize = 6.0,
        displayName = "Large Trailer"
    },
    ['trflat'] = { -- Flat Trailer
        maxVehicles = 3,
        loadPositions = {
            { x = 0.0, y = -1.0, z = 1.2, heading = 0.0 },
            { x = 0.0, y = -3.0, z = 1.2, heading = 0.0 },
            { x = 0.0, y = -5.0, z = 1.2, heading = 0.0 }
        },
        allowedClasses = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 },
        maxVehicleSize = 7.0,
        displayName = "Flat Trailer"
    },
    ['flatbed'] = { -- Standard Trailer
        maxVehicles = 1,
        loadPositions = {
            { x = 0.0, y = -2.0, z = 1.0, heading = 0.0 }
        },
        allowedClasses = { 0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12 },
        maxVehicleSize = 5.5,
        displayName = "Flatbed Trailer"
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
    -- Military/Weaponized
    'rhino', 'lazer', 'hydra', 'savage', 'insurgent', 'technical',
    'halftrack', 'apc', 'khanjali', 'chernobog', 'thruster',
    'oppressor', 'oppressor2', 'deluxo', 'stromberg', 'ruiner2',
    'tampa3', 'technical3', 'weaponizedtampa', 'insurgent2',

    -- Aircraft & Boats
    'dodo', 'luxor', 'shamal', 'titan', 'velum', 'volatus',
    'maverick', 'frogger', 'buzzard', 'annihilator',
    'jetmax', 'speeder', 'squalo', 'suntrap', 'toro',

    -- Service/Emergency (optional)
    'ambulance', 'firetruk', 'lguard', 'police', 'police2',
    'police3', 'police4', 'policeb', 'policeold1', 'policeold2',

    -- Special/Unique
    'rcbandito', 'minitank', 'caddy', 'caddy2', 'caddy3'
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
        -- Interactions
        ['open_menu'] = 'Press ~INPUT_CONTEXT~ to open vehicle loader menu',
        ['loading_vehicle'] = 'Loading vehicle...',
        ['unloading_vehicle'] = 'Unloading vehicle...',

        -- Status Messages
        ['no_trailer'] = 'No trailer nearby',
        ['trailer_full'] = 'Trailer is at maximum capacity',
        ['vehicle_loaded'] = 'Vehicle loaded successfully',
        ['vehicle_unloaded'] = 'Vehicle unloaded successfully',
        ['no_vehicle'] = 'No vehicle to load',
        ['no_vehicles_loaded'] = 'No vehicles loaded',
        ['no_vehicles_available'] = 'No vehicles available nearby',

        -- Errors
        ['blacklisted_vehicle'] = 'This vehicle cannot be loaded on trailers',
        ['not_vehicle_owner'] = 'You are not the owner of this vehicle',
        ['loading_failed'] = 'Failed to load vehicle',
        ['unloading_failed'] = 'Failed to unload vehicle',
        ['operation_in_progress'] = 'Operation already in progress',
        ['player_too_far'] = 'You are too far from the trailer',
        ['vehicle_too_large'] = 'Vehicle is too large for this trailer',
        ['cooldown_active'] = 'Please wait before performing another action',
        ['invalid_slot'] = 'Invalid trailer slot',
        ['vehicle_destroyed'] = 'Vehicle is destroyed and cannot be loaded',

        -- UI Elements
        ['menu_title'] = 'Vehicle Loader',
        ['load_vehicle'] = 'Load Vehicle',
        ['unload_vehicle'] = 'Unload Vehicle',
        ['vehicle_info'] = 'Vehicle Information',
        ['trailer_info'] = 'Trailer Information',
        ['loaded_vehicles'] = 'Loaded Vehicles',
        ['available_vehicles'] = 'Available Vehicles',
        ['trailer_capacity'] = 'Capacity',
        ['search_placeholder'] = 'Search vehicles...',
        ['all_classes'] = 'All Classes',
        ['close'] = 'Close',
        ['model'] = 'Model',
        ['capacity'] = 'Capacity',
        ['loaded'] = 'Loaded',
        ['vehicles'] = 'vehicles',
        ['distance'] = 'Distance',
        ['slot'] = 'Slot'
    },
    ['de'] = {
        -- Interactions
        ['open_menu'] = 'Drücke ~INPUT_CONTEXT~ um das Fahrzeug-Lader Menü zu öffnen',
        ['loading_vehicle'] = 'Lade Fahrzeug...',
        ['unloading_vehicle'] = 'Entlade Fahrzeug...',

        -- Status Messages
        ['no_trailer'] = 'Kein Trailer in der Nähe',
        ['trailer_full'] = 'Trailer hat maximale Kapazität erreicht',
        ['vehicle_loaded'] = 'Fahrzeug erfolgreich geladen',
        ['vehicle_unloaded'] = 'Fahrzeug erfolgreich entladen',
        ['no_vehicle'] = 'Kein Fahrzeug zum Laden',
        ['no_vehicles_loaded'] = 'Keine Fahrzeuge geladen',
        ['no_vehicles_available'] = 'Keine Fahrzeuge in der Nähe verfügbar',

        -- Errors
        ['blacklisted_vehicle'] = 'Dieses Fahrzeug kann nicht auf Trailer geladen werden',
        ['not_vehicle_owner'] = 'Du bist nicht der Besitzer dieses Fahrzeugs',
        ['loading_failed'] = 'Laden des Fahrzeugs fehlgeschlagen',
        ['unloading_failed'] = 'Entladen des Fahrzeugs fehlgeschlagen',
        ['operation_in_progress'] = 'Vorgang bereits im Gange',
        ['player_too_far'] = 'Du bist zu weit vom Trailer entfernt',
        ['vehicle_too_large'] = 'Fahrzeug ist zu groß für diesen Trailer',
        ['cooldown_active'] = 'Bitte warte vor der nächsten Aktion',
        ['invalid_slot'] = 'Ungültiger Trailer-Slot',
        ['vehicle_destroyed'] = 'Fahrzeug ist zerstört und kann nicht geladen werden',

        -- UI Elements
        ['menu_title'] = 'Fahrzeug Lader',
        ['load_vehicle'] = 'Fahrzeug Laden',
        ['unload_vehicle'] = 'Fahrzeug Entladen',
        ['vehicle_info'] = 'Fahrzeug Information',
        ['trailer_info'] = 'Trailer Information',
        ['loaded_vehicles'] = 'Geladene Fahrzeuge',
        ['available_vehicles'] = 'Verfügbare Fahrzeuge',
        ['trailer_capacity'] = 'Kapazität',
        ['search_placeholder'] = 'Fahrzeuge suchen...',
        ['all_classes'] = 'Alle Klassen',
        ['close'] = 'Schließen',
        ['model'] = 'Modell',
        ['capacity'] = 'Kapazität',
        ['loaded'] = 'Geladen',
        ['vehicles'] = 'Fahrzeuge',
        ['distance'] = 'Entfernung',
        ['slot'] = 'Slot'
    }
}

-- Animation Settings
Config.Animations = {
    loading = {
        dict = "mini@repair",
        anim = "fixing_a_player",
        duration = Config.Timeouts.ANIMATION_LOAD,
        flags = 49
    },
    unloading = {
        dict = "mini@repair",
        anim = "fixing_a_player",
        duration = Config.Timeouts.ANIMATION_UNLOAD,
        flags = 49
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
    success = {
        name = "SELECT",
        set = "HUD_FRONTEND_DEFAULT_SOUNDSET"
    },
    error = {
        name = "ERROR",
        set = "HUD_FRONTEND_DEFAULT_SOUNDSET"
    },
    menu_open = {
        name = "NAV_UP_DOWN",
        set = "HUD_FRONTEND_DEFAULT_SOUNDSET"
    },
    menu_close = {
        name = "BACK",
        set = "HUD_FRONTEND_DEFAULT_SOUNDSET"
    }
}

-- Permissions (if using ACE permissions)
Config.Permissions = {
    USE_LOADER = 'vehicleloader.use',
    ADMIN = 'vehicleloader.admin',
    BYPASS_RESTRICTIONS = 'vehicleloader.bypass'
}

-- Database Settings (optional)
Config.Database = {
    Enabled = false,
    SaveInterval = 60000, -- Save every minute
    Table = 'vehicle_loader_data'
}

-- Advanced Settings
Config.Advanced = {
    UseEntityLockdown = true,    -- Lock loaded vehicles
    PreventVehicleDamage = true, -- Prevent damage to loaded vehicles
    AutoRepairOnUnload = false,  -- Auto-repair vehicles when unloading
    SyncVehicleColors = true,    -- Sync vehicle colors/mods
    UseAdvancedPhysics = true,   -- Use advanced attachment physics
    EnableStatistics = true,     -- Track usage statistics
    LogOperations = true         -- Log all operations
}
