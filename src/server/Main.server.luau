local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConstants = require(Shared:WaitForChild("GameConstants"))

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end

	return folder
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

local function ensurePart(parent, name, size, cframe, color, material)
	local part = parent:FindFirstChild(name)
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Parent = parent
	end

	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	return part
end

local function ensurePrompt(part, actionText, objectText)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = part
	end

	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	return prompt
end

local function ensureBillboard(part, text, color)
	local billboard = part:FindFirstChild("StationLabel")
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "StationLabel"
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.fromOffset(220, 56)
		billboard.StudsOffset = Vector3.new(0, 2.8, 0)
		billboard.Parent = part

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 0.08
		label.BorderSizePixel = 0
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextWrapped = true
		label.Parent = billboard

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
	end

	local label = billboard:FindFirstChild("Label")
	if label then
		label.Text = text
		label.TextColor3 = Color3.fromRGB(27, 25, 25)
		label.BackgroundColor3 = color
	end
end

local function ensureStation(parent, name, stationType, position, color, actionText)
	local station = ensurePart(parent, name, Vector3.new(4, 2, 4), CFrame.new(position), color, Enum.Material.SmoothPlastic)
	station:SetAttribute("StationType", stationType)
	ensurePrompt(station, actionText, name)
	ensureBillboard(station, name .. "\n" .. stationType, Color3.fromRGB(255, 255, 255))
	return station
end

local function ensureFoodTruckMap()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(135, 155, 180)
	Lighting.OutdoorAmbient = Color3.fromRGB(180, 190, 205)

	local foodTruck = Workspace:FindFirstChild("FoodTruck")
	if not foodTruck then
		foodTruck = Instance.new("Model")
		foodTruck.Name = "FoodTruck"
		foodTruck.Parent = Workspace
	end

	ensurePart(foodTruck, "FestivalGround", Vector3.new(64, 0.25, 52), CFrame.new(0, 0.05, -4), Color3.fromRGB(91, 194, 137), Enum.Material.Grass)
	ensurePart(foodTruck, "TruckBase", Vector3.new(20, 1.2, 10), CFrame.new(0, 1.1, 1), Color3.fromRGB(255, 92, 92), Enum.Material.SmoothPlastic)
	ensurePart(foodTruck, "TruckBody", Vector3.new(20, 5, 8), CFrame.new(0, 4.2, 1), Color3.fromRGB(255, 121, 75), Enum.Material.SmoothPlastic)
	ensurePart(foodTruck, "ServiceWindow", Vector3.new(10, 2.8, 0.35), CFrame.new(0, 4.1, -3.2), Color3.fromRGB(95, 221, 255), Enum.Material.Glass)
	ensurePart(foodTruck, "Awning", Vector3.new(14, 0.35, 4), CFrame.new(0, 6.6, -5), Color3.fromRGB(255, 214, 64), Enum.Material.SmoothPlastic)
	ensurePart(foodTruck, "MenuSign", Vector3.new(14, 2, 0.4), CFrame.new(0, 7.7, -3.6), Color3.fromRGB(255, 245, 181), Enum.Material.SmoothPlastic)

	ensureStation(foodTruck, "IngredientStation", "Ingredient", Vector3.new(-9, 1.1, -3), Color3.fromRGB(93, 215, 124), "Add Step")
	ensureStation(foodTruck, "CookingStation", "Cooking", Vector3.new(0, 1.1, -3), Color3.fromRGB(255, 156, 74), "Cook Step")
	ensureStation(foodTruck, "DrinkStation", "Drink", Vector3.new(9, 1.1, -3), Color3.fromRGB(80, 205, 255), "Mix Step")

	local counter = ensurePart(foodTruck, "Counter", Vector3.new(12, 1.5, 3), CFrame.new(0, 1.1, -8), Color3.fromRGB(255, 234, 98), Enum.Material.SmoothPlastic)
	counter:SetAttribute("StationType", "Serving")
	ensurePrompt(counter, "Serve Customer", "Counter")
	ensureBillboard(counter, "Counter\nServing", Color3.fromRGB(255, 255, 255))

	local upgradeStation = ensurePart(foodTruck, "UpgradeStation", Vector3.new(4, 2, 4), CFrame.new(13, 1.1, 4), Color3.fromRGB(188, 128, 255), Enum.Material.SmoothPlastic)
	upgradeStation:SetAttribute("StationType", "Upgrade")
	ensurePrompt(upgradeStation, "Open Upgrades", "Upgrade Station")
	ensureBillboard(upgradeStation, "Upgrade Station\nUpgrade", Color3.fromRGB(255, 255, 255))

	local queue = ensureFolder(foodTruck, "CustomerQueue")
	for index, xPosition in ipairs({ -5, 0, 5 }) do
		local spawnPoint = ensurePart(queue, "SpawnPoint" .. index, Vector3.new(3, 0.25, 3), CFrame.new(xPosition, 0.2, -16), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
		spawnPoint.Transparency = 0.15
		ensureBillboard(spawnPoint, "Queue " .. index, Color3.fromRGB(255, 255, 255))
	end

	local customerExit = ensurePart(foodTruck, "CustomerExit", Vector3.new(8, 0.25, 3), CFrame.new(0, 0.2, -27), Color3.fromRGB(255, 154, 154), Enum.Material.Neon)
	customerExit.Transparency = 0.2
	ensureBillboard(customerExit, "Customer Exit", Color3.fromRGB(255, 255, 255))

	ensureFolder(foodTruck, "ActiveCustomers")

	for index = 1, 8 do
		local x = -21 + (index - 1) * 6
		local color
		if index % 2 == 0 then
			color = Color3.fromRGB(85, 210, 255)
		else
			color = Color3.fromRGB(255, 101, 160)
		end
		ensurePart(foodTruck, "FestivalLight" .. index, Vector3.new(1, 1, 1), CFrame.new(x, 8.5, -10), color, Enum.Material.Neon)
	end
end

local remotes = ensureRemoteEvents()
ensureFoodTruckMap()

local servicesFolder = ServerScriptService:WaitForChild("Services")
local PlayerDataService = require(servicesFolder:WaitForChild("PlayerDataService"))
local TrendService = require(servicesFolder:WaitForChild("TrendService"))
local RecipeService = require(servicesFolder:WaitForChild("RecipeService"))
local CustomerService = require(servicesFolder:WaitForChild("CustomerService"))
local UpgradeService = require(servicesFolder:WaitForChild("UpgradeService"))
local ViralRushService = require(servicesFolder:WaitForChild("ViralRushService"))

PlayerDataService:Init()
ViralRushService:Init(remotes)
TrendService:Init(remotes)
UpgradeService:Init(remotes, PlayerDataService)
RecipeService:Init(remotes, PlayerDataService)
CustomerService:Init(remotes, {
	PlayerDataService = PlayerDataService,
	TrendService = TrendService,
	RecipeService = RecipeService,
	ViralRushService = ViralRushService,
})

print("Food Truck Frenzy: Viral Kitchen MVP server initialized.")
