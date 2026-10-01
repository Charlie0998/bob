-- Keeps every piece of on-screen text readable. Watches the player's whole
-- GUI (like ButtonFX), so text made later gets the same treatment:
--   * text that doesn't fit its box shrinks to fit, never bigger than the
--     size it was designed at and never smaller than MIN_SIZE
--   * text that was already set to scale gets a size cap, so it can't
--     balloon on big screens

local Players = game:GetService("Players")

local MIN_SIZE = 9
local SCALED_MAX = 30

local TextFit = {}

type TextObject = TextLabel | TextButton | TextBox

local function constraint(object: TextObject): UITextSizeConstraint
	local existing = object:FindFirstChildOfClass("UITextSizeConstraint")
	if existing then
		return existing
	end
	local made = Instance.new("UITextSizeConstraint")
	made.Parent = object
	return made
end

local function watch(object: TextObject)
	if object:GetAttribute("TextFitWatched") then
		return
	end
	object:SetAttribute("TextFitWatched", true)
	if object.TextScaled then
		local c = constraint(object)
		if c.MaxTextSize >= 100 then -- the default: no cap set yet
			c.MaxTextSize = SCALED_MAX
		end
		c.MinTextSize = math.min(c.MinTextSize, MIN_SIZE)
		return
	end
	local designed = object.TextSize
	local function check()
		-- TextFits is only meaningful once the object has a size on screen.
		if object.TextScaled or object.AbsoluteSize.X < 1 or object.Text == "" then
			return
		end
		if not object.TextFits then
			local c = constraint(object)
			c.MaxTextSize = designed
			c.MinTextSize = math.min(MIN_SIZE, designed)
			local text: any = object
			text.TextWrapped = true
			text.TextScaled = true
		end
	end
	object:GetPropertyChangedSignal("Text"):Connect(check)
	object:GetPropertyChangedSignal("AbsoluteSize"):Connect(check)
	task.defer(check)
end

local function onDescendant(item: Instance)
	-- The loading screen's big title is meant to be big; leave it alone.
	if item:FindFirstAncestor("LoadingScreen") then
		return
	end
	if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
		watch(item)
	end
end

function TextFit.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	playerGui.DescendantAdded:Connect(onDescendant)
	for _, item in playerGui:GetDescendants() do
		onDescendant(item)
	end
end

return TextFit
