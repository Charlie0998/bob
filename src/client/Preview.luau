-- Small 3D previews of corals and creatures for GUI cards (Book, Market).
-- Undiscovered entries can be shown as a solid black silhouette.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local CoralModels = require(ReplicatedStorage.Shared.CoralModels)
local CreatureModels = require(ReplicatedStorage.Shared.CreatureModels)
local DecorModels = require(ReplicatedStorage.Shared.DecorModels)
local UIKit = require(script.Parent.UIKit)

local COLORS = UIKit.COLORS

local Preview = {}

local function frame(viewport: ViewportFrame, model: Model, direction: Vector3)
	model.Parent = viewport
	local cframe, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(cframe.Position + direction.Unit * radius * 2.6, cframe.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function makeViewport(parent: GuiObject, position: UDim2, size: UDim2, known: boolean): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Position = position
	viewport.Size = size
	viewport.BackgroundTransparency = 1
	viewport.Ambient = if known then COLORS.previewAmbient else COLORS.silhouette
	viewport.LightColor = if known then COLORS.previewLight else COLORS.silhouette
	viewport.LightDirection = Vector3.new(-1, -2, -1)
	viewport.Parent = parent
	return viewport
end

local function strip(model: Model, known: boolean)
	for _, item in model:GetDescendants() do
		if item:IsA("Light") or item:IsA("ParticleEmitter") then
			item:Destroy()
		elseif item:IsA("BasePart") and not known and item.Transparency < 1 then
			item.Color = COLORS.silhouette
			item.Material = Enum.Material.SmoothPlastic
			item.Transparency = 0
		end
	end
end

-- A coral (isCoral) or creature preview inside `parent`.
function Preview.attach(parent: GuiObject, id: string, isCoral: boolean, known: boolean, position: UDim2, size: UDim2): ViewportFrame
	local viewport = makeViewport(parent, position, size, known)
	local def = if isCoral then Balance.corals[id] else Balance.creatures[id]
	local model = if isCoral then CoralModels.build(id, def.color, 7) else CreatureModels.build(def.kind, def.color, def.accent)
	strip(model, known)
	frame(viewport, model, if isCoral then Vector3.new(1, 0.6, 1) else Vector3.new(1, 0.4, -1))
	return viewport
end

-- A decoration preview.
function Preview.decor(parent: GuiObject, id: string, position: UDim2, size: UDim2): ViewportFrame
	local viewport = makeViewport(parent, position, size, true)
	local model = DecorModels.build(id)
	strip(model, true)
	frame(viewport, model, Vector3.new(1, 0.5, -1))
	return viewport
end

return Preview
