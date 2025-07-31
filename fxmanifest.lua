-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'github.com/user/zhoraFPS'
description 'Freunde werben Freunde Skript mit Vue2 NUI'
version '1.0.9' 

lua54 'yes' 

shared_script 'config.lua'


files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

ui_page_options {
     opaque = false 
}


ui_page 'html/index.html'


client_scripts {
    '@es_extended/locale.lua',
    'client/client.lua'        
}


server_scripts {
    '@es_extended/locale.lua',
    'server/server.lua'
}

dependencies {
    'es_extended',
    'oxmysql'
}


