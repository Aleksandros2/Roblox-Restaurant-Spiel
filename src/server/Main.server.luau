local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConstants = require(Shared:WaitForChild("GameConstants"))
local StationBillboardManager = require(ServerScriptService:WaitForChild("StationBillboardManager"))

local function ensureChild(parent, className, name)
	local child = parent:FindFirstChild(name)
	if child and not child:IsA(className) then
		child:Destroy()
		child = nil
	end

	if not child then
		child = Instance.new(className)
		child.Name = name
		child.Parent = parent
	end

	return child
end

local function applyProperties(instance, properties)
	for property, value in pairs(properties or {}) do
		instance[property] = value
	end
end

local function ensureFolder(parent, name)
	return ensureChild(parent, "Folder", name)
end

local function ensureModel(parent, name)
	return ensureChild(parent, "Model", name)
end

local function ensurePart(parent, name, properties)
	local part = ensureChild(parent, "Part", name)
	applyProperties(part, properties)
	return part
end

local function ensurePrompt(part, actionText, objectText, offset)
	local attachment = ensureChild(part, "Attachment", "InteractionPromptAttachment")
	attachment.Position = offset or Vector3.new(0, -0.25, -2.65)

	local prompt = attachment:FindFirstChildOfClass("ProximityPrompt")
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("ProximityPrompt") then
			if not prompt then
				child.Parent = attachment
				prompt = child
			else
				child:Destroy()
			end
		end
	end

	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = attachment
	end

	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.18
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, 42)
	return prompt
end

local function ensureSurfaceSign(part, name, face, text, backgroundColor, textColor, textSize)
	local surface = ensureChild(part, "SurfaceGui", name)
	applyProperties(surface, {
		AlwaysOnTop = true,
		CanvasSize = Vector2.new(720, 240),
		Face = face,
		LightInfluence = 0,
		PixelsPerStud = 48,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
	})

	local label = ensureChild(surface, "TextLabel", "Label")
	applyProperties(label, {
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = textColor,
		TextScaled = false,
		TextSize = textSize,
		TextWrapped = true,
	})

	local corner = ensureChild(label, "UICorner", "Corner")
	corner.CornerRadius = UDim.new(0, 12)

	local stroke = ensureChild(label, "UIStroke", "Stroke")
	applyProperties(stroke, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 2,
		Transparency = 0.35,
	})

	return surface
end

local function ensureQueuePadNumber(part, text)
	local surface = ensureChild(part, "SurfaceGui", "PadNumberSurface")
	applyProperties(surface, {
		AlwaysOnTop = false,
		CanvasSize = Vector2.new(180, 180),
		Face = Enum.NormalId.Top,
		LightInfluence = 0,
		PixelsPerStud = 32,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
	})

	local label = ensureChild(surface, "TextLabel", "Label")
	applyProperties(label, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = Color3.fromRGB(72, 61, 47),
		TextScaled = true,
		TextWrapped = true,
	})

	local constraint = ensureChild(label, "UITextSizeConstraint", "TextSizeConstraint")
	applyProperties(constraint, {
		MaxTextSize = 42,
		MinTextSize = 18,
	})
end

local function ensurePointLight(parent, name, color, range, brightness)
	local light = ensureChild(parent, "PointLight", name)
	applyProperties(light, {
		Brightness = brightness,
		Color = color,
		Enabled = true,
		Range = range,
		Shadows = false,
	})
	return light
end

local function ensureLightingEffect(className, name, properties)
	local effect = ensureChild(Lighting, className, name)
	applyProperties(effect, properties)
	return effect
end

local function ensureRemoteEvents()
	local remotesFolder = ensureFolder(ReplicatedStorage, "Remotes")
	local remotes = {}

	for _, remoteName in ipairs(GameConstants.REMOTE_NAMES) do
		local remote = remotesFolder:FindFirstChild(remoteName)
		if remote and not remote:IsA("RemoteEvent") then
			warn(remoteName .. " existed but was not a RemoteEvent. Recreating it.")
			remote:Destroy()
			remote = nil
		end

		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = remoteName
			remote.Parent = remotesFolder
		end

		remotes[remoteName] = remote
	end

	return remotes
end

local function ensureDecorSphere(parent, name, position, color, size, range, brightness)
	local bulb = ensurePart(parent, name, {
		Anchored = true,
		CanCollide = false,
		Color = color,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
		Size = size or Vector3.new(0.85, 0.85, 0.85),
		CFrame = CFrame.new(position),
	})
	ensurePointLight(bulb, "Glow", color, range or 9, brightness or 0.45)
	return bulb
end

local function ensureStation(parent, name, stationType, position, accentColor, actionText, displayTitle, subtitle)
	local base = ensurePart(parent, name .. "Base", {
		Anchored = true,
		Color = Color3.fromRGB(69, 58, 64),
		Material = Enum.Material.Concrete,
		Size = Vector3.new(5.8, 1.1, 5.8),
		CFrame = CFrame.new(position.X, 0.55, position.Z),
	})
	base.TopSurface = Enum.SurfaceType.Smooth
	base.BottomSurface = Enum.SurfaceType.Smooth

	local station = ensurePart(parent, name, {
		Anchored = true,
		Color = accentColor,
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(4.4, 2.4, 4.4),
		CFrame = CFrame.new(position),
	})
	station:SetAttribute("StationType", stationType)
	station.TopSurface = Enum.SurfaceType.Smooth
	station.BottomSurface = Enum.SurfaceType.Smooth

	local trim = ensurePart(parent, name .. "Trim", {
		Anchored = true,
		CanCollide = false,
		Color = Color3.fromRGB(255, 248, 228),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(4.8, 0.2, 4.8),
		CFrame = station.CFrame + Vector3.new(0, 1.31, 0),
	})

	local canopy = ensurePart(parent, name .. "Canopy", {
		Anchored = true,
		CanCollide = false,
		Color = Color3.fromRGB(255, 246, 226),
		Material = Enum.Material.Fabric,
		Size = Vector3.new(5.4, 0.24, 5.4),
		CFrame = station.CFrame + Vector3.new(0, 3.15, 0),
	})

	ensurePrompt(station, actionText, displayTitle, Vector3.new(0, -0.2, -2.85))
	StationBillboardManager.EnsureStationSign(station, {
		backgroundColor = accentColor,
		maxDistance = 68,
		studsOffset = Vector3.new(0, 3.75, 0),
		subtitle = subtitle or stationType,
		title = displayTitle,
	})
	ensurePointLight(trim, "AccentLight", accentColor, 10, 0.45)

	return station, base, canopy
end

local function ensureRestaurantTemplate()
	Lighting.ClockTime = 17.3
	Lighting.Brightness = 2.05
	Lighting.Ambient = Color3.fromRGB(94, 91, 108)
	Lighting.OutdoorAmbient = Color3.fromRGB(126, 122, 132)
	Lighting.FogColor = Color3.fromRGB(238, 215, 190)
	Lighting.FogEnd = 900

	ensureLightingEffect("Atmosphere", "FestivalAtmosphere", {
		Color = Color3.fromRGB(238, 221, 204),
		Decay = Color3.fromRGB(190, 144, 120),
		Density = 0.21,
		Glare = 0.06,
		Haze = 0.45,
	})
	ensureLightingEffect("BloomEffect", "FestivalBloom", {
		Enabled = true,
		Intensity = 0.08,
		Size = 18,
		Threshold = 1.8,
	})
	ensureLightingEffect("ColorCorrectionEffect", "FestivalGrade", {
		Brightness = -0.02,
		Contrast = 0.04,
		Saturation = 0.08,
		TintColor = Color3.fromRGB(255, 246, 236),
	})
	ensureLightingEffect("SunRaysEffect", "FestivalSunRays", {
		Enabled = true,
		Intensity = 0.03,
		Spread = 0.68,
	})

	local oldFoodTruck = Workspace:FindFirstChild("FoodTruck")
	if oldFoodTruck then
		oldFoodTruck:Destroy()
	end

	local templates = ensureFolder(ServerStorage, "Templates")
	local foodTruck = ensureModel(templates, "RestaurantTemplate")
	foodTruck:ClearAllChildren()

	local pivot = ensurePart(foodTruck, "RestaurantPivot", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 0, 0),
		Transparency = 1,
	})
	foodTruck.PrimaryPart = pivot

	ensurePart(foodTruck, "FestivalGround", {
		Anchored = true,
		Color = Color3.fromRGB(184, 176, 166),
		Material = Enum.Material.Concrete,
		Size = Vector3.new(62, 0.18, 48),
		CFrame = CFrame.new(0, 0.02, -7),
		Locked = true,
	})

	ensurePart(foodTruck, "FestivalPath", {
		Anchored = true,
		Color = Color3.fromRGB(98, 89, 102),
		Material = Enum.Material.Slate,
		Size = Vector3.new(34, 0.18, 26),
		CFrame = CFrame.new(0, 0.12, -15),
	})

	ensurePart(foodTruck, "TruckDeck", {
		Anchored = true,
		Color = Color3.fromRGB(121, 77, 63),
		Material = Enum.Material.WoodPlanks,
		Size = Vector3.new(30, 0.4, 18),
		CFrame = CFrame.new(0, 0.2, 1),
	})

	ensurePart(foodTruck, "TruckBase", {
		Anchored = true,
		Color = Color3.fromRGB(250, 106, 92),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(22, 2.2, 11),
		CFrame = CFrame.new(0, 1.5, 1),
	})

	ensurePart(foodTruck, "TruckCab", {
		Anchored = true,
		Color = Color3.fromRGB(255, 210, 88),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(6, 4.4, 10.4),
		CFrame = CFrame.new(7.6, 4.7, 1),
	})

	ensurePart(foodTruck, "TruckBody", {
		Anchored = true,
		Color = Color3.fromRGB(255, 141, 103),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(22, 6.2, 9.2),
		CFrame = CFrame.new(0, 5.2, 1),
	})

	ensurePart(foodTruck, "TruckRoof", {
		Anchored = true,
		Color = Color3.fromRGB(255, 243, 213),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(23, 0.45, 10.2),
		CFrame = CFrame.new(0, 8.55, 1),
	})

	ensurePart(foodTruck, "RoofTrim", {
		Anchored = true,
		CanCollide = false,
		Color = Color3.fromRGB(98, 209, 255),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(23.2, 0.15, 0.5),
		CFrame = CFrame.new(0, 8.75, -4.35),
	})

	ensurePart(foodTruck, "WindowFrame", {
		Anchored = true,
		Color = Color3.fromRGB(255, 243, 213),
		Material = Enum.Material.Metal,
		Size = Vector3.new(13, 0.25, 0.4),
		CFrame = CFrame.new(0, 5.8, -3.85),
	})

	ensurePart(foodTruck, "ServiceWindow", {
		Anchored = true,
		Color = Color3.fromRGB(113, 219, 255),
		Material = Enum.Material.Glass,
		Size = Vector3.new(11.8, 2.6, 0.24),
		CFrame = CFrame.new(0, 4.8, -3.9),
		Transparency = 0.35,
	})

	local awning = ensurePart(foodTruck, "Awning", {
		Anchored = true,
		Color = Color3.fromRGB(255, 212, 103),
		Material = Enum.Material.Fabric,
		Size = Vector3.new(16, 0.35, 5.4),
		CFrame = CFrame.new(0, 7.1, -6.85),
	})
	ensurePointLight(awning, "AwningGlow", Color3.fromRGB(255, 205, 124), 14, 0.45)

	local menuSign = ensurePart(foodTruck, "MenuSign", {
		Anchored = true,
		Color = Color3.fromRGB(255, 245, 215),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(15.8, 2.2, 0.35),
		CFrame = CFrame.new(0, 10.3, -4.15),
	})
	ensureSurfaceSign(menuSign, "MenuSurface", Enum.NormalId.Front, "TREND BONUS x2\nVIP BONUS x3", Color3.fromRGB(255, 248, 216), Color3.fromRGB(50, 34, 33), 54)

	local titleSign = ensurePart(foodTruck, "HeaderSign", {
		Anchored = true,
		Color = Color3.fromRGB(255, 112, 130),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(11.8, 2, 0.45),
		CFrame = CFrame.new(-2.8, 10.35, 5.35),
	})
	ensureSurfaceSign(titleSign, "HeaderSurface", Enum.NormalId.Back, "VIRAL KITCHEN", Color3.fromRGB(255, 120, 133), Color3.fromRGB(255, 252, 240), 64)
	ensurePointLight(titleSign, "TitleGlow", Color3.fromRGB(255, 164, 162), 12, 0.5)

	for wheelIndex, wheelData in ipairs({
		{ name = "FrontLeftWheel", x = -6.5, z = -4.4 },
		{ name = "FrontRightWheel", x = -6.5, z = 6.4 },
		{ name = "RearLeftWheel", x = 6.8, z = -4.4 },
		{ name = "RearRightWheel", x = 6.8, z = 6.4 },
	}) do
		local wheel = ensurePart(foodTruck, wheelData.name, {
			Anchored = true,
			Color = Color3.fromRGB(44, 41, 48),
			Material = Enum.Material.SmoothPlastic,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.6, 2.6, 2.6),
			CFrame = CFrame.new(wheelData.x, 0.8, wheelData.z) * CFrame.Angles(0, 0, math.rad(90)),
		})
		ensurePart(foodTruck, wheelData.name .. "Hub", {
			Anchored = true,
			CanCollide = false,
			Color = Color3.fromRGB(226, 220, 214),
			Material = Enum.Material.Metal,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 1.2, 1.2),
			CFrame = wheel.CFrame,
		})
	end

	local counter = ensurePart(foodTruck, "Counter", {
		Anchored = true,
		Color = Color3.fromRGB(255, 232, 122),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(13, 1.7, 3.4),
		CFrame = CFrame.new(0, 1.35, -10.2),
	})
	counter:SetAttribute("StationType", "Serving")
	ensurePrompt(counter, "Serve", "Counter", Vector3.new(0, 0.05, -2.15))
	StationBillboardManager.EnsureStationSign(counter, {
		backgroundColor = Color3.fromRGB(255, 244, 188),
		maxDistance = 62,
		size = UDim2.fromOffset(160, 50),
		studsOffset = Vector3.new(0, 2.55, 0),
		subtitle = "Serve Orders",
		title = "Counter",
	})
	ensurePointLight(counter, "CounterGlow", Color3.fromRGB(255, 226, 122), 12, 0.45)

	ensurePart(foodTruck, "CounterTop", {
		Anchored = true,
		CanCollide = false,
		Color = Color3.fromRGB(255, 248, 224),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(13.2, 0.18, 3.6),
		CFrame = counter.CFrame + Vector3.new(0, 0.95, 0),
	})

	ensureStation(foodTruck, "IngredientStation", "Ingredient", Vector3.new(-12.2, 1.25, -4.1), Color3.fromRGB(98, 221, 142), "Add Step", "Ingredients", "Prep")
	ensureStation(foodTruck, "CookingStation", "Cooking", Vector3.new(0, 1.25, -4.1), Color3.fromRGB(255, 150, 92), "Cook Step", "Cooking", "Heat")
	ensureStation(foodTruck, "DrinkStation", "Drink", Vector3.new(12.2, 1.25, -4.1), Color3.fromRGB(100, 207, 255), "Mix Step", "Drinks", "Mix")

	local upgradeStation = ensurePart(foodTruck, "UpgradeStation", {
		Anchored = true,
		Color = Color3.fromRGB(181, 137, 255),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(4.4, 2.4, 4.4),
		CFrame = CFrame.new(17, 1.25, 5.2),
	})
	upgradeStation:SetAttribute("StationType", "Upgrade")
	ensurePrompt(upgradeStation, "Open", "Upgrades", Vector3.new(0, -0.2, -2.85))
	StationBillboardManager.EnsureStationSign(upgradeStation, {
		backgroundColor = Color3.fromRGB(220, 194, 255),
		maxDistance = 62,
		studsOffset = Vector3.new(0, 3.75, 0),
		subtitle = "Truck Boosts",
		title = "Upgrades",
	})
	ensurePart(foodTruck, "UpgradeStationBase", {
		Anchored = true,
		Color = Color3.fromRGB(68, 55, 78),
		Material = Enum.Material.Concrete,
		Size = Vector3.new(5.8, 1.1, 5.8),
		CFrame = CFrame.new(17, 0.55, 5.2),
	})
	ensurePart(foodTruck, "UpgradeStationTrim", {
		Anchored = true,
		CanCollide = false,
		Color = Color3.fromRGB(232, 221, 255),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(4.8, 0.2, 4.8),
		CFrame = CFrame.new(17, 2.56, 5.2),
	})
	ensurePointLight(upgradeStation, "UpgradeGlow", Color3.fromRGB(206, 173, 255), 11, 0.45)

	local queue = ensureFolder(foodTruck, "CustomerQueue")
	for index, xPosition in ipairs({ -6, 0, 6 }) do
		local spawnPoint = ensurePart(queue, "SpawnPoint" .. index, {
			Anchored = true,
			Color = Color3.fromRGB(255, 239, 191),
			Material = Enum.Material.SmoothPlastic,
			Size = Vector3.new(3.4, 0.2, 3.4),
			CFrame = CFrame.new(xPosition, 0.12, -19.2),
			Transparency = 0.36,
		})
		StationBillboardManager.ClearManagedBillboards(spawnPoint)
		ensureQueuePadNumber(spawnPoint, tostring(index))
	end

	local queueSignAnchor = ensurePart(queue, "QueueSignAnchor", {
		Anchored = true,
		CanCollide = false,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 1.05, -23.2),
		Transparency = 1,
	})
	StationBillboardManager.EnsureQueueSign(queueSignAnchor, "Customer Queue")

	local customerExit = ensurePart(foodTruck, "CustomerExit", {
		Anchored = true,
		Color = Color3.fromRGB(255, 146, 146),
		Material = Enum.Material.Neon,
		Size = Vector3.new(9, 0.2, 3.6),
		CFrame = CFrame.new(0, 0.12, -29),
		Transparency = 0.38,
		CanCollide = false,
	})
	StationBillboardManager.EnsureStationSign(customerExit, {
		backgroundColor = Color3.fromRGB(255, 219, 219),
		maxDistance = 45,
		size = UDim2.fromOffset(112, 34),
		studsOffset = Vector3.new(0, 1.15, 0),
		title = "Exit",
	})

	local activeCustomers = ensureFolder(foodTruck, "ActiveCustomers")
	for _, child in ipairs(activeCustomers:GetChildren()) do
		child:Destroy()
	end

	ensurePart(foodTruck, "QueueRailLeft", {
		Anchored = true,
		Color = Color3.fromRGB(255, 233, 180),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(0.35, 1.2, 12),
		CFrame = CFrame.new(-9.1, 0.8, -16.3),
	})
	ensurePart(foodTruck, "QueueRailRight", {
		Anchored = true,
		Color = Color3.fromRGB(255, 233, 180),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(0.35, 1.2, 12),
		CFrame = CFrame.new(9.1, 0.8, -16.3),
	})
	ensurePart(foodTruck, "QueueRailFront", {
		Anchored = true,
		Color = Color3.fromRGB(255, 233, 180),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(18.6, 1.2, 0.35),
		CFrame = CFrame.new(0, 0.8, -10.5),
	})

	ensurePart(foodTruck, "FestivalArchLeft", {
		Anchored = true,
		Color = Color3.fromRGB(255, 210, 97),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(1.6, 8.5, 1.6),
		CFrame = CFrame.new(-15, 4.25, -12.2),
	})
	ensurePart(foodTruck, "FestivalArchRight", {
		Anchored = true,
		Color = Color3.fromRGB(255, 210, 97),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(1.6, 8.5, 1.6),
		CFrame = CFrame.new(15, 4.25, -12.2),
	})
	local archTop = ensurePart(foodTruck, "FestivalArchTop", {
		Anchored = true,
		Color = Color3.fromRGB(255, 106, 144),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(31, 1.2, 1.8),
		CFrame = CFrame.new(0, 8.4, -12.2),
	})
	ensureSurfaceSign(archTop, "ArchSurface", Enum.NormalId.Front, "FOOD FESTIVAL\nTREND TRUCK ZONE", Color3.fromRGB(255, 114, 147), Color3.fromRGB(255, 247, 241), 50)

	for index, xPosition in ipairs({ -21, -15, -9, -3, 3, 9, 15, 21 }) do
		local color = if index % 2 == 0 then Color3.fromRGB(98, 209, 255) else Color3.fromRGB(255, 109, 154)
		ensureDecorSphere(foodTruck, "FestivalLight" .. index, Vector3.new(xPosition, 9.2, -10.2), color, Vector3.new(0.9, 0.9, 0.9), 9, 0.45)
	end

	ensurePart(foodTruck, "StringLightPoleLeft", {
		Anchored = true,
		Color = Color3.fromRGB(86, 77, 83),
		Material = Enum.Material.Metal,
		Size = Vector3.new(0.5, 10, 0.5),
		CFrame = CFrame.new(-24, 5, -8.8),
	})
	ensurePart(foodTruck, "StringLightPoleRight", {
		Anchored = true,
		Color = Color3.fromRGB(86, 77, 83),
		Material = Enum.Material.Metal,
		Size = Vector3.new(0.5, 10, 0.5),
		CFrame = CFrame.new(24, 5, -8.8),
	})

	local leftTable = ensurePart(foodTruck, "LoungeTableLeft", {
		Anchored = true,
		Color = Color3.fromRGB(255, 242, 215),
		Material = Enum.Material.WoodPlanks,
		Size = Vector3.new(5, 0.35, 3.4),
		CFrame = CFrame.new(-21, 1.9, 6),
	})
	local rightTable = ensurePart(foodTruck, "LoungeTableRight", {
		Anchored = true,
		Color = Color3.fromRGB(255, 242, 215),
		Material = Enum.Material.WoodPlanks,
		Size = Vector3.new(5, 0.35, 3.4),
		CFrame = CFrame.new(21, 1.9, 6),
	})

	for _, tablePart in ipairs({ leftTable, rightTable }) do
		for legIndex, offset in ipairs({
			Vector3.new(-2.1, -1, -1.2),
			Vector3.new(2.1, -1, -1.2),
			Vector3.new(-2.1, -1, 1.2),
			Vector3.new(2.1, -1, 1.2),
		}) do
			ensurePart(foodTruck, tablePart.Name .. "Leg" .. legIndex, {
				Anchored = true,
				Color = Color3.fromRGB(113, 84, 67),
				Material = Enum.Material.WoodPlanks,
				Size = Vector3.new(0.35, 2, 0.35),
				CFrame = tablePart.CFrame + offset,
			})
		end
	end

	local planterLeft = ensurePart(foodTruck, "PlanterLeft", {
		Anchored = true,
		Color = Color3.fromRGB(103, 79, 60),
		Material = Enum.Material.WoodPlanks,
		Size = Vector3.new(3.4, 1.4, 3.4),
		CFrame = CFrame.new(-27, 0.7, 8),
	})
	local planterRight = ensurePart(foodTruck, "PlanterRight", {
		Anchored = true,
		Color = Color3.fromRGB(103, 79, 60),
		Material = Enum.Material.WoodPlanks,
		Size = Vector3.new(3.4, 1.4, 3.4),
		CFrame = CFrame.new(27, 0.7, 8),
	})

	ensureDecorSphere(planterLeft, "PlantGlow", planterLeft.Position + Vector3.new(0, 2.6, 0), Color3.fromRGB(118, 222, 138), Vector3.new(2.4, 2.4, 2.4), 8, 0.2)
	ensureDecorSphere(planterRight, "PlantGlow", planterRight.Position + Vector3.new(0, 2.6, 0), Color3.fromRGB(118, 222, 138), Vector3.new(2.4, 2.4, 2.4), 8, 0.2)

	local trendBoard = ensurePart(foodTruck, "TrendBoard", {
		Anchored = true,
		Color = Color3.fromRGB(255, 246, 228),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(8, 3.4, 0.4),
		CFrame = CFrame.new(-17.8, 4.6, -5),
	})
	ensureSurfaceSign(trendBoard, "TrendSurface", Enum.NormalId.Front, "TREND OF THE DAY\nCHECK THE HUD", Color3.fromRGB(255, 246, 228), Color3.fromRGB(43, 32, 34), 50)

	return foodTruck
end

local remotes = ensureRemoteEvents()
local restaurantTemplate = ensureRestaurantTemplate()

local servicesFolder = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(servicesFolder:WaitForChild("PlayerDataService"))
local PlotManager = require(servicesFolder:WaitForChild("PlotManager"))
local TrendService = require(servicesFolder:WaitForChild("TrendService"))
local RecipeService = require(servicesFolder:WaitForChild("RecipeService"))
local CustomerService = require(servicesFolder:WaitForChild("CustomerService"))
local UpgradeService = require(servicesFolder:WaitForChild("UpgradeService"))
local ViralRushService = require(servicesFolder:WaitForChild("ViralRushService"))

PlayerDataService:Init()
PlotManager:Init(remotes, restaurantTemplate)
ViralRushService:Init(remotes)
TrendService:Init(remotes)
UpgradeService:Init(remotes, PlayerDataService, PlotManager)
RecipeService:Init(remotes, PlayerDataService, PlotManager)
CustomerService:Init(remotes, {
	PlayerDataService = PlayerDataService,
	PlotManager = PlotManager,
	TrendService = TrendService,
	RecipeService = RecipeService,
	ViralRushService = ViralRushService,
})

print("Food Truck Frenzy: Viral Kitchen MVP server initialized.")
