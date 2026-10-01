-- Photo mode: hides every UI and label, offers a few camera angles around
-- the player (plus a slow orbit), and saves a screenshot to the device
-- gallery where Roblox supports it.

local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Offsets from the player: distance back, height, and how far above the
-- player to look.
local ANGLES = {
	{ name = "Wide", back = 34, up = 16, look = 2 },
	{ name = "Top", back = 4, up = 42, look = 0 },
	{ name = "Low", back = 14, up = 2.5, look = 4 },
	{ name = "Close", back = 9, up = 5, look = 2 },
}

local PhotoMode = {}

function PhotoMode.start(hud: ScreenGui): () -> ()
	local controls = UIKit.make("ScreenGui", {
		Name = "PhotoControls",
		ResetOnSpawn = false,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local bar = UIKit.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(4 * 128, 52),
		BackgroundTransparency = 1,
		Parent = controls,
	}, {
		UIKit.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
	})
	local angleButton = UIKit.button("Angle: Wide", "accent", { Size = UDim2.fromOffset(120, 48), Parent = bar })
	local orbitButton = UIKit.button("Orbit: off", "muted", { Size = UDim2.fromOffset(120, 48), Parent = bar })
	local snapButton = UIKit.button("Save photo", "gold", { Size = UDim2.fromOffset(120, 48), Parent = bar })
	local exitButton = UIKit.button("Exit", "muted", { Size = UDim2.fromOffset(120, 48), Parent = bar })

	local active = false
	local angleIndex = 1
	local orbit = false
	local yaw = 0
	local hidden: { BillboardGui } = {}
	local connection: RBXScriptConnection? = nil

	local function focus(): Vector3
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return if root then root.Position else Vector3.zero
	end

	local function exit()
		if not active then
			return
		end
		active = false
		if connection then
			connection:Disconnect()
			connection = nil
		end
		controls.Enabled = false
		hud.Enabled = true
		for _, billboard in hidden do
			billboard.Enabled = true
		end
		table.clear(hidden)
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
		camera.CameraType = Enum.CameraType.Custom
	end

	local function enter()
		active = true
		hud.Enabled = false
		controls.Enabled = true
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
		for _, item in workspace:GetDescendants() do
			if item:IsA("BillboardGui") and item.Enabled then
				item.Enabled = false
				table.insert(hidden, item)
			end
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		yaw = if root then math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z) else 0
		camera.CameraType = Enum.CameraType.Scriptable
		connection = RunService.RenderStepped:Connect(function(dt)
			if orbit then
				yaw += dt * 0.25
			end
			local angle = ANGLES[angleIndex]
			local center = focus()
			local offset = CFrame.Angles(0, yaw, 0) * Vector3.new(0, angle.up, angle.back)
			camera.CFrame = CFrame.lookAt(center + offset, center + Vector3.new(0, angle.look, 0))
		end)
	end

	angleButton.Activated:Connect(function()
		angleIndex = angleIndex % #ANGLES + 1
		angleButton.Text = "Angle: " .. ANGLES[angleIndex].name
	end)
	orbitButton.Activated:Connect(function()
		orbit = not orbit
		orbitButton.Text = if orbit then "Orbit: on" else "Orbit: off"
	end)
	snapButton.Activated:Connect(function()
		-- Hide the controls for the shot, then bring them back.
		controls.Enabled = false
		task.wait(0.1)
		local ok = pcall(function()
			CaptureService:CaptureScreenshot(function(capture)
				controls.Enabled = active
				pcall(function()
					CaptureService:PromptSaveCapturesToGallery({ capture }, function() end)
				end)
			end)
		end)
		if not ok then
			controls.Enabled = active
			snapButton.Text = "Use device screenshot"
		end
	end)
	exitButton.Activated:Connect(exit)
	player.CharacterRemoving:Connect(exit)

	return function()
		if active then
			exit()
		else
			enter()
		end
	end
end

return PhotoMode
