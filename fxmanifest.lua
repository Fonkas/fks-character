fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'fks-character'
author 'Fonkas'
description 'Multicharacter, character creator and starter experience for RedM (VORP)'
version '1.1.0'
license 'GPL-2.0' -- see LICENSE
-- fks-character  Copyright (C) 2026 Fonkas

-- Replaces vorp_character: the vorp_core character events are handled here.
provide 'vorp_character'

-- The interface is drawn by fks-core (shared FKS UI): this resource ships no HTML of its own.
fks_core_version '2.1.0'

shared_scripts {
    '@fks-core/import.lua',
    'config.lua',
    'locales/*.lua',
    'shared/locale.lua',
    'shared/data/clothing.lua',
    'shared/data/hairs.lua',
    'shared/appearance.lua',
    'shared/catalog.lua',
    'shared/validate.lua',
}

client_scripts {
    '@vorp_core/client/dataview.lua',
    'client/natives.lua',
    'client/rpc.lua',
    'client/ui.lua',
    'client/appearance.lua',
    'client/camera.lua',
    'client/scene.lua',
    'client/selection.lua',
    'client/creator.lua',
    'client/arrival.lua',
    'client/cinematics.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/rpc.lua',
    'server/characters.lua',
    'server/main.lua',
    'server/tebex.lua',
    'server/kits.lua',
    'server/skinmenu.lua',
    'server/commands.lua',
    'server/version.lua',
}

dependencies {
    'fks-core',
    'vorp_core',
    'oxmysql',
}
