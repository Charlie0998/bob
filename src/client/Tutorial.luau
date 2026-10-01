-- First-time tutorial: an animated hint card (pops in, types out its text,
-- bobs, shows step dots) with a Skip button, a big bouncing arrow over the
-- thing to tap, a pulsing ring on the ground under it, and a sparkly guide
-- line from the player to it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Balance)
local SoundFX = require(script.Parent.SoundFX)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local COLORS = UIKit.COLORS

local HINTS = {
	"Tap the glowing shell under the arrow to plant your first coral!",
	"Your coral is growing! When it says Ready, tap it to collect pearls.",
	"Save up pearls, then tap the giant clam to unlock a new slot.",
	"Follow the brick path to the Market for rare corals and deals!",
}

local Tutorial = {}

local function ownedTiles(): { BasePart }
	local list = {}
	for _, tile in CollectionService:GetTagged("ReefSlot") do
		if tile:GetAttribute("OwnerId") == player.UserId then
			table.insert(list, tile)
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Slot") or 0) < (b:GetAttribute("Slot") or 0)
	end)
	return list
end

-- Where the arrow points for each step.
local function target(step: number): Vector3?
	if step == 0 or step == 1 then
		for _, tile in ownedTiles() do
			local planted = (tile:GetAttribute("CoralType") or "") ~= ""
			if (step == 0 and not planted) or (step == 1 and planted) then
				return tile.Position + Vector3.new(0, if step == 1 then 5 else 1, 0)
			end
		end
	elseif step == 2 then
		for _, pad in CollectionService:GetTagged("ReefBuyPad") do
			if pad:GetAttribute("OwnerId") == player.UserId then
				return pad.Position
			end
		end
	elseif step == 3 then
		local a = math.rad(Balance.world.plaza.angle)
		return Vector3.new(math.cos(a), 0, math.sin(a)) * Balance.world.plaza.radius + Vector3.new(0, 4, 0)
	end
	return nil
end

function Tutorial.start(gui: ScreenGui, remotes: Instance)
	local remote = remotes:WaitForChild("Tutorial") :: RemoteEvent

	local cardScale = UIKit.make("UIScale", {})
	local card = UIKit.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -76),
		Size = UDim2.fromOffset(380, 78),
		Visible = false,
		Parent = gui,
	}, { cardScale })
	UIKit.gloss(card, COLORS.panel, 14)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = COLORS.gold
	end
	local stepLabel = UIKit.label("", { Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(120, 16), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	local text = UIKit.label("", { Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -96, 0, 38), TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	local skip = UIKit.button("Skip", "muted", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(70, 34), TextSize = 14, Parent = card })
	skip.Activated:Connect(function()
		remote:FireServer("skip")
	end)
	-- One dot per step: filled gold when done, pulsing on the current one.
	local dots: { Frame } = {}
	for i = 1, #HINTS do
		dots[i] = UIKit.make("Frame", {
			Position = UDim2.fromOffset(12 + (i - 1) * 18, 64),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = COLORS.muted,
			Parent = card,
		}, { UIKit.make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end

	-- The arrow: a gold shaft with a stepped point, bobbing and spinning.
	local arrow = Instance.new("Model")
	arrow.Name = "TutorialArrow"
	local arrowParts: { BasePart } = {}
	local offsets: { CFrame } = {}
	local function arrowPart(size: Vector3, offset: CFrame)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = COLORS.gold
		p.Parent = arrow
		table.insert(arrowParts, p)
		table.insert(offsets, offset * CFrame.Angles(0, 0, math.pi / 2))
	end
	arrowPart(Vector3.new(3, 0.7, 0.7), CFrame.new(0, 3.5, 0))
	for i = 0, 3 do
		arrowPart(Vector3.new(0.5, 2.4 - i * 0.6, 2.4 - i * 0.6), CFrame.new(0, 1.8 - i * 0.5, 0))
	end
	local light = Instance.new("PointLight")
	light.Color = COLORS.gold
	light.Range = 10
	light.Parent = arrowParts[1]

	-- A glowing guide line from the player to the target.
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(COLORS.gold)
	beam.LightEmission = 1
	beam.Width0 = 0.4
	beam.Width1 = 0.4
	beam.FaceCamera = true
	beam.Transparency = NumberSequence.new(0.2, 0.6)
	-- Sparkles stream along the line toward the target, in a gentle arc.
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 3
	beam.TextureSpeed = -1.5
	beam.CurveSize0 = 4
	beam.Segments = 20
	beam.Parent = anchor

	-- A ring on the ground under the target that grows and fades, over and over.
	local ring = Instance.new("Part")
	ring.Name = "TutorialRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = COLORS.gold
	ring.Parent = arrow

	local function step(): number
		return player:GetAttribute("TutorialStep") or #HINTS
	end

	local shownStep = -1
	local function refresh()
		local s = step()
		local active = s < #HINTS
		arrow.Parent = if active then workspace else nil
		anchor.Parent = if active then workspace else nil
		if not active then
			if card.Visible then
				-- All done: the card shrinks away.
				local tween = TweenService:Create(cardScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
				tween.Completed:Once(function()
					card.Visible = step() < #HINTS
				end)
				tween:Play()
			end
			return
		end
		if s == shownStep then
			return
		end
		if shownStep >= 0 then
			SoundFX.play("level_up")
		end
		shownStep = s
		card.Visible = true
		stepLabel.Text = string.format("Step %d of %d", s + 1, #HINTS)
		-- Pop in, then type the hint out letter by letter.
		cardScale.Scale = 0.6
		TweenService:Create(cardScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		text.Text = HINTS[s + 1]
		text.MaxVisibleGraphemes = 0
		TweenService:Create(text, TweenInfo.new(#text.Text / 45, Enum.EasingStyle.Linear), { MaxVisibleGraphemes = #text.Text }):Play()
		for i, dot in dots do
			dot.Size = UDim2.fromOffset(10, 10)
			TweenService:Create(dot, TweenInfo.new(0.3), { BackgroundColor3 = if i <= s + 1 then COLORS.gold else COLORS.muted }):Play()
		end
	end
	player:GetAttributeChangedSignal("TutorialStep"):Connect(refresh)
	refresh()

	RunService.RenderStepped:Connect(function()
		if not arrow.Parent then
			return
		end
		local position = target(step())
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not position or not root then
			arrow.Parent = nil
			return
		end
		local t = os.clock()
		-- The card bobs gently, the current step's dot and the border pulse.
		card.Position = UDim2.new(0.5, 0, 1, -76 + math.sin(t * 2) * 3)
		local pulse = (math.sin(t * 4) + 1) / 2
		if stroke then
			stroke.Transparency = pulse * 0.5
		end
		local current = dots[step() + 1]
		if current then
			current.Size = UDim2.fromOffset(10 + pulse * 3, 10 + pulse * 3)
		end
		local grow = (t * 0.8) % 1
		-- Just above the surface under each target: slot shell, clam pad, plaza floor.
		local ringY = ({ 1.55, 1.55, 1.15, 0.65 })[step() + 1] or 0.65
		ring.Size = Vector3.new(0.2, 3 + grow * 6, 3 + grow * 6)
		ring.CFrame = CFrame.new(position.X, ringY, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = 0.3 + grow * 0.7
		local base = CFrame.new(position + Vector3.new(0, 3 + math.sin(t * 4) * 0.6, 0)) * CFrame.Angles(0, t * 2, 0)
		local frames = {}
		for i in arrowParts do
			frames[i] = base * offsets[i]
		end
		workspace:BulkMoveTo(arrowParts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		anchor.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
		local rootAttachment = root:FindFirstChild("TutorialAttachment") :: Attachment?
		if not rootAttachment then
			local made = Instance.new("Attachment")
			made.Name = "TutorialAttachment"
			made.Parent = root
			rootAttachment = made
		end
		beam.Attachment0 = rootAttachment
	end)
	-- Re-show the arrow once its target exists again (e.g. after respawning).
	task.spawn(function()
		while true do
			task.wait(1)
			if card.Visible and not arrow.Parent then
				arrow.Parent = workspace
			end
		end
	end)
end

-- The Market reports that it was opened (tutorial step 4).
function Tutorial.marketOpened(remotes: Instance)
	if (player:GetAttribute("TutorialStep") or 99) == 3 then
		(remotes:WaitForChild("Tutorial") :: RemoteEvent):FireServer("market")
	end
end

return Tutorial
