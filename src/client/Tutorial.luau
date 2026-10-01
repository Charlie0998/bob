-- First-time tutorial: a hint card with a Skip button, a big bouncing arrow
-- over the thing to tap, and a glowing guide line from the player to it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Balance)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local COLORS = UIKit.COLORS

local HINTS = {
	"Tap the sand slot under the arrow to plant a coral.",
	"Your coral is growing! Tap it when it says Ready to harvest pearls.",
	"Save up pearls, then tap the gold pad to unlock a new slot.",
	"Visit the Market at spawn for rare corals and deals!",
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

	local card = UIKit.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -76),
		Size = UDim2.fromOffset(360, 56),
		Visible = false,
		Parent = gui,
	})
	UIKit.gloss(card, COLORS.panel, 14)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = COLORS.gold
	end
	local text = UIKit.label("", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -96, 1, 0), TextSize = 15, Parent = card })
	local skip = UIKit.button("Skip", "muted", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(70, 34), TextSize = 14, Parent = card })
	skip.Activated:Connect(function()
		remote:FireServer("skip")
	end)

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
	beam.Parent = anchor

	local function step(): number
		return player:GetAttribute("TutorialStep") or #HINTS
	end

	local function refresh()
		local s = step()
		local active = s < #HINTS
		card.Visible = active
		arrow.Parent = if active then workspace else nil
		anchor.Parent = if active then workspace else nil
		if active then
			text.Text = HINTS[s + 1]
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
