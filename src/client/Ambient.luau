-- Ambient sea life, all on the client:
--   * sea turtles and manta rays gliding on wide loops
--   * hermit crabs wandering the sand around spawn and the plots
--   * cleaner shrimp and tiny fish gathering around corals ready to harvest
--   * glowing jellyfish drifting near you at night (bioluminescence)
-- Everything moves in one BulkMoveTo per frame, and only near the camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CreatureModels = require(ReplicatedStorage.Shared.CreatureModels)
local CoralRenderer = require(script.Parent.CoralRenderer)
local Mood = require(script.Parent.Mood)

local GLIDERS = { { kind = "turtle", count = 3 }, { kind = "ray", count = 2 } }
local CRABS = 10
local CLEANERS = 10
local JELLIES = 12
local ANIMATE_DISTANCE = 260

local Ambient = {}

local folder = Instance.new("Folder")
folder.Name = "AmbientLife"

type Body = { parts: { BasePart }, offsets: { CFrame }, roles: { string } }

local function build(kind: string, color: { number }, accent: { number }, scale: number): Body
	local model = CreatureModels.build(kind, color, accent)
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	local root = (model.PrimaryPart :: BasePart).CFrame
	local body: Body = { parts = {}, offsets = {}, roles = {} }
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(body.parts, p)
			table.insert(body.offsets, root:ToObjectSpace(p.CFrame))
			table.insert(body.roles, p.Name)
		end
	end
	model.Parent = folder
	return body
end

local function pose(role: string, t: number, phase: number): CFrame
	if role == "Tail" then
		return CFrame.Angles(0, math.sin(t * 6 + phase) * 0.4, 0)
	elseif role == "Fin" then
		return CFrame.Angles(0, 0, math.sin(t * 2 + phase) * 0.4)
	elseif role == "Tentacle" or role == "Leg" then
		return CFrame.Angles(math.sin(t * 4 + phase) * 0.3, 0, 0)
	end
	return CFrame.identity
end

local parts: { BasePart } = {}
local frames: { CFrame } = {}

local function emit(body: Body, root: CFrame, t: number, phase: number)
	for i, p in body.parts do
		parts[#parts + 1] = p
		frames[#frames + 1] = root * body.offsets[i] * pose(body.roles[i], t, phase)
	end
end

local function hide(body: Body)
	for _, p in body.parts do
		parts[#parts + 1] = p
		frames[#frames + 1] = CFrame.new(0, -500, 0)
	end
end

function Ambient.start()
	folder.Parent = workspace
	local camera = workspace.CurrentCamera
	local rng = Random.new()

	-- Gliders on big, slow, tilted loops around the reef.
	type Glider = { body: Body, radius: number, height: number, speed: number, phase: number, center: Vector3 }
	local gliders: { Glider } = {}
	for _, spec in GLIDERS do
		for _ = 1, spec.count do
			local color = if spec.kind == "turtle" then { 110, 150, 90 } else { 40, 50, 70 }
			local accent = if spec.kind == "turtle" then { 170, 130, 70 } else { 235, 235, 245 }
			table.insert(gliders, {
				body = build(spec.kind, color, accent, if spec.kind == "ray" then 1.6 else 1.3),
				radius = rng:NextNumber(60, 240),
				height = rng:NextNumber(14, 30),
				speed = rng:NextNumber(0.03, 0.06) * (if rng:NextNumber() < 0.5 then 1 else -1),
				phase = rng:NextNumber(0, math.pi * 2),
				center = Vector3.new(rng:NextNumber(-60, 60), 0, rng:NextNumber(-60, 60)),
			})
		end
	end

	-- Hermit crabs: walk to a nearby spot, pause, pick another.
	type Crab = { body: Body, position: Vector3, goal: Vector3, home: Vector3, wait: number, facing: Vector3, phase: number }
	local crabs: { Crab } = {}
	local homes = { Vector3.new(0, 0, 0) }
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		table.insert(homes, Vector3.new(math.cos(a) * 68, 0, math.sin(a) * 68))
	end
	for i = 1, CRABS do
		local home = homes[(i - 1) % #homes + 1] + Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
		table.insert(crabs, {
			body = build("crab", { 220, 110, 70 }, { 240, 220, 190 }, 0.7),
			position = home,
			goal = home,
			home = home,
			wait = 0,
			facing = Vector3.new(1, 0, 0),
			phase = rng:NextNumber(0, 6),
		})
	end

	-- Cleaner shrimp and tiny fish that gather around ready corals.
	type Cleaner = { body: Body, slot: number, phase: number }
	local cleaners: { Cleaner } = {}
	for i = 1, CLEANERS do
		local shrimp = i % 2 == 0
		table.insert(cleaners, {
			body = if shrimp
				then build("crab", { 245, 110, 90 }, { 255, 240, 230 }, 0.35)
				else build("fish", { 80, 200, 255 }, { 255, 255, 255 }, 0.45),
			slot = i,
			phase = rng:NextNumber(0, 6),
		})
	end

	-- Night jellies: glowing, drifting around the camera.
	type Jelly = { body: Body, offset: Vector3, phase: number }
	local jellies: { Jelly } = {}
	local glows = { { 120, 255, 230 }, { 190, 150, 255 }, { 255, 160, 220 } }
	for i = 1, JELLIES do
		local color = glows[(i - 1) % #glows + 1]
		table.insert(jellies, {
			body = build("jelly", color, { 255, 255, 255 }, rng:NextNumber(0.5, 0.9)),
			offset = Vector3.new(rng:NextNumber(-45, 45), rng:NextNumber(6, 22), rng:NextNumber(-45, 45)),
			phase = rng:NextNumber(0, 6),
		})
	end

	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		local cam = camera.CFrame.Position
		table.clear(parts)
		table.clear(frames)

		for _, g in gliders do
			local angle = g.phase + t * g.speed
			local position = g.center + Vector3.new(math.cos(angle) * g.radius, g.height + math.sin(t * 0.3 + g.phase) * 3, math.sin(angle) * g.radius)
			if (position - cam).Magnitude < ANIMATE_DISTANCE then
				local heading = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * math.sign(g.speed)
				emit(g.body, CFrame.lookAt(position, position + heading) * CFrame.Angles(0, 0, math.sin(t * 0.5 + g.phase) * 0.15), t, g.phase)
			end
		end

		for _, crab in crabs do
			if (crab.position - cam).Magnitude > ANIMATE_DISTANCE * 0.6 then
				continue
			end
			if crab.wait > 0 then
				crab.wait -= dt
			else
				local toGoal = crab.goal - crab.position
				if toGoal.Magnitude < 0.3 then
					crab.wait = rng:NextNumber(1, 4)
					crab.goal = crab.home + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10))
				else
					crab.facing = toGoal.Unit
					crab.position += toGoal.Unit * math.min(toGoal.Magnitude, dt * 2.2)
				end
			end
			-- Crabs scuttle sideways.
			local side = Vector3.new(-crab.facing.Z, 0, crab.facing.X)
			emit(crab.body, CFrame.lookAt(crab.position, crab.position + side) * CFrame.new(0, 0.05, 0), if crab.wait > 0 then 0 else t * 2, crab.phase)
		end

		-- Assign cleaners to the nearest ready corals.
		local tops = CoralRenderer.readyTops()
		table.sort(tops, function(a, b)
			return (a - cam).Magnitude < (b - cam).Magnitude
		end)
		for i, c in cleaners do
			local top = tops[(i - 1) % math.max(1, math.min(#tops, 5)) + 1]
			if top and (top - cam).Magnitude < 120 then
				local a = t * (1.2 + (i % 3) * 0.3) + c.phase
				local position = top + Vector3.new(math.cos(a) * 1.8, math.sin(t * 2 + c.phase) * 0.6 - 0.8, math.sin(a) * 1.8)
				local heading = Vector3.new(-math.sin(a), 0, math.cos(a))
				emit(c.body, CFrame.lookAt(position, position + heading), t, c.phase)
			else
				hide(c.body)
			end
		end

		-- Jellies only come out at night.
		local night = Mood.nightAmount() > 0.6 or ReplicatedStorage:GetAttribute("EventId") == "NightGlow"
		for _, j in jellies do
			if night then
				local o = j.offset
				local drift = Vector3.new(math.sin(t * 0.2 + j.phase) * 6, math.sin(t * 0.6 + j.phase) * 2, math.cos(t * 0.17 + j.phase) * 6)
				local position = Vector3.new(cam.X + o.X, o.Y, cam.Z + o.Z) + drift
				emit(j.body, CFrame.new(position) * CFrame.Angles(0, t * 0.2 + j.phase, 0), t, j.phase)
			else
				hide(j.body)
			end
		end

		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return Ambient
