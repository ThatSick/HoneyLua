-- HoneyLua UI demo (loadstring usage)
-- Example:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ThatSick/HoneyLua/main/src/honeylua_ui.lua"))()

local ui = getgenv().HoneyLuaUI
if not ui then
    warn("HoneyLua UI not loaded. Run the UI script first.")
    return
end

local mainTab = ui.CreateTab("Main")

mainTab.AddToggle({
    id = "autoSprint",
    label = "Auto Sprint",
    default = true,
    onChange = function(value)
        print("Auto Sprint:", value)
    end,
})

mainTab.AddButton({
    id = "quickFarm",
    label = "Quick Farm",
    text = "Run",
    onClick = function()
        print("Quick Farm triggered")
    end,
})

mainTab.AddSlider({
    id = "speed",
    label = "Speed",
    min = 10,
    max = 100,
    step = 5,
    default = 30,
    onChange = function(value)
        print("Speed:", value)
    end,
})

mainTab.AddDropdown({
    id = "targetMode",
    label = "Target Mode",
    items = { "Nearest", "Lowest HP", "Highest HP" },
    default = "Nearest",
    onChange = function(value)
        print("Target Mode:", value)
    end,
})

ui.SetActiveTab("Main")
