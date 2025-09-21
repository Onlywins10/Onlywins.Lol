-- onlywin.lol - Advanced Combat Lock System v2
-- Features: Auto-Unlock on death/leave, Stomp detection, Auto-lock on stomp

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

-- Local references
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Configuration - Modified for extreme distance
local LOCK_DISTANCE = 100000000  -- 100 million studs
local FORCE_LOCK = true
local AUTO_LOCK_ON_STOMP = true

-- State management
local lockState = {
    enabled = false,
    target = nil,
    dragging = false,
    dragInput = nil,
    dragStart = nil,
    startPos = nil,
    lastStomper = nil
}

-- Animation variables
local loadingProgress = 0
local isLoadingComplete = false
local loadingElements = {}

-- UI Initialization
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "onlywinUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Black screen covering the whole screen
    local blackScreen = Instance.new("Frame")
    blackScreen.Name = "BlackScreen"
    blackScreen.Size = UDim2.new(1, 0, 1, 0)
    blackScreen.BackgroundColor3 = Color3.new(0, 0, 0)
    blackScreen.BackgroundTransparency = 0
    blackScreen.BorderSizePixel = 0
    blackScreen.ZIndex = 10
    blackScreen.Parent = screenGui

    -- Loading container (centered on screen)
    local loadingContainer = Instance.new("Frame")
    loadingContainer.Name = "LoadingContainer"
    loadingContainer.Size = UDim2.new(0, 300, 0, 100)
    loadingContainer.Position = UDim2.new(0.5, -150, 0.5, -50)
    loadingContainer.BackgroundTransparency = 1
    loadingContainer.Parent = screenGui
    loadingContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    loadingContainer.ZIndex = 11
    
    -- Loading text - centered in the middle of the screen
    local loadingText = Instance.new("TextLabel")
    loadingText.Name = "LoadingText"
    loadingText.Size = UDim2.new(0, 300, 0, 40)
    loadingText.Position = UDim2.new(0.5, -150, 0.5, -50)
    loadingText.BackgroundTransparency = 1
    loadingText.TextColor3 = Color3.new(1, 1, 1)
    loadingText.Text = "OnlyWins.lol loading!"
    loadingText.Font = Enum.Font.SourceSansBold
    loadingText.TextSize = 24
    loadingText.TextTransparency = 0
    loadingText.Parent = screenGui
    loadingText.AnchorPoint = Vector2.new(0.5, 0.5)
    loadingText.ZIndex = 12
    loadingText.TextYAlignment = Enum.TextYAlignment.Center
    loadingText.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Loading bar background
    local loadingBarBg = Instance.new("Frame")
    loadingBarBg.Name = "LoadingBarBg"
    loadingBarBg.Size = UDim2.new(0, 300, 0, 20)
    loadingBarBg.Position = UDim2.new(0.5, -150, 0.5, 10)
    loadingBarBg.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    loadingBarBg.BorderSizePixel = 0
    loadingBarBg.Parent = screenGui
    loadingBarBg.AnchorPoint = Vector2.new(0.5, 0.5)
    loadingBarBg.ZIndex = 12
    
    -- Loading bar fill
    local loadingBar = Instance.new("Frame")
    loadingBar.Name = "LoadingBar"
    loadingBar.Size = UDim2.new(0, 0, 1, 0)
    loadingBar.Position = UDim2.new(0, 0, 0, 0)
    loadingBar.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    loadingBar.BorderSizePixel = 0
    loadingBar.Parent = loadingBarBg
    
    -- Loading percentage text
    local percentText = Instance.new("TextLabel")
    percentText.Name = "PercentText"
    percentText.Size = UDim2.new(1, 0, 1, 0)
    percentText.Position = UDim2.new(0, 0, 0, 0)
    percentText.BackgroundTransparency = 1
    percentText.TextColor3 = Color3.new(1, 1, 1)
    percentText.Text = "0%"
    percentText.Font = Enum.Font.SourceSansBold
    percentText.TextSize = 14
    percentText.TextTransparency = 0
    percentText.Parent = loadingBarBg
    
    -- Store loading elements for animation
    loadingElements = {
        blackScreen = blackScreen,
        text = loadingText,
        barBg = loadingBarBg,
        bar = loadingBar,
        percent = percentText
    }

    -- Main lock button (initially hidden)
    local lockButton = Instance.new("TextButton")
    lockButton.Name = "onlywin.lol"
    lockButton.Size = UDim2.new(0, 120, 0, 45)
    lockButton.Position = UDim2.new(0.5, -60, 0.92, -22.5)
    lockButton.BackgroundColor3 = Color3.new(0, 0, 0)
    lockButton.TextColor3 = Color3.new(1, 1, 1)
    lockButton.Text = "onlywin.lol"
    lockButton.Font = Enum.Font.SourceSansBold
    lockButton.TextSize = 16
    lockButton.BorderSizePixel = 2
    lockButton.BorderColor3 = Color3.new(1, 1, 1)
    lockButton.AnchorPoint = Vector2.new(0.5, 0.5)
    lockButton.Visible = false  -- Initially hidden
    lockButton.ZIndex = 20

    -- Add glow effect to lock button
    local lockButtonGlow = Instance.new("UIStroke")
    lockButtonGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    lockButtonGlow.Color = Color3.fromRGB(0, 120, 255)
    lockButtonGlow.Thickness = 2
    lockButtonGlow.Transparency = 0.8
    lockButtonGlow.Parent = lockButton

    -- Mobile adjustments
    if UserInputService.TouchEnabled then
        lockButton.Size = UDim2.new(0, 140, 0, 55)
        lockButton.TextSize = 18
        lockButton.Position = UDim2.new(0.5, -70, 0.92, -27.5)
    end

    -- Notification system
    local function showNotification(message)
        local notification = Instance.new("TextLabel")
        notification.Name = "Notification"
        notification.Size = UDim2.new(0, 200, 0, 50)
        notification.Position = UDim2.new(0.85, 0, 0.92, -25)
        notification.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        notification.TextColor3 = Color3.new(1, 1, 1)
        notification.Text = message
        notification.Font = Enum.Font.SourceSansBold
        notification.TextSize = 14
        notification.BorderSizePixel = 0
        notification.TextXAlignment = Enum.TextXAlignment.Left
        notification.TextYAlignment = Enum.TextYAlignment.Top
        notification.AnchorPoint = Vector2.new(0.5, 0.5)
        notification.Parent = screenGui
        notification.BackgroundTransparency = 1
        notification.TextTransparency = 1
        notification.ZIndex = 20
        
        local fadeIn = TweenService:Create(
            notification,
            TweenInfo.new(0.5),
            {BackgroundTransparency = 0.3, TextTransparency = 0}
        )
        fadeIn:Play()
        
        task.delay(3, function()
            local fadeOut = TweenService:Create(
                notification,
            TweenInfo.new(0.5),
            {BackgroundTransparency = 1, TextTransparency = 1}
            )
            fadeOut:Play()
            fadeOut.Completed:Wait()
            notification:Destroy()
        end)
    end

    -- UI Protection
    if not is_sirhurt_closure and syn and syn.protect_gui then
        syn.protect_gui(screenGui)
    end

    return screenGui, lockButton, showNotification, lockButtonGlow
end

local ScreenGui, LockButton, showNotification, LockButtonGlow = createUI()

-- Loading animation function
local function updateLoadingAnimation()
    if isLoadingComplete then return end
    
    loadingProgress = math.min(loadingProgress + 0.5, 100)
    
    -- Update loading bar
    loadingElements.bar.Size = UDim2.new(loadingProgress/100, 0, 1, 0)
    loadingElements.percent.Text = math.floor(loadingProgress) .. "%"
    
    -- Pulsing glow effect on loading bar
    local pulseValue = 0.5 + 0.5 * math.sin(tick() * 5)
    loadingElements.bar.BackgroundColor3 = Color3.fromRGB(
        0, 
        120 + math.floor(135 * pulseValue), 
        255
    )
    
    -- Check if loading is complete
    if loadingProgress >= 100 and not isLoadingComplete then
        isLoadingComplete = true
        
        -- Fade out black screen and loading elements together
        local fadeOutBlackScreen = TweenService:Create(
            loadingElements.blackScreen,
            TweenInfo.new(1.5),
            {BackgroundTransparency = 1}
        )
        fadeOutBlackScreen:Play()
        
        local fadeOutText = TweenService:Create(
            loadingElements.text,
            TweenInfo.new(1.5),
            {TextTransparency = 1}
        )
        fadeOutText:Play()
        
        local fadeOutBar = TweenService:Create(
            loadingElements.barBg,
            TweenInfo.new(1.5),
            {BackgroundTransparency = 1}
        )
        fadeOutBar:Play()
        
        local fadeOutPercent = TweenService:Create(
            loadingElements.percent,
            TweenInfo.new(1.5),
            {TextTransparency = 1}
        )
        fadeOutPercent:Play()
        
        -- Show and animate in the lock button
        LockButton.Visible = true
        LockButton.Position = UDim2.new(0.5, -60, 0.7, -22.5) -- Start from higher position
        
        local slideIn = TweenService:Create(
            LockButton,
            TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Position = UDim2.new(0.5, -60, 0.92, -22.5)}
        )
        slideIn:Play()
        
        -- Initial glow pulse for the lock button
        local intenseGlow = TweenService:Create(
            LockButtonGlow,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Thickness = 6, Transparency = 0.1}
        )
        intenseGlow:Play()
        
        intenseGlow.Completed:Connect(function()
            local resetGlow = TweenService:Create(
                LockButtonGlow,
                TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Thickness = 2, Transparency = 0.2}
            )
            resetGlow:Play()
        end)
        
        -- Clean up loading elements after animation
        task.delay(2, function()
            loadingElements.blackScreen:Destroy()
            loadingElements.text:Destroy()
            loadingElements.barBg:Destroy()
        end)
    end
end

-- Core Functions
local function updateButtonState()
    if lockState.enabled and lockState.target then
        LockButton.Text = "Locked-"..string.sub(lockState.target.Name, 1, 8)
        LockButton.BackgroundColor3 = Color3.new(0.8, 0, 0)
        
        -- Add glowing effect when locked
        LockButtonGlow.Color = Color3.new(1, 0, 0)
        local intenseGlow = TweenService:Create(
            LockButtonGlow,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Thickness = 4, Transparency = 0.1}
        )
        intenseGlow:Play()
    else
        LockButton.Text = "onlywin.lol"
        LockButton.BackgroundColor3 = Color3.new(0, 0, 0)
        
        -- Reset glow effect
        LockButtonGlow.Color = Color3.fromRGB(0, 120, 255)
        local resetGlow = TweenService:Create(
            LockButtonGlow,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Thickness = 2, Transparency = 0.2}
        )
        resetGlow:Play()
    end
end

-- Start pulsing glow animation
local pulseGlow = coroutine.wrap(function()
    while LockButton and LockButton.Parent do
        local pulseOut = TweenService:Create(
            LockButtonGlow,
            TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Transparency = 0.5}
        )
        pulseOut:Play()
        pulseOut.Completed:Wait()
        
        local pulseIn = TweenService:Create(
            LockButtonGlow,
            TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Transparency = 0.2}
        )
        pulseIn:Play()
        pulseIn.Completed:Wait()
    end
end)()

local function releaseLock()
    if lockState.enabled and lockState.target then
        lockState.enabled = false
        lockState.target = nil
        updateButtonState()
    end
end

local function acquireLock(target)
    if not target or not target.Character then return false end
    
    local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
    local head = target.Character:FindFirstChild("Head")
    
    if not head or (humanoid and humanoid.Health <= 0) then
        return false
    end
    
    lockState.target = target
    lockState.enabled = true
    updateButtonState()
    showNotification("Locked: "..target.Name)
    
    -- Immediate lock with no prediction or smoothness
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
    return true
end

-- Stomp Detection
local function setupStompDetection()
    if not LocalPlayer.Character then return end
    
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    humanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.FallingDown then
            -- Check if someone is above us (potential stomper)
            local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not rootPart then return end
            
            local stomper = nil
            local shortestDistance = 10 -- Max stomp distance
            
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                    if targetRoot then
                        local distance = (targetRoot.Position - rootPart.Position).magnitude
                        if distance < shortestDistance and targetRoot.Position.Y > rootPart.Position.Y then
                            stomper = player
                            shortestDistance = distance
                        end
                    end
                end
            end
            
            if stomper then
                lockState.lastStomper = stomper
                if AUTO_LOCK_ON_STOMP then
                    acquireLock(stomper)
                end
            end
        end
    end)
end

-- Death/Leave Handling
local function handleDeath()
    releaseLock()
end

local function onCharacterAdded(character)
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.Died:Connect(handleDeath)
    
    -- Setup stomp detection for new character
    setupStompDetection()
end

if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- Target Finding
local function getViewportCenter()
    if UserInputService.MouseEnabled then
        local mousePos = UserInputService:GetMouseLocation()
        return Vector2.new(mousePos.X, mousePos.Y)
    end
    return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
end

local function findBestTarget()
    local closestPlayer = nil
    local shortestDistance = LOCK_DISTANCE
    local viewportPoint = getViewportCenter()

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            local head = player.Character:FindFirstChild("Head")
            
            if head and humanoid and humanoid.Health > 0 then
                local headPosition, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local distance = (Vector2.new(headPosition.X, headPosition.Y) - viewportPoint).magnitude
                    if distance < shortestDistance then
                        closestPlayer = player
                        shortestDistance = distance
                    end
                end
            end
        end
    end
    
    -- Prioritize last stomper if they're visible
    if lockState.lastStomper and lockState.lastStomper.Character then
        local humanoid = lockState.lastStomper.Character:FindFirstChildOfClass("Humanoid")
        local head = lockState.lastStomper.Character:FindFirstChild("Head")
        if head and humanoid and humanoid.Health > 0 then
            local headPosition, onScreen = Camera:WorldToViewportPoint(head.Position)
            if onScreen then
                return lockState.lastStomper
            end
        end
    end
    
    return closestPlayer
end

-- Lock Maintenance with no smoothness or prediction - Modified for extreme distance
local function maintainLock()
    if not lockState.enabled or not lockState.target or not lockState.target.Character then
        return
    end
    
    local head = lockState.target.Character:FindFirstChild("Head")
    if not head then
        releaseLock()
        return
    end
    
    -- Calculate distance to target
    local distance = (head.Position - Camera.CFrame.Position).Magnitude
    
    -- Only lock if within 100 million studs
    if distance <= LOCK_DISTANCE then
        -- Direct lock with no smoothness or prediction
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
    else
        -- Release lock if target is too far
        releaseLock()
        showNotification("Target out of range")
    end
end

-- Input Handlers
local function handleLockToggle()
    if lockState.enabled then
        releaseLock()
    else
        local target = findBestTarget()
        if target then
            acquireLock(target)
        else
            LockButton.Text = "NO TARGET"
            task.delay(0.7, updateButtonState)
        end
    end
end

local function updateDragPosition(input)
    if not lockState.dragging then return end
    local delta = input.Position - lockState.dragStart
    LockButton.Position = UDim2.new(
        lockState.startPos.X.Scale, 
        lockState.startPos.X.Offset + delta.X, 
        lockState.startPos.Y.Scale, 
        lockState.startPos.Y.Offset + delta.Y
    )
end

-- Event Connections
LockButton.MouseButton1Click:Connect(handleLockToggle)

LockButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        lockState.dragging = true
        lockState.dragStart = input.Position
        lockState.startPos = LockButton.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                lockState.dragging = false
            end
        end)
    end
end)

LockButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        lockState.dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == lockState.dragInput and lockState.dragging then
        updateDragPosition(input)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player == lockState.target then
        releaseLock()
        showNotification("Target left the game")
    end
end)

-- Main Runtime
RunService.RenderStepped:Connect(function()
    maintainLock()
    
    -- Update loading animation if not complete
    if not isLoadingComplete then
        updateLoadingAnimation()
    end
    
    -- Auto-unlock if target is invalid
    if lockState.enabled and lockState.target and lockState.target.Character then
        local humanoid = lockState.target.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            releaseLock()
            showNotification("Target eliminated")
        end
    end
end)

-- UI Activation
ScreenGui.Parent = CoreGui or LocalPlayer:WaitForChild("PlayerGui")
LockButton.Parent = ScreenGui

print("onlywin.lol combat system activated!")
