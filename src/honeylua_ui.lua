-- HoneyLua Config Manager UI (Executor-ready)
-- Loadstring-friendly: exposes getgenv().HoneyLuaUI for adding tabs & controls.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

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
    uiWidth = 560,
    uiHeight = 380,
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
        tab.button.BackgroundColor3 = isActive and Color3.fromRGB(255, 186, 90) or Color3.fromRGB(255, 237, 200)
        tab.button.TextColor3 = isActive and Color3.fromRGB(92, 55, 17) or Color3.fromRGB(124, 82, 30)
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
    main.Size = UDim2.fromOffset(settings.uiWidth or 560, settings.uiHeight or 380)
    main.Position = UDim2.new(0.5, -(settings.uiWidth or 560) / 2, 0.5, -(settings.uiHeight or 380) / 2)
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

    local honeyPattern = Instance.new("TextLabel")
    honeyPattern.Name = "HoneyPattern"
    honeyPattern.Size = UDim2.new(2, 0, 2, 0)
    honeyPattern.Position = UDim2.fromOffset(-200, -160)
    honeyPattern.BackgroundTransparency = 1
    honeyPattern.Font = Enum.Font.GothamBold
    honeyPattern.TextSize = 24
    honeyPattern.TextColor3 = Color3.fromRGB(255, 200, 120)
    honeyPattern.TextTransparency = 0.86
    honeyPattern.Text = ("HONEY "):rep(60)
    honeyPattern.TextWrapped = true
    honeyPattern.Parent = main

    local patternTween = TweenService:Create(
        honeyPattern,
        TweenInfo.new(18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Position = UDim2.fromOffset(-240, -120) }
    )
    patternTween:Play()

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, -24, 0, 26)
    header.Position = UDim2.fromOffset(12, 12)
    header.BackgroundTransparency = 1
    header.Parent = main

    local headerTitle = Instance.new("TextLabel")
    headerTitle.Name = "HeaderTitle"
    headerTitle.Size = UDim2.new(1, 0, 1, 0)
    headerTitle.BackgroundTransparency = 1
    headerTitle.Font = Enum.Font.GothamBold
    headerTitle.TextSize = 20
    headerTitle.Text = "HoneyLua"
    headerTitle.TextColor3 = Color3.fromRGB(92, 55, 17)
    headerTitle.TextXAlignment = Enum.TextXAlignment.Left
    headerTitle.Parent = header

    local tabsHolder = Instance.new("Frame")
    tabsHolder.Name = "TabsHolder"
    tabsHolder.Size = UDim2.fromOffset(120, 290)
    tabsHolder.Position = UDim2.fromOffset(12, 54)
    tabsHolder.BackgroundTransparency = 1
    tabsHolder.Parent = main

    local tabsLayout = Instance.new("UIListLayout")
    tabsLayout.FillDirection = Enum.FillDirection.Vertical
    tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabsLayout.Padding = UDim.new(0, 8)
    tabsLayout.Parent = tabsHolder

    local tabContent = Instance.new("Frame")
    tabContent.Name = "TabContent"
    tabContent.Size = UDim2.new(1, -156, 1, -70)
    tabContent.Position = UDim2.fromOffset(144, 54)
    tabContent.BackgroundTransparency = 1
    tabContent.Parent = main

    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

    return {
        screenGui = screenGui,
        mainFrame = main,
        statusLabel = nil,
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

local function createTab(tabName, layoutOrder)
    if Tabs[tabName] then
        return Tabs[tabName].api
    end

    local tabButton = Instance.new("TextButton")
    tabButton.Name = tabName .. "Tab"
    tabButton.Size = UDim2.fromOffset(120, 30)
    tabButton.BackgroundColor3 = Color3.fromRGB(255, 237, 200)
    tabButton.BorderSizePixel = 0
    tabButton.Font = Enum.Font.GothamBold
    tabButton.TextSize = 14
    tabButton.Text = tabName
    tabButton.TextColor3 = Color3.fromRGB(124, 82, 30)
    tabButton.LayoutOrder = layoutOrder or 1
    tabButton.Parent = UI.tabsHolder

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 10)
    tabCorner.Parent = tabButton

    local tabStroke = Instance.new("UIStroke")
    tabStroke.Color = Color3.fromRGB(236, 191, 122)
    tabStroke.Thickness = 1
    tabStroke.Parent = tabButton

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
        toggle.Size = UDim2.fromOffset(120, 30)
        toggle.BackgroundColor3 = Color3.fromRGB(255, 186, 90)
        toggle.BorderSizePixel = 0
        toggle.Font = Enum.Font.GothamBold
        toggle.TextSize = 13
        toggle.TextColor3 = Color3.fromRGB(92, 55, 17)
        toggle.Parent = container

        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(0, 10)
        toggleCorner.Parent = toggle

        local toggleStroke = Instance.new("UIStroke")
        toggleStroke.Color = Color3.fromRGB(236, 191, 122)
        toggleStroke.Thickness = 1
        toggleStroke.Parent = toggle

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
        button.Size = UDim2.fromOffset(140, 30)
        button.BackgroundColor3 = Color3.fromRGB(255, 186, 90)
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamBold
        button.TextSize = 13
        button.TextColor3 = Color3.fromRGB(92, 55, 17)
        button.Text = options.text or "Run"
        button.Parent = container

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 10)
        buttonCorner.Parent = button

        local buttonStroke = Instance.new("UIStroke")
        buttonStroke.Color = Color3.fromRGB(236, 191, 122)
        buttonStroke.Thickness = 1
        buttonStroke.Parent = button

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
        sliderFrame.Size = UDim2.new(1, -60, 0, 30)
        sliderFrame.BackgroundColor3 = Color3.fromRGB(255, 237, 200)
        sliderFrame.BorderSizePixel = 0
        sliderFrame.Parent = container

        local sliderCorner = Instance.new("UICorner")
        sliderCorner.CornerRadius = UDim.new(0, 10)
        sliderCorner.Parent = sliderFrame

        local sliderStroke = Instance.new("UIStroke")
        sliderStroke.Color = Color3.fromRGB(236, 191, 122)
        sliderStroke.Thickness = 1
        sliderStroke.Parent = sliderFrame

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(255, 186, 90)
        fill.BorderSizePixel = 0
        fill.Parent = sliderFrame

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 10)
        fillCorner.Parent = fill

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.fromOffset(48, 30)
        valueLabel.Position = UDim2.new(1, 8, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 13
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

        local dragging = false

        local function updateFromInput(inputPosition)
            local relative = math.clamp((inputPosition - sliderFrame.AbsolutePosition.X) / sliderFrame.AbsoluteSize.X, 0, 1)
            setValue(min + (max - min) * relative)
        end

        sliderFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                updateFromInput(input.Position.X)
            end
        end)

        sliderFrame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateFromInput(input.Position.X)
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
        dropdown.Size = UDim2.fromOffset(190, 30)
        dropdown.BackgroundColor3 = Color3.fromRGB(255, 237, 200)
        dropdown.BorderSizePixel = 0
        dropdown.Font = Enum.Font.Gotham
        dropdown.TextSize = 13
        dropdown.TextColor3 = Color3.fromRGB(92, 55, 17)
        dropdown.Parent = container

        local dropdownCorner = Instance.new("UICorner")
        dropdownCorner.CornerRadius = UDim.new(0, 10)
        dropdownCorner.Parent = dropdown

        local dropdownStroke = Instance.new("UIStroke")
        dropdownStroke.Color = Color3.fromRGB(236, 191, 122)
        dropdownStroke.Thickness = 1
        dropdownStroke.Parent = dropdown

        local listFrame = Instance.new("Frame")
        listFrame.Size = UDim2.fromOffset(190, 0)
        listFrame.BackgroundColor3 = Color3.fromRGB(255, 237, 200)
        listFrame.BorderSizePixel = 0
        listFrame.Visible = false
        listFrame.Parent = container

        local listCorner = Instance.new("UICorner")
        listCorner.CornerRadius = UDim.new(0, 10)
        listCorner.Parent = listFrame

        local listStroke = Instance.new("UIStroke")
        listStroke.Color = Color3.fromRGB(236, 191, 122)
        listStroke.Thickness = 1
        listStroke.Parent = listFrame

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
            itemButton.Size = UDim2.fromOffset(178, 26)
            itemButton.BackgroundColor3 = Color3.fromRGB(255, 186, 90)
            itemButton.BorderSizePixel = 0
            itemButton.Font = Enum.Font.Gotham
            itemButton.TextSize = 12
            itemButton.TextColor3 = Color3.fromRGB(92, 55, 17)
            itemButton.Text = tostring(item)
            itemButton.Parent = listFrame

            local itemCorner = Instance.new("UICorner")
            itemCorner.CornerRadius = UDim.new(0, 8)
            itemCorner.Parent = itemButton

            itemButton.MouseButton1Click:Connect(function()
                selectItem(item)
                listFrame.Visible = false
            end)
        end

        listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            listFrame.Size = UDim2.fromOffset(190, listLayout.AbsoluteContentSize.Y + 8)
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
        Container = container,
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

local function buildSettingsTab(tabApi)
    local container = tabApi.Container

    local function addSectionLabel(text)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 20)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 15
        label.TextColor3 = Color3.fromRGB(92, 55, 17)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = text
        label.Parent = container
        return label
    end

    local function addRow(labelText, control)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -20, 0, 30)
        row.BackgroundTransparency = 1
        row.Parent = container

        local rowLayout = Instance.new("UIListLayout")
        rowLayout.FillDirection = Enum.FillDirection.Horizontal
        rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rowLayout.Padding = UDim.new(0, 12)
        rowLayout.Parent = row

        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromOffset(150, 30)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(92, 55, 17)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = labelText
        label.Parent = row

        control.Parent = row
        return row
    end

    local configTitle = Instance.new("TextLabel")
    configTitle.Size = UDim2.new(1, 0, 0, 24)
    configTitle.BackgroundTransparency = 1
    configTitle.Font = Enum.Font.GothamBold
    configTitle.TextSize = 18
    configTitle.TextColor3 = Color3.fromRGB(92, 55, 17)
    configTitle.TextXAlignment = Enum.TextXAlignment.Left
    configTitle.Text = "Config Manager"
    configTitle.Parent = container

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 20)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 13
    statusLabel.TextColor3 = Color3.fromRGB(120, 79, 28)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Text = "Loaded config: " .. currentConfigName
    statusLabel.Parent = container

    UI.statusLabel = statusLabel

    addSectionLabel("Config")

    local configNameBox = Instance.new("TextBox")
    configNameBox.Size = UDim2.fromOffset(220, 30)
    configNameBox.BackgroundColor3 = Color3.fromRGB(255, 237, 200)
    configNameBox.BorderSizePixel = 0
    configNameBox.Font = Enum.Font.Gotham
    configNameBox.TextSize = 13
    configNameBox.TextColor3 = Color3.fromRGB(92, 55, 17)
    configNameBox.ClearTextOnFocus = false
    configNameBox.Text = currentConfigName

    local configCorner = Instance.new("UICorner")
    configCorner.CornerRadius = UDim.new(0, 10)
    configCorner.Parent = configNameBox

    local configStroke = Instance.new("UIStroke")
    configStroke.Color = Color3.fromRGB(236, 191, 122)
    configStroke.Thickness = 1
    configStroke.Parent = configNameBox

    addRow("Config Name", configNameBox)

    local autoLoadToggle = Instance.new("TextButton")
    autoLoadToggle.Size = UDim2.fromOffset(120, 30)
    autoLoadToggle.BackgroundColor3 = Color3.fromRGB(255, 186, 90)
    autoLoadToggle.BorderSizePixel = 0
    autoLoadToggle.Font = Enum.Font.GothamBold
    autoLoadToggle.TextSize = 13
    autoLoadToggle.TextColor3 = Color3.fromRGB(92, 55, 17)
    autoLoadToggle.Text = settings.autoLoad and "ON" or "OFF"

    local autoLoadCorner = Instance.new("UICorner")
    autoLoadCorner.CornerRadius = UDim.new(0, 10)
    autoLoadCorner.Parent = autoLoadToggle

    local autoLoadStroke = Instance.new("UIStroke")
    autoLoadStroke.Color = Color3.fromRGB(236, 191, 122)
    autoLoadStroke.Thickness = 1
    autoLoadStroke.Parent = autoLoadToggle

    addRow("Auto Load", autoLoadToggle)

    local autoSaveToggle = Instance.new("TextButton")
    autoSaveToggle.Size = UDim2.fromOffset(120, 30)
    autoSaveToggle.BackgroundColor3 = Color3.fromRGB(255, 186, 90)
    autoSaveToggle.BorderSizePixel = 0
    autoSaveToggle.Font = Enum.Font.GothamBold
    autoSaveToggle.TextSize = 13
    autoSaveToggle.TextColor3 = Color3.fromRGB(92, 55, 17)
    autoSaveToggle.Text = settings.autoSave and "ON" or "OFF"

    local autoSaveCorner = Instance.new("UICorner")
    autoSaveCorner.CornerRadius = UDim.new(0, 10)
    autoSaveCorner.Parent = autoSaveToggle

    local autoSaveStroke = Instance.new("UIStroke")
    autoSaveStroke.Color = Color3.fromRGB(236, 191, 122)
    autoSaveStroke.Thickness = 1
    autoSaveStroke.Parent = autoSaveToggle

    addRow("Auto Save", autoSaveToggle)

    addSectionLabel("Actions")

    local actionsRow = Instance.new("Frame")
    actionsRow.Size = UDim2.new(1, -20, 0, 32)
    actionsRow.BackgroundTransparency = 1
    actionsRow.Parent = container

    local actionsLayout = Instance.new("UIListLayout")
    actionsLayout.FillDirection = Enum.FillDirection.Horizontal
    actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    actionsLayout.Padding = UDim.new(0, 8)
    actionsLayout.Parent = actionsRow

    local function makeActionButton(text)
        local button = Instance.new("TextButton")
        button.Size = UDim2.fromOffset(90, 30)
        button.BackgroundColor3 = Color3.fromRGB(255, 186, 90)
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamBold
        button.TextSize = 13
        button.TextColor3 = Color3.fromRGB(92, 55, 17)
        button.Text = text

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 10)
        buttonCorner.Parent = button

        local buttonStroke = Instance.new("UIStroke")
        buttonStroke.Color = Color3.fromRGB(236, 191, 122)
        buttonStroke.Thickness = 1
        buttonStroke.Parent = button

        return button
    end

    local createButton = makeActionButton("Create")
    local saveButton = makeActionButton("Save")
    local loadButton = makeActionButton("Load")
    local resetButton = makeActionButton("Reset")

    createButton.Parent = actionsRow
    saveButton.Parent = actionsRow
    loadButton.Parent = actionsRow
    resetButton.Parent = actionsRow

    autoLoadToggle.MouseButton1Click:Connect(function()
        toggleAuto("autoLoad")
        autoLoadToggle.Text = settings.autoLoad and "ON" or "OFF"
        updateStatus("Auto load: " .. (settings.autoLoad and "ON" or "OFF"))
    end)

    autoSaveToggle.MouseButton1Click:Connect(function()
        toggleAuto("autoSave")
        autoSaveToggle.Text = settings.autoSave and "ON" or "OFF"
        updateStatus("Auto save: " .. (settings.autoSave and "ON" or "OFF"))
    end)

    createButton.MouseButton1Click:Connect(function()
        local name = configNameBox.Text
        if name == "" then
            updateStatus("Enter a config name.")
            return
        end
        createConfig(name)
        configNameBox.Text = currentConfigName
    end)

    saveButton.MouseButton1Click:Connect(function()
        saveConfig()
    end)

    loadButton.MouseButton1Click:Connect(function()
        local name = configNameBox.Text
        if name == "" then
            updateStatus("Enter a config name.")
            return
        end
        loadConfig(name)
        configNameBox.Text = currentConfigName
    end)

    resetButton.MouseButton1Click:Connect(function()
        resetCurrentConfig()
    end)

    UI.configNameBox = configNameBox
end

local settingsTab = createTab("Settings", 999)
buildSettingsTab(settingsTab)

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

local function setUISize(width, height)
    local clampedWidth = math.clamp(width or settings.uiWidth or 560, 420, 900)
    local clampedHeight = math.clamp(height or settings.uiHeight or 380, 280, 700)
    settings.uiWidth = clampedWidth
    settings.uiHeight = clampedHeight
    syncSettings()
    if UI and UI.mainFrame then
        UI.mainFrame.Size = UDim2.fromOffset(clampedWidth, clampedHeight)
    end
end

getgenv().HoneyLuaUI = {
    CreateTab = createTab,
    SaveConfig = saveConfig,
    LoadConfig = loadConfig,
    ResetConfig = resetCurrentConfig,
    CreateConfig = createConfig,
    ListConfigs = listConfigs,
    SetActiveTab = setTabActive,
    SetSize = setUISize,
    UI = UI,
}

if RunService:IsStudio() then
    warn("HoneyLua UI loaded in Studio. Use an executor for file APIs.")
end
