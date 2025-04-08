fx_version 'cerulean'
game 'gta5'

client_scripts {
    'config.lua',  -- Сначала загружаем config.lua
    'client.lua'   -- Затем client.lua
}

ui_page 'index.html'

files {
    'index.html',
    'sound/*.wav'
}