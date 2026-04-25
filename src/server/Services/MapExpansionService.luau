local Workspace = game:GetService("Workspace")

local MapExpansionService = {}

MapExpansionService._initialized = false

local ROOT_NAME = "MapExpansion"

local COLORS = {
	grass = Color3.fromRGB(113, 180, 78),
	grassDark = Color3.fromRGB(82, 145, 68),
	path = Color3.fromRGB(205, 204, 188),
	road = Color3.fromRGB(58, 74, 86),
	roadLine = Color3.fromRGB(238, 242, 236),
	plot = Color3.fromRGB(232, 207, 154),
	plotLine = Color3.fromRGB(136, 116, 78),
	water = Color3.fromRGB(65, 176, 216),
	rock = Color3.fromRGB(142, 153, 142),
	trunk = Color3.fromRGB(111, 70, 54),
	leaf = Color3.fromRGB(66, 151, 61),
	leafLight = Color3.fromRGB(98, 184, 75),
}

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end

	return folder
end

local function makePart(parent, name, properties)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic

	for property, value in pairs(properties or {}) do
		part[property] = value
	end

	part.Parent = parent
	return part
end

local function makeModel(parent, name)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function makeFlatPart(parent, name, position, size, color, material)
	return makePart(parent, name, {
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Size = size,
		CFrame = CFrame.new(position),
	})
end

local function makeRoadSegment(parent, name, fromPosition, toPosition, width, color, material, withDashes)
	local delta = toPosition - fromPosition
	local length = Vector3.new(delta.X, 0, delta.Z).Magnitude
	if length < 0.1 then
		return nil
	end

	local center = (fromPosition + toPosition) / 2
	local cframe = CFrame.lookAt(center, Vector3.new(toPosition.X, center.Y, toPosition.Z))
	local segment = makePart(parent, name, {
		Color = color or COLORS.road,
		Material = material or Enum.Material.Slate,
		Size = Vector3.new(width, 0.18, length),
		CFrame = cframe,
	})

	if withDashes == false then
		return segment
	end

	local dashCount = math.max(1, math.floor(length / 13))
	for index = 1, dashCount do
		local zOffset = (-length / 2) + 6 + ((index - 1) * 13)
		if zOffset < length / 2 - 4 then
			makePart(parent, name .. "_Dash_" .. index, {
				CanCollide = false,
				Color = COLORS.roadLine,
				Material = Enum.Material.SmoothPlastic,
				Size = Vector3.new(0.8, 0.04, 5.2),
				CFrame = cframe * CFrame.new(0, 0.12, zOffset),
			})
		end
	end

	return segment
end

local function makeRoadPath(parent, name, points, width, color, material, withDashes)
	local pathFolder = ensureFolder(parent, name)
	for index = 1, #points - 1 do
		makeRoadSegment(pathFolder, "Segment_" .. index, points[index], points[index + 1], width, color, material, withDashes)
	end
	return pathFolder
end

local function makePlotArea(parent, id, center, rotation, size)
	local model = makeModel(parent, string.format("PlotArea_%02d", id))
	local baseCFrame = CFrame.new(center) * CFrame.Angles(0, rotation or 0, 0)

	makePart(model, "BuildField", {
		Color = COLORS.plot,
		Material = Enum.Material.Sand,
		Size = size,
		CFrame = baseCFrame,
	})

	local borderThickness = 1
	local xSize = size.X
	local zSize = size.Z
	local borderColor = Color3.fromRGB(232, 224, 199)
	makePart(model, "BorderFront", {
		Color = borderColor,
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(xSize + 3, 0.12, borderThickness),
		CFrame = baseCFrame * CFrame.new(0, 0.08, -zSize / 2),
	})
	makePart(model, "BorderBack", {
		Color = borderColor,
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(xSize + 3, 0.12, borderThickness),
		CFrame = baseCFrame * CFrame.new(0, 0.08, zSize / 2),
	})
	makePart(model, "BorderLeft", {
		Color = borderColor,
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(borderThickness, 0.12, zSize + 3),
		CFrame = baseCFrame * CFrame.new(-xSize / 2, 0.08, 0),
	})
	makePart(model, "BorderRight", {
		Color = borderColor,
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(borderThickness, 0.12, zSize + 3),
		CFrame = baseCFrame * CFrame.new(xSize / 2, 0.08, 0),
	})

	for dashIndex = 1, 9 do
		local offset = (-zSize / 2) + (dashIndex * (zSize / 10))
		makePart(model, "DividerVerticalDash_" .. dashIndex, {
			CanCollide = false,
			Color = COLORS.plotLine,
			Material = Enum.Material.SmoothPlastic,
			Size = Vector3.new(0.28, 0.08, 3.2),
			CFrame = baseCFrame * CFrame.new(0, 0.14, offset),
			Transparency = 0.18,
		})
	end

	for dashIndex = 1, 9 do
		local offset = (-xSize / 2) + (dashIndex * (xSize / 10))
		makePart(model, "DividerHorizontalDash_" .. dashIndex, {
			CanCollide = false,
			Color = COLORS.plotLine,
			Material = Enum.Material.SmoothPlastic,
			Size = Vector3.new(3.2, 0.08, 0.28),
			CFrame = baseCFrame * CFrame.new(offset, 0.14, 0),
			Transparency = 0.18,
		})
	end

	model:SetAttribute("PlotAreaId", id)
	return model
end

local function makeTree(parent, name, position, scale, lightLeaves)
	local model = makeModel(parent, name)
	scale = scale or 1

	makePart(model, "Trunk", {
		Color = COLORS.trunk,
		Material = Enum.Material.Wood,
		Size = Vector3.new(1.1, 4.1, 1.1) * scale,
		CFrame = CFrame.new(position.X, position.Y + (2.05 * scale), position.Z),
	})

	makePart(model, "Crown", {
		Color = lightLeaves and COLORS.leafLight or COLORS.leaf,
		Material = Enum.Material.Grass,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5.2, 4.6, 5.2) * scale,
		CFrame = CFrame.new(position.X, position.Y + (5.1 * scale), position.Z),
	})

	return model
end

local function makeRock(parent, name, position, scale)
	scale = scale or 1
	return makePart(parent, name, {
		Color = COLORS.rock,
		Material = Enum.Material.Slate,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.8, 1.7, 2.8) * scale,
		CFrame = CFrame.new(position),
	})
end

local function makeHill(parent, name, position, scale)
	return makePart(parent, name, {
		CanCollide = false,
		Color = Color3.fromRGB(126, 194, 79),
		Material = Enum.Material.Grass,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(26, 4, 18) * (scale or 1),
		CFrame = CFrame.new(position),
		Transparency = 0.12,
	})
end

local function makeWaterOval(parent, name, position, size)
	return makePart(parent, name, {
		CanCollide = false,
		Color = COLORS.water,
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
		Size = size,
		CFrame = CFrame.new(position),
		Transparency = 0.08,
	})
end

local function makeWindmill(parent, name, position, rotation)
	local model = makeModel(parent, name)
	local baseCFrame = CFrame.new(position) * CFrame.Angles(0, rotation or 0, 0)

	makePart(model, "Tower", {
		Color = Color3.fromRGB(228, 232, 228),
		Material = Enum.Material.Metal,
		Size = Vector3.new(1.4, 16, 1.4),
		CFrame = baseCFrame * CFrame.new(0, 8, 0),
	})

	local hubCFrame = baseCFrame * CFrame.new(0, 16.8, -0.8)
	makePart(model, "Hub", {
		Color = Color3.fromRGB(244, 246, 244),
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.7, 1.7, 1.7),
		CFrame = hubCFrame,
	})

	for bladeIndex = 1, 3 do
		local angle = math.rad((bladeIndex - 1) * 120)
		makePart(model, "Blade_" .. bladeIndex, {
			CanCollide = false,
			Color = Color3.fromRGB(250, 250, 246),
			Material = Enum.Material.SmoothPlastic,
			Size = Vector3.new(0.42, 8.6, 0.28),
			CFrame = hubCFrame * CFrame.Angles(0, 0, angle) * CFrame.new(0, 4.4, 0),
		})
	end

	return model
end

function MapExpansionService:_buildGround(nature)
	makeFlatPart(nature, "OuterGrass_North", Vector3.new(0, 0.03, -184), Vector3.new(500, 0.1, 150), COLORS.grass, Enum.Material.Grass)
	makeFlatPart(nature, "OuterGrass_South", Vector3.new(0, 0.03, 184), Vector3.new(500, 0.1, 150), COLORS.grass, Enum.Material.Grass)
	makeFlatPart(nature, "OuterGrass_West", Vector3.new(-184, 0.03, 0), Vector3.new(150, 0.1, 230), COLORS.grass, Enum.Material.Grass)
	makeFlatPart(nature, "OuterGrass_East", Vector3.new(184, 0.03, 0), Vector3.new(150, 0.1, 230), COLORS.grass, Enum.Material.Grass)
end

function MapExpansionService:_buildRoads(roads)
	makeRoadPath(roads, "NorthAccessRoad", {
		Vector3.new(-120, 0.16, -110),
		Vector3.new(-70, 0.16, -140),
		Vector3.new(0, 0.16, -150),
		Vector3.new(70, 0.16, -140),
		Vector3.new(120, 0.16, -110),
	}, 9, COLORS.path)

	makeRoadPath(roads, "WestPlotRoad", {
		Vector3.new(-110, 0.17, -35),
		Vector3.new(-145, 0.17, -60),
		Vector3.new(-178, 0.17, -110),
		Vector3.new(-184, 0.17, -168),
	}, 8, COLORS.path)

	makeRoadPath(roads, "EastPlotRoad", {
		Vector3.new(110, 0.17, -35),
		Vector3.new(145, 0.17, -62),
		Vector3.new(178, 0.17, -112),
		Vector3.new(184, 0.17, -168),
	}, 8, COLORS.path)

	makeRoadPath(roads, "SouthLoopRoad", {
		Vector3.new(-110, 0.17, 95),
		Vector3.new(-65, 0.17, 145),
		Vector3.new(-18, 0.17, 190),
		Vector3.new(58, 0.17, 212),
		Vector3.new(112, 0.17, 184),
	}, 8, COLORS.path)

	makeRoadPath(roads, "LeftNatureRoad", {
		Vector3.new(-120, 0.17, 40),
		Vector3.new(-170, 0.17, 38),
		Vector3.new(-206, 0.17, 22),
	}, 8, COLORS.path)

	makeRoadPath(roads, "RightNatureRoad", {
		Vector3.new(120, 0.17, 40),
		Vector3.new(170, 0.17, 38),
		Vector3.new(206, 0.17, 22),
	}, 8, COLORS.path)
end

function MapExpansionService:_buildPlotAreas(plots)
	local plotSize = Vector3.new(74, 0.12, 58)
	local definitions = {
		{ id = 1, center = Vector3.new(-184, 0.08, -168), rotation = math.rad(-7) },
		{ id = 2, center = Vector3.new(184, 0.08, -168), rotation = math.rad(7) },
		{ id = 3, center = Vector3.new(-206, 0.08, 22), rotation = math.rad(3) },
		{ id = 4, center = Vector3.new(206, 0.08, 22), rotation = math.rad(-3) },
		{ id = 5, center = Vector3.new(-162, 0.08, 172), rotation = math.rad(8) },
		{ id = 6, center = Vector3.new(162, 0.08, 172), rotation = math.rad(-8) },
		{ id = 7, center = Vector3.new(-58, 0.08, 212), rotation = math.rad(-4) },
		{ id = 8, center = Vector3.new(58, 0.08, 212), rotation = math.rad(4) },
	}

	for _, definition in ipairs(definitions) do
		makePlotArea(plots, definition.id, definition.center, definition.rotation, plotSize)
	end
end

function MapExpansionService:_buildNature(nature, decorations)
	local rng = Random.new(4252026)
	local treeAreas = {
		{ xMin = -240, xMax = -120, zMin = -230, zMax = 230 },
		{ xMin = 120, xMax = 240, zMin = -230, zMax = 230 },
		{ xMin = -120, xMax = 120, zMin = -240, zMax = -120 },
		{ xMin = -120, xMax = 120, zMin = 120, zMax = 245 },
	}

	for index = 1, 64 do
		local area = treeAreas[rng:NextInteger(1, #treeAreas)]
		local position = Vector3.new(rng:NextNumber(area.xMin, area.xMax), 0.05, rng:NextNumber(area.zMin, area.zMax))
		local scale = rng:NextNumber(0.75, 1.25)
		makeTree(nature, "Tree_" .. index, position, scale, index % 3 == 0)
	end

	for index = 1, 16 do
		local side = if index % 2 == 0 then -1 else 1
		local position = Vector3.new(side * rng:NextNumber(135, 232), 0.9, rng:NextNumber(-210, 225))
		makeRock(nature, "Rock_" .. index, position, rng:NextNumber(0.65, 1.25))
	end

	for index, hillData in ipairs({
		{ position = Vector3.new(-226, 1.1, -30), scale = 1.3 },
		{ position = Vector3.new(226, 1.1, -90), scale = 1.15 },
		{ position = Vector3.new(-104, 1.1, 226), scale = 1 },
		{ position = Vector3.new(106, 1.1, -226), scale = 0.95 },
	}) do
		makeHill(nature, "Hill_" .. index, hillData.position, hillData.scale)
	end

	makeWaterOval(decorations, "NorthPond", Vector3.new(0, 0.12, -210), Vector3.new(48, 0.18, 22))
	makeWaterOval(decorations, "SouthPond", Vector3.new(116, 0.12, 224), Vector3.new(34, 0.16, 16))
	makeRoadPath(decorations, "WestCreek", {
		Vector3.new(-236, 0.14, 214),
		Vector3.new(-224, 0.14, 198),
		Vector3.new(-236, 0.14, 178),
		Vector3.new(-214, 0.14, 156),
		Vector3.new(-222, 0.14, 132),
	}, 6, COLORS.water, Enum.Material.SmoothPlastic, false)

	makeWindmill(decorations, "Windmill_NorthWest", Vector3.new(-90, 0.05, -224), math.rad(-14))
	makeWindmill(decorations, "Windmill_North", Vector3.new(-18, 0.05, -230), math.rad(8))
	makeWindmill(decorations, "Windmill_South", Vector3.new(18, 0.05, 236), math.rad(-10))
	makeWindmill(decorations, "Windmill_SouthEast", Vector3.new(92, 0.05, 226), math.rad(12))
end

function MapExpansionService:Init()
	if self._initialized then
		return
	end
	self._initialized = true

	local root = Workspace:FindFirstChild(ROOT_NAME)
	if root and not root:IsA("Folder") then
		root:Destroy()
		root = nil
	end
	root = root or ensureFolder(Workspace, ROOT_NAME)
	root:ClearAllChildren()

	ensureFolder(root, "City")
	local roads = ensureFolder(root, "Roads")
	local nature = ensureFolder(root, "Nature")
	local plots = ensureFolder(root, "Plots")
	local decorations = ensureFolder(root, "Decorations")

	self:_buildGround(nature)
	self:_buildPlotAreas(plots)
	self:_buildRoads(roads)
	self:_buildNature(nature, decorations)
end

return MapExpansionService
