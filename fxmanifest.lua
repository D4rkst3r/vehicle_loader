fx_version 'cerulean'
game 'gta5'

author 'D4rkst3r'
description 'Professional Vehicle Loader System - Enhanced Edition'
version '2.0.0'
url 'https://github.com/your-repo/vehicle-loader'

-- Lua 5.4 compatibility
lua54 'yes'

-- Client Scripts
client_scripts {
    'config.lua',
    'client/main.lua',
    'client/functions.lua'
}

-- Server Scripts
server_scripts {
    'config.lua',
    'server/main.lua'
}

-- Shared Scripts
shared_scripts {
    'config.lua'
}

-- UI Files
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/*.png',
    'html/assets/*.jpg',
    'html/assets/*.svg'
}

-- Dependencies
dependencies {
    'spawnmanager'
}

-- Optional dependencies for enhanced features
-- Uncomment if you have these resources
-- dependency 'mysql-async'  -- For database persistence
-- dependency 'es_extended'  -- For ESX integration
-- dependency 'qb-core'      -- For QB-Core integration
-- dependency 'vrp'          -- For vRP integration

-- Resource metadata
provide 'vehicle-loader'

-- Server exports
server_exports {
    'GetLoadedVehicles',
    'GetTrailerVehicles',
    'IsVehicleLoaded',
    'GetStatistics',
    'ForceUnloadVehicle'
}

-- Client exports
client_exports {
    'GetLoadedVehicles',
    'IsVehicleLoaded',
    'GetNearbyTrailer'
}

-- ACE Permissions
--add_ace_object "group.admin" "vehicleloader.admin"
--allow
--add_ace_object "group.mod" "vehicleloader.admin"
--allow
--add_ace_object "builtin.everyone" "vehicleloader.use"
--allow

-- ConVars for runtime configuration
set_convar "vehicleloader_debug" "false"
set_convar "vehicleloader_max_distance" "10.0"
set_convar "vehicleloader_check_ownership" "false"
set_convar "vehicleloader_auto_cleanup" "true"

-- Resource information
repository 'https://github.com/your-repo/vehicle-loader'
issues 'https://github.com/your-repo/vehicle-loader/issues'
