fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mz_computer'
author 'Mazus / MZ Framework'
description 'MZ OS - secure in-game computer platform with digital accounts, devices, apps and MZ Net'
version '1.3.3'

ui_page 'ui/dist/index.html'

files {
    'ui/dist/index.html',
    'ui/dist/calibration.html',
    'ui/dist/display.html',
    'ui/dist/app.js',
    'ui/dist/screen-math.js',
    'ui/dist/hybrid-math.js',
    'ui/dist/surface.js',
    'ui/dist/desktop.css',
    'ui/dist/styles.css',
    'ui/dist/assets/icons/*.svg',
    'ui/dist/assets/icons/LICENSE.txt'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/constants.lua',
    'shared/validation.lua',
    'shared/screen_geometry.lua',
    'shared/contracts.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/crypto.lua',
    'server/migrations.lua',
    'server/repository.lua',
    'server/identity.lua',
    'server/audit.lua',
    'server/devices.lua',
    'server/terminal_editor.lua',
    'server/sessions.lua',
    'server/permissions.lua',
    'server/apps.lua',
    'server/sites.lua',
    'server/accounts.lua',
    'server/content.lua',
    'server/notifications.lua',
    'server/auth.lua',
    'server/bridge.lua',
    'server/integrations.lua',
    'server/exports.lua',
    'server/main.lua'
}

client_scripts {
    'client/state.lua',
    'client/device.lua',
    'client/world.lua',
    'client/terminal_editor.lua',
    'client/interaction.lua',
    'client/nui.lua',
    'client/main.lua'
}

dependencies {
    'oxmysql',
    'ox_lib',
    'mz_core',
    'mz_org',
    'mz_inventory'
}
