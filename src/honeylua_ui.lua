-- HoneyLua Config Manager UI (Executor-ready)
-- Loadstring-friendly: exposes getgenv().HoneyLuaUI for adding tabs & controls.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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
        return decodeJson(raw, {})
    end
    return {}
end

local function writeConfig(configName, data)
    local path = configPath(configName)
    FS.writefile(path, encodeJson(data))
end

local function resetConfig(configName)
    writeConfig(configName, {})
    return {}
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

local UI = {}
local Controls = {}
local Tabs = {}
local ActiveTab = nil

local function updateStatus(message)
    if UI and UI.statusLabel then
        UI.statusLabel.Text = message
    end
end

local function applyConfigToControls()
    for key, control in pairs(Controls) do
        local value = configData[key]
        if value == nil then
            value = control.default
        end
        control.set(value)
    end
end

local function captureControlValues()
    local data = {}
    for key, control in pairs(Controls) do
        data[key] = control.get()
    end
    return data
end

local function createConfig(configName)
    currentConfigName = configName
    configData = {}
    writeConfig(currentConfigName, configData)
    syncSettings()
    applyConfigToControls()
    updateStatus("Created config: " .. currentConfigName)
end

local function saveConfig()
    configData = captureControlValues()
    writeConfig(currentConfigName, configData)
    syncSettings()
    updateStatus("Saved config: " .. currentConfigName)
end

local function loadConfig(configName)
    currentConfigName = configName
    configData = readConfig(currentConfigName)
    syncSettings()
    applyConfigToControls()
    updateStatus("Loaded config: " .. currentConfigName)
end

local function resetCurrentConfig()
    configData = resetConfig(currentConfigName)
    applyConfigToControls()
    updateStatus("Reset config: " .. currentConfigName)
end

local function toggleAuto(settingKey)
    settings[settingKey] = not settings[settingKey]
    syncSettings()
end

local function registerControl(id, defaultValue, getter, setter)
    Controls[id] = {
        default = defaultValue,
        get = getter,
        set = setter,
    }
    applyConfigToControls()
end

local function setTabActive(tabName)
    for name, tab in pairs(Tabs) do
        local isActive = name == tabName
        tab.button.BackgroundColor3 = isActive and Color3.fromRGB(255, 176, 68) or Color3.fromRGB(255, 237, 200)
        tab.container.Visible = isActive
    end
    ActiveTab = tabName
end

local function buildUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HoneyLuaUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.fromOffset(500, 360)
    main.Position = UDim2.new(0.5, -250, 0.5, -180)
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
    title.TextXAlignment = Enum.TextXAlignment.Left
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
    configNameBox.Size = UDim2.fromOffset(200, 26)
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

    local autoLoadLabel = Instance.new("TextLabel")
    autoLoadLabel.Size = UDim2.fromOffset(140, 22)
    autoLoadLabel.Position = UDim2.fromOffset(230, 72)
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
    autoLoadToggle.Position = UDim2.fromOffset(230, 96)
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
    autoSaveLabel.Position = UDim2.fromOffset(330, 72)
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
    autoSaveToggle.Position = UDim2.fromOffset(330, 96)
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

    local createButton = makeButton("Create", "Create", 12, 132)
    local saveButton = makeButton("Save", "Save", 114, 132)
    local loadButton = makeButton("Load", "Load", 216, 132)
    local resetButton = makeButton("Reset", "Reset", 318, 132)

    local tabsHolder = Instance.new("Frame")
    tabsHolder.Name = "TabsHolder"
    tabsHolder.Size = UDim2.new(1, -24, 0, 32)
    tabsHolder.Position = UDim2.fromOffset(12, 176)
    tabsHolder.BackgroundTransparency = 1
    tabsHolder.Parent = main

    local tabsLayout = Instance.new("UIListLayout")
    tabsLayout.FillDirection = Enum.FillDirection.Horizontal
    tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabsLayout.Padding = UDim.new(0, 8)
    tabsLayout.Parent = tabsHolder

    local tabContent = Instance.new("Frame")
    tabContent.Name = "TabContent"
    tabContent.Size = UDim2.new(1, -24, 1, -220)
    tabContent.Position = UDim2.fromOffset(12, 216)
    tabContent.BackgroundTransparency = 1
    tabContent.Parent = main

    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

    return {
        screenGui = screenGui,
        mainFrame = main,
        statusLabel = status,
        configNameBox = configNameBox,
        autoLoadToggle = autoLoadToggle,
        autoSaveToggle = autoSaveToggle,
        createButton = createButton,
        saveButton = saveButton,
        loadButton = loadButton,
        resetButton = resetButton,
        tabsHolder = tabsHolder,
        tabContent = tabContent,
    }
end

UI = buildUI()

local function enableDragging(frame, dragHandle)
    local dragging = false
    local dragInput
    local dragStart
    local startPos

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

enableDragging(UI.mainFrame, UI.mainFrame)

local function createTab(tabName)
    if Tabs[tabName] then
        return Tabs[tabName].api
    end

    local tabButton = Instance.new("TextButton")
    tabButton.Name = tabName .. "Tab"
    tabButton.Size = UDim2.fromOffset(96, 28)
    tabButton.BackgroundColor3 = Color3.fromRGB(255, 237, 200)
    tabButton.BorderSizePixel = 0
    tabButton.Font = Enum.Font.GothamBold
    tabButton.TextSize = 14
    tabButton.Text = tabName
    tabButton.TextColor3 = Color3.fromRGB(92, 55, 17)
    tabButton.Parent = UI.tabsHolder

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 8)
    tabCorner.Parent = tabButton

    local container = Instance.new("Frame")
    container.Name = tabName .. "Container"
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1
    container.Visible = false
    container.Parent = UI.tabContent

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.Parent = container

    local function makeLabel(text)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(92, 55, 17)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = text
        label.Size = UDim2.new(1, 0, 0, 18)
        label.Parent = container
        return label
    end

    local function addToggle(options)
        local label = makeLabel(options.label)
        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.fromOffset(120, 28)
        toggle.BackgroundColor3 = Color3.fromRGB(255, 176, 68)
        toggle.BorderSizePixel = 0
        toggle.Font = Enum.Font.GothamBold
        toggle.TextSize = 14
        toggle.TextColor3 = Color3.fromRGB(92, 55, 17)
        toggle.Parent = container

        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(0, 8)
        toggleCorner.Parent = toggle

        local state = options.default or false
        local function applyState(value)
            state = value
            toggle.Text = state and "ON" or "OFF"
        end

        applyState(state)
        toggle.MouseButton1Click:Connect(function()
            applyState(not state)
            if options.onChange then
                options.onChange(state)
            end
        end)

        registerControl(options.id, options.default or false, function()
            return state
        end, function(value)
            applyState(value)
        end)

        return {
            label = label,
            button = toggle,
        }
    end

    local function addButton(options)
        local label = makeLabel(options.label)
        local button = Instance.new("TextButton")
        button.Size = UDim2.fromOffset(140, 28)
        button.BackgroundColor3 = Color3.fromRGB(255, 176, 68)
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamBold
        button.TextSize = 14
        button.TextColor3 = Color3.fromRGB(92, 55, 17)
        button.Text = options.text or "Run"
        button.Parent = container

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 8)
        buttonCorner.Parent = button

        button.MouseButton1Click:Connect(function()
            if options.onClick then
                options.onClick()
            end
        end)

        return {
            label = label,
            button = button,
        }
    end

    local function addSlider(options)
        local label = makeLabel(options.label)
        local sliderFrame = Instance.new("Frame")
        sliderFrame.Size = UDim2.new(1, -40, 0, 28)
        sliderFrame.BackgroundColor3 = Color3.fromRGB(255, 237, 200)
        sliderFrame.BorderSizePixel = 0
        sliderFrame.Parent = container

        local sliderCorner = Instance.new("UICorner")
        sliderCorner.CornerRadius = UDim.new(0, 8)
        sliderCorner.Parent = sliderFrame

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(255, 176, 68)
        fill.BorderSizePixel = 0
        fill.Parent = sliderFrame

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 8)
        fillCorner.Parent = fill

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.fromOffset(40, 28)
        valueLabel.Position = UDim2.new(1, 8, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 14
        valueLabel.TextColor3 = Color3.fromRGB(92, 55, 17)
        valueLabel.Parent = sliderFrame

        local min = options.min or 0
        local max = options.max or 100
        local step = options.step or 1
        local value = options.default or min

        local function setValue(newValue)
            local clamped = math.clamp(newValue, min, max)
            local snapped = math.floor((clamped - min) / step + 0.5) * step + min
            value = snapped
            local alpha = (value - min) / (max - min)
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            valueLabel.Text = tostring(value)
            if options.onChange then
                options.onChange(value)
            end
        end

        sliderFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local mouse = localPlayer:GetMouse()
                local function update()
                    local relative = math.clamp((mouse.X - sliderFrame.AbsolutePosition.X) / sliderFrame.AbsoluteSize.X, 0, 1)
                    setValue(min + (max - min) * relative)
                end
                update()
                local moveConn
                moveConn = UserInputService.InputChanged:Connect(function(moveInput)
                    if moveInput.UserInputType == Enum.UserInputType.MouseMovement then
                        update()
                    end
                end)
                local endConn
                endConn = UserInputService.InputEnded:Connect(function(endInput)
                    if endInput.UserInputType == Enum.UserInputType.MouseButton1 then
                        if moveConn then
                            moveConn:Disconnect()
                        end
                        if endConn then
                            endConn:Disconnect()
                        end
                    end
                end)
            end
        end)

        setValue(value)

        registerControl(options.id, options.default or min, function()
            return value
        end, function(newValue)
            setValue(newValue)
        end)

        return {
            label = label,
            frame = sliderFrame,
        }
    end

    local function addDropdown(options)
        local label = makeLabel(options.label)
        local dropdown = Instance.new("TextButton")
        dropdown.Size = UDim2.fromOffset(180, 28)
        dropdown.BackgroundColor3 = Color3.fromRGB(255, 237, 200)
        dropdown.BorderSizePixel = 0
        dropdown.Font = Enum.Font.Gotham
        dropdown.TextSize = 14
        dropdown.TextColor3 = Color3.fromRGB(92, 55, 17)
        dropdown.Parent = container

        local dropdownCorner = Instance.new("UICorner")
        dropdownCorner.CornerRadius = UDim.new(0, 8)
        dropdownCorner.Parent = dropdown

        local listFrame = Instance.new("Frame")
        listFrame.Size = UDim2.fromOffset(180, 0)
        listFrame.BackgroundColor3 = Color3.fromRGB(255, 237, 200)
        listFrame.BorderSizePixel = 0
        listFrame.Visible = false
        listFrame.Parent = container

        local listCorner = Instance.new("UICorner")
        listCorner.CornerRadius = UDim.new(0, 8)
        listCorner.Parent = listFrame

        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, 4)
        listLayout.Parent = listFrame

        local optionsList = options.items or {}
        local selected = options.default or optionsList[1]

        local function selectItem(item)
            selected = item
            dropdown.Text = tostring(item)
            if options.onChange then
                options.onChange(item)
            end
        end

        dropdown.MouseButton1Click:Connect(function()
            listFrame.Visible = not listFrame.Visible
        end)

        for _, item in ipairs(optionsList) do
            local itemButton = Instance.new("TextButton")
            itemButton.Size = UDim2.fromOffset(170, 24)
            itemButton.BackgroundColor3 = Color3.fromRGB(255, 176, 68)
            itemButton.BorderSizePixel = 0
            itemButton.Font = Enum.Font.Gotham
            itemButton.TextSize = 13
            itemButton.TextColor3 = Color3.fromRGB(92, 55, 17)
            itemButton.Text = tostring(item)
            itemButton.Parent = listFrame

            local itemCorner = Instance.new("UICorner")
            itemCorner.CornerRadius = UDim.new(0, 6)
            itemCorner.Parent = itemButton

            itemButton.MouseButton1Click:Connect(function()
                selectItem(item)
                listFrame.Visible = false
            end)
        end

        listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            listFrame.Size = UDim2.fromOffset(180, listLayout.AbsoluteContentSize.Y + 8)
        end)

        selectItem(selected)

        registerControl(options.id, selected, function()
            return selected
        end, function(value)
            selectItem(value)
        end)

        return {
            label = label,
            dropdown = dropdown,
            list = listFrame,
        }
    end

    local api = {
        AddToggle = addToggle,
        AddButton = addButton,
        AddSlider = addSlider,
        AddDropdown = addDropdown,
    }

    Tabs[tabName] = {
        button = tabButton,
        container = container,
        api = api,
    }

    tabButton.MouseButton1Click:Connect(function()
        setTabActive(tabName)
    end)

    if not ActiveTab then
        setTabActive(tabName)
    end

    return api
end

UI.autoLoadToggle.MouseButton1Click:Connect(function()
    toggleAuto("autoLoad")
    UI.autoLoadToggle.Text = settings.autoLoad and "ON" or "OFF"
    updateStatus("Auto load: " .. (settings.autoLoad and "ON" or "OFF"))
end)

UI.autoSaveToggle.MouseButton1Click:Connect(function()
    toggleAuto("autoSave")
    UI.autoSaveToggle.Text = settings.autoSave and "ON" or "OFF"
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

getgenv().HoneyLuaUI = {
    CreateTab = createTab,
    SaveConfig = saveConfig,
    LoadConfig = loadConfig,
    ResetConfig = resetCurrentConfig,
    CreateConfig = createConfig,
    ListConfigs = listConfigs,
    UI = UI,
}

if RunService:IsStudio() then
    warn("HoneyLua UI loaded in Studio. Use an executor for file APIs.")
end
