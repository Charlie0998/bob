-- One-shot effects for harvesting, planting, and buying slots. Everyone nearby
-- sees the particles; sounds, flying pearls, and "+N" numbers are only for the
-- player who acted.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CoralRenderer = require(script.Parent.CoralRenderer)
local CreatureRenderer = require(script.Parent.CreatureRenderer)
local SoundFX = require(script.Parent.SoundFX)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local PUFF = "rbxasset://textures/particles/smoke_main.dds"
local PEARL_COLOR = Color3.fromRGB(255, 248, 230)

local Effects = {}

local playSound = SoundFX.play

-- Emits a burst of particles at a point from a temporary invisible part.
local function burst(position: Vector3, props: { [string]: any }, count: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.SpreadAngle = Vector2.new(180, 180)
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = anchor
	anchor.Parent = workspace
	emitter:Emit(count)
	Debris:AddItem(anchor, 3)
end

local function floatingText(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 50)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	anchor.Parent = workspace

	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.2)
end

-- Little pearls pop out of the coral and fly to the player.
local function pearlsToPlayer(from: Vector3, count: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for i = 1, count do
		local pearl = Instance.new("Part")
		pearl.Shape = Enum.PartType.Ball
		pearl.Size = Vector3.one * 0.5
		pearl.Material = Enum.Material.Neon
		pearl.Color = PEARL_COLOR
		pearl.Anchored = true
		pearl.CanCollide = false
		pearl.CanQuery = false
		pearl.CanTouch = false
		pearl.CastShadow = false
		pearl.Position = from
		pearl.Parent = workspace
		local spread = Vector3.new(math.random() - 0.5, 0.6 + math.random() * 0.4, math.random() - 0.5) * 4
		local up = TweenService:Create(pearl, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = from + spread })
		up.Completed:Connect(function()
			local fly = TweenService:Create(
				pearl,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = root.Position, Size = Vector3.one * 0.2 }
			)
			fly.Completed:Connect(function()
				pearl:Destroy()
			end)
			fly:Play()
		end)
		task.delay(i * 0.04, function()
			up:Play()
		end)
	end
end

local function onHarvest(tile: BasePart, amount: number, isMine: boolean)
	local top = CoralRenderer.topOf(tile)
	CoralRenderer.pulse(tile)
	burst(top, {
		Texture = SPARKLE,
		Color = ColorSequence.new(PEARL_COLOR, Color3.fromRGB(255, 220, 120)),
		LightEmission = 1,
		Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(6, 10),
		Drag = 4,
	}, 18)
	if isMine then
		playSound("harvest")
		floatingText(top, "+" .. amount, Color3.fromRGB(255, 235, 150))
		pearlsToPlayer(top, math.clamp(amount // 5, 3, 8))
	end
end

local function onPlant(tile: BasePart, isMine: boolean)
	CoralRenderer.pop(tile)
	burst(tile.Position + Vector3.new(0, 0.5, 0), {
		Texture = PUFF,
		Color = ColorSequence.new(Color3.fromRGB(235, 215, 165)),
		Transparency = NumberSequence.new(0.3, 1),
		Size = NumberSequence.new(1, 2.5),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(3, 5),
		Drag = 5,
		EmissionDirection = Enum.NormalId.Right, -- the tile's cylinder axis points up
		SpreadAngle = Vector2.new(70, 70),
	}, 12)
	if isMine then
		playSound("plant")
	end
end

local function onSlot(tile: BasePart, isMine: boolean)
	-- The new tile rises out of the sand.
	local final = tile.CFrame
	tile.CFrame = final - Vector3.new(0, 1.5, 0)
	TweenService:Create(tile, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = final }):Play()
	burst(final.Position + Vector3.new(0, 1, 0), {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 225, 120)),
		LightEmission = 1,
		Size = NumberSequence.new(0.8, 0),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(5, 8),
		Drag = 3,
	}, 24)
	if isMine then
		playSound("buy_slot")
	end
end

local function onFeed(anchor: BasePart, shells: number, isMine: boolean)
	CreatureRenderer.hop(anchor)
	burst(anchor.Position, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 160, 210), Color3.fromRGB(255, 240, 200)),
		LightEmission = 1,
		Size = NumberSequence.new(0.7, 0),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(4, 7),
		Drag = 3,
	}, 16)
	if isMine then
		playSound("bubble_pop")
		floatingText(anchor.Position + Vector3.new(0, 2, 0), "+" .. shells .. " shells", Color3.fromRGB(255, 190, 230))
	end
end

-- Full-screen celebration for the local player: a flash, a big banner that
-- pops in, and confetti falling across the screen.
local celebrationGui: ScreenGui? = nil

local function celebrate(title: string, subtitle: string, color: Color3)
	if not celebrationGui then
		local made = Instance.new("ScreenGui")
		made.Name = "Celebrations"
		made.IgnoreGuiInset = true
		made.ResetOnSpawn = false
		made.DisplayOrder = 20
		made.Parent = player:WaitForChild("PlayerGui")
		celebrationGui = made
	end
	local gui = celebrationGui :: ScreenGui
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.4
	flash.Parent = gui
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(flash, 0.6)

	local banner = UIKit.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.fromOffset(360, 110),
		Parent = gui,
	})
	UIKit.gloss(banner, UIKit.COLORS.panel, 20)
	local stroke = banner:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
		stroke.Thickness = 4
	end
	UIKit.label(title, { Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 56), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = color, TextStrokeTransparency = 0, Parent = banner })
	UIKit.label(subtitle, { Position = UDim2.fromOffset(10, 66), Size = UDim2.new(1, -20, 0, 34), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Parent = banner })
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = banner
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.4, function()
		TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 0 }):Play()
		Debris:AddItem(banner, 0.3)
	end)

	local palette = { UIKit.COLORS.gold, UIKit.COLORS.coral, UIKit.COLORS.accent, UIKit.COLORS.purple, Color3.new(1, 1, 1) }
	for _ = 1, 60 do
		local piece = Instance.new("Frame")
		piece.Size = UDim2.fromOffset(math.random(6, 12), math.random(10, 18))
		piece.Position = UDim2.new(math.random(), 0, -0.05, 0)
		piece.Rotation = math.random(0, 360)
		piece.BackgroundColor3 = palette[math.random(1, #palette)]
		piece.BorderSizePixel = 0
		piece.Parent = gui
		local fall = TweenService:Create(piece, TweenInfo.new(math.random(18, 30) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.1, 0),
			Rotation = piece.Rotation + math.random(-360, 360),
		})
		fall:Play()
		Debris:AddItem(piece, 3.2)
	end
end

local function onRebirth(root: BasePart, level: number, isMine: boolean)
	for i = 0, 2 do
		task.delay(i * 0.25, function()
			burst(root.Position + Vector3.new(0, i * 2, 0), {
				Texture = SPARKLE,
				Color = ColorSequence.new(Color3.fromRGB(120, 230, 255), Color3.fromRGB(255, 255, 255)),
				LightEmission = 1,
				Size = NumberSequence.new(1.4, 0),
				Lifetime = NumberRange.new(1, 1.6),
				Speed = NumberRange.new(12, 20),
				Drag = 2,
			}, 60)
		end)
	end
	if isMine then
		playSound("level_up")
		task.delay(0.3, function()
			playSound("rare_find")
		end)
		celebrate("TIDE RESET!", string.format("Tide level %d: your pearls are worth more forever", level), Color3.fromRGB(120, 230, 255))
	end
end

local function onLevelUp(root: BasePart, level: number, isMine: boolean)
	burst(root.Position, {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(150, 235, 255), Color3.fromRGB(255, 230, 120)),
		LightEmission = 1,
		Size = NumberSequence.new(1, 0),
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(8, 14),
		Drag = 3,
	}, 40)
	floatingText(root.Position + Vector3.new(0, 4, 0), "Level " .. level .. "!", Color3.fromRGB(150, 235, 255))
	if isMine then
		playSound("level_up")
		celebrate("LEVEL " .. level .. "!", "Your reef grows stronger", UIKit.COLORS.gold)
	end
end

function Effects.start(remotes: Instance)
	(remotes:WaitForChild("Effect") :: RemoteEvent).OnClientEvent:Connect(function(kind: string, target: Instance?, amount: number, actorId: number)
		-- Rare finds (mutations, discoveries, treasure) have no place to show; just a sound.
		if kind == "rare" then
			if actorId == player.UserId then
				playSound("rare_find")
			end
			return
		end
		-- The target may not be streamed in on this client.
		if not target or not target:IsA("BasePart") or not target:IsDescendantOf(workspace) then
			return
		end
		local isMine = actorId == player.UserId
		if kind == "harvest" then
			onHarvest(target, amount, isMine)
		elseif kind == "plant" then
			onPlant(target, isMine)
		elseif kind == "slot" then
			onSlot(target, isMine)
		elseif kind == "feed" then
			onFeed(target, amount, isMine)
		elseif kind == "rebirth" then
			onRebirth(target, amount, isMine)
		elseif kind == "levelup" then
			onLevelUp(target, amount, isMine)
		elseif kind == "leave" then
			CreatureRenderer.leave(target)
		end
	end)
end

return Effects
