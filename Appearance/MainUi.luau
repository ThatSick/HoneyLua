-- HoneyLua Config Manager UI (Executor-ready)
if getgenv().HoneyLuaLoaded then return end
getgenv().HoneyLuaLoaded = true

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local gameId = tostring(game.PlaceId)

local FS = {writefile = writefile, readfile = readfile, isfile = isfile, isfolder = isfolder, makefolder = makefolder, listfiles = listfiles, delfile = delfile}

local function ensureExecutorFS()
    for name, fn in pairs(FS) do
        if type(fn) ~= "function" then if name ~= "delfile" then error("HoneyLua requires executor file APIs. Missing: " .. name) end end
    end
end
ensureExecutorFS()

local ROOT_FOLDER = "HoneyLua"
local GAMES_FOLDER = ROOT_FOLDER .. "/Games"
local CONFIG_FOLDER = GAMES_FOLDER .. "/" .. gameId
local SETTINGS_FILE = ROOT_FOLDER .. "/settings.json"

if not FS.isfolder(ROOT_FOLDER) then FS.makefolder(ROOT_FOLDER) end
if not FS.isfolder(GAMES_FOLDER) then FS.makefolder(GAMES_FOLDER) end
if not FS.isfolder(CONFIG_FOLDER) then FS.makefolder(CONFIG_FOLDER) end

local DEFAULT_SETTINGS = {
    autoLoad = true, autoSave = true, autoSaveInterval = 30,
    uiWidth = 520, uiHeight = 380,
    transparent = false, animatedBg = true, openKey = "RightControl", showMobileBtn = true,
    defaultConfigs = {}
}

local function decodeJson(p, f) local ok, d = pcall(function() return HttpService:JSONDecode(p) end); return (ok and type(d) == "table") and d or f end
local function encodeJson(p) return HttpService:JSONEncode(p) end
local function readSettings() return FS.isfile(SETTINGS_FILE) and decodeJson(FS.readfile(SETTINGS_FILE), DEFAULT_SETTINGS) or DEFAULT_SETTINGS end
local function writeSettings(s) FS.writefile(SETTINGS_FILE, encodeJson(s)) end
local function configPath(n) return CONFIG_FOLDER .. "/" .. n .. ".json" end
local function readConfig(n) local p = configPath(n); return FS.isfile(p) and decodeJson(FS.readfile(p), {}) or {} end
local function writeConfig(n, d) FS.writefile(configPath(n), encodeJson(d)) end
local function resetConfig(n) writeConfig(n, {}); return {} end
local function deleteConfigFile(n) if FS.delfile and FS.isfile(configPath(n)) then pcall(function() FS.delfile(configPath(n)) end) end end

local settings = readSettings()
for k, v in pairs(DEFAULT_SETTINGS) do if settings[k] == nil then settings[k] = v end end
if not settings.defaultConfigs then settings.defaultConfigs = {} end

local currentConfigName = settings.defaultConfigs[gameId] or "default"
local configData = readConfig(currentConfigName)

local function syncSettings() writeSettings(settings) end

local function listConfigs()
    local configs = {}
    if FS.isfolder(CONFIG_FOLDER) then
        for _, fp in ipairs(FS.listfiles(CONFIG_FOLDER)) do
            local name = fp:match("([^/\\]+)%.json$")
            if name then table.insert(configs, name) end
        end
    end
    if #configs == 0 then table.insert(configs, "default") end
    table.sort(configs)
    return configs
end

local UI = {}
local Controls = {}
local Tabs = {}
local TabOrder = {}
local ActiveTab = nil
local CurrentSection = "Main"
local BubbleContainer = nil
local MobileButton = nil

local function updateStatus(msg) if UI and UI.statusLabel then UI.statusLabel.Text = msg end end
local function updateSection(name) CurrentSection = name; if UI and UI.sectionLabel then UI.sectionLabel.Text = "› " .. name end end

local function applyTransparency(on)
    if not UI.mainFrame then return end
    local t1 = on and 0.4 or 0
    local t2 = on and 0.3 or 0
    TweenService:Create(UI.mainFrame, TweenInfo.new(0.3), {BackgroundTransparency = t1}):Play()
    if UI.sidebar then TweenService:Create(UI.sidebar, TweenInfo.new(0.3), {BackgroundTransparency = t2}):Play() end
    if UI.sideClip then TweenService:Create(UI.sideClip, TweenInfo.new(0.3), {BackgroundTransparency = t2}):Play() end
    if UI.contentArea then TweenService:Create(UI.contentArea, TweenInfo.new(0.3), {BackgroundTransparency = t2}):Play() end
end

local function applyAnimatedBg(on)
    if BubbleContainer then BubbleContainer.Visible = on end
end

local function applyMobileBtn(on)
    if MobileButton then MobileButton.Visible = on end
end

local function applyConfigToControls()
    for key, ctrl in pairs(Controls) do
        local val = configData[key]; if val == nil then val = ctrl.default end; ctrl.set(val)
    end
end

local function captureControlValues()
    local data = {}; for key, ctrl in pairs(Controls) do data[key] = ctrl.get() end; return data
end

local function createConfig(n) currentConfigName = n; configData = {}; writeConfig(currentConfigName, configData); syncSettings(); applyConfigToControls(); updateStatus("Created: " .. currentConfigName) end
local function saveConfig() configData = captureControlValues(); writeConfig(currentConfigName, configData); syncSettings(); updateStatus("Saved: " .. currentConfigName) end
local function loadConfig(n) currentConfigName = n; configData = readConfig(currentConfigName); syncSettings(); applyConfigToControls(); updateStatus("Loaded: " .. currentConfigName) end
local function resetCurrentConfig() configData = resetConfig(currentConfigName); applyConfigToControls(); updateStatus("Reset: " .. currentConfigName) end
local function toggleAuto(key) settings[key] = not settings[key]; writeSettings(settings) end
local function registerControl(id, def, getter, setter) Controls[id] = {default = def, get = getter, set = setter}; applyConfigToControls() end

local function setTabActive(tabName)
    for name, tab in pairs(Tabs) do
        local isActive = name == tabName
        local targetBg = isActive and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(50, 40, 30)
        local targetText = isActive and Color3.fromRGB(60, 40, 15) or Color3.fromRGB(200, 170, 120)
        TweenService:Create(tab.button, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundColor3 = targetBg, TextColor3 = targetText}):Play()
        if isActive and not tab.container.Visible then
            tab.container.Visible = true; tab.container.GroupTransparency = 1
            TweenService:Create(tab.container, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {GroupTransparency = 0}):Play()
        elseif not isActive and tab.container.Visible then
            local tw = TweenService:Create(tab.container, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {GroupTransparency = 1})
            tw:Play(); tw.Completed:Connect(function() if ActiveTab ~= name then tab.container.Visible = false end end)
        end
    end
    ActiveTab = tabName
end

local function createAnimatedBackground(parent)
    local bg = Instance.new("Frame")
    bg.Name = "AnimatedBG"; bg.Size = UDim2.new(1, 0, 1, 0); bg.BackgroundTransparency = 1
    bg.ClipsDescendants = true; bg.ZIndex = 1; bg.Parent = parent
    BubbleContainer = bg

    if not settings.animatedBg then bg.Visible = false end

    -- Honey drip effect
    for i = 1, 8 do
        local drip = Instance.new("Frame")
        drip.BackgroundColor3 = Color3.fromRGB(255, 195, 80)
        drip.BackgroundTransparency = 0.75
        drip.BorderSizePixel = 0
        drip.Size = UDim2.new(0, math.random(30, 80), 0, math.random(60, 150))
        drip.Position = UDim2.new(math.random() * 0.9, 0, -0.3, 0)
        drip.ZIndex = 1; drip.Parent = bg
        local dripCorner = Instance.new("UICorner"); dripCorner.CornerRadius = UDim.new(0, 20); dripCorner.Parent = drip
        local dripGrad = Instance.new("UIGradient"); dripGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.7, 0.8), NumberSequenceKeypoint.new(1, 1)}); dripGrad.Rotation = 90; dripGrad.Parent = drip

        task.spawn(function()
            task.wait(i * 0.8)
            while drip and drip.Parent do
                local x = math.random() * 0.85
                drip.Position = UDim2.new(x, 0, -0.4, 0)
                drip.Size = UDim2.new(0, math.random(25, 70), 0, math.random(50, 120))
                local dur = 12 + math.random() * 10
                TweenService:Create(drip, TweenInfo.new(dur, Enum.EasingStyle.Sine), {Position = UDim2.new(x, 0, 1.2, 0)}):Play()
                task.wait(dur)
            end
        end)
    end
    return bg
end

local function buildUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HoneyLuaUI"; screenGui.ResetOnSpawn = false; screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 999999; screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Enabled = true

    local uiW, uiH = settings.uiWidth or 520, settings.uiHeight or 380

    local main = Instance.new("Frame")
    main.Name = "Main"; main.Size = UDim2.fromOffset(uiW, uiH)
    main.Position = UDim2.new(0.5, -uiW/2, 0.5, -uiH/2)
    main.BackgroundColor3 = Color3.fromRGB(25, 22, 18); main.BackgroundTransparency = settings.transparent and 0.3 or 0
    main.BorderSizePixel = 0; main.Parent = screenGui

    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = main
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(255, 190, 80); stroke.Thickness = 2; stroke.Transparency = 0.3; stroke.Parent = main

    createAnimatedBackground(main)

    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"; sidebar.Size = UDim2.new(0, 130, 1, 0); sidebar.Position = UDim2.fromOffset(0, 0)
    sidebar.BackgroundColor3 = Color3.fromRGB(35, 30, 25); sidebar.BackgroundTransparency = settings.transparent and 0.2 or 0
    sidebar.BorderSizePixel = 0; sidebar.ZIndex = 2; sidebar.Parent = main

    local sideCorner = Instance.new("UICorner"); sideCorner.CornerRadius = UDim.new(0, 12); sideCorner.Parent = sidebar
    local sideClip = Instance.new("Frame"); sideClip.Size = UDim2.new(0, 12, 1, 0); sideClip.Position = UDim2.new(1, -12, 0, 0)
    sideClip.BackgroundColor3 = Color3.fromRGB(35, 30, 25); sideClip.BackgroundTransparency = settings.transparent and 0.2 or 0
    sideClip.BorderSizePixel = 0; sideClip.ZIndex = 2; sideClip.Parent = sidebar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 32); title.Position = UDim2.fromOffset(12, 12); title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold; title.TextSize = 16; title.Text = "🍯 HoneyLua"
    title.TextColor3 = Color3.fromRGB(255, 210, 130); title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 3; title.Parent = sidebar

    local tabsHolder = Instance.new("ScrollingFrame")
    tabsHolder.Name = "TabsHolder"; tabsHolder.Size = UDim2.new(1, -16, 1, -55); tabsHolder.Position = UDim2.fromOffset(8, 48)
    tabsHolder.BackgroundTransparency = 1; tabsHolder.ScrollBarThickness = 2; tabsHolder.ScrollBarImageColor3 = Color3.fromRGB(255, 190, 100)
    tabsHolder.ScrollBarImageTransparency = 0.5; tabsHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabsHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y; tabsHolder.ZIndex = 3; tabsHolder.Parent = sidebar

    local tabsLayout = Instance.new("UIListLayout"); tabsLayout.FillDirection = Enum.FillDirection.Vertical
    tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder; tabsLayout.Padding = UDim.new(0, 4); tabsLayout.Parent = tabsHolder

    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"; contentArea.Size = UDim2.new(1, -140, 1, -10); contentArea.Position = UDim2.fromOffset(135, 5)
    contentArea.BackgroundColor3 = Color3.fromRGB(40, 35, 28); contentArea.BackgroundTransparency = settings.transparent and 0.15 or 0
    contentArea.BorderSizePixel = 0; contentArea.ZIndex = 2; contentArea.Parent = main

    local contentCorner = Instance.new("UICorner"); contentCorner.CornerRadius = UDim.new(0, 10); contentCorner.Parent = contentArea

    local header = Instance.new("Frame"); header.Size = UDim2.new(1, 0, 0, 40); header.BackgroundTransparency = 1; header.ZIndex = 3; header.Parent = contentArea

    local sepLabel = Instance.new("TextLabel")
    sepLabel.Size = UDim2.new(1, -20, 0, 20); sepLabel.Position = UDim2.fromOffset(12, 8); sepLabel.BackgroundTransparency = 1
    sepLabel.Font = Enum.Font.GothamBold; sepLabel.TextSize = 14; sepLabel.Text = "› " .. CurrentSection
    sepLabel.TextColor3 = Color3.fromRGB(255, 200, 110); sepLabel.TextXAlignment = Enum.TextXAlignment.Left; sepLabel.ZIndex = 3; sepLabel.Parent = header

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -20, 0, 14); status.Position = UDim2.fromOffset(12, 26); status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham; status.TextSize = 10; status.Text = "Ready."
    status.TextColor3 = Color3.fromRGB(160, 140, 100); status.TextXAlignment = Enum.TextXAlignment.Left; status.ZIndex = 3; status.Parent = header

    local tabContent = Instance.new("Frame")
    tabContent.Name = "TabContent"; tabContent.Size = UDim2.new(1, -10, 1, -50); tabContent.Position = UDim2.fromOffset(5, 45)
    tabContent.BackgroundTransparency = 1; tabContent.ZIndex = 2; tabContent.Parent = contentArea

    local resizeHandle = Instance.new("TextButton")
    resizeHandle.Size = UDim2.fromOffset(14, 14); resizeHandle.Position = UDim2.new(1, -16, 1, -16)
    resizeHandle.BackgroundColor3 = Color3.fromRGB(255, 190, 100); resizeHandle.BackgroundTransparency = 0.5
    resizeHandle.Text = ""; resizeHandle.ZIndex = 10; resizeHandle.Parent = main

    local resizeCorner = Instance.new("UICorner"); resizeCorner.CornerRadius = UDim.new(0, 4); resizeCorner.Parent = resizeHandle

    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(24, 24); closeBtn.Position = UDim2.new(1, -30, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60); closeBtn.Text = "✕"
    closeBtn.TextSize = 14; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.AutoButtonColor = false; closeBtn.ZIndex = 10; closeBtn.Parent = main
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    -- Mobile toggle button (transparent, draggable)
    local mobileBtn = Instance.new("TextButton")
    mobileBtn.Name = "MobileButton"; mobileBtn.Size = UDim2.fromOffset(50, 50)
    mobileBtn.Position = UDim2.new(0, 15, 0.5, -25); mobileBtn.BackgroundColor3 = Color3.fromRGB(255, 190, 80)
    mobileBtn.BackgroundTransparency = 0.3; mobileBtn.Text = "🍯"; mobileBtn.TextSize = 24
    mobileBtn.Font = Enum.Font.GothamBold; mobileBtn.TextColor3 = Color3.fromRGB(80, 50, 20)
    mobileBtn.AutoButtonColor = false; mobileBtn.ZIndex = 999; mobileBtn.Visible = settings.showMobileBtn
    mobileBtn.Parent = screenGui
    Instance.new("UICorner", mobileBtn).CornerRadius = UDim.new(1, 0)
    local mobileBtnStroke = Instance.new("UIStroke"); mobileBtnStroke.Color = Color3.fromRGB(200, 140, 50)
    mobileBtnStroke.Thickness = 2; mobileBtnStroke.Transparency = 0.3; mobileBtnStroke.Parent = mobileBtn
    MobileButton = mobileBtn

    mobileBtn.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)

    -- Mobile button dragging
    local mobileDrag, mobileDragStart, mobileStartPos = false, nil, nil
    mobileBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            mobileDrag = true; mobileDragStart = input.Position; mobileStartPos = mobileBtn.Position
        end
    end)
    mobileBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then mobileDrag = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if mobileDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - mobileDragStart
            mobileBtn.Position = UDim2.new(mobileStartPos.X.Scale, mobileStartPos.X.Offset + delta.X, mobileStartPos.Y.Scale, mobileStartPos.Y.Offset + delta.Y)
        end
    end)

    -- Prompt overlay
    local promptOverlay = Instance.new("Frame")
    promptOverlay.Size = UDim2.new(1, 0, 1, 0); promptOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    promptOverlay.BackgroundTransparency = 0.5; promptOverlay.ZIndex = 100; promptOverlay.Visible = false; promptOverlay.Parent = main
    local promptBox = Instance.new("Frame")
    promptBox.Size = UDim2.fromOffset(280, 120); promptBox.Position = UDim2.new(0.5, -140, 0.5, -60)
    promptBox.BackgroundColor3 = Color3.fromRGB(45, 40, 35); promptBox.ZIndex = 101; promptBox.Parent = promptOverlay
    Instance.new("UICorner", promptBox).CornerRadius = UDim.new(0, 10)
    local promptStroke = Instance.new("UIStroke"); promptStroke.Color = Color3.fromRGB(255, 190, 80); promptStroke.Thickness = 2; promptStroke.Parent = promptBox
    local promptText = Instance.new("TextLabel")
    promptText.Size = UDim2.new(1, -20, 0, 50); promptText.Position = UDim2.fromOffset(10, 10)
    promptText.BackgroundTransparency = 1; promptText.Font = Enum.Font.GothamSemibold; promptText.TextSize = 12
    promptText.TextColor3 = Color3.fromRGB(220, 200, 160); promptText.TextWrapped = true; promptText.ZIndex = 102; promptText.Parent = promptBox
    local promptYes = Instance.new("TextButton")
    promptYes.Size = UDim2.fromOffset(100, 30); promptYes.Position = UDim2.new(0.5, -110, 1, -45)
    promptYes.BackgroundColor3 = Color3.fromRGB(255, 100, 100); promptYes.Text = "Yes"; promptYes.Font = Enum.Font.GothamBold
    promptYes.TextSize = 12; promptYes.TextColor3 = Color3.fromRGB(255, 255, 255); promptYes.ZIndex = 102; promptYes.Parent = promptBox
    Instance.new("UICorner", promptYes).CornerRadius = UDim.new(0, 6)
    local promptNo = Instance.new("TextButton")
    promptNo.Size = UDim2.fromOffset(100, 30); promptNo.Position = UDim2.new(0.5, 10, 1, -45)
    promptNo.BackgroundColor3 = Color3.fromRGB(80, 70, 60); promptNo.Text = "No"; promptNo.Font = Enum.Font.GothamBold
    promptNo.TextSize = 12; promptNo.TextColor3 = Color3.fromRGB(200, 180, 140); promptNo.ZIndex = 102; promptNo.Parent = promptBox
    Instance.new("UICorner", promptNo).CornerRadius = UDim.new(0, 6)

    return {screenGui = screenGui, mainFrame = main, statusLabel = status, sectionLabel = sepLabel, tabsHolder = tabsHolder, tabContent = tabContent, resizeHandle = resizeHandle, sidebar = sidebar, contentArea = contentArea, sideClip = sideClip, mobileBtn = mobileBtn, closeBtn = closeBtn, promptOverlay = promptOverlay, promptText = promptText, promptYes = promptYes, promptNo = promptNo}
end

UI = buildUI()

-- Prompt function
local function showPrompt(text, onYes, onNo)
    UI.promptText.Text = text; UI.promptOverlay.Visible = true
    local yesConn, noConn
    yesConn = UI.promptYes.MouseButton1Click:Connect(function() UI.promptOverlay.Visible = false; yesConn:Disconnect(); noConn:Disconnect(); if onYes then onYes() end end)
    noConn = UI.promptNo.MouseButton1Click:Connect(function() UI.promptOverlay.Visible = false; yesConn:Disconnect(); noConn:Disconnect(); if onNo then onNo() end end)
end

-- Unload function
local function unloadUI()
    getgenv().HoneyLuaLoaded = nil
    if UI.screenGui then UI.screenGui:Destroy() end
end

UI.closeBtn.MouseButton1Click:Connect(function()
    showPrompt("Are you sure you want to unload HoneyLua?", unloadUI)
end)

local function enableDragging(frame, handle)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = frame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function enableResizing(frame, handle)
    local resizing, startSize, startMouse = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true; startMouse = Vector2.new(input.Position.X, input.Position.Y); startSize = frame.Size
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and resizing then
            resizing = false; settings.uiWidth = frame.Size.X.Offset; settings.uiHeight = frame.Size.Y.Offset; writeSettings(settings)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - startMouse
            frame.Size = UDim2.fromOffset(math.clamp(startSize.X.Offset + delta.X, 420, 800), math.clamp(startSize.Y.Offset + delta.Y, 300, 600))
        end
    end)
end

enableDragging(UI.mainFrame, UI.mainFrame)
enableResizing(UI.mainFrame, UI.resizeHandle)

-- Toggle UI visibility (only main frame, not mobile button)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode.Name == settings.openKey then
        UI.mainFrame.Visible = not UI.mainFrame.Visible
    end
end)

-- Intro animation
UI.mainFrame.Size = UDim2.fromOffset(0, 0)
UI.mainFrame.BackgroundTransparency = 1
task.delay(0.1, function()
    local uiW, uiH = settings.uiWidth or 520, settings.uiHeight or 380
    TweenService:Create(UI.mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(uiW, uiH), BackgroundTransparency = settings.transparent and 0.4 or 0}):Play()
end)

local function createTab(tabName, isSettings)
    if Tabs[tabName] then return Tabs[tabName].api end

    local layoutOrder = isSettings and 9999 or (#TabOrder + 1)
    table.insert(TabOrder, tabName)

    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = tabName .. "Tab"; tabBtn.Size = UDim2.new(1, 0, 0, 28)
    tabBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 30); tabBtn.BorderSizePixel = 0
    tabBtn.Font = Enum.Font.GothamSemibold; tabBtn.TextSize = settings.textSize
    tabBtn.Text = tabName; tabBtn.TextColor3 = Color3.fromRGB(200, 170, 120)
    tabBtn.AutoButtonColor = false; tabBtn.ZIndex = 4; tabBtn.LayoutOrder = layoutOrder; tabBtn.Parent = UI.tabsHolder

    local tabCorner = Instance.new("UICorner"); tabCorner.CornerRadius = UDim.new(0, 6); tabCorner.Parent = tabBtn

    tabBtn.MouseEnter:Connect(function()
        if ActiveTab ~= tabName then TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(70, 55, 40)}):Play() end
    end)
    tabBtn.MouseLeave:Connect(function()
        if ActiveTab ~= tabName then TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(50, 40, 30)}):Play() end
    end)

    local container = Instance.new("CanvasGroup")
    container.Name = tabName .. "Container"; container.Size = UDim2.new(1, 0, 1, 0); container.BackgroundTransparency = 1
    container.Visible = false; container.GroupTransparency = 0; container.ZIndex = 2; container.Parent = UI.tabContent

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0); scroll.BackgroundTransparency = 1; scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 190, 100); scroll.ScrollBarImageTransparency = 0.4
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0); scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.ZIndex = 2; scroll.Parent = container

    local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 5); layout.Parent = scroll
    local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 5); pad.PaddingRight = UDim.new(0, 8); pad.PaddingTop = UDim.new(0, 2); pad.Parent = scroll

    local function makeLabel(text)
        local lbl = Instance.new("TextLabel"); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = settings.textSize; lbl.TextColor3 = Color3.fromRGB(180, 155, 110); lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = text; lbl.Size = UDim2.new(1, 0, 0, 14); lbl.ZIndex = 2; lbl.Parent = scroll; return lbl
    end

    local function addSection(name)
        local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 0, 24); f.BackgroundTransparency = 1; f.ZIndex = 2; f.Parent = scroll
        local l = Instance.new("Frame"); l.Size = UDim2.new(0.3, -8, 0, 1); l.Position = UDim2.new(0, 0, 0.5, 0); l.BackgroundColor3 = Color3.fromRGB(100, 85, 60); l.BorderSizePixel = 0; l.ZIndex = 2; l.Parent = f
        local t = Instance.new("TextLabel"); t.Size = UDim2.new(0.4, 0, 1, 0); t.Position = UDim2.new(0.3, 0, 0, 0); t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBold; t.TextSize = 10; t.Text = name; t.TextColor3 = Color3.fromRGB(200, 170, 110); t.ZIndex = 2; t.Parent = f
        local r = Instance.new("Frame"); r.Size = UDim2.new(0.3, -8, 0, 1); r.Position = UDim2.new(0.7, 8, 0.5, 0); r.BackgroundColor3 = Color3.fromRGB(100, 85, 60); r.BorderSizePixel = 0; r.ZIndex = 2; r.Parent = f
        local b = Instance.new("TextButton"); b.Size = UDim2.new(1, 0, 1, 0); b.BackgroundTransparency = 1; b.Text = ""; b.ZIndex = 3; b.Parent = f
        b.MouseButton1Click:Connect(function() updateSection(name) end)
        return f
    end

    local function addText(options)
        local lbl = Instance.new("TextLabel"); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham
        lbl.TextSize = options.size or 10; lbl.TextColor3 = options.color or Color3.fromRGB(150, 130, 100)
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = options.text or ""; lbl.TextWrapped = true
        lbl.Size = UDim2.new(1, 0, 0, options.height or 14); lbl.ZIndex = 2; lbl.Parent = scroll
        return lbl
    end

    local function addToggle(options)
        local row = Instance.new("Frame"); row.Size = UDim2.new(1, 0, 0, 28); row.BackgroundColor3 = Color3.fromRGB(50, 43, 35); row.BorderSizePixel = 0; row.ZIndex = 2; row.Parent = scroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, -60, 1, 0); lbl.Position = UDim2.fromOffset(10, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = settings.textSize; lbl.TextColor3 = Color3.fromRGB(200, 180, 140); lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = options.label; lbl.ZIndex = 3; lbl.Parent = row
        local tf = Instance.new("Frame"); tf.Size = UDim2.fromOffset(38, 18); tf.Position = UDim2.new(1, -48, 0.5, -9); tf.BackgroundColor3 = Color3.fromRGB(70, 60, 45); tf.BorderSizePixel = 0; tf.ZIndex = 3; tf.Parent = row
        Instance.new("UICorner", tf).CornerRadius = UDim.new(1, 0)
        local knob = Instance.new("Frame"); knob.Size = UDim2.fromOffset(14, 14); knob.Position = UDim2.fromOffset(2, 2); knob.BackgroundColor3 = Color3.fromRGB(150, 130, 100); knob.ZIndex = 4; knob.Parent = tf
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
        local state = options.default or false
        local function apply(v, a)
            state = v; local tP = state and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2); local tC = state and Color3.fromRGB(255, 190, 80) or Color3.fromRGB(70, 60, 45); local kC = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 130, 100)
            if a then TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Position = tP, BackgroundColor3 = kC}):Play(); TweenService:Create(tf, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = tC}):Play()
            else knob.Position = tP; knob.BackgroundColor3 = kC; tf.BackgroundColor3 = tC end
        end
        apply(state, false)
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.ZIndex = 5; btn.Parent = row
        btn.MouseButton1Click:Connect(function() apply(not state, true); if options.onChange then options.onChange(state) end end)
        registerControl(options.id, options.default or false, function() return state end, function(v) apply(v, false) end)
        return {row = row}
    end

    local function addButton(options)
        local lbl = makeLabel(options.label)
        local btn = Instance.new("TextButton"); btn.Size = UDim2.fromOffset(120, 26); btn.BackgroundColor3 = Color3.fromRGB(255, 190, 80); btn.BorderSizePixel = 0; btn.Font = Enum.Font.GothamBold; btn.TextSize = settings.textSize; btn.TextColor3 = Color3.fromRGB(40, 30, 15); btn.Text = options.text or "Run"; btn.AutoButtonColor = false; btn.ZIndex = 2; btn.Parent = scroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255, 210, 120)}):Play() end)
        btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255, 190, 80)}):Play() end)
        btn.MouseButton1Click:Connect(function() if options.onClick then options.onClick() end end)
        return {label = lbl, button = btn}
    end

    local function addSlider(options)
        local lbl = makeLabel(options.label .. ": " .. tostring(options.default or options.min or 0))
        local sf = Instance.new("Frame"); sf.Size = UDim2.new(1, -20, 0, 6); sf.BackgroundColor3 = Color3.fromRGB(70, 60, 45); sf.BorderSizePixel = 0; sf.ZIndex = 2; sf.Parent = scroll
        Instance.new("UICorner", sf).CornerRadius = UDim.new(1, 0)
        local fill = Instance.new("Frame"); fill.Size = UDim2.new(0, 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(255, 190, 80); fill.BorderSizePixel = 0; fill.ZIndex = 2; fill.Parent = sf
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
        local thumb = Instance.new("Frame"); thumb.Size = UDim2.fromOffset(14, 14); thumb.Position = UDim2.new(0, -7, 0.5, -7); thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255); thumb.ZIndex = 3; thumb.Parent = sf
        Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
        local min, max, step, value = options.min or 0, options.max or 100, options.step or 1, options.default or options.min or 0
        local function setVal(nv, ut)
            local c = math.clamp(nv, min, max); local s = math.floor((c - min) / step + 0.5) * step + min; value = s
            local a = (value - min) / (max - min); fill.Size = UDim2.new(a, 0, 1, 0); if ut then thumb.Position = UDim2.new(a, -7, 0.5, -7) end
            lbl.Text = options.label .. ": " .. tostring(value); if options.onChange then options.onChange(value) end
        end
        local dragging = false
        local sBtn = Instance.new("TextButton"); sBtn.Size = UDim2.new(1, 0, 1, 14); sBtn.Position = UDim2.fromOffset(0, -7); sBtn.BackgroundTransparency = 1; sBtn.Text = ""; sBtn.ZIndex = 4; sBtn.Parent = sf
        sBtn.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
        UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then local r = math.clamp((i.Position.X - sf.AbsolutePosition.X) / sf.AbsoluteSize.X, 0, 1); setVal(min + (max - min) * r, true) end end)
        setVal(value, true)
        registerControl(options.id, options.default or min, function() return value end, function(v) setVal(v, true) end)
        return {label = lbl, frame = sf}
    end

    local function addDropdown(options)
        local row = Instance.new("Frame"); row.Size = UDim2.new(1, 0, 0, 28); row.BackgroundColor3 = Color3.fromRGB(50, 43, 35); row.BorderSizePixel = 0; row.ZIndex = 2; row.Parent = scroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        
        local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, -170, 1, 0); lbl.Position = UDim2.fromOffset(10, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = settings.textSize; lbl.TextColor3 = Color3.fromRGB(200, 180, 140); lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = options.label; lbl.ZIndex = 3; lbl.Parent = row
        
        local dd = Instance.new("TextButton"); dd.Size = UDim2.fromOffset(150, 22); dd.Position = UDim2.new(1, -160, 0.5, -11); dd.BackgroundColor3 = Color3.fromRGB(55, 48, 38); dd.BorderSizePixel = 0; dd.Font = Enum.Font.Gotham; dd.TextSize = settings.textSize; dd.TextColor3 = Color3.fromRGB(200, 180, 140); dd.AutoButtonColor = false; dd.ZIndex = 5; dd.Parent = row
        Instance.new("UICorner", dd).CornerRadius = UDim.new(0, 6)
        
        local arrow = Instance.new("TextLabel"); arrow.Size = UDim2.fromOffset(16, 22); arrow.Position = UDim2.new(1, -18, 0, 0); arrow.BackgroundTransparency = 1; arrow.Text = "▼"; arrow.TextColor3 = Color3.fromRGB(150, 130, 100); arrow.Font = Enum.Font.GothamBold; arrow.TextSize = 8; arrow.ZIndex = 6; arrow.Parent = dd
        
        -- Dropdown list container
        local lf = Instance.new("Frame")
        lf.Size = UDim2.new(1, 0, 0, 0)
        lf.Position = UDim2.fromOffset(0, 24) -- Positioned below the button
        lf.BackgroundColor3 = Color3.fromRGB(30, 25, 20)
        lf.BorderSizePixel = 0
        lf.ClipsDescendants = true
        lf.Visible = false
        lf.ZIndex = 100
        lf.Parent = dd -- Parent to the button so it moves with it
        Instance.new("UICorner", lf).CornerRadius = UDim.new(0, 8)
        
        -- Border stroke for dropdown list
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 180, 80)
        stroke.Thickness = 1.5
        stroke.Transparency = 0.3
        stroke.Parent = lf
        
        local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 3); ll.Parent = lf
        local lp = Instance.new("UIPadding"); lp.PaddingTop = UDim.new(0, 5); lp.PaddingBottom = UDim.new(0, 5); lp.PaddingLeft = UDim.new(0, 5); lp.PaddingRight = UDim.new(0, 5); lp.Parent = lf
        
        local items, selected, isOpen, itemBtns = options.items or {}, options.default or (options.items or {})[1], false, {}
        
        local function sel(it, silent) 
            selected = it
            dd.Text = "  " .. tostring(it)
            if not silent and options.onChange then options.onChange(it) end 
        end
        
        local function close() 
            if not isOpen then return end
            isOpen = false
            row.ZIndex = 2 -- Reset ZIndex on close
            TweenService:Create(arrow, TweenInfo.new(0.2), {Rotation = 0}):Play()
            TweenService:Create(lf, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
            task.delay(0.2, function() if not isOpen then lf.Visible = false end end) 
        end
        
        local function open() 
            if isOpen then return end
            isOpen = true
            row.ZIndex = 100 -- Set row ZIndex high so list is above other rows
            lf.Visible = true
            lf.Size = UDim2.new(1, 0, 0, 0)
            TweenService:Create(arrow, TweenInfo.new(0.2), {Rotation = 180}):Play()
            TweenService:Create(lf, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, math.min(#items * 26 + 12, 200))}):Play()
            
            for i, b in ipairs(itemBtns) do 
                b.Position = UDim2.new(0, -15, 0, 0)
                b.BackgroundTransparency = 1
                task.delay(i * 0.03, function() 
                    TweenService:Create(b, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0}):Play() 
                end) 
            end 
        end
        
        dd.MouseButton1Click:Connect(function() if isOpen then close() else open() end end)
        
        local function createButtons()
            for _, b in ipairs(itemBtns) do b:Destroy() end
            table.clear(itemBtns)
            for i, it in ipairs(items) do
                local ib = Instance.new("TextButton")
                ib.Size = UDim2.new(1, 0, 0, 22)
                ib.BackgroundColor3 = Color3.fromRGB(50, 42, 35)
                ib.BorderSizePixel = 0
                ib.Font = Enum.Font.Gotham
                ib.TextSize = 11
                ib.TextColor3 = Color3.fromRGB(220, 200, 160)
                ib.Text = tostring(it)
                ib.AutoButtonColor = false
                ib.ZIndex = 101
                ib.Parent = lf
                Instance.new("UICorner", ib).CornerRadius = UDim.new(0, 5)
                ib.MouseEnter:Connect(function() TweenService:Create(ib, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 190, 80), TextColor3 = Color3.fromRGB(30, 25, 15)}):Play() end)
                ib.MouseLeave:Connect(function() TweenService:Create(ib, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(50, 42, 35), TextColor3 = Color3.fromRGB(220, 200, 160)}):Play() end)
                ib.MouseButton1Click:Connect(function() sel(it); close() end)
                table.insert(itemBtns, ib)
            end
        end
        
        createButtons()
        sel(selected, true)
        
        registerControl(options.id, selected, function() return selected end, function(v) sel(v) end)
        
        local dropdownApi = {label = lbl, dropdown = dd, frame = row}
        
        function dropdownApi:SetItems(newItems)
            items = newItems or {}
            createButtons()
            if not table.find(items, selected) then
                sel(items[1] or "None")
            end
            if isOpen then
                TweenService:Create(lf, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, math.min(#items * 26 + 12, 200))}):Play()
            end
        end
        
        function dropdownApi:SetValue(value, silent)
            if table.find(items, value) then
                sel(value, silent)
            end
        end
        
        function dropdownApi:GetValue()
            return selected
        end
        
        function dropdownApi:Refresh()
            createButtons()
        end
        
        return dropdownApi
    end

    local function addKeybind(options)
        local row = Instance.new("Frame"); row.Size = UDim2.new(1, 0, 0, 28); row.BackgroundColor3 = Color3.fromRGB(50, 43, 35); row.BorderSizePixel = 0; row.ZIndex = 2; row.Parent = scroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, -90, 1, 0); lbl.Position = UDim2.fromOffset(10, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = settings.textSize; lbl.TextColor3 = Color3.fromRGB(200, 180, 140); lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = options.label; lbl.ZIndex = 3; lbl.Parent = row
        local keyBtn = Instance.new("TextButton"); keyBtn.Size = UDim2.fromOffset(70, 20); keyBtn.Position = UDim2.new(1, -80, 0.5, -10); keyBtn.BackgroundColor3 = Color3.fromRGB(60, 52, 42); keyBtn.BorderSizePixel = 0; keyBtn.Font = Enum.Font.GothamBold; keyBtn.TextSize = 9; keyBtn.TextColor3 = Color3.fromRGB(255, 200, 120); keyBtn.Text = options.default or "None"; keyBtn.AutoButtonColor = false; keyBtn.ZIndex = 4; keyBtn.Parent = row
        Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 4)
        local currentKey = options.default or "None"
        local listening = false
        keyBtn.MouseButton1Click:Connect(function()
            if listening then return end
            listening = true; keyBtn.Text = "..."
            local conn; conn = UserInputService.InputBegan:Connect(function(input, processed)
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    currentKey = input.KeyCode.Name; keyBtn.Text = currentKey; listening = false; conn:Disconnect()
                    if options.onChange then options.onChange(currentKey) end
                end
            end)
        end)
        return {row = row, getKey = function() return currentKey end, setKey = function(k) currentKey = k; keyBtn.Text = k end}
    end

    local api = {AddToggle = addToggle, AddButton = addButton, AddSlider = addSlider, AddDropdown = addDropdown, AddSection = addSection, AddKeybind = addKeybind, AddText = addText, Container = scroll}
    Tabs[tabName] = {button = tabBtn, container = container, api = api}
    tabBtn.MouseButton1Click:Connect(function() setTabActive(tabName) end)
    if not ActiveTab then setTabActive(tabName) end
    return api
end

local function buildSettingsTab(tabApi)
    local scroll = tabApi.Container

    tabApi.AddSection("Config Manager")
    updateSection("Config Manager")

    -- Config dropdown (on top with high ZIndex)
    local cfgDropRow = Instance.new("Frame"); cfgDropRow.Size = UDim2.new(1, 0, 0, 28); cfgDropRow.BackgroundColor3 = Color3.fromRGB(50, 43, 35); cfgDropRow.BorderSizePixel = 0; cfgDropRow.ZIndex = 60; cfgDropRow.ClipsDescendants = false; cfgDropRow.Parent = scroll
    Instance.new("UICorner", cfgDropRow).CornerRadius = UDim.new(0, 6)
    local cfgDropLbl = Instance.new("TextLabel"); cfgDropLbl.Size = UDim2.fromOffset(50, 28); cfgDropLbl.Position = UDim2.fromOffset(10, 0); cfgDropLbl.BackgroundTransparency = 1; cfgDropLbl.Font = Enum.Font.Gotham; cfgDropLbl.TextSize = 11; cfgDropLbl.TextColor3 = Color3.fromRGB(200, 180, 140); cfgDropLbl.TextXAlignment = Enum.TextXAlignment.Left; cfgDropLbl.Text = "Config"; cfgDropLbl.ZIndex = 61; cfgDropLbl.Parent = cfgDropRow
    local cfgDropBtn = Instance.new("TextButton"); cfgDropBtn.Size = UDim2.new(1, -70, 0, 20); cfgDropBtn.Position = UDim2.fromOffset(60, 4); cfgDropBtn.BackgroundColor3 = Color3.fromRGB(55, 48, 38); cfgDropBtn.BorderSizePixel = 0; cfgDropBtn.Font = Enum.Font.Gotham; cfgDropBtn.TextSize = 10; cfgDropBtn.TextColor3 = Color3.fromRGB(200, 180, 140); cfgDropBtn.AutoButtonColor = false; cfgDropBtn.Text = "  " .. currentConfigName; cfgDropBtn.TextXAlignment = Enum.TextXAlignment.Left; cfgDropBtn.ZIndex = 61; cfgDropBtn.Parent = cfgDropRow
    Instance.new("UICorner", cfgDropBtn).CornerRadius = UDim.new(0, 4)
    local cfgDropArrow = Instance.new("TextLabel"); cfgDropArrow.Size = UDim2.fromOffset(16, 20); cfgDropArrow.Position = UDim2.new(1, -18, 0, 0); cfgDropArrow.BackgroundTransparency = 1; cfgDropArrow.Text = "▼"; cfgDropArrow.TextColor3 = Color3.fromRGB(150, 130, 100); cfgDropArrow.Font = Enum.Font.GothamBold; cfgDropArrow.TextSize = 8; cfgDropArrow.ZIndex = 62; cfgDropArrow.Parent = cfgDropBtn
    local cfgDropList = Instance.new("Frame"); cfgDropList.Size = UDim2.new(1, -70, 0, 0); cfgDropList.Position = UDim2.fromOffset(60, 26); cfgDropList.BackgroundColor3 = Color3.fromRGB(50, 43, 35); cfgDropList.BorderSizePixel = 0; cfgDropList.ClipsDescendants = true; cfgDropList.Visible = false; cfgDropList.ZIndex = 70; cfgDropList.Parent = cfgDropRow
    Instance.new("UICorner", cfgDropList).CornerRadius = UDim.new(0, 6)
    local cfgDropLayout = Instance.new("UIListLayout"); cfgDropLayout.Padding = UDim.new(0, 2); cfgDropLayout.Parent = cfgDropList
    local cfgDropPad = Instance.new("UIPadding"); cfgDropPad.PaddingTop = UDim.new(0, 3); cfgDropPad.PaddingBottom = UDim.new(0, 3); cfgDropPad.PaddingLeft = UDim.new(0, 3); cfgDropPad.PaddingRight = UDim.new(0, 3); cfgDropPad.Parent = cfgDropList
    local cfgDropOpen = false
    local cfgDropItems = {}

    local cfgRow = Instance.new("Frame"); cfgRow.Size = UDim2.new(1, 0, 0, 28); cfgRow.BackgroundColor3 = Color3.fromRGB(50, 43, 35); cfgRow.BorderSizePixel = 0; cfgRow.ZIndex = 2; cfgRow.Parent = scroll
    Instance.new("UICorner", cfgRow).CornerRadius = UDim.new(0, 6)
    local cfgLbl = Instance.new("TextLabel"); cfgLbl.Size = UDim2.fromOffset(50, 28); cfgLbl.Position = UDim2.fromOffset(10, 0); cfgLbl.BackgroundTransparency = 1; cfgLbl.Font = Enum.Font.Gotham; cfgLbl.TextSize = 11; cfgLbl.TextColor3 = Color3.fromRGB(200, 180, 140); cfgLbl.TextXAlignment = Enum.TextXAlignment.Left; cfgLbl.Text = "Name"; cfgLbl.ZIndex = 3; cfgLbl.Parent = cfgRow
    local cfgBox = Instance.new("TextBox"); cfgBox.Size = UDim2.new(1, -70, 0, 20); cfgBox.Position = UDim2.fromOffset(60, 4); cfgBox.BackgroundColor3 = Color3.fromRGB(40, 35, 28); cfgBox.BorderSizePixel = 0; cfgBox.Font = Enum.Font.Gotham; cfgBox.TextSize = 10; cfgBox.TextColor3 = Color3.fromRGB(220, 200, 160); cfgBox.PlaceholderText = "config name..."; cfgBox.PlaceholderColor3 = Color3.fromRGB(120, 105, 80); cfgBox.ClearTextOnFocus = false; cfgBox.Text = currentConfigName; cfgBox.ZIndex = 3; cfgBox.Parent = cfgRow
    Instance.new("UICorner", cfgBox).CornerRadius = UDim.new(0, 4)
    local cfgPad = Instance.new("UIPadding"); cfgPad.PaddingLeft = UDim.new(0, 6); cfgPad.Parent = cfgBox

    local function refreshDropdown()
        for _, c in ipairs(cfgDropItems) do c:Destroy() end
        cfgDropItems = {}
        local configs = listConfigs()
        for _, cfg in ipairs(configs) do
            local ib = Instance.new("TextButton"); ib.Size = UDim2.new(1, 0, 0, 20); ib.BackgroundColor3 = Color3.fromRGB(65, 55, 45); ib.BorderSizePixel = 0; ib.Font = Enum.Font.Gotham; ib.TextSize = 10; ib.TextColor3 = Color3.fromRGB(200, 180, 140); ib.Text = cfg; ib.AutoButtonColor = false; ib.ZIndex = 71; ib.Parent = cfgDropList
            Instance.new("UICorner", ib).CornerRadius = UDim.new(0, 4)
            ib.MouseEnter:Connect(function() TweenService:Create(ib, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 190, 80), TextColor3 = Color3.fromRGB(40, 30, 15)}):Play() end)
            ib.MouseLeave:Connect(function() TweenService:Create(ib, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(65, 55, 45), TextColor3 = Color3.fromRGB(200, 180, 140)}):Play() end)
            ib.MouseButton1Click:Connect(function()
                cfgDropBtn.Text = "  " .. cfg; cfgBox.Text = cfg
                cfgDropOpen = false; cfgDropList.Visible = false
                TweenService:Create(cfgDropArrow, TweenInfo.new(0.2), {Rotation = 0}):Play()
                TweenService:Create(cfgDropList, TweenInfo.new(0.2), {Size = UDim2.new(1, -70, 0, 0)}):Play()
            end)
            table.insert(cfgDropItems, ib)
        end
    end
    refreshDropdown()

    cfgDropBtn.MouseButton1Click:Connect(function()
        if cfgDropOpen then
            cfgDropOpen = false
            TweenService:Create(cfgDropArrow, TweenInfo.new(0.2), {Rotation = 0}):Play()
            TweenService:Create(cfgDropList, TweenInfo.new(0.2), {Size = UDim2.new(1, -70, 0, 0)}):Play()
            task.delay(0.2, function() if not cfgDropOpen then cfgDropList.Visible = false end end)
        else
            refreshDropdown()
            cfgDropOpen = true; cfgDropList.Visible = true; cfgDropList.Size = UDim2.new(1, -70, 0, 0)
            TweenService:Create(cfgDropArrow, TweenInfo.new(0.2), {Rotation = 180}):Play()
            TweenService:Create(cfgDropList, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(1, -70, 0, #listConfigs() * 24 + 8)}):Play()
        end
    end)

    local function makeToggleRow(label, on, key)
        local row = Instance.new("Frame"); row.Size = UDim2.new(1, 0, 0, 28); row.BackgroundColor3 = Color3.fromRGB(50, 43, 35); row.BorderSizePixel = 0; row.ZIndex = 2; row.Parent = scroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, -60, 1, 0); lbl.Position = UDim2.fromOffset(10, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11; lbl.TextColor3 = Color3.fromRGB(200, 180, 140); lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = label; lbl.ZIndex = 3; lbl.Parent = row
        local tf = Instance.new("Frame"); tf.Size = UDim2.fromOffset(38, 18); tf.Position = UDim2.new(1, -48, 0.5, -9); tf.BackgroundColor3 = on and Color3.fromRGB(255, 190, 80) or Color3.fromRGB(70, 60, 45); tf.BorderSizePixel = 0; tf.ZIndex = 3; tf.Parent = row
        Instance.new("UICorner", tf).CornerRadius = UDim.new(1, 0)
        local knob = Instance.new("Frame"); knob.Size = UDim2.fromOffset(14, 14); knob.Position = on and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2); knob.BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 130, 100); knob.ZIndex = 4; knob.Parent = tf
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.ZIndex = 5; btn.Parent = row
        btn.MouseButton1Click:Connect(function()
            settings[key] = not settings[key]; writeSettings(settings); local o = settings[key]
            TweenService:Create(knob, TweenInfo.new(0.2), {Position = o and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2), BackgroundColor3 = o and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 130, 100)}):Play()
            TweenService:Create(tf, TweenInfo.new(0.2), {BackgroundColor3 = o and Color3.fromRGB(255, 190, 80) or Color3.fromRGB(70, 60, 45)}):Play()
            updateStatus(label .. ": " .. (o and "ON" or "OFF"))
        end)
        return row
    end

    makeToggleRow("Auto Load", settings.autoLoad, "autoLoad")
    makeToggleRow("Auto Save", settings.autoSave, "autoSave")

    local actionsRow = Instance.new("Frame"); actionsRow.Size = UDim2.new(1, 0, 0, 28); actionsRow.BackgroundTransparency = 1; actionsRow.ZIndex = 2; actionsRow.Parent = scroll
    local al = Instance.new("UIListLayout"); al.FillDirection = Enum.FillDirection.Horizontal; al.Padding = UDim.new(0, 4); al.Parent = actionsRow

    local function makeBtn(text, w, isRed)
        local baseColor = isRed and Color3.fromRGB(180, 80, 80) or Color3.fromRGB(255, 190, 80)
        local hoverColor = isRed and Color3.fromRGB(220, 100, 100) or Color3.fromRGB(255, 210, 120)
        local textColor = isRed and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(40, 30, 15)
        local btn = Instance.new("TextButton"); btn.Size = UDim2.fromOffset(w or 50, 24); btn.BackgroundColor3 = baseColor; btn.BorderSizePixel = 0; btn.Font = Enum.Font.GothamBold; btn.TextSize = 9; btn.TextColor3 = textColor; btn.Text = text; btn.AutoButtonColor = false; btn.ZIndex = 2
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = hoverColor}):Play() end)
        btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = baseColor}):Play() end)
        return btn
    end

    local createBtn, saveBtn, loadBtn, resetBtn = makeBtn("Create"), makeBtn("Save"), makeBtn("Load"), makeBtn("Reset")
    createBtn.Parent = actionsRow; saveBtn.Parent = actionsRow; loadBtn.Parent = actionsRow; resetBtn.Parent = actionsRow

    local actionsRow2 = Instance.new("Frame"); actionsRow2.Size = UDim2.new(1, 0, 0, 28); actionsRow2.BackgroundTransparency = 1; actionsRow2.ZIndex = 2; actionsRow2.Parent = scroll
    local al2 = Instance.new("UIListLayout"); al2.FillDirection = Enum.FillDirection.Horizontal; al2.Padding = UDim.new(0, 4); al2.Parent = actionsRow2

    local deleteBtn = makeBtn("Delete", 55, true); deleteBtn.Parent = actionsRow2
    local setDefaultBtn = makeBtn("Set Default", 70); setDefaultBtn.Parent = actionsRow2

    createBtn.MouseButton1Click:Connect(function() if cfgBox.Text == "" then updateStatus("Enter a config name.") return end; createConfig(cfgBox.Text); cfgBox.Text = currentConfigName; UI.configLabel.Text = "Current: " .. currentConfigName; cfgDropBtn.Text = "  " .. currentConfigName; refreshDropdown() end)
    saveBtn.MouseButton1Click:Connect(function() saveConfig() end)
    loadBtn.MouseButton1Click:Connect(function() if cfgBox.Text == "" then updateStatus("Enter a config name.") return end; loadConfig(cfgBox.Text); cfgBox.Text = currentConfigName; UI.configLabel.Text = "Current: " .. currentConfigName; cfgDropBtn.Text = "  " .. currentConfigName end)
    resetBtn.MouseButton1Click:Connect(function() resetCurrentConfig() end)
    deleteBtn.MouseButton1Click:Connect(function()
        if cfgBox.Text == "" or cfgBox.Text == "default" then updateStatus("Cannot delete default config.") return end
        showPrompt("Delete config '" .. cfgBox.Text .. "'?", function()
            deleteConfigFile(cfgBox.Text); updateStatus("Deleted: " .. cfgBox.Text)
            if currentConfigName == cfgBox.Text then currentConfigName = "default"; configData = readConfig("default") end
            cfgBox.Text = currentConfigName; UI.configLabel.Text = "Current: " .. currentConfigName; cfgDropBtn.Text = "  " .. currentConfigName; refreshDropdown()
        end)
    end)
    setDefaultBtn.MouseButton1Click:Connect(function()
        if cfgBox.Text == "" then updateStatus("Enter a config name.") return end
        settings.defaultConfigs[gameId] = cfgBox.Text; writeSettings(settings)
        updateStatus("Default set to: " .. cfgBox.Text)
    end)

    tabApi.AddSection("Theme")

    -- Transparent toggle with apply
    local transRow = Instance.new("Frame"); transRow.Size = UDim2.new(1, 0, 0, 28); transRow.BackgroundColor3 = Color3.fromRGB(50, 43, 35); transRow.BorderSizePixel = 0; transRow.ZIndex = 2; transRow.Parent = scroll
    Instance.new("UICorner", transRow).CornerRadius = UDim.new(0, 6)
    local transLbl = Instance.new("TextLabel"); transLbl.Size = UDim2.new(1, -60, 1, 0); transLbl.Position = UDim2.fromOffset(10, 0); transLbl.BackgroundTransparency = 1; transLbl.Font = Enum.Font.Gotham; transLbl.TextSize = 11; transLbl.TextColor3 = Color3.fromRGB(200, 180, 140); transLbl.TextXAlignment = Enum.TextXAlignment.Left; transLbl.Text = "Transparent"; transLbl.ZIndex = 3; transLbl.Parent = transRow
    local transTf = Instance.new("Frame"); transTf.Size = UDim2.fromOffset(38, 18); transTf.Position = UDim2.new(1, -48, 0.5, -9); transTf.BackgroundColor3 = settings.transparent and Color3.fromRGB(255, 190, 80) or Color3.fromRGB(70, 60, 45); transTf.BorderSizePixel = 0; transTf.ZIndex = 3; transTf.Parent = transRow
    Instance.new("UICorner", transTf).CornerRadius = UDim.new(1, 0)
    local transKnob = Instance.new("Frame"); transKnob.Size = UDim2.fromOffset(14, 14); transKnob.Position = settings.transparent and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2); transKnob.BackgroundColor3 = settings.transparent and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 130, 100); transKnob.ZIndex = 4; transKnob.Parent = transTf
    Instance.new("UICorner", transKnob).CornerRadius = UDim.new(1, 0)
    local transBtn = Instance.new("TextButton"); transBtn.Size = UDim2.new(1, 0, 1, 0); transBtn.BackgroundTransparency = 1; transBtn.Text = ""; transBtn.ZIndex = 5; transBtn.Parent = transRow
    transBtn.MouseButton1Click:Connect(function()
        settings.transparent = not settings.transparent; writeSettings(settings); local o = settings.transparent
        TweenService:Create(transKnob, TweenInfo.new(0.2), {Position = o and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2), BackgroundColor3 = o and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 130, 100)}):Play()
        TweenService:Create(transTf, TweenInfo.new(0.2), {BackgroundColor3 = o and Color3.fromRGB(255, 190, 80) or Color3.fromRGB(70, 60, 45)}):Play()
        applyTransparency(o)
        updateStatus("Transparent: " .. (o and "ON" or "OFF"))
    end)

    -- Animated Background toggle with apply
    local animRow = Instance.new("Frame"); animRow.Size = UDim2.new(1, 0, 0, 28); animRow.BackgroundColor3 = Color3.fromRGB(50, 43, 35); animRow.BorderSizePixel = 0; animRow.ZIndex = 2; animRow.Parent = scroll
    Instance.new("UICorner", animRow).CornerRadius = UDim.new(0, 6)
    local animLbl = Instance.new("TextLabel"); animLbl.Size = UDim2.new(1, -60, 1, 0); animLbl.Position = UDim2.fromOffset(10, 0); animLbl.BackgroundTransparency = 1; animLbl.Font = Enum.Font.Gotham; animLbl.TextSize = 11; animLbl.TextColor3 = Color3.fromRGB(200, 180, 140); animLbl.TextXAlignment = Enum.TextXAlignment.Left; animLbl.Text = "Animated BG"; animLbl.ZIndex = 3; animLbl.Parent = animRow
    local animTf = Instance.new("Frame"); animTf.Size = UDim2.fromOffset(38, 18); animTf.Position = UDim2.new(1, -48, 0.5, -9); animTf.BackgroundColor3 = settings.animatedBg and Color3.fromRGB(255, 190, 80) or Color3.fromRGB(70, 60, 45); animTf.BorderSizePixel = 0; animTf.ZIndex = 3; animTf.Parent = animRow
    Instance.new("UICorner", animTf).CornerRadius = UDim.new(1, 0)
    local animKnob = Instance.new("Frame"); animKnob.Size = UDim2.fromOffset(14, 14); animKnob.Position = settings.animatedBg and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2); animKnob.BackgroundColor3 = settings.animatedBg and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 130, 100); animKnob.ZIndex = 4; animKnob.Parent = animTf
    Instance.new("UICorner", animKnob).CornerRadius = UDim.new(1, 0)
    local animBtn = Instance.new("TextButton"); animBtn.Size = UDim2.new(1, 0, 1, 0); animBtn.BackgroundTransparency = 1; animBtn.Text = ""; animBtn.ZIndex = 5; animBtn.Parent = animRow
    animBtn.MouseButton1Click:Connect(function()
        settings.animatedBg = not settings.animatedBg; writeSettings(settings); local o = settings.animatedBg
        TweenService:Create(animKnob, TweenInfo.new(0.2), {Position = o and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2), BackgroundColor3 = o and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 130, 100)}):Play()
        TweenService:Create(animTf, TweenInfo.new(0.2), {BackgroundColor3 = o and Color3.fromRGB(255, 190, 80) or Color3.fromRGB(70, 60, 45)}):Play()
        applyAnimatedBg(o)
        updateStatus("Animated BG: " .. (o and "ON" or "OFF"))
    end)

    local keyRow = Instance.new("Frame"); keyRow.Size = UDim2.new(1, 0, 0, 28); keyRow.BackgroundColor3 = Color3.fromRGB(50, 43, 35); keyRow.BorderSizePixel = 0; keyRow.ZIndex = 2; keyRow.Parent = scroll
    Instance.new("UICorner", keyRow).CornerRadius = UDim.new(0, 6)
    local keyLbl = Instance.new("TextLabel"); keyLbl.Size = UDim2.new(1, -90, 1, 0); keyLbl.Position = UDim2.fromOffset(10, 0); keyLbl.BackgroundTransparency = 1; keyLbl.Font = Enum.Font.Gotham; keyLbl.TextSize = 11; keyLbl.TextColor3 = Color3.fromRGB(200, 180, 140); keyLbl.TextXAlignment = Enum.TextXAlignment.Left; keyLbl.Text = "Open UI Key"; keyLbl.ZIndex = 3; keyLbl.Parent = keyRow
    local keyBtn = Instance.new("TextButton"); keyBtn.Size = UDim2.fromOffset(70, 20); keyBtn.Position = UDim2.new(1, -80, 0.5, -10); keyBtn.BackgroundColor3 = Color3.fromRGB(60, 52, 42); keyBtn.BorderSizePixel = 0; keyBtn.Font = Enum.Font.GothamBold; keyBtn.TextSize = 9; keyBtn.TextColor3 = Color3.fromRGB(255, 200, 120); keyBtn.Text = settings.openKey; keyBtn.AutoButtonColor = false; keyBtn.ZIndex = 4; keyBtn.Parent = keyRow
    Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 4)
    local keyListening = false
    keyBtn.MouseButton1Click:Connect(function()
        if keyListening then return end; keyListening = true; keyBtn.Text = "..."
        local conn; conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                settings.openKey = input.KeyCode.Name; writeSettings(settings); keyBtn.Text = settings.openKey; keyListening = false; conn:Disconnect()
            end
        end)
    end)

    -- Mobile Button toggle
    local mobileRow = Instance.new("Frame"); mobileRow.Size = UDim2.new(1, 0, 0, 28); mobileRow.BackgroundColor3 = Color3.fromRGB(50, 43, 35); mobileRow.BorderSizePixel = 0; mobileRow.ZIndex = 2; mobileRow.Parent = scroll
    Instance.new("UICorner", mobileRow).CornerRadius = UDim.new(0, 6)
    local mobileLbl = Instance.new("TextLabel"); mobileLbl.Size = UDim2.new(1, -60, 1, 0); mobileLbl.Position = UDim2.fromOffset(10, 0); mobileLbl.BackgroundTransparency = 1; mobileLbl.Font = Enum.Font.Gotham; mobileLbl.TextSize = 11; mobileLbl.TextColor3 = Color3.fromRGB(200, 180, 140); mobileLbl.TextXAlignment = Enum.TextXAlignment.Left; mobileLbl.Text = "Mobile Button"; mobileLbl.ZIndex = 3; mobileLbl.Parent = mobileRow
    local mobileTf = Instance.new("Frame"); mobileTf.Size = UDim2.fromOffset(38, 18); mobileTf.Position = UDim2.new(1, -48, 0.5, -9); mobileTf.BackgroundColor3 = settings.showMobileBtn and Color3.fromRGB(255, 190, 80) or Color3.fromRGB(70, 60, 45); mobileTf.BorderSizePixel = 0; mobileTf.ZIndex = 3; mobileTf.Parent = mobileRow
    Instance.new("UICorner", mobileTf).CornerRadius = UDim.new(1, 0)
    local mobileKnob = Instance.new("Frame"); mobileKnob.Size = UDim2.fromOffset(14, 14); mobileKnob.Position = settings.showMobileBtn and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2); mobileKnob.BackgroundColor3 = settings.showMobileBtn and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 130, 100); mobileKnob.ZIndex = 4; mobileKnob.Parent = mobileTf
    Instance.new("UICorner", mobileKnob).CornerRadius = UDim.new(1, 0)
    local mobileBtn = Instance.new("TextButton"); mobileBtn.Size = UDim2.new(1, 0, 1, 0); mobileBtn.BackgroundTransparency = 1; mobileBtn.Text = ""; mobileBtn.ZIndex = 5; mobileBtn.Parent = mobileRow
    mobileBtn.MouseButton1Click:Connect(function()
        settings.showMobileBtn = not settings.showMobileBtn; writeSettings(settings); local o = settings.showMobileBtn
        TweenService:Create(mobileKnob, TweenInfo.new(0.2), {Position = o and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2), BackgroundColor3 = o and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 130, 100)}):Play()
        TweenService:Create(mobileTf, TweenInfo.new(0.2), {BackgroundColor3 = o and Color3.fromRGB(255, 190, 80) or Color3.fromRGB(70, 60, 45)}):Play()
        applyMobileBtn(o)
        updateStatus("Mobile Button: " .. (o and "ON" or "OFF"))
    end)

    UI.configNameBox = cfgBox
end

local settingsTab = createTab("Settings", true)
buildSettingsTab(settingsTab)

if settings.autoLoad and FS.isfile(configPath(currentConfigName)) then loadConfig(currentConfigName)
else updateStatus("Ready. Configs: " .. table.concat(listConfigs(), ", ")) end

if settings.autoSave then
    task.spawn(function()
        while UI and UI.screenGui and UI.screenGui.Parent do
            task.wait(settings.autoSaveInterval or 30)
            if settings.autoSave then saveConfig() end
        end
    end)
end

getgenv().HoneyLuaUI = {CreateTab = createTab, SaveConfig = saveConfig, LoadConfig = loadConfig, ResetConfig = resetCurrentConfig, CreateConfig = createConfig, ListConfigs = listConfigs, SetActiveTab = setTabActive, UpdateSection = updateSection, ShowPrompt = showPrompt, UI = UI}

if RunService:IsStudio() then warn("HoneyLua UI loaded in Studio. Use an executor for file APIs.") end

return getgenv().HoneyLuaUI
