fx_version 'cerulean'
game 'gta5'

author 'D4rkst3r'
description 'Professional Vehicle Loader '
version '1.0.0'

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

-- UI Files
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

-- Dependencies
dependencies {
    'spawnmanager'
}
