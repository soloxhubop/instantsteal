local S = {
    Players = game:GetService("Players"),
    UserInputService = game:GetService("UserInputService"),
    TweenService = game:GetService("TweenService"),
    RunService = game:GetService("RunService"),
    ProximityPromptService = game:GetService("ProximityPromptService"),
}

S.LocalPlayer = S.Players.LocalPlayer
S.PlayerGui = S.LocalPlayer:FindFirstChild("PlayerGui") or S.LocalPlayer:WaitForChild("PlayerGui", 2)

local COLORS = {
    Accent = Color3.fromRGB(0, 150, 255),
    Surface = Color3.fromRGB(25, 35, 50),
    Background = Color3.fromRGB(8, 8, 15),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(168, 184, 208),
    Success = Color3.fromRGB(120, 255, 200),
    Green = Color3.fromRGB(0, 200, 0), -- Solid green for valid trajectory
    Red = Color3.fromRGB(200, 0, 0), -- Solid red for blocked trajectory
}

local CONFIG_FILE = "KawatanInstantTPConfig.json"

local CONFIG = {
    GUI_POSITION_X = nil,
    GUI_POSITION_Y = nil,
    GUI_COLLAPSED = false,
    ENABLED = false,
    SAVED_POSITION = nil, -- Saved CFrame for teleport (pos1)
}

-- Hardcoded target positions (exactly like leak script)
local targetPositions = {
    Vector3.new(-481.88, -3.79, 138.02),
    Vector3.new(-481.75, -3.79, 89.18),
    Vector3.new(-481.82, -3.79, 30.95),
    Vector3.new(-481.75, -3.79, -17.79),
    Vector3.new(-481.80, -3.79, -76.06),
    Vector3.new(-481.72, -3.79, -124.70),
    Vector3.new(-337.45, -3.85, -124.72),
    Vector3.new(-337.37, -3.85, -76.07),
    Vector3.new(-337.46, -3.79, -17.72),
    Vector3.new(-337.41, -3.79, 30.92),
    Vector3.new(-337.32, -3.79, 89.02),
    Vector3.new(-337.27, -3.79, 137.90),
    Vector3.new(-337.45, -3.79, 196.29),
    Vector3.new(-337.37, -3.79, 244.91),
    Vector3.new(-481.72, -3.79, 196.21),
    Vector3.new(-481.76, -3.79, 244.92)
}

local function saveConfig()
    if not writefile then return end
    -- Convert CFrame to serializable format for saved position
    local configToSave = {}
    for k, v in pairs(CONFIG) do
        if k == "SAVED_POSITION" and v then
            -- Save CFrame as table with Position and LookVector
            configToSave[k] = {
                Position = {X = v.Position.X, Y = v.Position.Y, Z = v.Position.Z},
                LookVector = {X = v.LookVector.X, Y = v.LookVector.Y, Z = v.LookVector.Z}
            }
        else
            configToSave[k] = v
        end
    end
    
    local success, jsonData = pcall(function()
        return game:GetService("HttpService"):JSONEncode(configToSave)
    end)
    if success and jsonData then
        pcall(function()
            writefile(CONFIG_FILE, jsonData)
        end)
    end
end

local function loadConfig()
    if not readfile or not isfile then return end
    if not isfile(CONFIG_FILE) then return end
    
    local ok, data = pcall(function()
        return readfile(CONFIG_FILE)
    end)
    if not ok or not data then return end
    
    local ok2, saved = pcall(function()
        return game:GetService("HttpService"):JSONDecode(data)
    end)
    if ok2 and saved then
        if saved.GUI_POSITION_X then CONFIG.GUI_POSITION_X = saved.GUI_POSITION_X end
        if saved.GUI_POSITION_Y then CONFIG.GUI_POSITION_Y = saved.GUI_POSITION_Y end
        if saved.GUI_COLLAPSED ~= nil then CONFIG.GUI_COLLAPSED = saved.GUI_COLLAPSED end
        if saved.ENABLED ~= nil then CONFIG.ENABLED = saved.ENABLED end
        if saved.SAVED_POSITION then
            -- Load saved position (stored as table with Position and LookVector)
            if saved.SAVED_POSITION.Position and saved.SAVED_POSITION.LookVector then
                CONFIG.SAVED_POSITION = CFrame.new(
                    Vector3.new(saved.SAVED_POSITION.Position.X, saved.SAVED_POSITION.Position.Y, saved.SAVED_POSITION.Position.Z),
                    Vector3.new(saved.SAVED_POSITION.LookVector.X, saved.SAVED_POSITION.LookVector.Y, saved.SAVED_POSITION.LookVector.Z) + Vector3.new(saved.SAVED_POSITION.Position.X, saved.SAVED_POSITION.Position.Y, saved.SAVED_POSITION.Position.Z)
                )
            end
        end
    end
end

loadConfig()

local function tween(obj, tweenInfo, props)
    local tween = S.TweenService:Create(obj, tweenInfo, props)
    tween:Play()
    return tween
end

local tweenInfoMedium = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local beam = nil
local beamAttachment0 = nil
local beamAttachment1 = nil
local diamond = nil
local indicatorFolder = nil

local function createIndicator()
    if indicatorFolder then return end
    
    indicatorFolder = Instance.new("Folder")
    indicatorFolder.Name = "InstantTPIndicator"
    indicatorFolder.Parent = workspace
    
    -- Diamond (much larger, solid color)
    -- Use Model to ensure center positioning
    local diamondModel = Instance.new("Model")
    diamondModel.Name = "DiamondModel"
    diamondModel.Parent = indicatorFolder
    
    diamond = Instance.new("Part")
    diamond.Name = "Diamond"
    diamond.Size = Vector3.new(6, 12, 6)
    diamond.Material = Enum.Material.Neon
    diamond.Color = COLORS.Red
    diamond.Transparency = 0
    diamond.Anchored = true
    diamond.CanCollide = false
    diamond.Parent = diamondModel
    
    local diamondMesh = Instance.new("SpecialMesh")
    diamondMesh.MeshType = Enum.MeshType.FileMesh
    diamondMesh.MeshId = "rbxassetid://9756362"
    diamondMesh.Scale = Vector3.new(3, 4, 3)
    diamondMesh.Parent = diamond
    
    -- Set diamond as PrimaryPart so we can position the model's center
    diamondModel.PrimaryPart = diamond
end

local function updateIndicator(tpPosition)
    if not indicatorFolder or not diamond then return end
    if not tpPosition then return end
    
    -- Update diamond model position so center is at exact TP location
    local diamondModel = diamond.Parent
    if diamondModel and diamondModel:IsA("Model") and diamondModel.PrimaryPart then
        diamondModel:SetPrimaryPartCFrame(CFrame.new(tpPosition))
    else
        -- Fallback: position diamond directly (assuming pivot is at center)
        diamond.CFrame = CFrame.new(tpPosition)
    end
    
    -- Update beam attachment at center of diamond
    if beamAttachment1 then
        beamAttachment1.Position = Vector3.new(0, 0, 0)
    end
end

local function destroyIndicator()
    if indicatorFolder then
        indicatorFolder:Destroy()
        indicatorFolder = nil
        diamond = nil
    end
end

local function createBeam()
    if beam then return end
    if not diamond then return end -- Wait for diamond to be created first
    
    local character = S.LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Attachments
    beamAttachment0 = Instance.new("Attachment")
    beamAttachment0.Name = "BeamAttachment0"
    beamAttachment0.Parent = hrp
    
    beamAttachment1 = Instance.new("Attachment")
    beamAttachment1.Name = "BeamAttachment1"
    beamAttachment1.Parent = diamond
    beamAttachment1.Position = Vector3.new(0, 0, 0) -- Center of diamond
    
    -- Beam (red color)
    beam = Instance.new("Beam")
    beam.Attachment0 = beamAttachment0
    beam.Attachment1 = beamAttachment1
    beam.Color = ColorSequence.new(COLORS.Red)
    beam.Width0 = 0.25 -- Thinner to represent raycast width
    beam.Width1 = 0.25
    beam.FaceCamera = true
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0)
    })
    beam.Parent = hrp
end

local function destroyBeam()
    if beam then
        beam:Destroy()
        beam = nil
    end
    if beamAttachment0 then
        beamAttachment0:Destroy()
        beamAttachment0 = nil
    end
    if beamAttachment1 then
        beamAttachment1:Destroy()
        beamAttachment1 = nil
    end
end

local function updateVisuals()
    if not CONFIG.ENABLED then
        destroyBeam()
        destroyIndicator()
        return
    end
    
    local character = S.LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Use saved position
    if not CONFIG.SAVED_POSITION then
        destroyBeam()
        destroyIndicator()
        return
    end
    
    local tpPosition = CONFIG.SAVED_POSITION.Position
    
    createIndicator()
    updateIndicator(tpPosition)
    
    -- Update diamond color (red)
    if diamond then
        diamond.Color = COLORS.Red
    end
    
    -- Create or update beam
    if not beam then
        createBeam()
    else
        -- Update beam attachment if diamond exists
        if diamond and beamAttachment1 then
            if beamAttachment1.Parent ~= diamond then
                beamAttachment1.Parent = diamond
            end
            beamAttachment1.Position = Vector3.new(0, 0, 0) -- Center of diamond
        end
    end
    
    -- Beam is always red
    if beam then
        beam.Color = ColorSequence.new(COLORS.Red)
    end
end

local function findClosestPosition()
    local hrp = S.LocalPlayer.Character and S.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local closestDist = math.huge
    local closestPos = nil
    for _, v in ipairs(targetPositions) do
        local dist = (hrp.Position - v).Magnitude
        if dist < closestDist then
            closestDist = dist
            closestPos = v
        end
    end
    return closestPos and CFrame.new(closestPos) or nil
end

local function performTeleport(pos1)
    local character = S.LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Calculate pos2 BEFORE first teleport (from original position where you're stealing from)
    local pos2 = findClosestPosition()
    
    -- Double teleport bypass (exactly like leak script - simple and fast)
    if pos1 then hrp.CFrame = pos1 end
    if pos2 then task.wait(0.05); hrp.CFrame = pos2 end
end

local promptConnection = nil

local function equipCarpet()
    -- Carpet equip logic (exactly like leak script)
    local backpack = S.LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        local carpet = backpack:FindFirstChild("Flying Carpet")
        if carpet and S.LocalPlayer.Character and S.LocalPlayer.Character:FindFirstChild("Humanoid") then
            S.LocalPlayer.Character.Humanoid:EquipTool(carpet)
        end
    end
end

local function enablePromptDetection()
    if promptConnection then return end
    
    -- TP when hold ends (exactly like leak script)
    promptConnection = S.ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, who)
        if who ~= S.LocalPlayer then return end
        if prompt.Name ~= "Steal" and prompt.ActionText ~= "Steal" then return end
        if not CONFIG.ENABLED then return end
        
        local hrp = S.LocalPlayer.Character and S.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        -- Equip carpet (exactly like leak script - inside PromptButtonHoldEnded)
        equipCarpet()
        
        -- Perform teleport with exact bypass logic (pos1 = saved position, pos2 = closest hardcoded)
        performTeleport(CONFIG.SAVED_POSITION)
    end)
end

local function disablePromptDetection()
    if promptConnection then
        promptConnection:Disconnect()
        promptConnection = nil
    end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MeloskaHub"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = S.PlayerGui

local mainFrame = nil
local isDragging = false
local dragStart = nil
local dragStartPos = nil

local function createGUI()
    if mainFrame then
        mainFrame:Destroy()
    end
    
    local isMobile = S.UserInputService.TouchEnabled and not S.UserInputService.KeyboardEnabled
    local containerWidth = isMobile and 200 or 230
    local COLLAPSED_HEIGHT = 38
    local EXPANDED_HEIGHT = isMobile and 110 or 130
    local containerHeight = CONFIG.GUI_COLLAPSED and COLLAPSED_HEIGHT or EXPANDED_HEIGHT
    
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, containerWidth, 0, containerHeight)
    
    if CONFIG.GUI_POSITION_X and CONFIG.GUI_POSITION_Y then
        mainFrame.Position = UDim2.new(0, CONFIG.GUI_POSITION_X, 0, CONFIG.GUI_POSITION_Y)
        mainFrame.AnchorPoint = Vector2.new(0, 0)
    else
        mainFrame.Position = UDim2.new(0.5, 0, 0, 150)
        mainFrame.AnchorPoint = Vector2.new(0.5, 0)
    end
    
    mainFrame.BackgroundColor3 = COLORS.Surface
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.ZIndex = 999
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.Accent
    stroke.Thickness = 1.5
    stroke.Transparency = 0.5
    stroke.Parent = mainFrame
    
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.Parent = mainFrame
    
    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 18)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    header.BackgroundTransparency = 0.9
    header.BorderSizePixel = 0
    header.ZIndex = 1000
    header.Parent = mainFrame
    
    local headerGradient = Instance.new("UIGradient")
    headerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 120, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 80, 200))
    })
    headerGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.9),
        NumberSequenceKeypoint.new(1, 0.9)
    })
    headerGradient.Parent = header
    
    -- Collapse button
    local collapseBtn = Instance.new("TextButton")
    collapseBtn.Name = "CollapseBtn"
    collapseBtn.Size = UDim2.new(0, 28, 0, 18)
    collapseBtn.Position = UDim2.new(0, 0, 0, 0)
    collapseBtn.BackgroundTransparency = 1
    collapseBtn.Text = CONFIG.GUI_COLLAPSED and "â–²" or "â–¼"
    collapseBtn.TextColor3 = Color3.fromRGB(107, 155, 199)
    collapseBtn.TextSize = 18
    collapseBtn.Font = Enum.Font.GothamBold
    collapseBtn.ZIndex = 1003
    collapseBtn.Parent = header
    
    collapseBtn.MouseButton1Click:Connect(function()
        CONFIG.GUI_COLLAPSED = not CONFIG.GUI_COLLAPSED
        collapseBtn.Text = CONFIG.GUI_COLLAPSED and "â–²" or "â–¼"
        saveConfig()
        
        -- Smooth collapse animation (like NO_TOOL_DESYNC and PVP scripts)
        local targetHeight = CONFIG.GUI_COLLAPSED and COLLAPSED_HEIGHT or EXPANDED_HEIGHT
        local contentWrapper = mainFrame:FindFirstChild("ContentWrapper")
        
        -- Animate size change
        local collapseTween = S.TweenService:Create(
            mainFrame,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, containerWidth, 0, targetHeight)}
        )
        collapseTween:Play()
        
        -- Toggle content visibility
        if contentWrapper then
            contentWrapper.Visible = not CONFIG.GUI_COLLAPSED
        end
    end)
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -75, 1, 0)
    title.Position = UDim2.new(0, 30, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Instant TP"
    title.TextColor3 = COLORS.Accent
    title.TextSize = 11
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 1001
    title.Parent = header
    
    -- Drag handle
    local dragHandle = Instance.new("TextButton")
    dragHandle.Size = UDim2.new(1, -28, 1, 0)
    dragHandle.Position = UDim2.new(0, 28, 0, 0)
    dragHandle.BackgroundTransparency = 1
    dragHandle.Text = ""
    dragHandle.ZIndex = 1002
    dragHandle.Parent = header
    
    -- Drag functionality
    local function startDrag(input)
        isDragging = true
        dragStart = input.Position
        dragStartPos = mainFrame.Position
    end
    
    local function updateDrag(input)
        if not isDragging then return end
        local delta = input.Position - dragStart
        local newPos = UDim2.new(
            dragStartPos.X.Scale,
            dragStartPos.X.Offset + delta.X,
            dragStartPos.Y.Scale,
            dragStartPos.Y.Offset + delta.Y
        )
        mainFrame.Position = newPos
        CONFIG.GUI_POSITION_X = newPos.X.Offset
        CONFIG.GUI_POSITION_Y = newPos.Y.Offset
    end
    
    local function endDrag()
        if isDragging then
            isDragging = false
            saveConfig()
        end
    end
    
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input)
        end
    end)
    
    S.UserInputService.InputChanged:Connect(function(input)
        if isDragging then
            updateDrag(input)
        end
    end)
    
    S.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)
    
    -- Content wrapper
    local contentWrapper = Instance.new("Frame")
    contentWrapper.Name = "ContentWrapper"
    contentWrapper.Size = UDim2.new(1, 0, 1, -18)
    contentWrapper.Position = UDim2.new(0, 0, 0, 18)
    contentWrapper.BackgroundTransparency = 1
    contentWrapper.ClipsDescendants = true
    contentWrapper.Visible = not CONFIG.GUI_COLLAPSED
    contentWrapper.Parent = mainFrame
    
    -- Enable button
    local enableBtn = Instance.new("TextButton")
    enableBtn.Name = "EnableBtn"
    enableBtn.Size = UDim2.new(1, 0, 0, 30)
    enableBtn.Position = UDim2.new(0, 0, 0, 0)
    enableBtn.BackgroundColor3 = CONFIG.ENABLED and COLORS.Success or COLORS.Accent
    enableBtn.BackgroundTransparency = 0.88
    enableBtn.BorderSizePixel = 0
    enableBtn.Text = CONFIG.ENABLED and "Instant TP: ON" or "Instant TP: OFF"
    enableBtn.TextColor3 = CONFIG.ENABLED and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(0, 180, 255)
    enableBtn.TextSize = 10
    enableBtn.Font = Enum.Font.GothamBold
    enableBtn.ZIndex = 1001
    enableBtn.Parent = contentWrapper
    
    local enableCorner = Instance.new("UICorner")
    enableCorner.CornerRadius = UDim.new(0, 6)
    enableCorner.Parent = enableBtn
    
    local enableStroke = Instance.new("UIStroke")
    enableStroke.Color = CONFIG.ENABLED and COLORS.Success or COLORS.Accent
    enableStroke.Thickness = 1
    enableStroke.Transparency = 0.75
    enableStroke.Parent = enableBtn
    
    enableBtn.MouseButton1Click:Connect(function()
        CONFIG.ENABLED = not CONFIG.ENABLED
        saveConfig()
        
        if CONFIG.ENABLED then
            enableBtn.Text = "Instant TP: ON"
            enableBtn.BackgroundColor3 = COLORS.Success
            enableBtn.TextColor3 = Color3.fromRGB(80, 200, 80)
            enableStroke.Color = COLORS.Success
            enablePromptDetection()
            updateVisuals()
        else
            enableBtn.Text = "Instant TP: OFF"
            enableBtn.BackgroundColor3 = COLORS.Accent
            enableBtn.TextColor3 = Color3.fromRGB(0, 180, 255)
            enableStroke.Color = COLORS.Accent
            disablePromptDetection()
            destroyBeam()
            destroyIndicator()
        end
    end)
    
    -- Save Position button
    local savePosBtn = Instance.new("TextButton")
    savePosBtn.Name = "SavePosBtn"
    savePosBtn.Size = UDim2.new(1, 0, 0, 30)
    savePosBtn.Position = UDim2.new(0, 0, 0, 40)
    savePosBtn.BackgroundColor3 = COLORS.Accent
    savePosBtn.BackgroundTransparency = 0.88
    savePosBtn.BorderSizePixel = 0
    savePosBtn.Text = "Save Position"
    savePosBtn.TextColor3 = Color3.fromRGB(0, 180, 255)
    savePosBtn.TextSize = 10
    savePosBtn.Font = Enum.Font.GothamBold
    savePosBtn.ZIndex = 1001
    savePosBtn.Parent = contentWrapper
    
    local savePosCorner = Instance.new("UICorner")
    savePosCorner.CornerRadius = UDim.new(0, 6)
    savePosCorner.Parent = savePosBtn
    
    local savePosStroke = Instance.new("UIStroke")
    savePosStroke.Color = COLORS.Accent
    savePosStroke.Thickness = 1
    savePosStroke.Transparency = 0.75
    savePosStroke.Parent = savePosBtn
    
    savePosBtn.MouseButton1Click:Connect(function()
        local character = S.LocalPlayer.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                CONFIG.SAVED_POSITION = hrp.CFrame
                saveConfig()
                updateVisuals()
            end
        end
    end)
end

createGUI()

if CONFIG.ENABLED then
    enablePromptDetection()
    updateVisuals()
end

-- Update visuals periodically
S.RunService.Heartbeat:Connect(function()
    if CONFIG.ENABLED then
        updateVisuals()
    end
end)

-- Cleanup on respawn
S.LocalPlayer.CharacterAdded:Connect(function()
    -- Destroy old beam and indicators (they're attached to old character)
    destroyBeam()
    destroyIndicator()
    
    task.wait(0.5)
    if CONFIG.ENABLED then
        updateVisuals()
    end
end)
