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
--// ============================================================
--// MÓDULO: HubController
--// ============================================================
local HubController = { _systems = {} }

function HubController:Register(name, module)
    self._systems[name] = module
end

function HubController:Start(name, ...)
    local sys = self._systems[name]
    if not sys then
        warn("[redzHub] Sistema não registrado: " .. tostring(name))
        return
    end
    if ConnectionManager:IsRunning(name) then return end
    if sys.Start then sys.Start(...) end
end

function HubController:Stop(name)
    local sys = self._systems[name]
    if sys and sys.Stop then sys.Stop() end
    ConnectionManager:Stop(name)
end

function HubController:IsRunning(name)
    return ConnectionManager:IsRunning(name)
end

function HubController:StopAll()
    for name in pairs(self._systems) do
        self:Stop(name)
    end
end

--// ============================================================
--// MÓDULO: Section (componente)
--// ============================================================
local Section = {}

function Section.Create(parent, text)
    return Utility.Create("TextLabel", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Font = Config.Theme.FontBold,
        Text = text,
        TextColor3 = Config.Theme.Accent,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

--// ============================================================
--// MÓDULO: Button (componente)
--// ============================================================
local Button = {}

function Button.Create(parent, name, callback)
    local btn = Utility.Create("TextButton", {
        Parent = parent,
        BackgroundColor3 = Config.Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 28),
        Font = Config.Theme.FontBold,
        Text = name,
        TextColor3 = Config.Theme.Text,
        TextSize = 11,
        AutoButtonColor = false,
    })
    Utility.Corner(btn, 6)
    btn.MouseEnter:Connect(function()
        Utility.Tween(btn, 0.12, { BackgroundColor3 = Config.Theme.AccentDark })
    end)
    btn.MouseLeave:Connect(function()
        Utility.Tween(btn, 0.12, { BackgroundColor3 = Config.Theme.Accent })
    end)
    btn.MouseButton1Click:Connect(function()
        if callback then task.spawn(callback) end
    end)
    return btn
end

--// ============================================================
--// MÓDULO: Toggle (componente)
--// ============================================================
local Toggle = {}

function Toggle.Create(parent, key, default, callback)
    local state = StateManager:Get(key, default or false)

    local btn = Utility.Create("TextButton", {
        Parent = parent,
        BackgroundColor3 = Config.Theme.Element,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 28),
        Text = "",
        AutoButtonColor = false,
        Name = key,
    })
    Utility.Corner(btn, 6)
    Utility.Stroke(btn, Config.Theme.Border, 1, 0.6)

    Utility.Create("TextLabel", {
        Parent = btn,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -50, 1, 0),
        Font = Config.Theme.FontMedium,
        Text = key,
        TextColor3 = Config.Theme.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local sw = Utility.Create("Frame", {
        Parent = btn,
        BackgroundColor3 = state and Config.Theme.ToggleOn or Config.Theme.ToggleOff,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -42, 0.5, -8),
        Size = UDim2.new(0, 34, 0, 16),
    })
    Utility.Corner(sw, 8)

    local knob = Utility.Create("Frame", {
        Parent = sw,
        BackgroundColor3 = Color3.fromRGB(240, 240, 240),
        BorderSizePixel = 0,
        Position = state and UDim2.new(1, -16, 0, 2) or UDim2.new(0, 2, 0, 2),
        Size = UDim2.new(0, 12, 0, 12),
    })
    Utility.Corner(knob, 6)

    local function updateVisual()
        Utility.Tween(sw, 0.15, {
            BackgroundColor3 = state and Config.Theme.ToggleOn or Config.Theme.ToggleOff
        })
        Utility.Tween(knob, 0.15, {
            Position = state and UDim2.new(1, -16, 0, 2) or UDim2.new(0, 2, 0, 2)
        })
    end

    local function setValue(val)
        state = val
        StateManager:Set(key, val)
        updateVisual()
        if callback then task.spawn(callback, val) end
    end

    btn.MouseButton1Click:Connect(function()
        setValue(not state)
    end)
    btn.MouseEnter:Connect(function()
        Utility.Tween(btn, 0.12, { BackgroundColor3 = Config.Theme.ElementHover })
    end)
    btn.MouseLeave:Connect(function()
        Utility.Tween(btn, 0.12, { BackgroundColor3 = Config.Theme.Element })
    end)

    if state and callback then
        task.defer(function() task.spawn(callback, true) end)
    end

    return { Instance = btn, Set = setValue, Get = function() return state end }
end

--// ============================================================
--// MÓDULO: Dropdown (componente)
--// ============================================================
local Dropdown = {}

function Dropdown.Create(parent, key, options, callback)
    local selectedValue = StateManager:Get(key, nil)

    local container = Utility.Create("Frame", {
        Parent = parent,
        BackgroundColor3 = Config.Theme.Element,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 28),
        ClipsDescendants = false,
        Name = key,
    })
    Utility.Corner(container, 6)
    Utility.Stroke(container, Config.Theme.Border, 1, 0.6)

    local btn = Utility.Create("TextButton", {
        Parent = container,
        BackgroundColor3 = Config.Theme.Element,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
        AutoButtonColor = false,
    })
    Utility.Corner(btn, 6)

    Utility.Create("TextLabel", {
        Parent = btn, BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0.5, 0, 1, 0),
        Font = Config.Theme.FontMedium, Text = key,
        TextColor3 = Config.Theme.Text, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local sel = Utility.Create("TextLabel", {
        Parent = btn, BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -20, 1, 0),
        Font = Config.Theme.Font, Text = selectedValue or "Select...",
        TextColor3 = selectedValue and Config.Theme.Text or Config.Theme.TextDim,
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right,
    })

    local arrow = Utility.Create("TextLabel", {
        Parent = btn, BackgroundTransparency = 1,
        Position = UDim2.new(1, -20, 0, 0), Size = UDim2.new(0, 20, 1, 0),
        Font = Config.Theme.FontBold, Text = "▼",
        TextColor3 = Config.Theme.TextDim, TextSize = 8,
    })

    local list = Utility.Create("Frame", {
        Parent = container,
        BackgroundColor3 = Config.Theme.Sidebar,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, 2),
        Size = UDim2.new(1, 0, 0, math.min(#options, 6) * 22 + 6),
        Visible = false,
        ZIndex = 10,
    })
    Utility.Corner(list, 6)
    Utility.Stroke(list, Config.Theme.Border, 1, 0.4)
    Utility.List(list, 1)
    Utility.Create("UIPadding", {
        Parent = list,
        PaddingTop = UDim.new(0, 3),
        PaddingBottom = UDim.new(0, 3),
        PaddingLeft = UDim.new(0, 3),
        PaddingRight = UDim.new(0, 3),
    })

    local open = false
    btn.MouseButton1Click:Connect(function()
        open = not open
        list.Visible = open
        Utility.Tween(arrow, 0.15, { Rotation = open and 180 or 0 })
    end)

    for _, opt in ipairs(options) do
        local optBtn = Utility.Create("TextButton", {
            Parent = list,
            BackgroundColor3 = Config.Theme.Element,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 20),
            Font = Config.Theme.Font,
            Text = "  " .. opt,
            TextColor3 = Config.Theme.Text,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
        })
        Utility.Corner(optBtn, 4)
        optBtn.MouseEnter:Connect(function()
            Utility.Tween(optBtn, 0.1, { BackgroundColor3 = Config.Theme.AccentDark })
        end)
        optBtn.MouseLeave:Connect(function()
            Utility.Tween(optBtn, 0.1, { BackgroundColor3 = Config.Theme.Element })
        end)
        optBtn.MouseButton1Click:Connect(function()
            sel.Text = opt
            sel.TextColor3 = Config.Theme.Text
            open = false
            list.Visible = false
            Utility.Tween(arrow, 0.15, { Rotation = 0 })
            StateManager:Set(key, opt)
            if callback then task.spawn(callback, opt) end
        end)
    end

    return { Instance = container, Get = function() return StateManager:Get(key) end }
end

--// ============================================================
--// MÓDULO: Slider (componente)
--// ============================================================
local Slider = {}

function Slider.Create(parent, key, minV, maxV, default, callback)
    local value = StateManager:Get(key, default or minV)

    local container = Utility.Create("Frame", {
        Parent = parent,
        BackgroundColor3 = Config.Theme.Element,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 32),
        Name = key,
    })
    Utility.Corner(container, 6)
    Utility.Stroke(container, Config.Theme.Border, 1, 0.6)

    Utility.Create("TextLabel", {
        Parent = container, BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 2), Size = UDim2.new(0.7, 0, 0, 14),
        Font = Config.Theme.FontMedium, Text = key,
        TextColor3 = Config.Theme.Text, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local valLbl = Utility.Create("TextLabel", {
        Parent = container, BackgroundTransparency = 1,
        Position = UDim2.new(0.7, 0, 0, 2), Size = UDim2.new(0.3, -10, 0, 14),
        Font = Config.Theme.FontBold, Text = tostring(value),
        TextColor3 = Config.Theme.Accent, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local track = Utility.Create("Frame", {
        Parent = container,
        BackgroundColor3 = Config.Theme.ToggleOff,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 1, -12),
        Size = UDim2.new(1, -20, 0, 4),
    })
    Utility.Corner(track, 2)

    local fill = Utility.Create("Frame", {
        Parent = track,
        BackgroundColor3 = Config.Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new((value - minV) / (maxV - minV), 0, 1, 0),
    })
    Utility.Corner(fill, 2)

    local dragging = false
    local function updateFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = math.floor(minV + (maxV - minV) * rel + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        valLbl.Text = tostring(v)
        StateManager:Set(key, v)
        if callback then task.spawn(callback, v) end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return { Instance = container, Get = function() return StateManager:Get(key) end }
end

--// ============================================================
--// MÓDULO: Sidebar
--// ============================================================
local Sidebar = {}

function Sidebar.Create(parent, categories, onSelect)
    local sidebar = Utility.Create("Frame", {
        Name = "Sidebar",
        Parent = parent,
        BackgroundColor3 = Config.Theme.Sidebar,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Size = UDim2.new(0, Config.UI.SidebarWidth, 1, -Config.UI.TopBarHeight),
        Position = UDim2.new(0, 0, 0, Config.UI.TopBarHeight),
    })

    Utility.Create("Frame", {
        Parent = sidebar,
        BackgroundColor3 = Config.Theme.Border,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
    })

    local scroll = Utility.Create("ScrollingFrame", {
        Parent = sidebar,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 6, 0, 8),
        Size = UDim2.new(1, -12, 1, -16),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Config.Theme.Accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    Utility.List(scroll, 2)

    local buttons = {}
    local selected

    for _, name in ipairs(categories) do
        local btn = Utility.Create("TextButton", {
            Parent = scroll,
            BackgroundColor3 = Config.Theme.Element,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 26),
            Font = Config.Theme.FontMedium,
            Text = "  " .. name,
            TextColor3 = Config.Theme.TextDim,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
            Name = name,
        })
        Utility.Corner(btn, 5)

        local indicator = Utility.Create("Frame", {
            Parent = btn,
            BackgroundColor3 = Config.Theme.Accent,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 2, 0.6, 0),
            Position = UDim2.new(0, 0, 0.2, 0),
            Visible = false,
            Name = "Indicator",
        })
        Utility.Corner(indicator, 2)

        btn.MouseEnter:Connect(function()
            if selected ~= name then
                Utility.Tween(btn, 0.12, {
                    BackgroundTransparency = 0.6,
                    TextColor3 = Config.Theme.Text,
                })
            end
        end)
        btn.MouseLeave:Connect(function()
            if selected ~= name then
                Utility.Tween(btn, 0.12, {
                    BackgroundTransparency = 1,
                    TextColor3 = Config.Theme.TextDim,
                })
            end
        end)
        btn.MouseButton1Click:Connect(function()
            if selected == name then return end
            selected = name
            for _, other in ipairs(buttons) do
                other.BackgroundTransparency = 1
                other.TextColor3 = Config.Theme.TextDim
                other.Indicator.Visible = false
            end
            btn.BackgroundTransparency = 0.4
            btn.TextColor3 = Config.Theme.Text
            indicator.Visible = true
            if onSelect then onSelect(name) end
        end)

        buttons[#buttons + 1] = btn
    end

    return { Frame = sidebar, Buttons = buttons }
end

--// ============================================================
--// MÓDULO: MainUI
--// ============================================================
local MainUI = {}

local CATEGORIES = {
    "Info & Server", "Tab Farming", "Stack Farm", "Farm Mastery",
    "Sea Event", "Upgrade V4", "Dojo & Drago Race", "Get Item & Upgrade",
    "Raid & Fruit", "Local Player", "Local Shop", "Stats & ESP",
    "Tab Teleport", "Setting & UI",
}

function MainUI.Build()
    local ScreenGui = Utility.Create("ScreenGui", {
        Name = "redzHubv2",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        Parent = GUI_PARENT,
    })

    local Main = Utility.Create("Frame", {
        Name = "Main",
        Parent = ScreenGui,
        BackgroundColor3 = Config.Theme.Background,
        BackgroundTransparency = Config.UI.Transparency,
        BorderSizePixel = 0,
        Size = Config.UI.Size,
        Position = UDim2.new(0.5, -Config.UI.Size.X.Offset / 2, 0.5, -Config.UI.Size.Y.Offset / 2),
        Active = true,
        Draggable = true,
    })
    Utility.Corner(Main, Config.UI.CornerRadius)
    Utility.Stroke(Main, Config.Theme.Border, 1, 0.3)

    -- Aplica UIScale pra mobile
    local uiscale = Utility.Create("UIScale", { Parent = Main })
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local sx = math.min(viewport.X / 700, 1)
    local sy = math.min(viewport.Y / 500, 1)
    uiscale.Scale = math.min(sx, sy) * Config.UI.Scale

    -- TopBar
    local TopBar = Utility.Create("Frame", {
        Name = "TopBar",
        Parent = Main,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Config.UI.TopBarHeight),
    })

    Utility.Create("TextLabel", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 6),
        Size = UDim2.new(0, 200, 0, 18),
        Font = Config.Theme.FontBold,
        Text = Config.HubName,
        TextColor3 = Config.Theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    Utility.Create("TextLabel", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 24),
        Size = UDim2.new(0, 200, 0, 12),
        Font = Config.Theme.Font,
        Text = Config.Author,
        TextColor3 = Config.Theme.TextDim,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local btnContainer = Utility.Create("Frame", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -76, 0, 10),
        Size = UDim2.new(0, 66, 0, 22),
    })

    local function makeWinBtn(text, xPos, hoverColor, cb)
        local btn = Utility.Create("TextButton", {
            Parent = btnContainer,
            BackgroundColor3 = Config.Theme.Element,
            BorderSizePixel = 0,
            Position = UDim2.new(0, xPos, 0, 0),
            Size = UDim2.new(0, 20, 0, 20),
            Font = Config.Theme.FontBold,
            Text = text,
            TextColor3 = Config.Theme.Text,
            TextSize = 12,
            AutoButtonColor = false,
        })
        Utility.Corner(btn, 5)
        btn.MouseEnter:Connect(function()
            Utility.Tween(btn, 0.15, { BackgroundColor3 = hoverColor })
        end)
        btn.MouseLeave:Connect(function()
            Utility.Tween(btn, 0.15, { BackgroundColor3 = Config.Theme.Element })
        end)
        btn.MouseButton1Click:Connect(cb)
        return btn
    end

    makeWinBtn("–", 0, Config.Theme.ElementHover, function()
        Main.Visible = false
        local reopen = Utility.Create("TextButton", {
            Parent = ScreenGui,
            BackgroundColor3 = Config.Theme.Accent,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 100, 0, 28),
            Position = UDim2.new(0, 20, 0, 60),
            Font = Config.Theme.FontBold,
            Text = Config.HubName,
            TextColor3 = Config.Theme.Text,
            TextSize = 11,
            AutoButtonColor = false,
            Name = "Reopen",
        })
        Utility.Corner(reopen, 6)
        reopen.MouseButton1Click:Connect(function()
            Main.Visible = true
            reopen:Destroy()
        end)
    end)

    makeWinBtn("✕", 24, Color3.fromRGB(180, 30, 40), function()
        ScreenGui:Destroy()
        HubController:StopAll()
    end)

    Utility.Create("Frame", {
        Parent = TopBar,
        BackgroundColor3 = Config.Theme.Border,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
    })

    -- Sidebar
    local Content = Utility.Create("Frame", {
        Name = "Content",
        Parent = Main,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, Config.UI.SidebarWidth, 0, Config.UI.TopBarHeight),
        Size = UDim2.new(1, -Config.UI.SidebarWidth, 1, -Config.UI.TopBarHeight),
    })

    local Pages = {}
    local function switchPage(name)
        for pageName, page in pairs(Pages) do
            page.Visible = (pageName == name)
        end
    end

    local sidebar = Sidebar.Create(Main, CATEGORIES, switchPage)

    for _, catName in ipairs(CATEGORIES) do
        local page = Utility.Create("ScrollingFrame", {
            Parent = Content,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Config.Theme.Accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            Name = catName,
        })
        Utility.Create("UIPadding", {
            Parent = page,
            PaddingTop = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 12),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
        })
        Utility.List(page, 4)
        Pages[catName] = page
    end

    return {
        ScreenGui = ScreenGui,
        Main = Main,
        Pages = Pages,
        Sidebar = sidebar,
        SwitchPage = switchPage,
    }
end
