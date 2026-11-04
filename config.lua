Config = Config or {}

Config.Version = '1.3.2'
Config.Debug = true
Config.Locale = 'pt-BR'

Config.DeviceSkins = {
    -- asset/viewport are legacy metadata for consumers of the V1 skin contract.
    -- The 1.1 notebook shell is CSS; adjust 3D screens in WorldDisplay / display.
    notebook_basic = {
        id = 'notebook_basic',
        name = 'Notebook básico',
        asset = 'assets/notebook-frame-overlay.png',
        aspectRatio = 16 / 9,
        viewport = {
            left = 0.15052083,
            top = 0.10925926,
            width = 0.69791667,
            height = 0.77685185
        },
        camera = { enabled = false, fov = 50.0 },
        prop = {
            enabled = false,
            model = 'prop_laptop_01a',
            bone = 57005,
            offset = { x = 0.10, y = 0.02, z = -0.02 },
            rotation = { x = 10.0, y = 180.0, z = 20.0 }
        }
    },
    terminal_basic = {
        id = 'terminal_basic',
        name = 'Terminal público',
        asset = 'assets/notebook-frame-overlay.png',
        aspectRatio = 16 / 9,
        viewport = {
            left = 0.15052083,
            top = 0.10925926,
            width = 0.69791667,
            height = 0.77685185
        },
        camera = { enabled = false, fov = 50.0 },
        prop = { enabled = false }
    }
}
Config.DefaultSkin = 'notebook_basic'

-- Public PCs render the existing web UI onto a local 3D surface. Personal
-- notebooks keep the desktop shell. See docs/COMPUTER_3D.md for calibration.
Config.WorldDisplay = {
    enabled = true,
    width = 1280,
    height = 720,
    loadTimeoutMs = 8000,
    spawnDistance = 35.0,
    model = 'prop_monitor_01c',
    spawnProp = false, -- use existing world objects; /mztela registers each screen
    objectOffset = { x = 0.0, y = 0.0, z = 0.72 },
    screenOffset = { x = 0.0, y = -0.035, z = 0.28 },
    screenWidth = 0.48,
    screenHeight = 0.27,
    screenTilt = 0.0,
    cameraDistance = 0.72, -- calibration/fallback camera distance
    cameraFov = 42.0,
    transitionMs = 450,
    -- Runtime public PCs use a scripted first-person view from the player's
    -- head toward the mapped screen. /mztela starts with an external mapping
    -- preview, then switches to a live first-person simulator to capture the
    -- final player position and view.
    cameraMode = 'first_person',
    -- Hybrid is the canonical public-terminal interaction: the mapped DUI stays
    -- on the world prop, while the focused MZ OS runs as ordinary NUI over the
    -- projected glass. Set to 'dui' only to restore the legacy 3D input bridge.
    interactionMode = 'nui_overlay',
    hybridProjectionIntervalMs = 50,
    firstPersonHeadBone = 31086, -- SKEL_Head
    firstPersonFallbackHeight = 0.68,
    firstPersonEyeForward = 0.06, -- metres from head toward the monitor
    firstPersonEyeRight = 0.0,
    firstPersonEyeUp = 0.01,
    firstPersonTargetRight = 0.0,
    firstPersonTargetUp = 0.0,
    hideLocalPlayerInFirstPerson = true, -- local-only; other players still see the character
    -- Public terminals with a playerAnchor gently align the character before
    -- freezing input. Legacy terminals without anchors keep the old behaviour.
    playerAlignEnabled = true,
    playerAlignMaxDistance = 2.5,
    playerAlignTimeoutMs = 2800,
    playerAlignTolerance = 0.18,
    playerAlignSpeed = 1.0
}

Config.TerminalEditor = {
    enabled = true,
    command = 'mztela',
    allowWorldEditorAdmins = true,
    cameraDistanceMax = 20.0, -- metres; shared limit for editor and server validation
    anchorOffsetMax = 6.0, -- local metres from the selected prop
    interactionDistanceMin = 0.5,
    interactionDistanceMax = 4.0,
    maxTerminals = 200
}

Config.Auth = {
    usernameMinLength = 3,
    usernameMaxLength = 32,
    passwordMinLength = 6,
    passwordMaxLength = 128,
    onePersonalAccountPerCitizen = true,
    maxFailedAttempts = 5,
    failureWindowSeconds = 15 * 60,
    lockSeconds = 5 * 60,
    -- Self-contained V1 KDF. The implementation is PBKDF2-HMAC-SHA256 on the server.
    -- Keep this configurable because CPU characteristics vary between FxServer hosts.
    pbkdf2Iterations = 12000,
    pbkdf2YieldEvery = 250
}

Config.Sessions = {
    ttlSeconds = 30 * 60,
    maxConcurrentPerAccount = 1,
    revokeOldSessionOnLogin = true
}

Config.Devices = {
    publicLeaseSeconds = 10 * 60,
    publicMaxDistance = 3.0,
    requireServerDistance = true,
    closeOnDeath = true
}

Config.NotebookItem = {
    enabled = true,
    itemName = 'notebook',
    metadataKeys = { 'uid', 'device_uid', 'serial' }
}

-- Optional manual definitions. /mztela saves world monitors to terminals.json.
Config.PublicTerminals = {}

Config.Interaction = {
    enabled = true,
    drawDistance = 8.0,
    key = 38, -- INPUT_CONTEXT / E
    prompt = '[E] Usar computador'
}

Config.UI = {
    bootDurationMs = 1100,
    defaultTheme = 'dark',
    defaultScale = 1.0,
    minScale = 0.85,
    maxScale = 1.15,
    sounds = true,
    closeKeyLabel = 'ESC'
}

Config.Browser = {
    networkName = 'MZ Net',
    homeUrl = 'mz://home',
    blockedSchemes = {
        'http:', 'https:', 'ftp:', 'file:', 'javascript:', 'data:', 'blob:',
        'nui:', 'cfx-nui:', 'ws:', 'wss:'
    }
}

Config.Content = {
    maxNotes = 100,
    maxNoteTitle = 120,
    maxNoteContent = 10000,
    maxDocuments = 50,
    maxDocumentTitle = 120,
    maxDocumentContent = 20000
}

Config.Security = {
    requestRatePerMinute = 90,
    requestBurst = 20,
    staffAce = 'mzcomputer.staff',
    debugAce = 'mzcomputer.debug',
    trustedAppResources = {
        -- ['mz_bank'] = true,
        -- ['mz_jobs'] = true,
    }
}

Config.Database = {
    migrationsTable = 'mz_computer_migrations',
    migrationFiles = {
        'sql/001_initial_schema.sql',
        'sql/002_content_and_notifications.sql'
    }
}

Config.Developer = {
    -- Enables /mzcomputer only for Config.Security.debugAce or when Config.Debug=true.
    allowPortableCommand = true
}
