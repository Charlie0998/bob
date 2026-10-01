-- Makes every player's reef plot look like a place worth building up, all
-- drawn on the client:
--   * a sandstone rim with coral trim, corner pillars with lanterns, and an
--     entrance arch with a banner showing the owner's name
--   * a scalloped seashell dish around every slot, and a giant clam with a
--     floating pearl on the buy pad
--   * extra scenery as the reef grows (10 / 20 / 30 slots)
--   * a glowing shell path from spawn to the plot (yours is gold and pulses)
--   * seashells, starfish, sea urchins, and swaying anemones
-- Plots far from the camera are hidden.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Balance)
local CoralModels = require(ReplicatedStorage.Shared.CoralModels)
local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local WorldDecor = require(script.Parent.WorldDecor)

local HIDE_DISTANCE = 360
local PATH_START_RADIUS = 24 -- just past the spawn disc
local PATH_SPACING = 5
local TIERS = { 10, 20, 30 }

local SANDSTONE = Color3.fromRGB(214, 192, 152)
local TRIM = Color3.fromRGB(240, 120, 130)
local LANTERN = Color3.fromRGB(255, 215, 140)

local player = Players.LocalPlayer

-- Every place a plot can be.
local plotSites = PlotLayout.sites()
-- The Market plaza; paths stop at its edge.
local plaza = Balance.world.plaza
local plazaCenter = Vector3.new(math.cos(math.rad(plaza.angle)) * plaza.radius, 0, math.sin(math.rad(plaza.angle)) * plaza.radius)

local PlotDecor = {}

type Plot = { model: Model, folder: Folder, tierFolder: Folder, path: { BasePart }, center: Vector3, tier: number, flags: { { part: BasePart, top: CFrame } } }
local plots: { [Model]: Plot } = {}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function ellipsoid(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(parent, { Size = size, CFrame = cframe, Color = color, Material = material or Enum.Material.SmoothPlastic })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function lantern(parent: Instance, position: Vector3, lit: boolean)
	local glass = part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, CFrame = CFrame.new(position), Color = LANTERN, Material = Enum.Material.Neon })
	if lit then
		local light = Instance.new("PointLight")
		light.Color = LANTERN
		light.Range = 14
		light.Brightness = 1.3
		light.Parent = glass
	end
	part(parent, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.6, 1.6), CFrame = CFrame.new(position + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(90, 70, 50), Material = Enum.Material.Metal })
end

local function pillar(parent: Instance, base: CFrame, height: number, lit: boolean)
	part(parent, { Size = Vector3.new(2.6, 0.8, 2.6), CFrame = base * CFrame.new(0, 0.4, 0), Color = SANDSTONE:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Sandstone })
	part(parent, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 1.8, 1.8), CFrame = base * CFrame.new(0, height / 2 + 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = SANDSTONE, Material = Enum.Material.Sandstone })
	part(parent, { Size = Vector3.new(2.4, 0.5, 2.4), CFrame = base * CFrame.new(0, height + 1, 0), Color = TRIM, Material = Enum.Material.SmoothPlastic })
	lantern(parent, (base * CFrame.new(0, height + 2, 0)).Position, lit)
end

local function ownerName(model: Model): string
	local owner = Players:GetPlayerByUserId(model:GetAttribute("OwnerId") or 0)
	return if owner then owner.DisplayName .. "'s Reef" else "Reef"
end

-- Rim, pillars, and the entrance arch.
local function buildFrame(plot: Plot, base: BasePart)
	local folder = plot.folder
	local cf = base.CFrame
	local hx, hz = base.Size.X / 2, base.Size.Z / 2
	local function wall(from: Vector3, to: Vector3)
		local mid = (from + to) / 2
		local length = (to - from).Magnitude
		local frame = CFrame.lookAt(mid, to)
		part(folder, { Size = Vector3.new(1.4, 1.4, length), CFrame = frame * CFrame.new(0, 0.6, 0), Color = SANDSTONE, Material = Enum.Material.Sandstone, CanCollide = true })
		part(folder, { Size = Vector3.new(1.6, 0.3, length), CFrame = frame * CFrame.new(0, 1.45, 0), Color = TRIM })
	end
	local function at(x: number, z: number): Vector3
		return (cf * CFrame.new(x, 0.5, z)).Position
	end
	-- Back and sides are solid; the front (toward spawn, -Z) has a gap for the arch.
	wall(at(-hx, hz), at(hx, hz))
	wall(at(-hx, -hz), at(-hx, hz))
	wall(at(hx, -hz), at(hx, hz))
	wall(at(-hx, -hz), at(-6, -hz))
	wall(at(6, -hz), at(hx, -hz))
	for _, corner in { { -hx, -hz }, { hx, -hz }, { -hx, hz }, { hx, hz } } do
		pillar(folder, cf * CFrame.new(corner[1], 0.5, corner[2]), 6, corner[2] < 0)
	end
	-- Entrance arch over the gap.
	for _, side in { -1, 1 } do
		pillar(folder, cf * CFrame.new(side * 6, 0.5, -hz), 9, false)
	end
	for k = 0, 6 do
		local a = k / 6 * math.pi
		part(folder, {
			Size = Vector3.new(1.6, 1.4, 1.8),
			CFrame = cf * CFrame.new(math.cos(a) * 6, 10.8 + math.sin(a) * 3, -hz) * CFrame.Angles(0, 0, a - math.pi / 2),
			Color = if k % 2 == 0 then SANDSTONE else TRIM,
			Material = Enum.Material.Sandstone,
		})
	end
	-- A banner with the owner's name hangs from the arch.
	local banner = part(folder, { Size = Vector3.new(8, 2.2, 0.15), CFrame = cf * CFrame.new(0, 11.2, -hz - 0.4), Color = Color3.fromRGB(18, 96, 108), Material = Enum.Material.Fabric })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(400, 110)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0
		label.Text = ownerName(plot.model)
		label.Parent = gui
		gui.Parent = banner
	end
end

-- Extra scenery as the reef grows.
local function buildTier(plot: Plot, base: BasePart, tier: number)
	local folder = plot.tierFolder
	folder:ClearAllChildren()
	local cf = base.CFrame
	local hx, hz = base.Size.X / 2, base.Size.Z / 2
	if tier >= 1 then
		-- Flags on every pillar.
		table.clear(plot.flags)
		for i, corner in { { -hx, -hz }, { hx, -hz }, { -hx, hz }, { hx, hz } } do
			local top = cf * CFrame.new(corner[1], 9.5, corner[2])
			part(folder, { Size = Vector3.new(0.2, 4, 0.2), CFrame = top, Color = Color3.fromRGB(90, 70, 50) })
			local flag = part(folder, { Size = Vector3.new(0.1, 1.6, 2.4), CFrame = top * CFrame.new(0, 1.1, 1.2), Color = if i % 2 == 0 then TRIM else Color3.fromRGB(255, 200, 60), Material = Enum.Material.Fabric })
			table.insert(plot.flags, { part = flag, top = top * CFrame.new(0, 1.1, 0) })
		end
	end
	if tier >= 2 then
		-- Coral clusters grow up beside the corners.
		local kinds = { "Brain", "Fan", "GlowingTube", "Staghorn" }
		for i, corner in { { -hx - 4, -hz + 6 }, { hx + 4, -hz + 6 }, { -hx - 4, hz - 4 }, { hx + 4, hz - 4 } } do
			local kind = kinds[i]
			local model = CoralModels.build(kind, Balance.corals[kind].color, i * 13)
			model:PivotTo(cf * CFrame.new(corner[1], 0.5, corner[2]))
			model:ScaleTo(1.4)
			model.Parent = folder
		end
	end
	if tier >= 3 then
		-- Glowing crystal lamps along the rim and bubble streams from the back.
		for i = -3, 3 do
			local crystal = part(folder, {
				Size = Vector3.new(0.7, 2.4, 0.7),
				CFrame = cf * CFrame.new(i * (hx / 3.5), 2.8, hz) * CFrame.Angles(0, math.pi / 4, 0.15),
				Color = Color3.fromRGB(150, 230, 255),
				Material = Enum.Material.Neon,
			})
			if i % 2 == 0 then
				local light = Instance.new("PointLight")
				light.Color = crystal.Color
				light.Range = 10
				light.Parent = crystal
			end
		end
		for _, x in { -hx * 0.6, 0, hx * 0.6 } do
			local vent = part(folder, { Size = Vector3.one * 0.5, CFrame = cf * CFrame.new(x, 1, hz + 1), Transparency = 1 })
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(230, 250, 255))
			e.Transparency = NumberSequence.new(0.3, 1)
			e.Size = NumberSequence.new(0.3, 0.7)
			e.Lifetime = NumberRange.new(4, 6)
			e.Rate = 5
			e.Speed = NumberRange.new(4, 6)
			e.SpreadAngle = Vector2.new(6, 6)
			e.Parent = vent
		end
	end
end

local function starfish(parent: Instance, position: Vector3, yaw: number, color: Color3)
	for i = 1, 5 do
		ellipsoid(parent, Vector3.new(0.4, 0.15, 1.1), CFrame.new(position) * CFrame.Angles(0, yaw + i / 5 * math.pi * 2, 0) * CFrame.new(0, 0.12, -0.5), color)
	end
end

local function urchin(parent: Instance, position: Vector3, rng: Random)
	part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = CFrame.new(position + Vector3.new(0, 0.4, 0)), Color = Color3.fromRGB(60, 30, 70) })
	for _ = 1, 7 do
		local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.1, 1), rng:NextNumber(-1, 1)).Unit
		part(parent, {
			Size = Vector3.new(0.08, 0.08, 1.4),
			CFrame = CFrame.lookAt(position + Vector3.new(0, 0.4, 0) + direction * 0.7, position + Vector3.new(0, 0.4, 0) + direction * 2),
			Color = Color3.fromRGB(90, 40, 100),
		})
	end
end

-- Little things scattered on the sand around the plot.
local function buildSurroundings(plot: Plot, base: BasePart)
	local folder = plot.folder
	local rng = Random.new(math.floor(base.Position.X * 7 + base.Position.Z * 13))
	local hx, hz = base.Size.X / 2, base.Size.Z / 2
	local function around(): Vector3
		-- A spot in a band 3-12 studs outside the plot edges.
		local side = rng:NextInteger(1, 4)
		local along = rng:NextNumber(-1, 1)
		local out = rng:NextNumber(3, 12)
		local local_ = if side == 1 then Vector3.new(along * hx, 0, hz + out)
			elseif side == 2 then Vector3.new(-hx - out, 0, along * hz)
			elseif side == 3 then Vector3.new(hx + out, 0, along * hz)
			else Vector3.new(along * hx, 0, -hz - out)
		local p = (base.CFrame * CFrame.new(local_)).Position
		return Vector3.new(p.X, 0, p.Z)
	end
	for _ = 1, 6 do
		local p = around()
		local shell = ellipsoid(folder, Vector3.new(0.9, 0.35, 1.1), CFrame.new(p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color3.fromRGB(255, 225, 215):Lerp(TRIM, rng:NextNumber(0, 0.5)))
		shell.Material = Enum.Material.SmoothPlastic
	end
	for i = 1, 3 do
		starfish(folder, around(), rng:NextNumber(0, 6), if i % 2 == 0 then Color3.fromRGB(240, 110, 60) else Color3.fromRGB(230, 70, 90))
	end
	for _ = 1, 3 do
		urchin(folder, around(), rng)
	end
	-- Swaying anemones: a few short, colorful stalks in a clump.
	for _ = 1, 3 do
		local center = around()
		local color = if rng:NextNumber() < 0.5 then Color3.fromRGB(240, 120, 170) else Color3.fromRGB(170, 120, 240)
		for _ = 1, 5 do
			WorldDecor.addSwaying(center + Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8)), 3, color, folder)
		end
	end
end

-- Glowing shells from spawn to the plot's front.
local function buildPath(plot: Plot, base: BasePart)
	local front = (base.CFrame * CFrame.new(0, 0, -base.Size.Z / 2 - 8)).Position
	local flatFront = Vector3.new(front.X, 0, front.Z)
	local direction = flatFront.Unit
	local start = direction * PATH_START_RADIUS
	local length = (flatFront - start).Magnitude
	local mine = plot.model:GetAttribute("OwnerId") == player.UserId
	for d = 0, length, PATH_SPACING do
		local p = start + direction * d + Vector3.new(0, 0.35, 0) -- on top of the stone walkway
		-- Don't lay shells across another plot (outer-ring paths pass inner plots).
		local blocked = false
		for _, center in plotSites do
			local flat = Vector3.new(center.X, 0, center.Z)
			if (flat - Vector3.new(base.Position.X, 0, base.Position.Z)).Magnitude > 1 and (Vector3.new(p.X, 0, p.Z) - flat).Magnitude < 32 then
				blocked = true
			end
		end
		if (Vector3.new(p.X, 0, p.Z) - plazaCenter).Magnitude < plaza.size then
			blocked = true
		end
		if blocked then
			continue
		end
		local shell = part(plot.folder, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 1.3, 1.3),
			CFrame = CFrame.new(p) * CFrame.Angles(0, 0, math.pi / 2),
			Color = if mine then Color3.fromRGB(255, 210, 110) else Color3.fromRGB(150, 220, 230),
			Material = if mine then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			Transparency = if mine then 0.2 else 0.35,
		})
		table.insert(plot.path, shell)
	end
end

local function tierFor(model: Model): number
	local owner = Players:GetPlayerByUserId(model:GetAttribute("OwnerId") or 0)
	local slots = if owner then owner:GetAttribute("Slots") or 0 else 0
	local tier = 0
	for i, threshold in TIERS do
		if slots >= threshold then
			tier = i
		end
	end
	return tier
end

local function onPlot(model: Instance)
	if not model:IsA("Model") or plots[model] then
		return
	end
	local base = model:WaitForChild("Base", 10) :: BasePart?
	if not base or not model.Parent then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "PlotDecor"
	local tierFolder = Instance.new("Folder")
	tierFolder.Name = "Growth"
	tierFolder.Parent = folder
	local plot: Plot = { model = model, folder = folder, tierFolder = tierFolder, path = {}, center = base.Position, tier = -1, flags = {} }

	plots[model] = plot
	buildFrame(plot, base)
	buildSurroundings(plot, base)
	buildPath(plot, base)
	folder.Parent = workspace
	local function updateTier()
		local tier = tierFor(model)
		if tier ~= plot.tier then
			plot.tier = tier
			buildTier(plot, base, tier)
		end
	end
	updateTier()
	local owner = Players:GetPlayerByUserId(model:GetAttribute("OwnerId") or 0)
	if owner then
		owner:GetAttributeChangedSignal("Slots"):Connect(updateTier)
	end
end

-- Each slot is a scalloped seashell dish: pink and peach lobes around the
-- sand, plus a stone ring underneath. Your empty slots sparkle softly.
local SHELL_PINK = Color3.fromRGB(255, 170, 185)
local SHELL_PEACH = Color3.fromRGB(255, 210, 165)
local LOBES = 10

local function onTile(tile: Instance)
	if not tile:IsA("BasePart") or tile:FindFirstChild("ShellDish") then
		return
	end
	local dish = Instance.new("Folder")
	dish.Name = "ShellDish"
	-- The tile is a cylinder on its side; this frame has +Y pointing up.
	local upright = tile.CFrame * CFrame.Angles(0, 0, -math.pi / 2)
	local radius = tile.Size.Z / 2
	part(dish, { Name = "TileRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, tile.Size.Z + 0.8, tile.Size.Z + 0.8), CFrame = tile.CFrame * CFrame.new(-0.05, 0, 0), Color = Color3.fromRGB(150, 130, 105), Material = Enum.Material.Sandstone })
	for i = 1, LOBES do
		local a = i / LOBES * math.pi * 2
		ellipsoid(dish, Vector3.new(1.5, 0.6, 1.1), upright * CFrame.Angles(0, a, 0) * CFrame.new(0, tile.Size.X / 2, -(radius + 0.2)), if i % 2 == 0 then SHELL_PINK else SHELL_PEACH)
	end
	if tile:GetAttribute("OwnerId") == player.UserId then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180))
		sparkle.Size = NumberSequence.new(0.35, 0)
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Rate = 3
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.EmissionDirection = Enum.NormalId.Right -- the tile's axis points up
		sparkle.LightEmission = 1
		sparkle.Parent = tile
		local function update()
			sparkle.Enabled = (tile:GetAttribute("CoralType") or "") == ""
		end
		tile:GetAttributeChangedSignal("CoralType"):Connect(update)
		update()
	end
	dish.Parent = tile
end

-- The buy pad becomes a giant open clam with a floating, spinning pearl.
type Clam = { pad: BasePart, pearl: BasePart, home: CFrame, hinge: CFrame, lid: { { part: BasePart, offset: CFrame } }, phase: number }
local clams: { [BasePart]: Clam } = {}

local function onPad(pad: Instance)
	if not pad:IsA("BasePart") or clams[pad] then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Clam"
	local upright = pad.CFrame * CFrame.Angles(0, 0, -math.pi / 2) -- +Y up, +Z toward the plot
	local shell = Color3.fromRGB(240, 150, 175)
	-- Bottom shell cupped under the pad, and the lid hinged open behind it.
	ellipsoid(folder, Vector3.new(9, 1.6, 8.5), upright * CFrame.new(0, -0.6, 0), shell) -- rim peeks out around the pad
	-- The lid and its ridges, posed from the hinge each frame (it breathes).
	local lid: { { part: BasePart, offset: CFrame } } = {}
	table.insert(lid, { part = ellipsoid(folder, Vector3.new(9, 1.2, 8.5), CFrame.identity, shell:Lerp(Color3.new(1, 1, 1), 0.15)), offset = CFrame.new(0, 0, -4.25) })
	for i = -3, 3 do
		local ridge = part(folder, { Size = Vector3.new(0.25, 0.3, 7.5), Color = Color3.fromRGB(255, 200, 215) })
		table.insert(lid, { part = ridge, offset = CFrame.new(0, 0, -4.25) * CFrame.Angles(0, math.rad(i * 9), 0) * CFrame.new(0, 0.55, 0) })
	end
	local hinge = upright * CFrame.new(0, 0.4, 4.2)
	local home = upright * CFrame.new(0, 3.4, 0)
	local pearl = part(folder, { Name = "Pearl", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = home, Color = Color3.fromRGB(255, 250, 240), Reflectance = 0.3 })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 235, 200)
	light.Range = 10
	light.Brightness = 1.4
	light.Parent = pearl
	folder.Parent = pad
	clams[pad] = { pad = pad, pearl = pearl, home = home, hinge = hinge, lid = lid, phase = pad.Position.X * 0.1 }
	pad.Destroying:Connect(function()
		clams[pad] = nil
	end)
end

function PlotDecor.start()
	local reefs = workspace:WaitForChild("Reefs")
	reefs.ChildAdded:Connect(onPlot)
	reefs.ChildRemoved:Connect(function(model)
		local plot = plots[model :: Model]
		if plot then
			plots[model :: Model] = nil
			plot.folder:Destroy()
		end
	end)
	for _, model in reefs:GetChildren() do
		task.spawn(onPlot, model)
	end
	CollectionService:GetInstanceAddedSignal("ReefSlot"):Connect(onTile)
	for _, tile in CollectionService:GetTagged("ReefSlot") do
		onTile(tile)
	end
	CollectionService:GetInstanceAddedSignal("ReefBuyPad"):Connect(onPad)
	for _, pad in CollectionService:GetTagged("ReefBuyPad") do
		onPad(pad)
	end

	local camera = workspace.CurrentCamera
	-- Hide far plots; pulse your own path.
	task.spawn(function()
		while true do
			local position = camera.CFrame.Position
			for _, plot in plots do
				local near = (Vector3.new(position.X, 0, position.Z) - Vector3.new(plot.center.X, 0, plot.center.Z)).Magnitude < HIDE_DISTANCE
				plot.folder.Parent = if near then workspace else nil
			end
			task.wait(1)
		end
	end)
	-- Walkway lanterns (built by the server) flicker like little flames.
	local lanterns: { [PointLight]: number } = {} -- light -> flicker phase
	local walkways = workspace:WaitForChild("Walkways", 10)
	if walkways then
		local function addLantern(item: Instance)
			if item:IsA("PointLight") and item.Parent and item.Parent.Name == "Lantern" and not lanterns[item] then
				lanterns[item] = math.random() * 10
				item.Destroying:Connect(function()
					lanterns[item] = nil
				end)
			end
		end
		walkways.DescendantAdded:Connect(addLantern) -- streamed in later
		for _, item in walkways:GetDescendants() do
			addLantern(item)
		end
	end
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for light, phase in lanterns do
			light.Brightness = 1 + math.sin(t * 9 + phase) * 0.15 + math.sin(t * 23 + phase) * 0.1
		end
		for _, clam in clams do
			clam.pearl.CFrame = clam.home * CFrame.new(0, math.sin(t * 2) * 0.4, 0) * CFrame.Angles(0, t, 0)
			-- The lid slowly opens and closes, like the clam is breathing.
			local frame = clam.hinge * CFrame.Angles(math.rad(105 + math.sin(t * 1.1 + clam.phase) * 12), 0, 0)
			for _, piece in clam.lid do
				piece.part.CFrame = frame * piece.offset
			end
		end
		for _, plot in plots do
			if plot.folder.Parent then
				for i, flag in plot.flags do
					flag.part.CFrame = flag.top * CFrame.Angles(0, math.sin(t * 3 + i) * 0.35, 0) * CFrame.new(0, 0, 1.2)
				end
			end
		end
		for _, plot in plots do
			if plot.model:GetAttribute("OwnerId") == player.UserId then
				for i, shell in plot.path do
					shell.Transparency = 0.15 + (math.sin(t * 3 - i * 0.5) + 1) * 0.2
				end
			end
		end
	end)
end

return PlotDecor
