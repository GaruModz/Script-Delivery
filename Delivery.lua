local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ANCHOR_NAME = "DeliveryTargetAnchor"
local DIST_HIGH = 26
local DIST_LOW = 24

local LOOP_INTERVAL = 6 
local PLATFORM_SIZE = Vector3.new(10, 1, 10)
local PLATFORM_LIFE = 8

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local currentPlatform = nil
local platformFadeThread = nil

local function refreshJobSession()
    pcall(function()
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("RequestStartJobSession"):FireServer("Delivery", "jobPad")
    end)
end

local function destroyPlatform()
    if platformFadeThread then
        task.cancel(platformFadeThread)
        platformFadeThread = nil
    end
    if currentPlatform and currentPlatform.Parent then
        currentPlatform:Destroy()
    end
    currentPlatform = nil
end

local function spawnPlatformAt(position)
    destroyPlatform()

    local platform = Instance.new("Part")
    platform.Name = "TeleportPlatform"
    platform.Size = PLATFORM_SIZE
    platform.CFrame = CFrame.new(position - Vector3.new(0, 3 + PLATFORM_SIZE.Y / 2, 0))
    platform.Anchored = true
    platform.CanCollide = true
    platform.Transparency = 1
    platform.CastShadow = false
    platform.Parent = workspace

    currentPlatform = platform
end

local function schedulePlatformRemoval()
    if platformFadeThread then task.cancel(platformFadeThread) end
    platformFadeThread = task.delay(PLATFORM_LIFE, function()
        destroyPlatform()
    end)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TeleportGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 120)
frame.Position = UDim2.new(1, -240, 1, -140)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

-- [FITUR GESER / DRAG FOR MOBILE & PC]
local dragging, dragInput, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 180, 50)
stroke.Thickness = 2
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 24)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Text = "FishGuy Delivery (Draggable v4)"
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextColor3 = Color3.fromRGB(255, 200, 80)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local distLabel = Instance.new("TextLabel")
distLabel.Size = UDim2.new(1, -20, 0, 18)
distLabel.Position = UDim2.new(0, 10, 0, 32)
distLabel.BackgroundTransparency = 1
distLabel.Text = "Next: " .. DIST_HIGH .. " studs | OFF"
distLabel.Font = Enum.Font.Gotham
distLabel.TextSize = 11
distLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
distLabel.TextXAlignment = Enum.TextXAlignment.Left
distLabel.Parent = frame

local button = Instance.new("TextButton")
button.Size = UDim2.new(1, -20, 0, 40)
button.Position = UDim2.new(0, 10, 0, 56)
button.BackgroundColor3 = Color3.fromRGB(255, 175, 30)
button.Text = "Start Loop"
button.Font = Enum.Font.GothamBold
button.TextSize = 14
button.TextColor3 = Color3.fromRGB(15, 15, 20)
button.AutoButtonColor = false
button.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 10)
btnCorner.Parent = button

local isRunning = false
local loopThread = nil
local useHigh = true

local COLOR_OFF = Color3.fromRGB(255, 175, 30)
local COLOR_ON = Color3.fromRGB(50, 200, 100)
local COLOR_ERR = Color3.fromRGB(220, 60, 60)

local function findAnchor()
    return workspace:FindFirstChild(ANCHOR_NAME, true)
end

local function updateLabel()
    local nextDist = useHigh and DIST_HIGH or DIST_LOW
    distLabel.Text = "Next: " .. nextDist .. " studs | " .. (isRunning and "ON ✓" or "OFF")
end

local function triggerTouch(part, character)
    if not part or not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    if firetouchinterest and part:IsA("BasePart") then
        pcall(function()
            firetouchinterest(root, part, 0)
            task.wait(0.1)
            firetouchinterest(root, part, 1)
        end)
    end
end

local function doTeleport()
    local anchor = findAnchor()
    if not anchor then 
        refreshJobSession()
        return false 
    end

    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local dist = useHigh and DIST_HIGH or DIST_LOW
    local anchorCF = anchor:IsA("BasePart") and anchor.CFrame or CFrame.new(anchor.Position)
    local offset = anchorCF.LookVector * dist
    local targetPos = anchorCF.Position + offset + Vector3.new(0, 3, 0)

    spawnPlatformAt(targetPos)
    task.wait(0.1)

    rootPart.CFrame = CFrame.new(targetPos, anchorCF.Position)
    
    task.wait(6)

    triggerTouch(anchor, character)

    useHigh = not useHigh
    updateLabel()
    return true
end

local function startLoop()
    isRunning = true
    button.Text = "Stop Loop"
    button.BackgroundColor3 = COLOR_ON
    stroke.Color = Color3.fromRGB(50, 220, 100)
    updateLabel()

    refreshJobSession()

    loopThread = task.spawn(function()
        local counter = 0
        while isRunning do
            local ok = doTeleport()
            if not ok then
                task.wait(1)
            end
            
            counter = counter + 1
            if counter >= 5 then
                counter = 0
                refreshJobSession()
            end
            
            task.wait(LOOP_INTERVAL)
        end
    end)
end

local function stopLoop()
    isRunning = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
    button.Text = "Start Loop"
    button.BackgroundColor3 = COLOR_OFF
    stroke.Color = Color3.fromRGB(255, 180, 50)
    updateLabel()
    schedulePlatformRemoval()
end

player.CharacterRemoving:Connect(function()
    destroyPlatform()
end)

button.MouseEnter:Connect(function()
    button.BackgroundColor3 = isRunning and Color3.fromRGB(80, 230, 120) or Color3.fromRGB(255, 210, 80)
end)
button.MouseLeave:Connect(function()
    button.BackgroundColor3 = isRunning and COLOR_ON or COLOR_OFF
end)

button.MouseButton1Click:Connect(function()
    if isRunning then stopLoop() else startLoop() end
end)
