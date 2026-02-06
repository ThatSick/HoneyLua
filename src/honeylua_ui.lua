-- HoneyLua Config Manager UI (Executor-ready)
-- Paste into your executor or require this file in your loader.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local FS = {
    writefile = writefile,
    readfile = readfile,
    isfile = isfile,
    isfolder = isfolder,
    makefolder = makefolder,
    listfiles = listfiles,
}

local function ensureExecutorFS()
    for name, fn in pairs(FS) do
        if type(fn) ~= "function" then
            error(string.format("HoneyLua requires executor file APIs. Missing: %s", name))
        end
    end
end

ensureExecutorFS()

local ROOT_FOLDER = "HoneyLua"
local CONFIG_FOLDER = ROOT_FOLDER .. "/Configs"
local SETTINGS_FILE = ROOT_FOLDER .. "/settings.json"

if not FS.isfolder(ROOT_FOLDER) then
    FS.makefolder(ROOT_FOLDER)
end

if not FS.isfolder(CONFIG_FOLDER) then
    FS.makefolder(CONFIG_FOLDER)
end

local DEFAULT_SETTINGS = {
    autoLoad = true,
    autoSave = true,
    lastConfig = "default",
    autoSaveInterval = 30,
}

local DEFAULT_CONFIG = {
    honeyLevel = 5,
    enableGlow = true,
    notes = "Sweet and smooth.",
}

local function decodeJson(payload, fallback)
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(payload)
    end)
    if ok and type(decoded) == "table" then
        return decoded
    end
    return fallback
end

local function encodeJson(payload)
    return HttpService:JSONEncode(payload)
end

local function readSettings()
    if FS.isfile(SETTINGS_FILE) then
        local raw = FS.readfile(SETTINGS_FILE)
        return decodeJson(raw, DEFAULT_SETTINGS)
    end
    return DEFAULT_SETTINGS
end

local function writeSettings(settings)
    FS.writefile(SETTINGS_FILE, encodeJson(settings))
end

local function configPath(configName)
    return CONFIG_FOLDER .. "/" .. configName .. ".json"
end

local function readConfig(configName)
    local path = configPath(configName)
    if FS.isfile(path) then
        local raw = FS.readfile(path)
        return decodeJson(raw, DEFAULT_CONFIG)
    end
    return DEFAULT_CONFIG
end

local function writeConfig(configName, data)
    local path = configPath(configName)
    FS.writefile(path, encodeJson(data))
end

local function resetConfig(configName)
    writeConfig(configName, DEFAULT_CONFIG)
    return DEFAULT_CONFIG
end

local settings = readSettings()
local currentConfigName = settings.lastConfig or "default"
local configData = readConfig(currentConfigName)

local function syncSettings()
    settings.lastConfig = currentConfigName
    writeSettings(settings)
end

local function listConfigs()
    local configs = {}
    for _, filePath in ipairs(FS.listfiles(CONFIG_FOLDER)) do
        local name = filePath:match("([^/]+)%.json$")
        if name then
            table.insert(configs, name)
        end
    end
    table.sort(configs)
    return configs
end

local function applyConfigToUI()
    if not UI then
        return
    end
    UI.honeyLevelBox.Text = tostring(configData.honeyLevel or DEFAULT_CONFIG.honeyLevel)
    UI.enableGlowToggle.Text = (configData.enableGlow and "ON") or "OFF"
    UI.notesBox.Text = tostring(configData.notes or "")
    UI.autoLoadToggle.Text = settings.autoLoad and "ON" or "OFF"
    UI.autoSaveToggle.Text = settings.autoSave and "ON" or "OFF"
    UI.configNameBox.Text = currentConfigName
end

local function updateStatus(message)
    if UI and UI.statusLabel then
        UI.statusLabel.Text = message
    end
end

local function setConfigFromUI()
    local level = tonumber(UI.honeyLevelBox.Text) or DEFAULT_CONFIG.honeyLevel
    configData.honeyLevel = math.clamp(level, 1, 10)
    configData.enableGlow = UI.enableGlowToggle.Text == "ON"
    configData.notes = UI.notesBox.Text
end

local function createConfig(configName)
    currentConfigName = configName
    configData = DEFAULT_CONFIG
    writeConfig(currentConfigName, configData)
    syncSettings()
    applyConfigToUI()
    updateStatus("Created config: " .. currentConfigName)
end

local function saveConfig()
    setConfigFromUI()
    writeConfig(currentConfigName, configData)
    syncSettings()
    updateStatus("Saved config: " .. currentConfigName)
end

local function loadConfig(configName)
    currentConfigName = configName
    configData = readConfig(currentConfigName)
    syncSettings()
    applyConfigToUI()
    updateStatus("Loaded config: " .. currentConfigName)
end

local function resetCurrentConfig()
    configData = resetConfig(currentConfigName)
    applyConfigToUI()
    updateStatus("Reset config: " .. currentConfigName)
end

local function toggleAuto(settingKey)
    settings[settingKey] = not settings[settingKey]
    syncSettings()
    applyConfigToUI()
end

local function buildUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HoneyLuaUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.fromOffset(420, 320)
    main.Position = UDim2.new(0.5, -210, 0.5, -160)
    main.BackgroundColor3 = Color3.fromRGB(255, 219, 145)
    main.BorderSizePixel = 0
    main.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent = main

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(183, 124, 37)
    stroke.Thickness = 2
    stroke.Parent = main

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -24, 0, 32)
    title.Position = UDim2.fromOffset(12, 10)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.Text = "HoneyLua Config Manager"
    title.TextColor3 = Color3.fromRGB(92, 55, 17)
    title.Parent = main

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, -24, 0, 20)
    status.Position = UDim2.fromOffset(12, 44)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham
    status.TextSize = 14
    status.Text = "Ready."
    status.TextColor3 = Color3.fromRGB(120, 79, 28)
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = main

    local configNameLabel = Instance.new("TextLabel")
    configNameLabel.Size = UDim2.fromOffset(140, 22)
    configNameLabel.Position = UDim2.fromOffset(12, 72)
    configNameLabel.BackgroundTransparency = 1
    configNameLabel.Font = Enum.Font.GothamSemibold
    configNameLabel.TextSize = 14
    configNameLabel.Text = "Config Name"
    configNameLabel.TextColor3 = Color3.fromRGB(92, 55, 17)
    configNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    configNameLabel.Parent = main

    local configNameBox = Instance.new("TextBox")
    configNameBox.Name = "ConfigName"
    configNameBox.Size = UDim2.fromOffset(180, 26)
    configNameBox.Position = UDim2.fromOffset(12, 96)
    configNameBox.BackgroundColor3 = Color3.fromRGB(255, 237, 200)
    configNameBox.BorderSizePixel = 0
    configNameBox.Font = Enum.Font.Gotham
    configNameBox.TextSize = 14
    configNameBox.Text = currentConfigName
    configNameBox.TextColor3 = Color3.fromRGB(92, 55, 17)
    configNameBox.ClearTextOnFocus = false
    configNameBox.Parent = main

    local configCorner = Instance.new("UICorner")
    configCorner.CornerRadius = UDim.new(0, 8)
    configCorner.Parent = configNameBox

    local honeyLabel = Instance.new("TextLabel")
    honeyLabel.Size = UDim2.fromOffset(140, 22)
    honeyLabel.Position = UDim2.fromOffset(12, 132)
    honeyLabel.BackgroundTransparency = 1
    honeyLabel.Font = Enum.Font.GothamSemibold
    honeyLabel.TextSize = 14
    honeyLabel.Text = "Honey Level (1-10)"
    honeyLabel.TextColor3 = Color3.fromRGB(92, 55, 17)
    honeyLabel.TextXAlignment = Enum.TextXAlignment.Left
    honeyLabel.Parent = main

    local honeyLevelBox = Instance.new("TextBox")
    honeyLevelBox.Name = "HoneyLevel"
    honeyLevelBox.Size = UDim2.fromOffset(80, 26)
    honeyLevelBox.Position = UDim2.fromOffset(12, 156)
    honeyLevelBox.BackgroundColor3 = Color3.fromRGB(255, 237, 200)
    honeyLevelBox.BorderSizePixel = 0
    honeyLevelBox.Font = Enum.Font.Gotham
    honeyLevelBox.TextSize = 14
    honeyLevelBox.Text = tostring(configData.honeyLevel)
    honeyLevelBox.TextColor3 = Color3.fromRGB(92, 55, 17)
    honeyLevelBox.ClearTextOnFocus = false
    honeyLevelBox.Parent = main

    local honeyCorner = Instance.new("UICorner")
    honeyCorner.CornerRadius = UDim.new(0, 8)
    honeyCorner.Parent = honeyLevelBox

    local glowLabel = Instance.new("TextLabel")
    glowLabel.Size = UDim2.fromOffset(140, 22)
    glowLabel.Position = UDim2.fromOffset(110, 132)
    glowLabel.BackgroundTransparency = 1
    glowLabel.Font = Enum.Font.GothamSemibold
    glowLabel.TextSize = 14
    glowLabel.Text = "Glow"
    glowLabel.TextColor3 = Color3.fromRGB(92, 55, 17)
    glowLabel.TextXAlignment = Enum.TextXAlignment.Left
    glowLabel.Parent = main

    local glowToggle = Instance.new("TextButton")
    glowToggle.Name = "GlowToggle"
    glowToggle.Size = UDim2.fromOffset(80, 26)
    glowToggle.Position = UDim2.fromOffset(110, 156)
    glowToggle.BackgroundColor3 = Color3.fromRGB(255, 176, 68)
    glowToggle.BorderSizePixel = 0
    glowToggle.Font = Enum.Font.GothamBold
    glowToggle.TextSize = 14
    glowToggle.Text = configData.enableGlow and "ON" or "OFF"
    glowToggle.TextColor3 = Color3.fromRGB(92, 55, 17)
    glowToggle.Parent = main

    local glowCorner = Instance.new("UICorner")
    glowCorner.CornerRadius = UDim.new(0, 8)
    glowCorner.Parent = glowToggle

    local notesLabel = Instance.new("TextLabel")
    notesLabel.Size = UDim2.fromOffset(140, 22)
    notesLabel.Position = UDim2.fromOffset(210, 132)
    notesLabel.BackgroundTransparency = 1
    notesLabel.Font = Enum.Font.GothamSemibold
    notesLabel.TextSize = 14
    notesLabel.Text = "Notes"
    notesLabel.TextColor3 = Color3.fromRGB(92, 55, 17)
    notesLabel.TextXAlignment = Enum.TextXAlignment.Left
    notesLabel.Parent = main

    local notesBox = Instance.new("TextBox")
    notesBox.Name = "Notes"
    notesBox.Size = UDim2.fromOffset(198, 60)
    notesBox.Position = UDim2.fromOffset(210, 156)
    notesBox.BackgroundColor3 = Color3.fromRGB(255, 237, 200)
    notesBox.BorderSizePixel = 0
    notesBox.Font = Enum.Font.Gotham
    notesBox.TextSize = 14
    notesBox.TextWrapped = true
    notesBox.TextYAlignment = Enum.TextYAlignment.Top
    notesBox.Text = tostring(configData.notes)
    notesBox.TextColor3 = Color3.fromRGB(92, 55, 17)
    notesBox.ClearTextOnFocus = false
    notesBox.Parent = main

    local notesCorner = Instance.new("UICorner")
    notesCorner.CornerRadius = UDim.new(0, 8)
    notesCorner.Parent = notesBox

    local autoLoadLabel = Instance.new("TextLabel")
    autoLoadLabel.Size = UDim2.fromOffset(140, 22)
    autoLoadLabel.Position = UDim2.fromOffset(12, 200)
    autoLoadLabel.BackgroundTransparency = 1
    autoLoadLabel.Font = Enum.Font.GothamSemibold
    autoLoadLabel.TextSize = 14
    autoLoadLabel.Text = "Auto Load"
    autoLoadLabel.TextColor3 = Color3.fromRGB(92, 55, 17)
    autoLoadLabel.TextXAlignment = Enum.TextXAlignment.Left
    autoLoadLabel.Parent = main

    local autoLoadToggle = Instance.new("TextButton")
    autoLoadToggle.Name = "AutoLoad"
    autoLoadToggle.Size = UDim2.fromOffset(80, 26)
    autoLoadToggle.Position = UDim2.fromOffset(12, 224)
    autoLoadToggle.BackgroundColor3 = Color3.fromRGB(255, 176, 68)
    autoLoadToggle.BorderSizePixel = 0
    autoLoadToggle.Font = Enum.Font.GothamBold
    autoLoadToggle.TextSize = 14
    autoLoadToggle.Text = settings.autoLoad and "ON" or "OFF"
    autoLoadToggle.TextColor3 = Color3.fromRGB(92, 55, 17)
    autoLoadToggle.Parent = main

    local autoLoadCorner = Instance.new("UICorner")
    autoLoadCorner.CornerRadius = UDim.new(0, 8)
    autoLoadCorner.Parent = autoLoadToggle

    local autoSaveLabel = Instance.new("TextLabel")
    autoSaveLabel.Size = UDim2.fromOffset(140, 22)
    autoSaveLabel.Position = UDim2.fromOffset(110, 200)
    autoSaveLabel.BackgroundTransparency = 1
    autoSaveLabel.Font = Enum.Font.GothamSemibold
    autoSaveLabel.TextSize = 14
    autoSaveLabel.Text = "Auto Save"
    autoSaveLabel.TextColor3 = Color3.fromRGB(92, 55, 17)
    autoSaveLabel.TextXAlignment = Enum.TextXAlignment.Left
    autoSaveLabel.Parent = main

    local autoSaveToggle = Instance.new("TextButton")
    autoSaveToggle.Name = "AutoSave"
    autoSaveToggle.Size = UDim2.fromOffset(80, 26)
    autoSaveToggle.Position = UDim2.fromOffset(110, 224)
    autoSaveToggle.BackgroundColor3 = Color3.fromRGB(255, 176, 68)
    autoSaveToggle.BorderSizePixel = 0
    autoSaveToggle.Font = Enum.Font.GothamBold
    autoSaveToggle.TextSize = 14
    autoSaveToggle.Text = settings.autoSave and "ON" or "OFF"
    autoSaveToggle.TextColor3 = Color3.fromRGB(92, 55, 17)
    autoSaveToggle.Parent = main

    local autoSaveCorner = Instance.new("UICorner")
    autoSaveCorner.CornerRadius = UDim.new(0, 8)
    autoSaveCorner.Parent = autoSaveToggle

    local function makeButton(name, text, x, y)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = UDim2.fromOffset(92, 30)
        button.Position = UDim2.fromOffset(x, y)
        button.BackgroundColor3 = Color3.fromRGB(255, 176, 68)
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamBold
        button.TextSize = 14
        button.Text = text
        button.TextColor3 = Color3.fromRGB(92, 55, 17)
        button.Parent = main

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 8)
        buttonCorner.Parent = button

        return button
    end

    local createButton = makeButton("Create", "Create", 12, 264)
    local saveButton = makeButton("Save", "Save", 114, 264)
    local loadButton = makeButton("Load", "Load", 216, 264)
    local resetButton = makeButton("Reset", "Reset", 318, 264)

    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

    return {
        screenGui = screenGui,
        statusLabel = status,
        configNameBox = configNameBox,
        honeyLevelBox = honeyLevelBox,
        enableGlowToggle = glowToggle,
        notesBox = notesBox,
        autoLoadToggle = autoLoadToggle,
        autoSaveToggle = autoSaveToggle,
        createButton = createButton,
        saveButton = saveButton,
        loadButton = loadButton,
        resetButton = resetButton,
    }
end

UI = buildUI()
applyConfigToUI()

UI.enableGlowToggle.MouseButton1Click:Connect(function()
    configData.enableGlow = not configData.enableGlow
    applyConfigToUI()
    updateStatus("Glow toggled.")
end)

UI.autoLoadToggle.MouseButton1Click:Connect(function()
    toggleAuto("autoLoad")
    updateStatus("Auto load: " .. (settings.autoLoad and "ON" or "OFF"))
end)

UI.autoSaveToggle.MouseButton1Click:Connect(function()
    toggleAuto("autoSave")
    updateStatus("Auto save: " .. (settings.autoSave and "ON" or "OFF"))
end)

UI.createButton.MouseButton1Click:Connect(function()
    local name = UI.configNameBox.Text
    if name == "" then
        updateStatus("Enter a config name.")
        return
    end
    createConfig(name)
end)

UI.saveButton.MouseButton1Click:Connect(function()
    saveConfig()
end)

UI.loadButton.MouseButton1Click:Connect(function()
    local name = UI.configNameBox.Text
    if name == "" then
        updateStatus("Enter a config name.")
        return
    end
    loadConfig(name)
end)

UI.resetButton.MouseButton1Click:Connect(function()
    resetCurrentConfig()
end)

if settings.autoLoad and FS.isfile(configPath(currentConfigName)) then
    loadConfig(currentConfigName)
else
    updateStatus("Ready. Configs: " .. table.concat(listConfigs(), ", "))
end

if settings.autoSave then
    task.spawn(function()
        while UI and UI.screenGui and UI.screenGui.Parent do
            task.wait(settings.autoSaveInterval or 30)
            if settings.autoSave then
                saveConfig()
            end
        end
    end)
end

if RunService:IsStudio() then
    warn("HoneyLua UI loaded in Studio. Use an executor for file APIs.")
end
