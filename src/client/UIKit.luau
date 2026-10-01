-- Shared GUI helpers: the look (colors, corners, strokes) and a modal panel
-- with a title, close button, and a scrolling body.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

UIKit.COLORS = {
	panel = Color3.fromRGB(20, 60, 80),
	card = Color3.fromRGB(30, 85, 105),
	muted = Color3.fromRGB(45, 65, 75),
	text = Color3.fromRGB(255, 255, 255),
	hint = Color3.fromRGB(170, 210, 220),
	gold = Color3.fromRGB(255, 205, 90),
	goldText = Color3.fromRGB(60, 40, 10),
	accent = Color3.fromRGB(60, 170, 190),
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

-- A label inside a card.
function UIKit.label(text: string, props: { [string]: any }?): TextLabel
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = UIKit.COLORS.text,
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
	})
	for key, value in (props or {}) :: { [string]: any } do
		(label :: any)[key] = value
	end
	return label
end

-- A big button. `style` is "gold", "accent", or "muted".
function UIKit.button(text: string, style: string?, props: { [string]: any }?): TextButton
	local colors = UIKit.COLORS
	local background = if style == "gold" then colors.gold elseif style == "muted" then colors.muted else colors.accent
	local button = make("TextButton", {
		BackgroundColor3 = background,
		Font = Enum.Font.FredokaOne,
		TextSize = 18,
		TextColor3 = if style == "gold" then colors.goldText else colors.text,
		Text = text,
		Size = UDim2.fromOffset(160, 48),
	}, { UIKit.corner(10) })
	for key, value in (props or {}) :: { [string]: any } do
		(button :: any)[key] = value
	end
	return button
end

-- Puts an icon on the left of a button (no-op until the icon is uploaded).
function UIKit.addIcon(button: GuiObject, name: string)
	local icon = UIKit.icon(name, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.new(0, 0, 1, -6),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Parent = button,
	})
	if icon then
		icon.Size = UDim2.fromScale(0.85, 0.85)
		local padding = button:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, button.AbsoluteSize.Y > 0 and button.AbsoluteSize.Y or 40)
		padding.Parent = button
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
		BackgroundColor3 = colors.panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, {
		UIKit.corner(18),
		make("UISizeConstraint", { MaxSize = Vector2.new(640, 500) }),
		make("UIStroke", { Color = Color3.fromRGB(150, 230, 240), Thickness = 2 }),
	})
	table.insert(openPanels, frame)
	local titleIcon = if iconName
		then UIKit.icon(iconName, { Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(40, 40), Parent = frame })
		else nil
	local title = UIKit.label(titleText, {
		Position = UDim2.fromOffset(if titleIcon then 60 else 16, 10),
		Size = UDim2.new(1, if titleIcon then -134 else -90, 0, 36),
		TextSize = 26,
		Parent = frame,
	})
	local close = UIKit.button("X", "muted", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(48, 48),
		TextSize = 24,
		Parent = frame,
	})
	local body = make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.new(1, -24, 1, -72),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	local function toggle()
		local opening = not frame.Visible
		for _, other in openPanels do
			other.Visible = false
		end
		frame.Visible = opening
		if opening and onOpen then
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
	}, { UIKit.corner(10) })
end

function UIKit.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return UIKit
