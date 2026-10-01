-- Overhead nametags: reef level, Tide (prestige) badge, and VIP, so veterans
-- show off their progress when visiting other reefs.

local Players = game:GetService("Players")

local Nametags = {}

local function text(player: Player): string
	local parts = { string.format("Lv %d", player:GetAttribute("Level") :: number? or 1) }
	local tide = player:GetAttribute("TideLevel") :: number? or 0
	if tide > 0 then
		table.insert(parts, string.format("Tide %d", tide))
	end
	if player:GetAttribute("Pass_VIP") then
		table.insert(parts, "VIP")
	end
	return table.concat(parts, "  ·  ")
end

local function attach(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "ReefNametag"
	tag.Size = UDim2.fromOffset(160, 26)
	tag.StudsOffset = Vector3.new(0, 2.4, 0)
	tag.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 60, 80)
	label.BackgroundTransparency = 0 -- solid, so the text stays readable over anything
	label.TextColor3 = if player:GetAttribute("Pass_VIP") then Color3.fromRGB(255, 205, 90) else Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text(player)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	label.Parent = tag
	tag.Parent = head
	local connection
	connection = player.AttributeChanged:Connect(function(name)
		if not tag.Parent then
			connection:Disconnect()
		elseif name == "Level" or name == "TideLevel" or name == "Pass_VIP" then
			label.Text = text(player)
			label.TextColor3 = if player:GetAttribute("Pass_VIP") then Color3.fromRGB(255, 205, 90) else Color3.fromRGB(255, 255, 255)
		end
	end)
end

function Nametags.start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			attach(player, character)
		end)
		if player.Character then
			task.spawn(attach, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return Nametags
