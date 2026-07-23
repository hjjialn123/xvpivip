-- ============================================
--  Roblox 控制面板 v4.3 (WindUI 重构版)
--  功能：速度修改、跳跃高度修改、飞行模式、色彩滤镜、FOV调整等
--  作者：Kimi (WindUI重构版)
--  使用方式：将本脚本放入 StarterGui 或 StarterPlayerScripts
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

-- ============================================
--  加载 WindUI 库
-- ============================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ============================================
--  状态管理
-- ============================================
local State = {
    isFlying = false,
    infiniteJump = false,
    godMode = false,
    noclip = false,
    fullBright = false,
    currentFilter = "Normal",
    savedPosition = nil,
    flySpeed = 50,
    walkSpeed = 16,
    jumpPower = 50,
    fov = 70,
}

-- ============================================
--  工具函数
-- ============================================
local function getHumanoid()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function notify(title, content, duration)
    WindUI:Notify({
        Title = title,
        Content = content,
        Duration = duration or 3,
    })
end

-- ============================================
--  功能实现
-- ============================================

-- 飞行系统
local flyConnection = nil
local flyBodyVelocity = nil
local flyBodyGyro = nil

local function startFlying()
    if State.isFlying then return end
    State.isFlying = true

    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.MaxTorque = Vector3.new(400000, 400000, 400000)
    flyBodyGyro.P = 10000
    flyBodyGyro.Parent = hrp

    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(400000, 400000, 400000)
    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyBodyVelocity.Parent = hrp

    flyConnection = RunService.RenderStepped:Connect(function()
        if not State.isFlying then return end
        if not player.Character then return end
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local camera = workspace.CurrentCamera
        local moveDirection = Vector3.new(0, 0, 0)
        local speed = State.flySpeed

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDirection = moveDirection + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDirection = moveDirection - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDirection = moveDirection - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDirection = moveDirection + camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection = moveDirection + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDirection = moveDirection - Vector3.new(0, 1, 0)
        end

        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit * speed
        end

        if flyBodyVelocity and flyBodyVelocity.Parent then
            flyBodyVelocity.Velocity = moveDirection
        end
        if flyBodyGyro and flyBodyGyro.Parent then
            flyBodyGyro.CFrame = camera.CFrame
        end
    end)
end

local function stopFlying()
    State.isFlying = false
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end
end

-- 无限跳跃
local infJumpConnection = nil

local function toggleInfiniteJump(enabled)
    State.infiniteJump = enabled
    if enabled then
        infJumpConnection = UserInputService.JumpRequest:Connect(function()
            if player.Character then
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    else
        if infJumpConnection then
            infJumpConnection:Disconnect()
            infJumpConnection = nil
        end
    end
end

-- 无敌模式
local godModeConnection = nil

local function toggleGodMode(enabled)
    State.godMode = enabled
    if enabled then
        godModeConnection = RunService.Stepped:Connect(function()
            if player.Character then
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.MaxHealth = math.huge
                    hum.Health = math.huge
                end
            end
        end)
    else
        if godModeConnection then
            godModeConnection:Disconnect()
            godModeConnection = nil
        end
        if player.Character then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.MaxHealth = 100
                hum.Health = 100
            end
        end
    end
end

-- 穿墙模式
local noclipConnection = nil

local function toggleNoclip(enabled)
    State.noclip = enabled
    if enabled then
        noclipConnection = RunService.Stepped:Connect(function()
            if player.Character then
                for _, part in pairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
        if player.Character then
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- 全亮模式
local fullBrightConnection = nil
local originalBrightness = Lighting.Brightness
local originalAmbient = Lighting.Ambient
local originalOutdoorAmbient = Lighting.OutdoorAmbient
local originalGlobalShadows = Lighting.GlobalShadows
local originalClockTime = Lighting.ClockTime

local function toggleFullBright(enabled)
    State.fullBright = enabled
    if enabled then
        originalBrightness = Lighting.Brightness
        originalAmbient = Lighting.Ambient
        originalOutdoorAmbient = Lighting.OutdoorAmbient
        originalGlobalShadows = Lighting.GlobalShadows
        originalClockTime = Lighting.ClockTime

        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.GlobalShadows = false
        Lighting.ClockTime = 12

        fullBrightConnection = Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
            Lighting.Brightness = 2
        end)
    else
        if fullBrightConnection then
            fullBrightConnection:Disconnect()
            fullBrightConnection = nil
        end
        Lighting.Brightness = originalBrightness
        Lighting.Ambient = originalAmbient
        Lighting.OutdoorAmbient = originalOutdoorAmbient
        Lighting.GlobalShadows = originalGlobalShadows
        Lighting.ClockTime = originalClockTime
    end
end

-- 色彩滤镜
local colorCorrection = nil

local function applyColorFilter(filterType)
    State.currentFilter = filterType
    if colorCorrection then
        colorCorrection:Destroy()
        colorCorrection = nil
    end
    if filterType == "Normal" then return end

    colorCorrection = Instance.new("ColorCorrectionEffect")
    colorCorrection.Name = "WindUI_ColorFilter"

    local presets = {
        Warm = { TintColor = Color3.fromRGB(255, 220, 180), Contrast = 0.1, Saturation = 0.2, Brightness = 0.05 },
        Cool = { TintColor = Color3.fromRGB(180, 210, 255), Contrast = 0.05, Saturation = 0.1, Brightness = 0 },
        Vintage = { TintColor = Color3.fromRGB(220, 190, 150), Contrast = 0.2, Saturation = -0.2, Brightness = -0.05 },
        Cyber = { TintColor = Color3.fromRGB(255, 0, 128), Contrast = 0.3, Saturation = 0.5, Brightness = 0.1 },
        Mono = { TintColor = Color3.fromRGB(128, 128, 128), Contrast = 0.1, Saturation = -1, Brightness = 0 },
        Night = { TintColor = Color3.fromRGB(100, 100, 200), Contrast = 0.15, Saturation = 0.1, Brightness = -0.1 },
        Dream = { TintColor = Color3.fromRGB(220, 180, 255), Contrast = -0.1, Saturation = 0.3, Brightness = 0.05 },
            Red = { TintColor = Color3.fromRGB(255, 0, 0), Contrast = 0, Saturation = 10, Brightness = 0.05 }
        
    }

    local preset = presets[filterType]
    if preset then
        colorCorrection.TintColor = preset.TintColor
        colorCorrection.Contrast = preset.Contrast
        colorCorrection.Saturation = preset.Saturation
        colorCorrection.Brightness = preset.Brightness
    end
    colorCorrection.Parent = Lighting
end

-- 随机传送
local function randomTeleport()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local randomX = math.random(-500, 500)
    local randomZ = math.random(-500, 500)
    local randomY = math.random(50, 200)
    hrp.CFrame = CFrame.new(randomX, randomY, randomZ)
    notify("随机传送", string.format("已传送至: %.0f, %.0f, %.0f", randomX, randomY, randomZ))
end

-- 保存/加载位置
local function savePosition()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    State.savedPosition = hrp.CFrame
    notify("保存位置", string.format("位置已保存: %.0f, %.0f, %.0f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
end

local function loadPosition()
    if not State.savedPosition then
        notify("加载位置", "没有保存的位置！", 3)
        return
    end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = State.savedPosition
    notify("加载位置", "已传送至保存的位置")
end

-- 重置所有设置
local function resetAllSettings()
    local currentHum = getHumanoid()
    if currentHum then
        currentHum.WalkSpeed = 16
        currentHum.JumpPower = 50
    end
    workspace.CurrentCamera.FieldOfView = 70
    stopFlying()
    toggleInfiniteJump(false)
    toggleGodMode(false)
    toggleNoclip(false)
    toggleFullBright(false)
    applyColorFilter("Normal")
    State.savedPosition = nil
    State.walkSpeed = 16
    State.jumpPower = 50
    State.fov = 70
    State.flySpeed = 50
    notify("重置", "所有设置已重置")
end

-- ============================================
--  创建 WindUI 窗口
-- ============================================

local Window = WindUI:CreateWindow({
    Title = "控制面板 v4.0",
    Icon = "settings",
    Author = "Kimi",
    Folder = "ControlPanel",
    Size = UDim2.fromOffset(520, 440),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 180,
})

-- 自定义打开按钮
Window:EditOpenButton({
    Title = "打开控制面板",
    Icon = "settings",
    CornerRadius = UDim.new(0, 12),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromHex("8B5CF6"), Color3.fromHex("3B82F6")),
    Draggable = true,
})

-- ============================================
--  创建标签页
-- ============================================
local Tabs = {
    Movement = Window:Tab({ Title = "移动", Icon = "move" }),
    Flight   = Window:Tab({ Title = "飞行", Icon = "plane" }),
    Visual   = Window:Tab({ Title = "视觉", Icon = "eye" }),
    Player   = Window:Tab({ Title = "玩家", Icon = "shield" }),
    Settings = Window:Tab({ Title = "设置", Icon = "settings" }),
}

Window:SelectTab(1)

-- ============================================
--  移动标签页
-- ============================================
Tabs.Movement:Section({ Title = "移动控制" })

-- 行走速度滑块
Tabs.Movement:Slider({
    Title = "行走速度",
    Value = { Min = 0, Max = 200, Default = 16 },
    Callback = function(value)
        State.walkSpeed = value
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = value end
    end
})

-- 跳跃高度滑块
Tabs.Movement:Slider({
    Title = "跳跃高度",
    Value = { Min = 0, Max = 200, Default = 50 },
    Callback = function(value)
        State.jumpPower = value
        local hum = getHumanoid()
        if hum then hum.JumpPower = value end
    end
})

-- ============================================
--  飞行标签页
-- ============================================
Tabs.Flight:Section({ Title = "飞行控制" })

-- 飞行开关
Tabs.Flight:Toggle({
    Title = "启用飞行模式",
    Value = false,
    Callback = function(enabled)
        if enabled then
            startFlying()
            notify("飞行模式", "飞行已启用")
        else
            stopFlying()
            notify("飞行模式", "飞行已关闭")
        end
    end
})

-- 飞行速度滑块
Tabs.Flight:Slider({
    Title = "飞行速度",
    Value = { Min = 10, Max = 200, Default = 50 },
    Callback = function(value)
        State.flySpeed = value
    end
})

-- ============================================
--  视觉标签页
-- ============================================
Tabs.Visual:Section({ Title = "视觉特效" })

-- FOV滑块
Tabs.Visual:Slider({
    Title = "视野范围 (FOV)",
    Value = { Min = 30, Max = 120, Default = 70 },
    Callback = function(value)
        State.fov = value
        workspace.CurrentCamera.FieldOfView = value
    end
})

Tabs.Visual:Section({ Title = "色彩滤镜" })

-- 滤镜下拉菜单
Tabs.Visual:Dropdown({
    Title = "选择滤镜",
    Values = { "Normal", "Warm", "Cool", "Vintage", "Cyber", "Mono", "Night", "Dream", "Red" },
    Value = "Normal",
    Callback = function(option)
        applyColorFilter(option)
        notify("色彩滤镜", "已切换至 " .. option)
    end
})

-- 全亮开关
Tabs.Visual:Toggle({
    Title = "全亮模式 (FullBright)",
    Value = false,
    Callback = function(enabled)
        toggleFullBright(enabled)
        notify("全亮模式", enabled and "全亮已启用" or "全亮已关闭")
    end
})

-- ============================================
--  玩家标签页
-- ============================================
Tabs.Player:Section({ Title = "玩家功能" })

-- 无限跳跃
Tabs.Player:Toggle({
    Title = "无限跳跃",
    Value = false,
    Callback = function(enabled)
        toggleInfiniteJump(enabled)
        notify("无限跳跃", enabled and "无限跳跃已启用" or "无限跳跃已关闭")
    end
})

-- 无敌模式
Tabs.Player:Toggle({
    Title = "无敌模式",
    Value = false,
    Callback = function(enabled)
        toggleGodMode(enabled)
        notify("无敌模式", enabled and "无敌模式已启用" or "无敌模式已关闭")
    end
})

-- 穿墙模式
Tabs.Player:Toggle({
    Title = "穿墙模式 (Noclip)",
    Value = false,
    Callback = function(enabled)
        toggleNoclip(enabled)
        notify("穿墙模式", enabled and "穿墙已启用" or "穿墙已关闭")
    end
})

Tabs.Player:Section({ Title = "快捷操作" })

-- 随机传送按钮
Tabs.Player:Button({
    Title = "随机传送",
    Callback = function()
        randomTeleport()
    end
})

-- 保存位置按钮
Tabs.Player:Button({
    Title = "保存位置",
    Callback = function()
        savePosition()
    end
})

-- 加载位置按钮
Tabs.Player:Button({
    Title = "加载位置",
    Callback = function()
        loadPosition()
    end
})

-- 重置所有按钮
Tabs.Player:Button({
    Title = "重置所有设置",
    Callback = function()
        resetAllSettings()
    end
})

-- ============================================
--  设置标签页
-- ============================================
Tabs.Settings:Section({ Title = "界面设置" })

-- 主题切换
local themeValues = {}
for name, _ in pairs(WindUI:GetThemes()) do
    table.insert(themeValues, name)
end

Tabs.Settings:Dropdown({
    Title = "选择主题",
    Values = themeValues,
    Value = WindUI:GetCurrentTheme(),
    Callback = function(theme)
        WindUI:SetTheme(theme)
        notify("主题", "已切换至 " .. theme)
    end
})

-- 透明度开关
Tabs.Settings:Toggle({
    Title = "窗口透明",
    Value = false,
    Callback = function(enabled)
        Window:ToggleTransparency(enabled)
    end
})

-- UI缩放滑块
Tabs.Settings:Slider({
    Title = "界面缩放",
    Value = { Min = 50, Max = 150, Default = 100 },
    Callback = function(value)
        Window:SetUIScale(value / 100)
    end
})

Tabs.Settings:Section({ Title = "配置管理" })

-- 保存配置
Tabs.Settings:Button({
    Title = "保存配置",
    Callback = function()
        local config = {
            walkSpeed = State.walkSpeed,
            jumpPower = State.jumpPower,
            flySpeed = State.flySpeed,
            fov = State.fov,
            theme = WindUI:GetCurrentTheme(),
        }
        local folderPath = "WindUI/ControlPanel"
        if not isfolder(folderPath) then makefolder(folderPath) end
        writefile(folderPath .. "/config.json", HttpService:JSONEncode(config))
        notify("配置", "配置已保存")
    end
})

-- 加载配置
Tabs.Settings:Button({
    Title = "加载配置",
    Callback = function()
        local folderPath = "WindUI/ControlPanel"
        local filePath = folderPath .. "/config.json"
        if isfile(filePath) then
            local config = HttpService:JSONDecode(readfile(filePath))
            if config.walkSpeed then
                State.walkSpeed = config.walkSpeed
                local hum = getHumanoid()
                if hum then hum.WalkSpeed = config.walkSpeed end
            end
            if config.jumpPower then
                State.jumpPower = config.jumpPower
                local hum = getHumanoid()
                if hum then hum.JumpPower = config.jumpPower end
            end
            if config.flySpeed then State.flySpeed = config.flySpeed end
            if config.fov then
                State.fov = config.fov
                workspace.CurrentCamera.FieldOfView = config.fov
            end
            if config.theme then WindUI:SetTheme(config.theme) end
            notify("配置", "配置已加载")
        else
            notify("配置", "没有找到保存的配置")
        end
    end
})

-- ============================================
--  角色重生处理
-- ============================================
player.CharacterAdded:Connect(function(newCharacter)
    task.wait(0.5)
    local newHumanoid = newCharacter:WaitForChild("Humanoid")

    if State.walkSpeed ~= 16 then
        newHumanoid.WalkSpeed = State.walkSpeed
    end
    if State.jumpPower ~= 50 then
        newHumanoid.JumpPower = State.jumpPower
    end

    if State.isFlying then
        stopFlying()
        task.wait(0.3)
        startFlying()
    end

    if State.godMode then
        toggleGodMode(false)
        task.wait(0.1)
        toggleGodMode(true)
    end

    if State.noclip then
        toggleNoclip(false)
        task.wait(0.1)
        toggleNoclip(true)
    end
end)

-- ============================================
--  键盘快捷键
-- ============================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        if State.isFlying then
            stopFlying()
        else
            startFlying()
        end
    end
end)

-- ============================================
--  初始化完成通知
-- ============================================
notify("控制面板 v4.0", "WindUI 重构版已加载完成 | F键切换飞行", 5)
print("[控制面板 v4.0] WindUI 重构版已加载完成")
