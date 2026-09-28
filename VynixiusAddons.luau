if not getgc then
    return
end

local window = getgenv().VynixiusWindow
if not window then
    for _, obj in ipairs(getgc(true)) do
        if type(obj) == "table" then
            local hasAddTab = rawget(obj, "AddTab") ~= nil
            local hasAlwaysOnTop = rawget(obj, "SetAlwaysOnTop") ~= nil
            local hasAddKeyTab = rawget(obj, "AddKeyTab") ~= nil
            local hasCreateWindow = rawget(obj, "CreateWindow") ~= nil
            if hasAddTab and (hasAlwaysOnTop or hasAddKeyTab) and not hasCreateWindow then
                window = obj
                getgenv().VynixiusWindow = obj
                break
            end
        end
    end
end
if not window then return end

if getgenv().VynixiusAddonsLoaded then return end
getgenv().VynixiusAddonsLoaded = true

local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local starterGui = game:GetService("StarterGui")
local players = game:GetService("Players")

local tab = window:AddTab("Addons", "puzzle")
local infoTab = window:AddTab("Addon Info", "info")

local credits = infoTab:AddLeftGroupbox("Credits")
credits:AddLabel("Made by MorthenHubber", true)

local help = infoTab:AddRightGroupbox("How to add addons")
help:AddLabel("Open your executor folder, go into the Vynixius folder, then drop your addon file into the Addons folder inside it.", true)
help:AddLabel("Addons can be .lua, .luau, or .txt files.", true)

local api = {
    Tab = tab,
    Window = window,
    Player = players.LocalPlayer,
    Character = players.LocalPlayer.Character,
    RunService = runService,
    UserInputService = userInputService,
    AddLeftGroupbox = function(name) return tab:AddLeftGroupbox(name) end,
    AddRightGroupbox = function(name) return tab:AddRightGroupbox(name) end,
    Notify = function(title, desc)
        pcall(function()
            starterGui:SetCore("SendNotification", {
                Title = title,
                Text = desc,
                Duration = 5
            })
        end)
    end,
    Run = function(fn) return task.spawn(fn) end,
}

local loadedAddonNames = {}
local addonGroupboxes = {}

local function loadAddonFromPath(path)
    local ok, source = pcall(readfile, path)
    if not ok or type(source) ~= "string" or #source == 0 then
        return false, "read failed"
    end
    local fn = loadstring(source, "Addon_" .. path)
    if not fn then
        return false, "compile failed"
    end
    local okRun, addon = pcall(fn)
    if not okRun or type(addon) ~= "table" or type(addon.Init) ~= "function" then
        return false, "invalid addon"
    end
    local name = tostring(addon.Name or path)
    if loadedAddonNames[name] then
        return false, "already loaded"
    end

    local trackingApi = {}
    for k, v in pairs(api) do trackingApi[k] = v end
    trackingApi.AddLeftGroupbox = function(groupName)
        local g = tab:AddLeftGroupbox(groupName)
        table.insert(addonGroupboxes, g)
        return g
    end
    trackingApi.AddRightGroupbox = function(groupName)
        local g = tab:AddRightGroupbox(groupName)
        table.insert(addonGroupboxes, g)
        return g
    end

    local okInit, errInit = pcall(addon.Init, trackingApi, addon)
    if not okInit then
        return false, "init errored: " .. tostring(errInit)
    end
    loadedAddonNames[name] = true
    return true
end

local FS_ROOT = "Vynixius/Addons"

local hasFS = type(makefolder) == "function"
    and type(isfolder) == "function"
    and type(listfiles) == "function"
    and type(readfile) == "function"
    and type(writefile) == "function"

if hasFS then
    local function ensureFolder(path)
        if isfolder(path) then return true end
        pcall(makefolder, path)
        if isfolder(path) then return true end
        pcall(writefile, path .. "/.keep", "")
        return isfolder(path)
    end

    ensureFolder("Vynixius")
    ensureFolder(FS_ROOT)

    local function refreshAllAddons(force)
        if force then
            loadedAddonNames = {}
            for _, g in ipairs(addonGroupboxes) do
                pcall(function() g:Destroy() end)
            end
            addonGroupboxes = {}
        end

        local ok, fileList = pcall(listfiles, FS_ROOT)
        if not ok or type(fileList) ~= "table" then return 0, 0 end

        local loaded, failed = 0, 0
        for _, path in ipairs(fileList) do
            local lower = path:lower()
            if lower:match("%.lua$") or lower:match("%.luau$") or lower:match("%.txt$") then
                local ok2, reason = loadAddonFromPath(path)
                if ok2 then
                    loaded = loaded + 1
                elseif reason ~= "already loaded" then
                    failed = failed + 1
                    warn("Addon failed to load: " .. tostring(path) .. " - " .. tostring(reason))
                end
            end
        end
        return loaded, failed
    end

    refreshAllAddons(false)

    local reloadGroup = infoTab:AddRightGroupbox("Reload")
    reloadGroup:AddToggle("ReloadAddonsToggle", {
        Text = "Reload addons",
        Default = false,
        Callback = function(v)
            if v then
                refreshAllAddons(true)
                task.delay(1, function()
                    pcall(function() Toggles.ReloadAddonsToggle:SetValue(false) end)
                end)
            end
        end,
    })
end

local builtinAddons = {}

builtinAddons.Honcho = {
    Name = "Honcho",
    Author = "MorthenHubber",
    Description = "Become Honcho",
    Init = function(api)
        local morphGroup = api.AddLeftGroupbox("Morphs")
        local keysGroup = api.AddRightGroupbox("Honcho Keybinds")

        _G.honchoReplay = nil
        _G.honchoToggleAmb1 = nil
        _G.honchoToggleAmb2 = nil
        _G.honchoToggleAmb3 = nil

        keysGroup:AddLabel("Replay Animation"):AddKeyPicker("HonchoReplayKey", {
            Default = "B",
            Text = "Replay landing animation",
            Mode = "Press",
            Callback = function() if _G.honchoReplay then _G.honchoReplay() end end,
        })
        keysGroup:AddLabel("Ambience 1"):AddKeyPicker("HonchoAmbience1", {
            Default = "Z",
            Text = "Toggle ambience sound 1",
            Mode = "Press",
            Callback = function() if _G.honchoToggleAmb1 then _G.honchoToggleAmb1() end end,
        })
        keysGroup:AddLabel("Ambience 2"):AddKeyPicker("HonchoAmbience2", {
            Default = "X",
            Text = "Toggle ambience sound 2",
            Mode = "Press",
            Callback = function() if _G.honchoToggleAmb2 then _G.honchoToggleAmb2() end end,
        })
        keysGroup:AddLabel("Ambience 3"):AddKeyPicker("HonchoAmbience3", {
            Default = "V",
            Text = "Toggle ambience sound 3",
            Mode = "Press",
            Callback = function() if _G.honchoToggleAmb3 then _G.honchoToggleAmb3() end end,
        })

        local function becomeHoncho()
            local player = api.Player
            local modelId = 104515922403348
            local heightOffset = 3
            local idleAnimationId = 101907348895136
            local runAnimationId = 100466662502744
            local landingAnimationId = 91194170893496
            local landingSoundId = 82613796053949
            local impactSoundId = 74149238738530
            local ambienceSoundIds = {105438678078526, 92139743699536, 82618476532926}
            local landingCooldown = 10
            local toolGripOffset = CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(180), math.rad(0), math.rad(90))
            local isThirdPerson = false

            if _G.morphCleanup then pcall(_G.morphCleanup) end

            starterGui:SetCore("SendNotification", {
                Title = "Credits",
                Text = "Honcho morph made by MorthenHubber.",
                Duration = 5
            })

            task.wait(0.5)

            starterGui:SetCore("SendNotification", {
                Title = "Speed Bypass",
                Text = "Use Vynixius speed bypass and set speed to 45",
                Duration = 10
            })

            local function loadModel()
                local objects = game:GetObjects("rbxassetid://" .. modelId)
                return objects[1]
            end

            local morph = loadModel()
            if not morph then return end

            local originalCharacter = player.Character
            if not originalCharacter or not originalCharacter:FindFirstChild("HumanoidRootPart") then return end
            local originalRootPart = originalCharacter:FindFirstChild("HumanoidRootPart")
            local originalHumanoid = originalCharacter:FindFirstChildWhichIsA("Humanoid")
            local originalHeadPart = originalCharacter:FindFirstChild("Head")
            if not originalRootPart or not originalHumanoid then return end

            local originalWalkSpeed = originalHumanoid.WalkSpeed
            local originalJumpPower = originalHumanoid.JumpPower
            local originalJumpHeight = originalHumanoid.JumpHeight
            local lastLandingTime = 0

            local morphHumanoid = morph:FindFirstChildWhichIsA("Humanoid")
            if morphHumanoid then morphHumanoid:Destroy() end

            for _, part in ipairs(morph:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = false
                    part.CanCollide = false
                end
            end

            local morphRootPart = morph:FindFirstChild("HumanoidRootPart", true) or morph:FindFirstChild("RootPart", true)
            if not morphRootPart then
                morphRootPart = Instance.new("Part")
                morphRootPart.Name = "HumanoidRootPart"
                morphRootPart.Size = Vector3.new(2, 1, 1)
                morphRootPart.Anchored = false
                morphRootPart.CanCollide = false
                morphRootPart.Parent = morph
            end
            morph.PrimaryPart = morphRootPart

            local morphHeadPart = morph:FindFirstChild("Head", true)
            if not morphHeadPart then
                morphHeadPart = Instance.new("Part")
                morphHeadPart.Name = "Head"
                morphHeadPart.Size = Vector3.new(1, 1, 1)
                morphHeadPart.Anchored = false
                morphHeadPart.CanCollide = false
                morphHeadPart.Parent = morph
            end

            morph.Parent = workspace

            for _, part in ipairs(originalCharacter:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = 1
                    part.CanCollide = false
                end
            end

            local rootWeld = Instance.new("Weld")
            rootWeld.Part0 = originalRootPart
            rootWeld.Part1 = morphRootPart
            rootWeld.C0 = CFrame.new(0, heightOffset, 0)
            rootWeld.Parent = originalRootPart

            local headWeld = Instance.new("Weld")
            if originalHeadPart then headWeld.Part0 = originalHeadPart else headWeld.Part0 = originalRootPart end
            headWeld.Part1 = morphHeadPart
            local headWeldOffset = morphHeadPart.Position - (originalHeadPart and originalHeadPart.Position or originalRootPart.Position)
            headWeld.C0 = CFrame.new(headWeldOffset)
            headWeld.Parent = headWeld.Part0

            local camera = workspace.CurrentCamera
            if not camera then return end
            camera.CameraType = Enum.CameraType.Scriptable

            local enforceLoop = runService.RenderStepped:Connect(function()
                if rootWeld and rootWeld.Parent then
                    rootWeld.C0 = CFrame.new(0, heightOffset, 0)
                end
                if morphHeadPart and morphHeadPart:IsDescendantOf(workspace) then
                    local lookVector = camera.CFrame.LookVector
                    local upVector = camera.CFrame.UpVector
                    local headPos = morphHeadPart.Position
                    if isThirdPerson then
                        local camPos = headPos - (lookVector * 12) + Vector3.new(0, 2, 0)
                        camera.CFrame = CFrame.lookAt(camPos, headPos, upVector)
                    else
                        local offset = Vector3.new(0, 0.2, -0.5)
                        local targetPosition = morphHeadPart.CFrame:PointToWorldSpace(offset)
                        camera.CFrame = CFrame.lookAt(targetPosition, targetPosition + lookVector, upVector)
                    end
                end
                local morphRightHand = morph:FindFirstChild("RightHand", true)
                if originalCharacter and morphRightHand then
                    for _, tool in ipairs(originalCharacter:GetChildren()) do
                        if tool:IsA("Tool") then
                            local handle = tool:FindFirstChild("Handle")
                            if handle then
                                local defaultGrip = handle:FindFirstChild("RightGrip")
                                if defaultGrip then
                                    if defaultGrip:IsA("Motor6D") then defaultGrip.Enabled = false else defaultGrip:Destroy() end
                                end
                                local defaultLeftGrip = handle:FindFirstChild("LeftGrip")
                                if defaultLeftGrip then
                                    if defaultLeftGrip:IsA("Motor6D") then defaultLeftGrip.Enabled = false else defaultLeftGrip:Destroy() end
                                end
                                local morphWeld = handle:FindFirstChild("MorphWeld")
                                if not morphWeld then
                                    morphWeld = Instance.new("Weld")
                                    morphWeld.Name = "MorphWeld"
                                    morphWeld.Part0 = morphRightHand
                                    morphWeld.Part1 = handle
                                    morphWeld.C0 = toolGripOffset
                                    morphWeld.Parent = handle
                                elseif morphWeld.Part0 ~= morphRightHand then
                                    morphWeld.Part0 = morphRightHand
                                end
                            end
                        end
                    end
                end
            end)

            local animationController = morph:FindFirstChildWhichIsA("AnimationController") or morph:FindFirstChild("AnimationController", true)
            if not animationController then animationController = Instance.new("AnimationController", morph) end
            local animator = morph:FindFirstChildWhichIsA("Animator") or (animationController and animationController:FindFirstChildWhichIsA("Animator"))
            if not animator then animator = Instance.new("Animator", animationController) end

            local function createAnimation(id)
                local a = Instance.new("Animation")
                a.AnimationId = "rbxassetid://" .. id
                return a
            end
            local function playAnimation(anim, looped)
                local t = animator:LoadAnimation(anim)
                if t then t.Looped = looped or false t:Play() end
                return t
            end
            local function createSound(id)
                local s = Instance.new("Sound")
                s.SoundId = "rbxassetid://" .. id
                return s
            end
            local function playSound(s)
                if not s then return end
                s.Parent = morph or workspace
                s:Play()
            end

            local idleAnimation = createAnimation(idleAnimationId)
            local runAnimation = createAnimation(runAnimationId)
            local landingAnimation = createAnimation(landingAnimationId)
            local landingSound = createSound(landingSoundId)
            local impactSound = createSound(impactSoundId)

            local ambienceSounds = {}
            for i, id in ipairs(ambienceSoundIds) do
                local s = createSound(id)
                s.Looped = true
                ambienceSounds[i] = s
            end

            local footstepsSound = nil
            for _, child in ipairs(morph:GetDescendants()) do
                if child:IsA("Sound") and child.Name == "Footsteps" then footstepsSound = child break end
            end

            local currentAmbience = nil
            local movementEnabled = false
            local runTrack, idleTrack, landingTrack = nil, nil, nil
            local lastMoveState = nil

            local function replayLanding()
                if tick() - lastLandingTime < landingCooldown then return end
                lastLandingTime = tick()
                if landingTrack then landingTrack:Stop() end
                landingTrack = playAnimation(landingAnimation, false)
                playSound(landingSound)
                playSound(impactSound)
                movementEnabled = false
                originalHumanoid.WalkSpeed = 0
                originalHumanoid.JumpPower = 0
                if originalHumanoid.JumpHeight then originalHumanoid.JumpHeight = 0 end
                if landingTrack then
                    landingTrack.Stopped:Connect(function()
                        originalHumanoid.WalkSpeed = originalWalkSpeed
                        originalHumanoid.JumpPower = originalJumpPower
                        if originalHumanoid.JumpHeight then originalHumanoid.JumpHeight = originalJumpHeight end
                        movementEnabled = true
                        if not runTrack or not runTrack.IsPlaying then
                            idleTrack = playAnimation(idleAnimation, true)
                        end
                    end)
                else
                    originalHumanoid.WalkSpeed = originalWalkSpeed
                    originalHumanoid.JumpPower = originalJumpPower
                    if originalHumanoid.JumpHeight then originalHumanoid.JumpHeight = originalJumpHeight end
                    movementEnabled = true
                end
            end

            local function toggleAmbience(idx)
                local sound = ambienceSounds[idx]
                if not sound then return end
                if currentAmbience == sound then
                    sound:Stop()
                    currentAmbience = nil
                else
                    if currentAmbience then currentAmbience:Stop() end
                    playSound(sound)
                    currentAmbience = sound
                end
            end

            local cameraConn = userInputService.InputBegan:Connect(function(input, gp)
                if gp then return end
                if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.L then
                    isThirdPerson = not isThirdPerson
                end
            end)

            _G.honchoReplay = replayLanding
            _G.honchoToggleAmb1 = function() toggleAmbience(1) end
            _G.honchoToggleAmb2 = function() toggleAmbience(2) end
            _G.honchoToggleAmb3 = function() toggleAmbience(3) end

            replayLanding()

            local movementLoop = runService.RenderStepped:Connect(function()
                if not movementEnabled then return end
                local moveDirection = originalHumanoid.MoveDirection
                if not moveDirection then return end
                local moving = moveDirection.Magnitude > 0.1
                if moving then
                    if lastMoveState ~= "run" then
                        if idleTrack then idleTrack:Stop() end
                        runTrack = playAnimation(runAnimation, true)
                        lastMoveState = "run"
                    end
                    if footstepsSound and not footstepsSound.IsPlaying then footstepsSound:Play() end
                else
                    if lastMoveState ~= "idle" then
                        if runTrack then runTrack:Stop() end
                        idleTrack = playAnimation(idleAnimation, true)
                        lastMoveState = "idle"
                    end
                    if footstepsSound and footstepsSound.IsPlaying then footstepsSound:Stop() end
                end
            end)

            _G.morphCleanup = function()
                _G.honchoReplay = nil
                _G.honchoToggleAmb1 = nil
                _G.honchoToggleAmb2 = nil
                _G.honchoToggleAmb3 = nil
                if cameraConn then cameraConn:Disconnect() end
                if enforceLoop then enforceLoop:Disconnect() end
                if movementLoop then movementLoop:Disconnect() end
                if currentAmbience then currentAmbience:Stop() end
                if landingTrack then landingTrack:Stop() end
                if runTrack then runTrack:Stop() end
                if idleTrack then idleTrack:Stop() end
                if footstepsSound then footstepsSound:Stop() end
                if camera then camera.CameraType = Enum.CameraType.Custom end
                if originalCharacter then
                    for _, part in ipairs(originalCharacter:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Transparency = 0
                            part.CanCollide = true
                        end
                    end
                end
                if morph then morph:Destroy() end
                _G.morphCleanup = nil
            end
        end

        morphGroup:AddToggle("AddonsHoncho", {
            Text = "Become Honcho",
            Tooltip = "Rebind keys on the right. Credit: MorthenHubber",
            Default = false,
            Callback = function(v)
                if v then
                    task.spawn(becomeHoncho)
                else
                    if _G.morphCleanup then pcall(_G.morphCleanup) end
                end
            end
        })
    end
}

for _, addon in pairs(builtinAddons) do
    pcall(addon.Init, api, addon)
end