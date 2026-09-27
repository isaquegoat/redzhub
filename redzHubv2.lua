--[[
    ============================================================
    redz Hub v2  |  by tsread
    Loader modular (single file) para executors mobile
    Compatível com: Delta, Arceus X, Fluxus Mobile, Hydrogen, etc.
    ============================================================
]]

--// Serviços
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

--// Detecta ambiente seguro (CoreGui vs PlayerGui)
local GUI_PARENT
do
    local ok = pcall(function()
        if CoreGui:FindFirstChild("redzHubv2") then
            CoreGui.redzHubv2:Destroy()
        end
        local test = Instance.new("ScreenGui")
        test.Parent = CoreGui
        test:Destroy()
        GUI_PARENT = CoreGui
    end)
    if not ok then
        GUI_PARENT = LocalPlayer:WaitForChild("PlayerGui")
    end
end

--// ============================================================
--// MÓDULO: Config
--// ============================================================
local Config = {}

Config.HubName = "redz Hub v2"
Config.Author  = "by tsread"

Config.Theme = {
    Background      = Color3.fromRGB(15, 15, 15),
    Sidebar         = Color3.fromRGB(20, 20, 20),
    Panel           = Color3.fromRGB(25, 25, 25),
    Element         = Color3.fromRGB(32, 32, 32),
    ElementHover    = Color3.fromRGB(44, 44, 44),
    Accent          = Color3.fromRGB(220, 30, 40),
    AccentDark      = Color3.fromRGB(160, 20, 30),
    Text            = Color3.fromRGB(240, 240, 240),
    TextDim         = Color3.fromRGB(150, 150, 150),
    Border          = Color3.fromRGB(45, 45, 45),
    ToggleOff       = Color3.fromRGB(48, 48, 48),
    ToggleOn        = Color3.fromRGB(220, 30, 40),
    Font            = Enum.Font.Gotham,
    FontMedium      = Enum.Font.GothamMedium,
    FontBold        = Enum.Font.GothamBold,
}

Config.UI = {
    Size         = UDim2.new(0, 620, 0, 420),
    Transparency = 0.08,
    Scale        = 1.0,
    CornerRadius = 10,
    SidebarWidth = 140,
    TopBarHeight = 42,
}

Config.FarmChest = { MaxDistance = 180, MoveSpeed = 60 }

Config.Weapons   = { "Melee", "Sword", "Blox Fruit", "Gun" }
Config.Materials = { "Leather", "Scrap Metal", "Cloth", "Wood", "Stone", "Iron", "Gold", "Crystal" }
Config.Bosses    = { "All Bosses", "Boss1", "Boss2", "Boss3" }
Config.Locations = { "Spawn", "Home", "Shop", "Boss Area", "Sea", "Dungeon", "Arena" }
Config.LocationCFrames = {
    Spawn         = CFrame.new(0, 10, 0),
    Home          = CFrame.new(0, 5, 0),
    Shop          = CFrame.new(100, 10, 100),
    ["Boss Area"] = CFrame.new(500, 10, 500),
    Sea           = CFrame.new(0, 5, 1000),
    Dungeon       = CFrame.new(-500, 10, -500),
    Arena         = CFrame.new(250, 10, 250),
}
Config.Fruits = { "Rocket", "Spin", "Chop", "Spring", "Bomb", "Smoke", "Flame", "Ice", "Sand", "Dark" }
Config.Skills = { "Z", "X", "C", "V", "F" }

--// ============================================================
--// MÓDULO: Utility
--// ============================================================
local Utility = {}

function Utility.Create(className, props)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

function Utility.Corner(parent, radius)
    return Utility.Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 6),
        Parent = parent,
    })
end

function Utility.Stroke(parent, color, thickness, transparency)
    return Utility.Create("UIStroke", {
        Color = color or Config.Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

function Utility.List(parent, padding, sortOrder)
    return Utility.Create("UIListLayout", {
        Padding = UDim.new(0, padding or 4),
        SortOrder = sortOrder or Enum.SortOrder.LayoutOrder,
        Parent = parent,
    })
end

function Utility.Tween(obj, time, props)
    local t = TweenService:Create(
        obj,
        TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

function Utility.GetHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Utility.GetHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

function Utility.Distance(a, b)
    if not a or not b then return math.huge end
    return (a.Position - b.Position).Magnitude
end

--// ============================================================
--// MÓDULO: StateManager
--// ============================================================
local StateManager = { _state = {}, _listeners = {} }

function StateManager:Get(key, default)
    local v = self._state[key]
    if v == nil then return default end
    return v
end

function StateManager:Set(key, value)
    local old = self._state[key]
    if old == value then return end
    self._state[key] = value
    local listeners = self._listeners[key]
    if listeners then
        for _, fn in ipairs(listeners) do
            task.spawn(fn, value, old)
        end
    end
end

function StateManager:OnChange(key, fn)
    self._listeners[key] = self._listeners[key] or {}
    table.insert(self._listeners[key], fn)
end

--// ============================================================
--// MÓDULO: ConnectionManager
--// ============================================================
local ConnectionManager = {
    _connections = {},
    _threads     = {},
    _running     = {},
}

function ConnectionManager:Track(name, connection)
    self._connections[name] = self._connections[name] or {}
    table.insert(self._connections[name], connection)
    return connection
end

function ConnectionManager:IsRunning(name)
    return self._running[name] == true
end

function ConnectionManager:Start(name, loopFn, delay)
    if self._running[name] then return end
    self._running[name] = true
    local d = delay or 0.15
    local thread = task.spawn(function()
        while self._running[name] do
            local ok, err = pcall(loopFn)
            if not ok then
                warn(("[redzHub] %s: %s"):format(name, tostring(err)))
            end
            task.wait(d)
        end
    end)
    self._threads[name] = thread
end

function ConnectionManager:Stop(name)
    self._running[name] = false
    if self._connections[name] then
        for _, c in ipairs(self._connections[name]) do
            if typeof(c) == "RBXScriptConnection" and c.Connected then
                c:Disconnect()
            end
        end
        self._connections[name] = nil
    end
    local t = self._threads[name]
    if t and coroutine.status(t) ~= "dead" then
        pcall(task.cancel, t)
    end
    self._threads[name] = nil
end

function ConnectionManager:StopAll()
    for name in pairs(self._running) do
        self:Stop(name)
    end
end
