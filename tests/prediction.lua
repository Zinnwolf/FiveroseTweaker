if not table.create then
	function table.create()
		return {}
	end
end

local vector = {}
local vectorMeta = {}

function vectorMeta.__index(value, key)
	if key == 'Magnitude' then
		return math.sqrt(value.X * value.X + value.Y * value.Y + value.Z * value.Z)
	end

	return vector[key]
end

function vectorMeta.__add(left, right)
	return vector.new(left.X + right.X, left.Y + right.Y, left.Z + right.Z)
end

function vectorMeta.__sub(left, right)
	return vector.new(left.X - right.X, left.Y - right.Y, left.Z - right.Z)
end

function vectorMeta.__mul(left, right)
	if type(left) == 'number' then
		left, right = right, left
	end

	return vector.new(left.X * right, left.Y * right, left.Z * right)
end

function vectorMeta.__div(left, right)
	return vector.new(left.X / right, left.Y / right, left.Z / right)
end

function vector.new(x, y, z)
	return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, vectorMeta)
end

function vector:Dot(other)
	return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end

Vector3 = vector
Vector3.zero = vector.new()
workspace = {
	Raycast = function()
		return nil
	end
}

local file = assert(io.open('src/vape/libraries/prediction.lua', 'rb'))
local source = file:read('*a')
file:close()

local replacements = {
	{'for _, value in roots do', 'for _, value in pairs(roots) do'},
	{'for _, v in solutions do', 'for _, v in pairs(solutions) do'},
	{'q -= (.5 * playerGravity) * estTime', 'q = q - (.5 * playerGravity) * estTime'},
	{'estTime -= math.sqrt(((targetPos - newTarget).Magnitude * 2) / playerGravity)', 'estTime = estTime - math.sqrt(((targetPos - newTarget).Magnitude * 2) / playerGravity)'},
}

for _, replacement in ipairs(replacements) do
	local first, last = source:find(replacement[1], 1, true)
	assert(first, replacement[1])
	source = source:sub(1, first - 1)..replacement[2]..source:sub(last + 1)
end

local chunk, err = load(source, '@prediction.lua', 't', _ENV)
assert(chunk, err)
local prediction = chunk()

local function near(value, expected, tolerance)
	return math.abs(value - expected) <= (tolerance or 1e-5)
end

local origin = vector.new()
local stationary = prediction.SolveTrajectory(
	origin,
	50,
	0,
	vector.new(100, 0, 0),
	vector.new(),
	nil,
	nil,
	nil,
	nil
)
assert(stationary and near(stationary.X, 50) and near(stationary.Y, 0))

local lateral = prediction.SolveTrajectory(
	origin,
	50,
	0,
	vector.new(100, 0, 0),
	vector.new(0, 10, 0),
	nil,
	nil,
	nil,
	nil
)
assert(lateral and near(lateral.Magnitude, 50, 1e-4))
assert(near(lateral.Y, 10, 1e-4))

local receding = prediction.SolveTrajectory(
	origin,
	50,
	0,
	vector.new(100, 0, 0),
	vector.new(10, 0, 0),
	nil,
	nil,
	nil,
	nil
)
assert(receding and near(receding.X, 50, 1e-4))

local impossible = prediction.SolveTrajectory(
	origin,
	10,
	0,
	vector.new(100, 0, 0),
	vector.new(20, 0, 0),
	nil,
	nil,
	nil,
	nil
)
assert(impossible == nil)

local ballistic = prediction.SolveTrajectory(
	origin,
	50,
	9.81,
	vector.new(100, 0, 0),
	vector.new(),
	nil,
	nil,
	nil,
	nil
)
assert(ballistic and ballistic.Y > 0)
assert(near(ballistic.Magnitude, 50, 1e-3))

local roots = prediction.solveQuartic(1, -10, 35, -50, 24)
table.sort(roots)
for index = 1, 4 do
	assert(near(roots[index], index, 1e-4), tostring(roots[index]))
end

print('prediction tests passed')
