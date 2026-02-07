-- HoneyLua Notification System
-- Usage: loadstring(game:HttpGet("..."))().Notify({text = "Message", duration = 3})

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- Prevent double loading
--if getgenv().HoneyNotify then return getgenv().HoneyNotify end

local NotifyModule = {}
local notifications = {}
local notifyContainer = nil
local screenGui = nil
local NOTIFY_PADDING = 8
local MAX_NOTIFICATIONS = 5

-- Colors matching HoneyLua theme
local COLORS = {
    background = Color3.fromRGB(45, 40, 35),
    border = Color3.fromRGB(255, 190, 80),
    text = Color3.fromRGB(220, 200, 160),
    progressBg = Color3.fromRGB(60, 52, 42),
    progressFill = Color3.fromRGB(255, 190, 80),
    shadow = Color3.fromRGB(30, 25, 20)
}

-- Adaptive sizing based on screen
local function getAdaptiveSizes()
    local camera = workspace.CurrentCamera
    local viewportSize = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local scale = math.clamp(viewportSize.X / 1920, 0.6, 1.2)
    
    return {
        width = math.floor(280 * scale),
        height = math.floor(55 * scale),
        textSize = math.floor(11 * scale),
        iconSize = math.floor(20 * scale),
        padding = math.floor(8 * scale),
        cornerRadius = math.floor(8 * scale),
        progressHeight = math.floor(4 * scale)
    }
end

local function ensureContainer()
    if notifyContainer and notifyContainer.Parent then return notifyContainer end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HoneyNotifications"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999998
    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
    
    local sizes = getAdaptiveSizes()
    
    local container = Instance.new("Frame")
    container.Name = "NotifyContainer"
    container.Size = UDim2.new(0, sizes.width + 20, 0, 500)
    container.Position = UDim2.new(1, -sizes.width - 30, 1, -20)
    container.AnchorPoint = Vector2.new(0, 1)
    container.BackgroundTransparency = 1
    container.ClipsDescendants = false
    container.Parent = screenGui
    
    -- No UIListLayout - we'll manage positions manually for smooth animations
    
    notifyContainer = container
    return container
end

-- Recalculate and animate all notification positions
local function repositionNotifications()
    local sizes = getAdaptiveSizes()
    local yOffset = 0
    
    for i = #notifications, 1, -1 do
        local notif = notifications[i]
        if notif.frame and notif.frame.Parent then
            local targetY = -yOffset - sizes.height
            TweenService:Create(notif.frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, 1, targetY)
            }):Play()
            yOffset = yOffset + sizes.height + NOTIFY_PADDING
        end
    end
end

local function findExistingNotification(text)
    for _, notif in pairs(notifications) do
        if notif.text == text and notif.frame and notif.frame.Parent then
            return notif
        end
    end
    return nil
end

local function blinkNotification(notif)
    if not notif.frame then return end
    
    -- Use theme-consistent blink color (lighter amber)
    local blinkColor = Color3.fromRGB(255, 230, 160)
    local originalColor = COLORS.background
    
    TweenService:Create(notif.frame, TweenInfo.new(0.08), {BackgroundColor3 = blinkColor}):Play()
    task.delay(0.1, function()
        if notif.frame and notif.frame.Parent then
            TweenService:Create(notif.frame, TweenInfo.new(0.2), {BackgroundColor3 = originalColor}):Play()
        end
    end)

    -- Reset the progress bar
    if notif.progressFill then
        -- Cancel existing tween by setting size directly
        notif.progressFill.Size = UDim2.new(1, 0, 1, 0)
        task.defer(function()
            if notif.progressFill and notif.progressFill.Parent then
                local dur = notif.duration or 3
                TweenService:Create(notif.progressFill, TweenInfo.new(dur, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 1, 0)}):Play()
            end
        end)
    end
end

local function removeNotification(notif)
    if not notif.frame or not notif.frame.Parent then return end
    if notif.removing then return end
    notif.removing = true
    
    local sizes = getAdaptiveSizes()
    local frame = notif.frame
    local stroke = frame:FindFirstChildOfClass("UIStroke")
    
    -- Fade out and slide right animation
    local slideOut = TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = frame.Position + UDim2.new(0, sizes.width + 50, 0, 0),
        BackgroundTransparency = 1
    })
    slideOut:Play()
    
    -- Fade out stroke
    if stroke then
        TweenService:Create(stroke, TweenInfo.new(0.25), {Transparency = 1}):Play()
    end
    
    -- Fade out all text elements
    for _, child in ipairs(frame:GetDescendants()) do
        if child:IsA("TextLabel") then
            TweenService:Create(child, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
        elseif child:IsA("Frame") then
            TweenService:Create(child, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
        end
    end
    
    -- Remove from table first so repositioning ignores this one
    for i, n in ipairs(notifications) do
        if n == notif then
            table.remove(notifications, i)
            break
        end
    end
    
    -- Smoothly reposition remaining notifications
    task.spawn(function()
        task.wait(0.1)
        repositionNotifications()
    end)
    
    -- Destroy after animation completes
    slideOut.Completed:Connect(function()
        frame:Destroy()
    end)
end

-- Global monitor to handle removals reliably
local isMonitoring = false
local function startMonitoring()
    if isMonitoring then return end
    isMonitoring = true
    task.spawn(function()
        while isMonitoring do
            local now = tick()
            for i = #notifications, 1, -1 do
                local notif = notifications[i]
                if now >= notif.removeAt and not notif.removing then
                    removeNotification(notif)
                end
            end
            if #notifications == 0 then
                isMonitoring = false
                break
            end
            task.wait(0.2)
        end
    end)
end

local function createNotification(options)
    local container = ensureContainer()
    local text = options.text or "Notification"
    local duration = options.duration or 3
    local sizes = getAdaptiveSizes()
    
    -- Adaptive text size based on word count
    local wordCount = select(2, text:gsub("%S+", ""))
    local charCount = #text
    local adaptiveTextSize
    if wordCount <= 2 and charCount <= 15 then
        adaptiveTextSize = math.floor(sizes.textSize * 1.4) -- Bigger for short text
    elseif wordCount <= 5 and charCount <= 40 then
        adaptiveTextSize = math.floor(sizes.textSize * 1.15) -- Slightly bigger
    else
        adaptiveTextSize = sizes.textSize -- Normal size for long text
    end
    
    -- Check for existing notification with same text
    local existing = findExistingNotification(text)
    if existing then
        existing.removeAt = tick() + duration
        blinkNotification(existing)
        startMonitoring()
        return existing
    end
    
    -- Limit max notifications
    while #notifications >= MAX_NOTIFICATIONS do
        removeNotification(notifications[1])
        task.wait(0.05)
    end
    
    local notif = {text = text, duration = duration, removeAt = tick() + duration}
    
    -- Calculate Y position based on current notification count
    local slotIndex = #notifications
    local yOffset = 0
    for i = #notifications, 1, -1 do
        yOffset = yOffset + sizes.height + NOTIFY_PADDING
    end
    local targetY = -yOffset - sizes.height
    
    -- Main frame - starts off-screen to the right
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(sizes.width, sizes.height)
    frame.BackgroundColor3 = COLORS.background
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Position = UDim2.new(0, sizes.width + 50, 1, targetY) -- Start off-screen right at correct Y
    frame.Parent = container
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, sizes.cornerRadius)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.border
    stroke.Thickness = 1.5
    stroke.Transparency = 0.8
    stroke.Parent = frame
    
    -- Honey icon (starts small and transparent)
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.fromOffset(sizes.height - 10, sizes.height - 10)
    icon.Position = UDim2.fromOffset(sizes.padding, 5)
    icon.BackgroundTransparency = 1
    icon.Text = "🍯"
    icon.TextSize = 1
    icon.TextTransparency = 1
    icon.Font = Enum.Font.GothamBold
    icon.TextColor3 = COLORS.border
    icon.Parent = frame
    
    -- Text label (starts transparent)
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -(sizes.height + sizes.padding), 1, -sizes.progressHeight - 10)
    textLabel.Position = UDim2.fromOffset(sizes.height + 2, 5)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextSize = adaptiveTextSize
    textLabel.TextTransparency = 1
    textLabel.Font = Enum.Font.GothamSemibold
    textLabel.TextColor3 = COLORS.text
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Center
    textLabel.TextWrapped = true
    textLabel.TextTruncate = Enum.TextTruncate.AtEnd
    textLabel.Parent = frame
    
    -- Progress bar background
    local progressBg = Instance.new("Frame")
    progressBg.Size = UDim2.new(1, -sizes.padding * 2, 0, sizes.progressHeight)
    progressBg.Position = UDim2.new(0, sizes.padding, 1, -sizes.padding - sizes.progressHeight + 2)
    progressBg.BackgroundColor3 = COLORS.progressBg
    progressBg.BackgroundTransparency = 0.5
    progressBg.BorderSizePixel = 0
    progressBg.Parent = frame
    
    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(1, 0)
    progressCorner.Parent = progressBg
    
    -- Progress bar fill
    local progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.new(1, 0, 1, 0)
    progressFill.BackgroundColor3 = COLORS.progressFill
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = progressFill
    
    -- Gradient on progress fill
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 210, 120)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 60))
    })
    gradient.Parent = progressFill
    
    notif.frame = frame
    notif.progressFill = progressFill
    table.insert(notifications, notif)
    
    -- Animation sequence
    task.defer(function()
        -- Slide in from right to correct position
        TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 1, targetY),
            BackgroundTransparency = 0
        }):Play()
        
        -- Fade in stroke (glow effect)
        TweenService:Create(stroke, TweenInfo.new(0.3), {
            Transparency = 0.3
        }):Play()
        
        -- Icon pop in
        task.delay(0.15, function()
            if icon and icon.Parent then
                TweenService:Create(icon, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    TextSize = sizes.iconSize,
                    TextTransparency = 0
                }):Play()
            end
        end)
        
        -- Text fade in
        task.delay(0.2, function()
            if textLabel and textLabel.Parent then
                TweenService:Create(textLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    TextTransparency = 0
                }):Play()
            end
        end)
        
        -- Progress bar fade in
        task.delay(0.25, function()
            if progressBg and progressBg.Parent then
                TweenService:Create(progressBg, TweenInfo.new(0.2), {
                    BackgroundTransparency = 0
                }):Play()
            end
        end)
    end)
    
    -- Start monitoring removals
    startMonitoring()
    
    return notif
end

function NotifyModule.Notify(options)
    if type(options) == "string" then
        options = {text = options}
    end
    return createNotification(options)
end

function NotifyModule.Clear()
    for _, notif in ipairs(notifications) do
        removeNotification(notif)
    end
end

getgenv().HoneyNotify = NotifyModule
return NotifyModule
