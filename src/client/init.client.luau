-- Client: draws the HUD, coral picker, and timers over the local player's
-- slots, and starts the visual modules (corals, effects, world, fish). It only
-- reads attributes the server sets; the one request it sends (SelectCoral) is
-- validated on the server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Balance)
local ReefMath = require(ReplicatedStorage.Shared.ReefMath)
local ReefLevel = require(ReplicatedStorage.Shared.ReefLevel)
local ShopRotation = require(ReplicatedStorage.Shared.ShopRotation)
local Book = require(script.Book)
local ButtonFX = require(script.ButtonFX)
local CoralRenderer = require(script.CoralRenderer)
local CreatureRenderer = require(script.CreatureRenderer)
local Effects = require(script.Effects)
local EventFX = require(script.EventFX)
local Fish = require(script.Fish)
local Panels = require(script.Panels)
local UIKit = require(script.UIKit)
local PetRenderer = require(script.PetRenderer)
local PhotoMode = require(script.PhotoMode)
local WorldDecor = require(script.WorldDecor)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

WorldDecor.start()
ButtonFX.start()
CoralRenderer.start()
CreatureRenderer.start()
PetRenderer.start()
Effects.start(Remotes)
task.spawn(Fish.start)

local player = Players.LocalPlayer
local UPDATE_SECONDS = 0.25

local COLORS = {
	panel = Color3.fromRGB(20, 60, 80),
	text = Color3.fromRGB(255, 255, 255),
	pearl = Color3.fromRGB(255, 240, 200),
	ready = Color3.fromRGB(255, 225, 90),
	locked = Color3.fromRGB(90, 110, 120),
	selected = Color3.fromRGB(60, 170, 190),
}

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	return inst
end


-- Briefly grows a GUI object and springs it back.
local function bump(scale: UIScale, from: number)
	scale.Scale = from
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- HUD --------------------------------------------------------------------

local gui = make("ScreenGui", {
	Name = "ReefHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local pearlScale = make("UIScale", {})
local pearlLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(160, 40),
	TextColor3 = COLORS.pearl,
	TextStrokeTransparency = 0.6,
	TextXAlignment = Enum.TextXAlignment.Right,
	Font = Enum.Font.FredokaOne,
	TextSize = 22,
	Text = "0",
	Parent = gui,
}, {
	pearlScale,
	make("UIPadding", { PaddingRight = UDim.new(0, 12) }),
	-- A shiny pearl icon.
	make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Color3.fromRGB(255, 250, 240),
	}, {
		make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(225, 200, 230)),
			Rotation = 45,
		}),
	}),
})

UIKit.gloss(pearlLabel, UIKit.COLORS.panel, 12)

local nextLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 52),
	Size = UDim2.fromOffset(300, 20),
	BackgroundTransparency = 1,
	TextColor3 = COLORS.text,
	TextStrokeTransparency = 0.5,
	Font = Enum.Font.GothamMedium,
	TextSize = 16,
	Text = "",
	Parent = gui,
})

-- Reef level badge with XP bar; tap it to see the next reward -------------

local levelScale = make("UIScale", {})
local xpFill = make("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(120, 230, 255),
	BorderSizePixel = 0,
}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local levelButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(0.5, -88, 0, 8),
	Size = UDim2.fromOffset(66, 40),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.15,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextStrokeTransparency = 0.6,
	Font = Enum.Font.FredokaOne,
	TextSize = 17,
	TextYAlignment = Enum.TextYAlignment.Top,
	Text = "Lv 1",
	AutoButtonColor = false,
	Parent = gui,
}, {
	levelScale,
	make("UIPadding", { PaddingTop = UDim.new(0, 4) }),
	UIKit.icon("reef_level", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, -2, 0, 8),
		Size = UDim2.fromOffset(28, 28),
		ZIndex = 2,
	}) :: any,
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -14, 0, 6),
		BackgroundColor3 = COLORS.locked,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), xpFill }),
})
UIKit.gloss(levelButton, UIKit.COLORS.blue, 12)
local shownLevel = 0
local function updateLevel()
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("XP") or 0
	local xpNext = player:GetAttribute("XPNext") or 1
	levelButton.Text = "Lv " .. level
	TweenService:Create(xpFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(xp / xpNext, 0, 1), 1) }):Play()
	if shownLevel ~= 0 and level > shownLevel then
		bump(levelScale, 1.4)
	end
	shownLevel = level
end
player:GetAttributeChangedSignal("Level"):Connect(updateLevel)
player:GetAttributeChangedSignal("XP"):Connect(updateLevel)
updateLevel()

-- Shells counter (second currency) ---------------------------------------

local shellLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0.5, 88, 0, 8),
	Size = UDim2.fromOffset(100, 40),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextStrokeTransparency = 0.6,
	Font = Enum.Font.FredokaOne,
	TextSize = 16,
	Text = "0 shells",
	Parent = gui,
})
UIKit.gloss(shellLabel, UIKit.COLORS.purple, 12)
local function updateShells()
	shellLabel.Text = string.format("%d shells", player:GetAttribute("Shells") or 0)
end
player:GetAttributeChangedSignal("Shells"):Connect(updateShells)
updateShells()

-- Side menu ---------------------------------------------------------------

local menu = make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.fromOffset(70, 420),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }),
})

-- Adds a big, thumb-friendly menu button. Other systems call this too.
-- With its icon uploaded, a button is the icon with a small caption;
-- otherwise it falls back to a text button.
local function addMenuButton(text: string, onActivated: () -> (), iconName: string): GuiButton
	local scale = make("UIScale", {})
	local image = UIKit.iconImage(iconName)
	local button: GuiButton
	if image then
		button = make("ImageButton", {
			Size = UDim2.fromOffset(58, 72),
			BackgroundTransparency = 1,
			Image = "",
			Parent = menu,
		}, {
			scale,
			make("ImageLabel", {
				Size = UDim2.fromOffset(58, 58),
				BackgroundTransparency = 1,
				Image = image,
				ScaleType = Enum.ScaleType.Fit,
			}),
			make("TextLabel", {
				Position = UDim2.fromOffset(-8, 55),
				Size = UDim2.new(1, 16, 0, 16),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.text,
				TextStrokeTransparency = 0.4,
				Font = Enum.Font.FredokaOne,
				TextSize = 13,
				Text = text,
			}),
		})
	else
		button = make("TextButton", {
			Size = UDim2.fromOffset(70, 44),
			TextColor3 = COLORS.text,
			Font = Enum.Font.FredokaOne,
			TextSize = 15,
			Text = text,
			Parent = menu,
		}, { scale })
		UIKit.gloss(button, UIKit.COLORS.accent, 12)
	end
	button.Activated:Connect(function()
		bump(scale, 0.85)
		onActivated()
	end)
	return button
end

Book.start(gui, Remotes)
-- Five buttons at most (design pillar: understood in 10 seconds). Tide Reset
-- opens from the Shop.
addMenuButton("Shop", Panels.shop(gui, Remotes, Panels.tide(gui, Remotes)), "shop")
addMenuButton("Book", Book.toggle, "book")
addMenuButton("Travel", Panels.friends(gui, Remotes, Panels.trade(gui, Remotes)), "travel")
addMenuButton("Goals", Panels.goals(gui, Remotes), "goals")
addMenuButton("Photo", PhotoMode.start(gui), "photo")
Panels.project(gui)
Panels.streakPopup(gui)
Panels.zoneMarket(gui, Remotes)
EventFX.start(gui)

-- Reef health meter ------------------------------------------------------

local HEALTH_COLORS = {
	Struggling = Color3.fromRGB(230, 120, 90),
	Healthy = Color3.fromRGB(120, 210, 140),
	Thriving = Color3.fromRGB(110, 230, 230),
}
local healthFill = make("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = HEALTH_COLORS.Healthy,
	BorderSizePixel = 0,
}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local healthLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 72),
	Size = UDim2.fromOffset(240, 20),
	BackgroundTransparency = 1,
	TextColor3 = COLORS.text,
	TextStrokeTransparency = 0.5,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Text = "",
	Parent = gui,
})
make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 92),
	Size = UDim2.fromOffset(200, 10),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.2,
	Parent = gui,
}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }), healthFill })

local function updateHealth()
	local score = player:GetAttribute("ReefHealth") or 0
	local tier = player:GetAttribute("HealthTier") or "Struggling"
	local multiplier = player:GetAttribute("HealthMultiplier") or 1
	healthLabel.Text = string.format("Reef health: %s %d  (x%.2f pearls)", tier, score, multiplier)
	healthFill.BackgroundColor3 = HEALTH_COLORS[tier] or HEALTH_COLORS.Healthy
	TweenService:Create(healthFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(score / 100, 1) }):Play()
end
player:GetAttributeChangedSignal("ReefHealth"):Connect(updateHealth)
player:GetAttributeChangedSignal("HealthTier"):Connect(updateHealth)
updateHealth()

local toastScale = make("UIScale", {})
local toastLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(280, 40),
	TextColor3 = COLORS.text,
	TextStrokeTransparency = 0.6,
	Font = Enum.Font.FredokaOne,
	TextSize = 17,
	Visible = false,
	Parent = gui,
}, { toastScale })
UIKit.gloss(toastLabel, UIKit.COLORS.panel, 12)

local toastSerial = 0
Remotes:WaitForChild("Toast").OnClientEvent:Connect(function(text: string, kind: string)
	toastSerial += 1
	local serial = toastSerial
	toastLabel.Text = text
	toastLabel.TextColor3 = if kind == "pearls" then COLORS.pearl elseif kind == "unlock" then COLORS.ready else COLORS.text
	toastLabel.Visible = true
	bump(toastScale, 0.6)
	task.delay(1.5, function()
		if toastSerial == serial then
			toastLabel.Visible = false
		end
	end)
end)

levelButton.Activated:Connect(function()
	local level = player:GetAttribute("Level") or 1
	local at, text = ReefLevel.nextReward(level, Balance.levels)
	local xp, xpNext = player:GetAttribute("XP") or 0, player:GetAttribute("XPNext") or 1
	local message = if at then string.format("%d/%d XP. Next reward at Lv %d: %s", xp, xpNext, at, text) else "Max reef level!"
	toastSerial += 1
	local serial = toastSerial
	toastLabel.Text = message
	toastLabel.TextColor3 = COLORS.text
	toastLabel.Visible = true
	bump(toastScale, 0.6)
	task.delay(3, function()
		if toastSerial == serial then
			toastLabel.Visible = false
		end
	end)
end)

local shownPearls = 0
local function updatePearls()
	local pearls = player:GetAttribute("Pearls") or 0
	if pearls > shownPearls then
		bump(pearlScale, 1.15)
	end
	shownPearls = pearls
	pearlLabel.Text = string.format("%d", pearls)
end
player:GetAttributeChangedSignal("Pearls"):Connect(updatePearls)
updatePearls()

-- Coral picker -----------------------------------------------------------

local shopCorals = {}
for name in Balance.corals do
	-- Shop corals, the rotating rare coral, and corals that can sit in the
	-- inventory (creature drops, prestige shop) all get a button.
	table.insert(shopCorals, name)
end
table.sort(shopCorals, function(a, b)
	return Balance.corals[a].cost < Balance.corals[b].cost
end)

local picker = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.fromOffset(#shopCorals * 122, 50),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
	}),
})

local selectRemote = Remotes:WaitForChild("SelectCoral")
local pickerButtons: { [string]: TextButton } = {}
for _, name in shopCorals do
	local def = Balance.corals[name]
	local buttonScale = make("UIScale", {})
	local button = make("TextButton", {
		Size = UDim2.fromOffset(116, 50),
		TextColor3 = COLORS.text,
		TextStrokeTransparency = 0.6,
		Font = Enum.Font.FredokaOne,
		TextSize = 13,
		TextWrapped = true,
		AutoButtonColor = false,
		Parent = picker,
	}, {
		buttonScale,
		make("UIPadding", { PaddingLeft = UDim.new(0, 20) }),
		-- Color swatch so each coral is recognizable at a glance.
		make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -14, 0.5, 0),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = Color3.fromRGB(def.color[1], def.color[2], def.color[3]),
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
	})
	button.Activated:Connect(function()
		bump(buttonScale, 0.85)
		selectRemote:FireServer(name)
	end)
	pickerButtons[name] = button
	button:SetAttribute("Label", string.format("%s\n%d pearls", def.displayName, def.cost))
end

local function updatePicker()
	local selected = player:GetAttribute("SelectedCoral")
	local slots = player:GetAttribute("Slots") or 0
	local now = workspace:GetServerTimeNow()
	local rotating, endsAt = ShopRotation.current(Balance.shopRotation, now)
	local left = ReefMath.formatDuration(endsAt - now)
	for name, button in pickerButtons do
		local def = Balance.corals[name]
		local locked = slots < def.unlockSlots
		local text = button:GetAttribute("Label")
		local owned = player:GetAttribute("Inv_" .. name) or 0
		local inRotation = table.find(Balance.shopRotation.pool, name) ~= nil
		button.Visible = def.inShop or inRotation or owned > 0
		if owned > 0 then
			locked = false
			text = string.format("%s\n%d owned", def.displayName, owned)
		elseif locked then
			text = string.format("%s\nUnlocks at %d slots", def.displayName, def.unlockSlots)
		elseif not def.inShop then
			-- Rotating rare shop: in stock for the rest of this period, or restocking.
			if rotating == name then
				text = string.format("%s\n%d · %s left", def.displayName, def.cost, left)
			else
				locked = true
				text = string.format("%s\nRestock in %s", def.displayName, left)
			end
		end
		button.Text = text
		local styleKey = if locked then "muted" elseif name == selected then "accent" elseif not def.inShop then "purple" else "panel"
		if button:GetAttribute("StyleKey") ~= styleKey then
			button:SetAttribute("StyleKey", styleKey)
			UIKit.gloss(button, (UIKit.COLORS :: any)[styleKey], 12)
		end
	end
end
player:GetAttributeChangedSignal("SelectedCoral"):Connect(updatePicker)
player:GetAttributeChangedSignal("Slots"):Connect(updatePicker)

-- Slot and pad billboards ------------------------------------------------

local slotLabels: { [BasePart]: TextLabel } = {}
local padLabels: { [BasePart]: TextLabel } = {}

local function attachBillboard(part: BasePart, offset: number): TextLabel
	local label = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.text,
		TextStrokeTransparency = 0.3,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
	})
	make("BillboardGui", {
		Name = "ReefLabel",
		Size = UDim2.fromOffset(120, 36),
		StudsOffset = Vector3.new(0, offset, 0),
		MaxDistance = 120,
		AlwaysOnTop = true,
		-- Parented locally to the part, so it streams out with it.
		Parent = part,
	}, { label })
	return label
end

local function watchTag(tag: string, labels: { [BasePart]: TextLabel }, offset: number)
	local function added(part: Instance)
		if part:IsA("BasePart") and part:GetAttribute("OwnerId") == player.UserId and not labels[part] then
			labels[part] = attachBillboard(part, offset)
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(added)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(part)
		local label = labels[part :: BasePart]
		if label then
			labels[part :: BasePart] = nil
			local billboard = label.Parent
			if billboard then
				billboard:Destroy()
			end
		end
	end)
	for _, part in CollectionService:GetTagged(tag) do
		added(part)
	end
end

watchTag("ReefSlot", slotLabels, 5.5)
watchTag("ReefBuyPad", padLabels, 3)
updatePicker()

-- One loop updates every timer a few times a second, instead of per frame.
while true do
	local now = workspace:GetServerTimeNow()
	CoralRenderer.update(now)
	updatePicker()
	local soonest: number? = nil
	local soonestName = ""
	local readyCount = 0

	for part, label in slotLabels do
		local coralType = part:GetAttribute("CoralType")
		local def = coralType and Balance.corals[coralType]
		if not def then
			label.Text = "Tap to plant"
			label.TextColor3 = COLORS.text
			continue
		end
		local plantedAt = part:GetAttribute("PlantedAt") or now
		local cycles = ReefMath.readyCycles(plantedAt, now, def.growSeconds, Balance.offlineCapSeconds)
		local mutation = part:GetAttribute("Mutation")
		local prefix = if type(mutation) == "string" and mutation ~= "" then mutation .. " " else ""
		if cycles > 0 then
			readyCount += 1
			label.Text = prefix .. (if cycles > 1 then string.format("Ready! x%d", cycles) else "Ready!")
			label.TextColor3 = COLORS.ready
		else
			local left = ReefMath.secondsUntilReady(plantedAt, now, def.growSeconds)
			label.Text = prefix .. ReefMath.formatDuration(left)
			label.TextColor3 = COLORS.text
			if soonest == nil or left < soonest then
				soonest = left
				soonestName = def.displayName
			end
		end
	end

	for part, label in padLabels do
		local cost = part:GetAttribute("Cost") or 0
		label.Text = if cost < 0 then "Reef at max size" else string.format("New slot: %d", cost)
	end

	-- Return hook: always show what is coming next.
	if readyCount > 0 then
		nextLabel.Text = string.format("%d coral%s ready to harvest", readyCount, if readyCount == 1 then " is" else "s are")
	elseif soonest then
		nextLabel.Text = string.format("Next: %s in %s", soonestName, ReefMath.formatDuration(soonest))
	else
		nextLabel.Text = "Tap a sand slot to plant a coral"
	end

	task.wait(UPDATE_SECONDS)
end
