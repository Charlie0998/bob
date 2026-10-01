-- Minimal stand-ins for the Roblox datatypes CoralModels.luau uses, so its
-- builders can run in the standalone luau CLI for offline previews.

local Vector3 = {}
local V = {}
V.__index = function(v, k)
	if k == "X" then return v[1] elseif k == "Y" then return v[2] elseif k == "Z" then return v[3]
	elseif k == "Magnitude" then return math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
	elseif k == "Unit" then local m = math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2); return Vector3.new(v[1] / m, v[2] / m, v[3] / m)
	end
	return nil
end
function Vector3.new(x, y, z) return setmetatable({ x or 0, y or 0, z or 0 }, V) end
V.__add = function(a, b) return Vector3.new(a[1] + b[1], a[2] + b[2], a[3] + b[3]) end
V.__sub = function(a, b) return Vector3.new(a[1] - b[1], a[2] - b[2], a[3] - b[3]) end
V.__unm = function(a) return Vector3.new(-a[1], -a[2], -a[3]) end
V.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return Vector3.new(a[1] * b, a[2] * b, a[3] * b) end
	return Vector3.new(a[1] * b[1], a[2] * b[2], a[3] * b[3])
end
V.__div = function(a, b) return Vector3.new(a[1] / b, a[2] / b, a[3] / b) end
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zero = Vector3.new(0, 0, 0)

local function cross(a, b) return Vector3.new(a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1]) end

-- CFrame: position p and rotation matrix r (row-major 3x3).
local CFrame = {}
local C = {}
local function cf(p, r) return setmetatable({ p = p, r = r }, C) end
local function matmul(a, b)
	local out = {}
	for i = 0, 2 do for j = 0, 2 do
		local s = 0
		for k = 0, 2 do s += a[i * 3 + k + 1] * b[k * 3 + j + 1] end
		out[i * 3 + j + 1] = s
	end end
	return out
end
local function rotate(r, v) return Vector3.new(r[1] * v[1] + r[2] * v[2] + r[3] * v[3], r[4] * v[1] + r[5] * v[2] + r[6] * v[3], r[7] * v[1] + r[8] * v[2] + r[9] * v[3]) end
local I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
function CFrame.new(x, y, z)
	if type(x) == "table" then return cf(x, I) end
	return cf(Vector3.new(x, y, z), I)
end
function CFrame.Angles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(Vector3.zero, matmul(matmul(Rx, Ry), Rz))
end
function CFrame.lookAt(at, target, up)
	up = up or Vector3.yAxis
	local look = (target - at).Unit
	local right = cross(look, up).Unit
	local up2 = cross(right, look)
	return cf(at, { right[1], up2[1], -look[1], right[2], up2[2], -look[2], right[3], up2[3], -look[3] })
end
CFrame.identity = CFrame.new(0, 0, 0)
C.__index = function(c, k)
	if k == "Position" then return c.p end
	return nil
end
C.__mul = function(a, b)
	if getmetatable(b) == V then return a.p + rotate(a.r, b) end
	return cf(a.p + rotate(a.r, b.p), matmul(a.r, b.r))
end
C.__add = function(a, v) return cf(a.p + v, a.r) end
C.__sub = function(a, v) return cf(a.p - v, a.r) end

local Color3 = {}
local Col = {}
Col.__index = Col
function Color3.new(r, g, b) return setmetatable({ R = r, G = g, B = b }, Col) end
function Color3.fromRGB(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
function Col:Lerp(o, t) return Color3.new(self.R + (o.R - self.R) * t, self.G + (o.G - self.G) * t, self.B + (o.B - self.B) * t) end

local Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ s = (seed or 1) % 2147483647 + 1 }, Random)
end
function Random:_next()
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function Random:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:_next()
end
function Random:NextInteger(a, b) return math.floor(a + (b - a + 1) * self:_next()) end

local Enum = setmetatable({}, { __index = function(_, group)
	return setmetatable({}, { __index = function(_, name) return group .. "." .. name end })
end })

local all = {}
local Instance = {}
local Inst = {}
Inst.__index = Inst
Inst.__newindex = function(t, k, v)
	if k == "Parent" then
		rawset(t, "_parent", v)
		if v then table.insert(v._children, t) end
		return
	end
	rawset(t, k, v)
end
function Instance.new(className)
	local inst = setmetatable({ ClassName = className, _children = {}, Transparency = 0, Material = "Enum.Material.Plastic", Shape = "Enum.PartType.Block" }, Inst)
	table.insert(all, inst)
	return inst
end
function Inst:GetChildren() return self._children end

local function stub(...) return { ... } end
local Seq = { new = stub }

return {
	Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Random = Random, Enum = Enum, Instance = Instance,
	NumberSequence = Seq, ColorSequence = Seq, NumberRange = Seq, Vector2 = Seq, NumberSequenceKeypoint = Seq,
	all = all,
}
