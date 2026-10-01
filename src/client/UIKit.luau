-- Shared GUI helpers: the look (colors, corners, strokes) and a modal panel
-- with a title, close button, and a scrolling body.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Icons = require(ReplicatedStorage.Shared.Icons)

local UIKit = {}

-- The image for an icon in assets/icons, or nil until its upload ID is set
-- in src/shared/Icons.json. IDs must be Image assets (Asset Manager > Images).
function UIKit.iconImage(name: string): string?
	local id = (Icons :: any)[name]
	if type(id) ~= "number" or id == 0 then
		return nil
	end
	return "rbxassetid://" .. id
end

-- An ImageLabel for an icon, or nil when the icon isn't uploaded yet, so
-- every caller can fall back to its text-only look.
function UIKit.icon(name: string, props: { [string]: any }?): ImageLabel?
	local image = UIKit.iconImage(name)
	if not image then
		return nil
	end
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Image = image
	label.ScaleType = Enum.ScaleType.Fit
	for key, value in (props or {}) :: { [string]: any } do
		(label :: any)[key] = value
	end
	return label
end

-- The one place UI colors are defined (coral-reef palette): deep navy and
-- teal panels, teal cards, sunny-gold buttons, coral-pink accents. The HUD,
-- Book, and panels all read from here. Every text/background pair is kept
-- at WCAG 4.5:1 or better; run tests/contrast_check.py after changing one.
UIKit.COLORS = {
	-- Surfaces
	panel = Color3.fromRGB(12, 42, 60), -- deep navy-teal
	card = Color3.fromRGB(18, 96, 108), -- teal
	muted = Color3.fromRGB(70, 92, 108), -- locked / unavailable
	-- Text
	text = Color3.fromRGB(255, 255, 255),
	hint = Color3.fromRGB(180, 222, 232),
	pearl = Color3.fromRGB(255, 240, 200),
	ready = Color3.fromRGB(255, 225, 90),
	goldText = Color3.fromRGB(60, 36, 0),
	-- Buttons and accents
	gold = Color3.fromRGB(255, 200, 60), -- sunny gold
	accent = Color3.fromRGB(27, 120, 130), -- deep aqua (selected / primary)
	coral = Color3.fromRGB(182, 73, 84), -- coral pink
	pink = Color3.fromRGB(182, 73, 84),
	purple = Color3.fromRGB(127, 84, 202),
	blue = Color3.fromRGB(46, 108, 190),
	green = Color3.fromRGB(39, 124, 73),
	orange = Color3.fromRGB(159, 91, 31),
	-- Rarity outlines (Market cards)
	rarityCommon = Color3.fromRGB(150, 170, 180),
	rarityUncommon = Color3.fromRGB(90, 200, 120),
	rarityRare = Color3.fromRGB(80, 150, 255),
	rarityEpic = Color3.fromRGB(190, 110, 255),
	rarityLegendary = Color3.fromRGB(255, 200, 60),
	-- Meters
	xp = Color3.fromRGB(120, 230, 255),
	healthStruggling = Color3.fromRGB(240, 110, 90),
	healthHealthy = Color3.fromRGB(110, 205, 135),
	healthThriving = Color3.fromRGB(90, 215, 215),
	-- The little pearl on the pearl counter
	pearlIcon = Color3.fromRGB(255, 250, 240),
	pearlIconShade = Color3.fromRGB(225, 200, 230),
	-- Book 3D previews: lit when found, a black silhouette when not
	previewAmbient = Color3.fromRGB(170, 170, 170),
	previewLight = Color3.fromRGB(255, 255, 255),
	silhouette = Color3.fromRGB(0, 0, 0),
}

-- Fonts: rounded display font for titles and buttons, a clean font for body text.
UIKit.FONTS = {
	title = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
}

function UIKit.make(className: string, props: { [string]: any }, children: { Instance }?): any
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

local make = UIKit.make

function UIKit.corner(radius: number?): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local BLACK = Color3.new(0, 0, 0)

-- How dark the bottom of the glossy shine gets (1 = no shading). A
-- UIGradient tints an object's text as well as its background, so the shine
-- is grayscale and gentle: it shades both equally and never tints the text.
-- tests/contrast_check.py reads this value.
UIKit.GLOSS_SHADE = 0.86

-- The icon-tile look: a glossy shine (a bright band on top, a little deeper
-- at the bottom) and a thick outline in a darker shade of the same color.
function UIKit.gloss(object: GuiObject, color: Color3, radius: number?)
	object.BackgroundColor3 = color
	object.BackgroundTransparency = 0
	for _, old in object:GetChildren() do
		if old:IsA("UIGradient") or old:IsA("UIStroke") or old:IsA("UICorner") then
			old:Destroy()
		end
	end
	local shade = UIKit.GLOSS_SHADE
	local function gray(v: number): Color3
		return Color3.new(v, v, v)
	end
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, gray(1)),
			ColorSequenceKeypoint.new(0.44, gray(1 - (1 - shade) * 0.2)),
			ColorSequenceKeypoint.new(0.47, gray(1 - (1 - shade) * 0.65)),
			ColorSequenceKeypoint.new(1, gray(shade)),
		}),
		Parent = object,
	})
	make("UIStroke", {
		Color = color:Lerp(BLACK, 0.5),
		Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = object,
	})
	UIKit.corner(radius or 12).Parent = object
end

-- A label inside a card.
function UIKit.label(text: string, props: { [string]: any }?): TextLabel
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = UIKit.COLORS.text,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
	})
	for key, value in (props or {}) :: { [string]: any } do
		(label :: any)[key] = value
	end
	return label
end

-- A glossy button. `style` is a color name from UIKit.COLORS ("gold",
-- "accent", "muted", "pink", "purple", "blue", "green", "orange").
function UIKit.button(text: string, style: string?, props: { [string]: any }?): TextButton
	local colors = UIKit.COLORS :: any
	local color = colors[style or "accent"] or colors.accent
	local button = make("TextButton", {
		Font = Enum.Font.FredokaOne,
		TextSize = 15,
		TextColor3 = if style == "gold" then colors.goldText else colors.text,
		TextStrokeTransparency = if style == "gold" then 1 else 0.7,
		Text = text,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(128, 38),
	})
	UIKit.gloss(button, color, 10)
	for key, value in (props or {}) :: { [string]: any } do
		(button :: any)[key] = value
	end
	return button
end

-- Puts an icon on the left of a button (no-op until the icon is uploaded).
function UIKit.addIcon(button: GuiObject, name: string)
	local height = if button.AbsoluteSize.Y > 0 then button.AbsoluteSize.Y else button.Size.Y.Offset
	local size = math.max(20, height - 6)
	local icon = UIKit.icon(name, {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(size, size),
		Parent = button,
	})
	if icon then
		local padding = button:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, size + 4)
		padding.Parent = button
		-- Padding shifts children too, so pull the icon back to the left edge.
		icon.Position = UDim2.new(0, -size, 0.5, 0)
	end
end

export type Panel = { frame: Frame, body: ScrollingFrame, title: TextLabel, toggle: () -> (), isOpen: () -> boolean }

-- A centered modal panel. Opening one panel closes any other.
local openPanels: { Frame } = {}

function UIKit.panel(gui: ScreenGui, titleText: string, onOpen: (() -> ())?, iconName: string?): Panel
	local colors = UIKit.COLORS
	local frame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.75),
		Visible = false,
		Parent = gui,
	}, {
		make("UISizeConstraint", { MaxSize = Vector2.new(540, 430) }),
	})
	UIKit.gloss(frame, colors.panel, 18)
	local frameScale = make("UIScale", { Parent = frame })
	table.insert(openPanels, frame)
	local titleIcon = if iconName
		then UIKit.icon(iconName, { Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(36, 36), Parent = frame })
		else nil
	local title = UIKit.label(titleText, {
		Position = UDim2.fromOffset(if titleIcon then 52 else 14, 8),
		Size = UDim2.new(1, if titleIcon then -110 else -70, 0, 30),
		TextSize = 21,
		TextStrokeTransparency = 0.6,
		Parent = frame,
	})
	local close = UIKit.button("X", "pink", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 7),
		Size = UDim2.fromOffset(34, 34),
		TextSize = 18,
		Parent = frame,
	})
	local body = make("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 48),
		Size = UDim2.new(1, -20, 1, -58),
		ScrollBarImageColor3 = Color3.fromRGB(150, 220, 235),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }),
	})
	-- Panels pop open with a little bounce and shrink away when closed.
	local function close_()
		local tween = TweenService:Create(frameScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 })
		tween.Completed:Connect(function()
			if frameScale.Scale <= 0.86 then
				frame.Visible = false
			end
		end)
		tween:Play()
	end
	close.Activated:Connect(close_)
	local function toggle()
		local opening = not frame.Visible
		for _, other in openPanels do
			if other ~= frame then
				other.Visible = false
			end
		end
		if not opening then
			close_()
			return
		end
		frameScale.Scale = 0.8
		frame.Visible = true
		TweenService:Create(frameScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if onOpen then
			onOpen()
		end
	end
	return {
		frame = frame,
		body = body,
		title = title,
		toggle = toggle,
		isOpen = function()
			return frame.Visible
		end,
	}
end

-- A full-width card row inside a panel body.
function UIKit.card(parent: Instance, height: number, order: number?): Frame
	return make("Frame", {
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = UIKit.COLORS.card,
		LayoutOrder = order or 0,
		Parent = parent,
	}, {
		UIKit.corner(10),
		make("UIStroke", { Color = UIKit.COLORS.card:Lerp(Color3.new(0, 0, 0), 0.45), Thickness = 1.5 }),
	})
end

function UIKit.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return UIKit
