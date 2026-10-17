local repo = "https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/"

local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Options = Library.Options
local Toggles = Library.Toggles

Library.ShowToggleFrameInKeybinds = true
Library.ShowCustomCursor = true
Library.NotifySide = "Left"

-- Window

local Window = Library:CreateWindow({
    Title = "Cat's Admin Panel",
    Center = true,
    AutoShow = true,
    Resizable = true,
    ShowCustomCursor = true,
    UnlockMouseWhileOpen = true,
    NotifySide = "Left",
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Players = Window:AddTab("Players"),
    Movement = Window:AddTab("Movement"),
    Utilities = Window:AddTab("Utilities"),
    Settings = Window:AddTab("Settings")
}

-- Character helpers

local function getCharacter()
    local character = player.Character
    if not character then return nil end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then return nil end
    return character, humanoid, root
end

-- MOVEMENT

local MoveBox = Tabs.Movement:AddLeftGroupbox("Movement")

local flightActive = false
local flightConnection
local flightVelocity
local flightAttachment
local flightHumanoid
local flightCharacter
local flightAnimate
local oldAnimateDisabled
local oldAutoRotate
local oldPlatformStand
local oldTracks = {}

local function stopFly()
    flightActive = false

    if flightConnection then
        flightConnection:Disconnect()
        flightConnection = nil
    end

    if flightVelocity then
        flightVelocity:Destroy()
        flightVelocity = nil
    end

    if flightAttachment then
        flightAttachment:Destroy()
        flightAttachment = nil
    end

    if flightHumanoid and flightHumanoid.Parent then
        flightHumanoid.AutoRotate = oldAutoRotate
        flightHumanoid.PlatformStand = oldPlatformStand
    end

    if flightAnimate and flightAnimate.Parent then
        flightAnimate.Disabled = oldAnimateDisabled
    end

    for _, data in ipairs(oldTracks) do
        if data.wasPlaying and data.track.Parent then
            data.track:Play(0.15)
        end
    end

    table.clear(oldTracks)
    flightHumanoid = nil
    flightCharacter = nil
    flightAnimate = nil
end

local function startFly()
    if flightActive then return end

    local character, humanoid, root = getCharacter()
    if not character then
        Library:Notify("Character is not ready yet.")
        return
    end

    flightActive = true
    flightCharacter = character
    flightHumanoid = humanoid

    oldAutoRotate = humanoid.AutoRotate
    oldPlatformStand = humanoid.PlatformStand

    flightAnimate = character:FindFirstChild("Animate")
    oldAnimateDisabled = flightAnimate and flightAnimate.Disabled

    humanoid.AutoRotate = false
    humanoid.PlatformStand = true

    if flightAnimate then
        flightAnimate.Disabled = true
    end

    local animator = humanoid:FindFirstChildOfClass("Animator")

    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            table.insert(oldTracks, {
                track = track,
                wasPlaying = track.IsPlaying
            })
            track:Stop(0.15)
        end
    end

    flightAttachment = Instance.new("Attachment")
    flightAttachment.Name = "ClassicFlightAttachment"
    flightAttachment.Parent = root

    flightVelocity = Instance.new("LinearVelocity")
    flightVelocity.Name = "ClassicFlightVelocity"
    flightVelocity.Attachment0 = flightAttachment
    flightVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    flightVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    flightVelocity.MaxForce = 1000000
    flightVelocity.VectorVelocity = Vector3.zero
    flightVelocity.Parent = root

    flightConnection = RunService.RenderStepped:Connect(function()
        if not flightActive or not root.Parent or not humanoid.Parent then
            stopFly()
            return
        end

        local camera = workspace.CurrentCamera
        if not camera then return end

        local look = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector

        local flatForward = Vector3.new(look.X, 0, look.Z)
        local flatRight = Vector3.new(right.X, 0, right.Z)

        if flatForward.Magnitude > 0.001 then
            flatForward = flatForward.Unit
        else
            flatForward = Vector3.new(0, 0, -1)
        end

        if flatRight.Magnitude > 0.001 then
            flatRight = flatRight.Unit
        else
            flatRight = Vector3.new(1, 0, 0)
        end

        local move = humanoid.MoveDirection
        local forwardInput = move:Dot(flatForward)
        local sideInput = move:Dot(flatRight)

        local direction = look * forwardInput + flatRight * sideInput

        if direction.Magnitude > 1 then
            direction = direction.Unit
        end

        flightVelocity.VectorVelocity = direction * 60

        local facing = Vector3.new(look.X, 0, look.Z)
        if facing.Magnitude > 0.001 then
            local target = CFrame.lookAt(
                root.Position,
                root.Position + facing.Unit
            )
            root.CFrame = root.CFrame:Lerp(target, 0.25)
        end
    end)
end

MoveBox:AddToggle("Fly", {
    Text = "Fly",
    Default = false,
    Callback = function(value)
        if value then
            startFly()
        else
            stopFly()
        end
    end
})

MoveBox:AddSlider("WalkSpeed", {
    Text = "Walk Speed",
    Default = 16,
    Min = 0,
    Max = 200,
    Rounding = 0,
    Suffix = " studs/s",
    Callback = function(value)
        local _, humanoid = getCharacter()
        if humanoid then
            humanoid.WalkSpeed = value
        end
    end
})

MoveBox:AddSlider("JumpBoost", {
    Text = "Jump Boost",
    Default = 50,
    Min = 0,
    Max = 200,
    Rounding = 0,
    Callback = function(value)
        local _, humanoid = getCharacter()
        if humanoid then
            humanoid.UseJumpPower = true
            humanoid.JumpPower = value
        end
    end
})

-- NOCLIP

local NoclipBox = Tabs.Movement:AddRightGroupbox("Collision")

local noclipConnection
local savedCollisions = {}

local function stopNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    for part, oldValue in pairs(savedCollisions) do
        if part and part.Parent then
            part.CanCollide = oldValue
        end
    end

    table.clear(savedCollisions)
end

local function startNoclip()
    if noclipConnection then return end

    noclipConnection = RunService.Stepped:Connect(function()
        local character = player.Character
        if not character then return end

        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if savedCollisions[part] == nil then
                    savedCollisions[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    end)
end

NoclipBox:AddToggle("Noclip", {
    Text = "Noclip",
    Default = false,
    Callback = function(value)
        if value then
            startNoclip()
        else
            stopNoclip()
        end
    end
})

-- AUTO JUMP

local JumpBox = Tabs.Movement:AddLeftGroupbox("Auto Jump")

local autoJumpActive = false
local autoJumpToken = 0

JumpBox:AddToggle("AutoJump", {
    Text = "Auto Jump",
    Default = false,
    Callback = function(value)
        autoJumpActive = value
        autoJumpToken += 1

        local myToken = autoJumpToken

        if value then
            task.spawn(function()
                while autoJumpActive and autoJumpToken == myToken do
                    local _, humanoid = getCharacter()

                    if humanoid then
                        humanoid:ChangeState(
                            Enum.HumanoidStateType.Jumping
                        )
                    end

                    task.wait(Options.JumpDelay.Value)
                end
            end)
        end
    end
})

JumpBox:AddSlider("JumpDelay", {
    Text = "Jump Delay",
    Default = 5,
    Min = 0.5,
    Max = 10,
    Rounding = 1,
    Suffix = " sec"
})

-- PLAYER TELEPORT

local PlayerBox = Tabs.Players:AddLeftGroupbox("Teleport")

PlayerBox:AddDropdown("TargetPlayer", {
    SpecialType = "Player",
    ExcludeLocalPlayer = true,
    Text = "Select Player",
    Tooltip = "Choose the player you want to teleport beside.",
    Callback = function(value)
        -- The selected player is read by the Teleport button.
    end
})

PlayerBox:AddButton({
    Text = "Teleport to Player",
    Func = function()
        local selected = Options.TargetPlayer.Value

        if not selected then
            Library:Notify("Select a player first.")
            return
        end

        local target

        if typeof(selected) == "Instance" and selected:IsA("Player") then
            target = selected
        else
            target = Players:FindFirstChild(tostring(selected))
        end

        if not target or target == player then
            Library:Notify("That player is unavailable.")
            return
        end

        local targetCharacter = target.Character
        local targetRoot = targetCharacter
            and targetCharacter:FindFirstChild("HumanoidRootPart")

        local character = player.Character
        local ownRoot = character
            and character:FindFirstChild("HumanoidRootPart")

        if not targetRoot or not ownRoot then
            Library:Notify("A character is not ready.")
            return
        end

        character:PivotTo(targetRoot.CFrame * CFrame.new(3, 0, 0))
        Library:Notify("Teleport attempted.")
    end
})

-- Keep the player dropdown updated as players join or leave.
local function refreshPlayerDropdown()
    if Options.TargetPlayer and Options.TargetPlayer.SetValues then
        local names = {}

        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                table.insert(names, otherPlayer.Name)
            end
        end

        Options.TargetPlayer:SetValues(names)
    end
end

Players.PlayerAdded:Connect(function()
    task.wait(0.2)
    refreshPlayerDropdown()
end)

Players.PlayerRemoving:Connect(function()
    task.defer(refreshPlayerDropdown)
end)

refreshPlayerDropdown()

-- UTILITIES

local UtilityBox = Tabs.Utilities:AddLeftGroupbox("Utilities")

UtilityBox:AddButton({
    Text = "Reset Character",
    Func = function()
        local character, humanoid = getCharacter()

        if humanoid then
            humanoid.Health = 0
        end
    end
})

UtilityBox:AddButton({
    Text = "Reapply Movement Settings",
    Func = function()
        local _, humanoid = getCharacter()
        if not humanoid then
            Library:Notify("Character is not ready.")
            return
        end

        humanoid.WalkSpeed = Options.WalkSpeed.Value
        humanoid.UseJumpPower = true
        humanoid.JumpPower = Options.JumpBoost.Value

        Library:Notify("Movement settings applied.")
    end
})

-- Reapply sliders after respawning.
player.CharacterAdded:Connect(function(character)
    task.wait(0.5)

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    humanoid.WalkSpeed = Options.WalkSpeed.Value
    humanoid.UseJumpPower = true
    humanoid.JumpPower = Options.JumpBoost.Value

    if Toggles.Noclip and Toggles.Noclip.Value then
        stopNoclip()
        startNoclip()
    end
end)

-- SETTINGS

local AboutBox = Tabs.Settings:AddLeftGroupbox("About")

AboutBox:AddLabel("Cat's Admin Panel")
AboutBox:AddLabel("Version: 1.0.0")
AboutBox:AddLabel("Creator: Cat")
AboutBox:AddLabel("Built with LinoriaLib")

local MenuGroup = Tabs.Settings:AddRightGroupbox("Menu")

MenuGroup:AddToggle("KeybindMenuOpen", {
    Text = "Open Keybind Menu",
    Default = Library.KeybindFrame.Visible,
    Callback = function(value)
        Library.KeybindFrame.Visible = value
    end
})

MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor",
    Default = true,
    Callback = function(value)
        Library.ShowCustomCursor = value
    end
})

MenuGroup:AddDivider()

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu keybind"
})

MenuGroup:AddButton({
    Text = "Unload",
    Func = function()
        Library:Unload()
    end
})

Library.ToggleKeybind = Options.MenuKeybind

-- THEME AND CONFIGURATION

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})

ThemeManager:SetFolder("CatsAdminPanel")
SaveManager:SetFolder("CatsAdminPanel")
SaveManager:SetSubFolder("specific-game")

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

SaveManager:LoadAutoloadConfig()

-- WATERMARK

Library:SetWatermarkVisibility(true)

local frameTimer = tick()
local frameCounter = 0
local fps = 60

local watermarkConnection = RunService.RenderStepped:Connect(function()
    frameCounter += 1

    if tick() - frameTimer >= 1 then
        fps = frameCounter
        frameTimer = tick()
        frameCounter = 0
    end

    Library:SetWatermark(
        ("Cat's Admin Panel | %d FPS"):format(math.floor(fps))
    )
end)

Library:OnUnload(function()
    stopFly()
    stopNoclip()
    autoJumpActive = false
    autoJumpToken += 1

    if watermarkConnection then
        watermarkConnection:Disconnect()
    end

    print("Cat's Admin Panel unloaded.")
end)

Library:Notify("Cat's Admin Panel loaded.")