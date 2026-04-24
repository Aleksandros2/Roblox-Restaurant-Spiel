local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConstants = require(ReplicatedStorage.Shared.GameConstants)
local RecipeDefinitions = require(ReplicatedStorage.Shared.RecipeDefinitions)
local StationBillboardManager = require(ServerScriptService:WaitForChild("StationBillboardManager"))

local CustomerService = {}

CustomerService._remotes = nil
CustomerService._playerDataService = nil
CustomerService._plotManager = nil
CustomerService._trendService = nil
CustomerService._recipeService = nil
CustomerService._viralRushService = nil
CustomerService._customersByPlayer = {}
CustomerService._lastSpawnAtByPlayer = {}
CustomerService._customerSequence = 0
CustomerService._random = Random.new()
CustomerService._initialized = false

local CUSTOMER_COLORS = {
	Color3.fromRGB(255, 217, 102),
	Color3.fromRGB(116, 214, 255),
	Color3.fromRGB(255, 142, 185),
	Color3.fromRGB(142, 255, 174),
}

local RECIPE_ACCENTS = {
	SpicyRamen = Color3.fromRGB(255, 133, 96),
	BubbleTea = Color3.fromRGB(106, 209, 255),
	KoreanCornDog = Color3.fromRGB(255, 210, 95),
}

local function addPointLight(parent, color, range, brightness)
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = brightness
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Shadows = false
	pointLight.Parent = parent
	return pointLight
end

local function makeOrderBillboard(parent, customer)
	local displayName = RecipeDefinitions.GetRecipeDisplayName(customer.orderRecipeId)
	local queueOffset = (customer.queueIndex or 2) - 2
	local cardYOffset = if customer.queueIndex == 2 then 3.15 else 2.75

	StationBillboardManager.EnsureOrderCard(parent, {
		backgroundColor = customer.isInfluencer and Color3.fromRGB(255, 225, 134) or Color3.fromRGB(255, 248, 228),
		badge = if customer.isInfluencer then "VIP ORDER" else "ORDER",
		maxDistance = 58,
		size = UDim2.fromOffset(162, if customer.isInfluencer then 58 else 50),
		studsOffset = Vector3.new(0, cardYOffset, 0),
		studsOffsetWorldSpace = Vector3.new(queueOffset * 0.25, 0, 0),
		title = displayName,
	})
end

function CustomerService:_notify(player, message, notificationType)
	self._remotes.NotificationEvent:FireClient(player, {
		message = message,
		notificationType = notificationType or "Info",
	})
end

function CustomerService:_getCustomerBucket(player)
	local bucket = self._customersByPlayer[player]
	if not bucket then
		bucket = {}
		self._customersByPlayer[player] = bucket
	end

	return bucket
end

function CustomerService:_getRestaurant(player)
	local plot = self._plotManager:GetPlayerPlot(player)
	return plot and plot.RestaurantModel
end

function CustomerService:_getQueueFolder(player)
	local restaurant = self:_getRestaurant(player)
	return restaurant and restaurant:FindFirstChild("CustomerQueue")
end

function CustomerService:_getActiveCustomersFolder(player)
	local restaurant = self:_getRestaurant(player)
	if not restaurant then
		return nil
	end

	local folder = restaurant:FindFirstChild("ActiveCustomers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ActiveCustomers"
		folder.Parent = restaurant
	end

	return folder
end

function CustomerService:_getQueueSpawnPoint(player, index)
	local queueFolder = self:_getQueueFolder(player)
	if not queueFolder then
		return nil
	end

	return queueFolder:FindFirstChild("SpawnPoint" .. index)
end

function CustomerService:_getOpenQueueIndex(player)
	local used = {}
	for _, customer in pairs(self:_getCustomerBucket(player)) do
		if customer.queueIndex then
			used[customer.queueIndex] = true
		end
	end

	for index = 1, GameConstants.MAX_ACTIVE_CUSTOMERS do
		if not used[index] and self:_getQueueSpawnPoint(player, index) then
			return index
		end
	end

	return nil
end

function CustomerService:_buildCustomerPayload(customer)
	local remaining = math.max(1, customer.timeoutSeconds - (workspace:GetServerTimeNow() - customer.spawnTime))
	return {
		customerId = customer.customerId,
		orderRecipeId = customer.orderRecipeId,
		orderDisplayName = RecipeDefinitions.GetRecipeDisplayName(customer.orderRecipeId),
		isInfluencer = customer.isInfluencer,
		timeoutSeconds = remaining,
	}
end

function CustomerService:_createCustomerModel(player, customer)
	local spawnPoint = self:_getQueueSpawnPoint(player, customer.queueIndex)
	local activeFolder = self:_getActiveCustomersFolder(player)
	if not spawnPoint or not activeFolder then
		return nil
	end

	local accentColor = RECIPE_ACCENTS[customer.orderRecipeId] or CUSTOMER_COLORS[self._random:NextInteger(1, #CUSTOMER_COLORS)]
	local bodyColor = CUSTOMER_COLORS[self._random:NextInteger(1, #CUSTOMER_COLORS)]

	local model = Instance.new("Model")
	model.Name = customer.isInfluencer and ("Influencer_" .. customer.customerId) or ("Customer_" .. customer.customerId)
	model:SetAttribute("CustomerId", customer.customerId)
	model:SetAttribute("OrderRecipeId", customer.orderRecipeId)
	model:SetAttribute("IsInfluencer", customer.isInfluencer)
	model:SetAttribute("PlotId", spawnPoint:GetAttribute("PlotId"))
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = activeFolder

	local basePad = Instance.new("Part")
	basePad.Name = "QueueGlow"
	basePad.Anchored = true
	basePad.CanCollide = false
	basePad.Shape = Enum.PartType.Cylinder
	basePad.Size = Vector3.new(0.22, 3.4, 3.4)
	basePad.Color = accentColor
	basePad.Material = Enum.Material.SmoothPlastic
	basePad.Transparency = 0.32
	basePad.CFrame = CFrame.new(spawnPoint.Position + Vector3.new(0, 0.14, 0)) * CFrame.Angles(0, 0, math.rad(90))
	basePad.Parent = model
	addPointLight(basePad, accentColor, 7, 0.35)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Size = Vector3.new(2.1, 3, 1.1)
	body.Color = bodyColor
	body.Material = Enum.Material.SmoothPlastic
	body.CFrame = spawnPoint.CFrame + Vector3.new(0, 1.6, 0)
	body.Parent = model
	model.PrimaryPart = body

	local outfit = Instance.new("Part")
	outfit.Name = "Outfit"
	outfit.Anchored = true
	outfit.CanCollide = false
	outfit.Size = Vector3.new(2.18, 1.65, 1.16)
	outfit.Color = accentColor
	outfit.Material = Enum.Material.SmoothPlastic
	outfit.CFrame = body.CFrame + Vector3.new(0, -0.25, -0.02)
	outfit.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = true
	head.CanCollide = false
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.Color = Color3.fromRGB(255, 224, 189)
	head.Material = Enum.Material.SmoothPlastic
	head.CFrame = body.CFrame + Vector3.new(0, 2.2, 0)
	head.Parent = model

	local leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"
	leftArm.Anchored = true
	leftArm.CanCollide = false
	leftArm.Size = Vector3.new(0.55, 2.2, 0.55)
	leftArm.Color = bodyColor
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.CFrame = body.CFrame + Vector3.new(-1.25, 0.15, 0)
	leftArm.Parent = model

	local rightArm = Instance.new("Part")
	rightArm.Name = "RightArm"
	rightArm.Anchored = true
	rightArm.CanCollide = false
	rightArm.Size = Vector3.new(0.55, 2.2, 0.55)
	rightArm.Color = bodyColor
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.CFrame = body.CFrame + Vector3.new(1.25, 0.15, 0)
	rightArm.Parent = model

	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Anchored = true
	cap.CanCollide = false
	cap.Size = Vector3.new(1.7, 0.35, 1.7)
	cap.Color = accentColor
	cap.Material = Enum.Material.SmoothPlastic
	cap.CFrame = head.CFrame + Vector3.new(0, 0.82, 0)
	cap.Parent = model

	local visor = Instance.new("Part")
	visor.Name = "Visor"
	visor.Anchored = true
	visor.CanCollide = false
	visor.Size = Vector3.new(1.1, 0.14, 0.55)
	visor.Color = accentColor
	visor.Material = Enum.Material.SmoothPlastic
	visor.CFrame = cap.CFrame + Vector3.new(0, -0.08, -0.65)
	visor.Parent = model

	if customer.isInfluencer then
		local halo = Instance.new("Part")
		halo.Name = "InfluencerHalo"
		halo.Anchored = true
		halo.CanCollide = false
		halo.Shape = Enum.PartType.Cylinder
		halo.Size = Vector3.new(0.18, 2.5, 2.5)
		halo.Color = Color3.fromRGB(255, 214, 92)
		halo.Material = Enum.Material.Neon
		halo.CFrame = CFrame.new(head.Position + Vector3.new(0, 1.45, 0)) * CFrame.Angles(0, 0, math.rad(90))
		halo.Parent = model
		addPointLight(halo, Color3.fromRGB(255, 214, 92), 8, 0.5)
	end

	makeOrderBillboard(head, customer)

	return model
end

function CustomerService:_removeCustomer(player, customerId, reason)
	local bucket = self:_getCustomerBucket(player)
	local customer = bucket[customerId]
	if not customer then
		return
	end

	if customer.model then
		customer.model:Destroy()
	end

	bucket[customerId] = nil
	self._remotes.CustomerRemoved:FireClient(player, {
		customerId = customerId,
		reason = reason,
	})
end

function CustomerService:_countActiveCustomers(player)
	local count = 0
	for _ in pairs(self:_getCustomerBucket(player)) do
		count += 1
	end

	return count
end

function CustomerService:_spawnCustomer(player)
	if not self._plotManager:GetPlayerPlot(player) then
		return
	end

	if self:_countActiveCustomers(player) >= GameConstants.MAX_ACTIVE_CUSTOMERS then
		return
	end

	local queueIndex = self:_getOpenQueueIndex(player)
	if not queueIndex then
		return
	end

	self._customerSequence += 1
	local recipeId = RecipeDefinitions.GetRandomRecipeId(self._random)
	local customer = {
		customerId = "P" .. player.UserId .. "_Customer_" .. self._customerSequence,
		orderRecipeId = recipeId,
		isInfluencer = self._random:NextNumber() <= GameConstants.INFLUENCER_CHANCE,
		spawnTime = workspace:GetServerTimeNow(),
		timeoutSeconds = GameConstants.CUSTOMER_TIMEOUT_SECONDS,
		queueIndex = queueIndex,
		model = nil,
	}

	customer.model = self:_createCustomerModel(player, customer)
	if not customer.model then
		return
	end

	self:_getCustomerBucket(player)[customer.customerId] = customer

	self._remotes.CustomerSpawned:FireClient(player, self:_buildCustomerPayload(customer))

	task.delay(customer.timeoutSeconds, function()
		if player.Parent ~= Players then
			return
		end

		local activeCustomer = self:_getCustomerBucket(player)[customer.customerId]
		if activeCustomer and activeCustomer.spawnTime == customer.spawnTime then
			self:_removeCustomer(player, customer.customerId, "TimedOut")
		end
	end)
end

function CustomerService:_getSpawnInterval(player)
	local baseInterval
	if self._viralRushService:IsActive(player) then
		baseInterval = GameConstants.CUSTOMER_SPAWN_INTERVAL_VIRAL_RUSH
	else
		baseInterval = GameConstants.CUSTOMER_SPAWN_INTERVAL_NORMAL
	end

	local biggerCounterLevel = self._playerDataService:GetUpgradeLevel(player, "BiggerCounter")
	local upgradedInterval = baseInterval
		- (biggerCounterLevel * GameConstants.UPGRADES.BIGGER_COUNTER_INTERVAL_REDUCTION_SECONDS)

	return math.max(GameConstants.UPGRADES.MIN_CUSTOMER_SPAWN_INTERVAL_SECONDS, upgradedInterval)
end

function CustomerService:_calculateRewards(player, customer)
	local multiplier = 1
	local bonusLabels = {}

	if customer.orderRecipeId == self._trendService:GetCurrentTrendRecipeId() then
		multiplier *= GameConstants.MULTIPLIERS.Trend
		table.insert(bonusLabels, "Trend")
	end

	if customer.isInfluencer then
		multiplier *= GameConstants.MULTIPLIERS.Influencer
		table.insert(bonusLabels, "Influencer")
	end

	local money = GameConstants.BASE_REWARDS.Money * multiplier
	local viralPoints = GameConstants.BASE_REWARDS.ViralPoints * multiplier

	local marketingLevel = self._playerDataService:GetUpgradeLevel(player, "BetterMarketing")
	if marketingLevel > 0 then
		viralPoints += marketingLevel * GameConstants.UPGRADES.BETTER_MARKETING_VIRAL_BONUS_PER_LEVEL
		table.insert(bonusLabels, "Marketing +" .. marketingLevel)
	end

	return money, viralPoints, bonusLabels
end

function CustomerService:_validateServeStation(player, payload)
	if typeof(payload) ~= "table" or payload.station == nil then
		return true
	end

	if typeof(payload.station) ~= "Instance" or not payload.station:IsA("BasePart") then
		return false
	end

	if payload.station:GetAttribute("StationType") ~= "Serving" then
		return false
	end

	if not self._plotManager:IsPlayerOwnerOfInstance(player, payload.station) then
		self:_notify(player, "This is not your restaurant.", "Warning")
		return false
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or (rootPart.Position - payload.station.Position).Magnitude > GameConstants.MAX_STATION_INTERACTION_DISTANCE then
		self:_notify(player, "Move closer to your counter.", "Warning")
		return false
	end

	return true
end

function CustomerService:HandleServeRequest(player, payload)
	if typeof(payload) ~= "table" or typeof(payload.customerId) ~= "string" then
		self:_notify(player, "Choose a customer to serve.", "Warning")
		return
	end

	if not self:_validateServeStation(player, payload) then
		return
	end

	local customer = self:_getCustomerBucket(player)[payload.customerId]
	if not customer then
		self:_notify(player, "That customer is no longer in your line.", "Warning")
		return
	end

	local dish = self._recipeService:GetCompletedDish(player)
	if not dish then
		self:_notify(player, "Finish a dish before serving.", "Warning")
		return
	end

	if dish.recipeId ~= customer.orderRecipeId then
		self._recipeService:ClearDish(player)
		self:_notify(player, "Wrong order. Dish discarded; the customer is still waiting.", "Error")
		return
	end

	local money, viralPoints, bonusLabels = self:_calculateRewards(player, customer)
	self._playerDataService:AddCurrency(player, money, viralPoints)
	self._recipeService:ClearDish(player)
	self:_removeCustomer(player, customer.customerId, "Served")

	if customer.isInfluencer then
		self._viralRushService:StartViralRush(player)
	end

	local bonusText = ""
	if #bonusLabels > 0 then
		bonusText = " (" .. table.concat(bonusLabels, ", ") .. ")"
	end

	self:_notify(player, "Served " .. RecipeDefinitions.GetRecipeDisplayName(customer.orderRecipeId) .. " for $" .. money .. " and " .. viralPoints .. " VP" .. bonusText .. ".", "Success")
end

function CustomerService:SendExistingCustomers(player)
	for _, customer in pairs(self:_getCustomerBucket(player)) do
		self._remotes.CustomerSpawned:FireClient(player, self:_buildCustomerPayload(customer))
	end
end

function CustomerService:CleanupPlayer(player)
	local bucket = self._customersByPlayer[player]
	if bucket then
		for _, customer in pairs(bucket) do
			if customer.model then
				customer.model:Destroy()
			end
		end
	end

	self._customersByPlayer[player] = nil
	self._lastSpawnAtByPlayer[player] = nil
end

function CustomerService:Init(remotes, services)
	if self._initialized then
		return
	end
	self._initialized = true
	self._remotes = remotes
	self._playerDataService = services.PlayerDataService
	self._plotManager = services.PlotManager
	self._trendService = services.TrendService
	self._recipeService = services.RecipeService
	self._viralRushService = services.ViralRushService

	remotes.ServeRequest.OnServerEvent:Connect(function(player, payload)
		self:HandleServeRequest(player, payload)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			self:SendExistingCustomers(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:CleanupPlayer(player)
	end)

	task.spawn(function()
		task.wait(2)
		while true do
			local now = workspace:GetServerTimeNow()
			for _, player in ipairs(Players:GetPlayers()) do
				local lastSpawnAt = self._lastSpawnAtByPlayer[player] or 0
				if now - lastSpawnAt >= self:_getSpawnInterval(player) then
					self:_spawnCustomer(player)
					self._lastSpawnAtByPlayer[player] = now
				end
			end

			task.wait(0.5)
		end
	end)
end

return CustomerService
