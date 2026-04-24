local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.GameConstants)
local RecipeDefinitions = require(ReplicatedStorage.Shared.RecipeDefinitions)

local CustomerService = {}

CustomerService._remotes = nil
CustomerService._playerDataService = nil
CustomerService._trendService = nil
CustomerService._recipeService = nil
CustomerService._viralRushService = nil
CustomerService._customers = {}
CustomerService._customerSequence = 0
CustomerService._random = Random.new()
CustomerService._initialized = false

local CUSTOMER_COLORS = {
	Color3.fromRGB(255, 217, 102),
	Color3.fromRGB(116, 214, 255),
	Color3.fromRGB(255, 142, 185),
	Color3.fromRGB(142, 255, 174),
}

local function getFoodTruck()
	return workspace:FindFirstChild("FoodTruck")
end

local function getQueueFolder()
	local foodTruck = getFoodTruck()
	if not foodTruck then
		return nil
	end

	return foodTruck:FindFirstChild("CustomerQueue")
end

local function getActiveCustomersFolder()
	local foodTruck = getFoodTruck()
	if not foodTruck then
		return nil
	end

	local folder = foodTruck:FindFirstChild("ActiveCustomers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ActiveCustomers"
		folder.Parent = foodTruck
	end

	return folder
end

local function makeBillboard(parent, text, backgroundColor)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OrderBillboard"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(220, 70)
	billboard.StudsOffset = Vector3.new(0, 3.25, 0)
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundColor3 = backgroundColor
	label.BackgroundTransparency = 0.05
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(30, 26, 26)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

function CustomerService:_notify(player, message, notificationType)
	self._remotes.NotificationEvent:FireClient(player, {
		message = message,
		notificationType = notificationType or "Info",
	})
end

function CustomerService:_getQueueSpawnPoint(index)
	local queueFolder = getQueueFolder()
	if not queueFolder then
		return nil
	end

	return queueFolder:FindFirstChild("SpawnPoint" .. index)
end

function CustomerService:_getOpenQueueIndex()
	local used = {}
	for _, customer in pairs(self._customers) do
		if customer.queueIndex then
			used[customer.queueIndex] = true
		end
	end

	for index = 1, GameConstants.MAX_ACTIVE_CUSTOMERS do
		if not used[index] and self:_getQueueSpawnPoint(index) then
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

function CustomerService:_createCustomerModel(customer)
	local spawnPoint = self:_getQueueSpawnPoint(customer.queueIndex)
	local activeFolder = getActiveCustomersFolder()
	if not spawnPoint or not activeFolder then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = customer.isInfluencer and ("Influencer_" .. customer.customerId) or ("Customer_" .. customer.customerId)
	model:SetAttribute("CustomerId", customer.customerId)
	model:SetAttribute("OrderRecipeId", customer.orderRecipeId)
	model:SetAttribute("IsInfluencer", customer.isInfluencer)
	model.Parent = activeFolder

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Size = Vector3.new(2, 3, 1)
	body.Color = CUSTOMER_COLORS[self._random:NextInteger(1, #CUSTOMER_COLORS)]
	body.Material = Enum.Material.SmoothPlastic
	body.CFrame = spawnPoint.CFrame + Vector3.new(0, 1.6, 0)
	body.Parent = model
	model.PrimaryPart = body

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

	local labelText = RecipeDefinitions.GetRecipeDisplayName(customer.orderRecipeId)
	if customer.isInfluencer then
		labelText = "Influencer\n" .. labelText
	end
	makeBillboard(head, labelText, customer.isInfluencer and Color3.fromRGB(255, 209, 64) or Color3.fromRGB(255, 255, 255))

	return model
end

function CustomerService:_removeCustomer(customerId, reason)
	local customer = self._customers[customerId]
	if not customer then
		return
	end

	if customer.model then
		customer.model:Destroy()
	end

	self._customers[customerId] = nil
	self._remotes.CustomerRemoved:FireAllClients({
		customerId = customerId,
		reason = reason,
	})
end

function CustomerService:_spawnCustomer()
	if self:_countActiveCustomers() >= GameConstants.MAX_ACTIVE_CUSTOMERS then
		return
	end

	local queueIndex = self:_getOpenQueueIndex()
	if not queueIndex then
		return
	end

	self._customerSequence += 1
	local recipeId = RecipeDefinitions.GetRandomRecipeId(self._random)
	local customer = {
		customerId = "Customer_" .. self._customerSequence,
		orderRecipeId = recipeId,
		isInfluencer = self._random:NextNumber() <= GameConstants.INFLUENCER_CHANCE,
		spawnTime = workspace:GetServerTimeNow(),
		timeoutSeconds = GameConstants.CUSTOMER_TIMEOUT_SECONDS,
		queueIndex = queueIndex,
		model = nil,
	}

	customer.model = self:_createCustomerModel(customer)
	self._customers[customer.customerId] = customer

	self._remotes.CustomerSpawned:FireAllClients(self:_buildCustomerPayload(customer))

	task.delay(customer.timeoutSeconds, function()
		local activeCustomer = self._customers[customer.customerId]
		if activeCustomer and activeCustomer.spawnTime == customer.spawnTime then
			self:_removeCustomer(customer.customerId, "TimedOut")
		end
	end)
end

function CustomerService:_countActiveCustomers()
	local count = 0
	for _ in pairs(self._customers) do
		count += 1
	end

	return count
end

function CustomerService:_getSpawnInterval()
	local baseInterval
	if self._viralRushService:IsActive() then
		baseInterval = GameConstants.CUSTOMER_SPAWN_INTERVAL_VIRAL_RUSH
	else
		baseInterval = GameConstants.CUSTOMER_SPAWN_INTERVAL_NORMAL
	end

	local biggerCounterLevel = self._playerDataService:GetHighestUpgradeLevel("BiggerCounter")
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

function CustomerService:HandleServeRequest(player, payload)
	if typeof(payload) ~= "table" or typeof(payload.customerId) ~= "string" then
		self:_notify(player, "Choose a customer to serve.", "Warning")
		return
	end

	local customer = self._customers[payload.customerId]
	if not customer then
		self:_notify(player, "That customer is no longer in line.", "Warning")
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
	self:_removeCustomer(customer.customerId, "Served")

	if customer.isInfluencer then
		self._viralRushService:StartViralRush()
	end

	local bonusText = ""
	if #bonusLabels > 0 then
		bonusText = " (" .. table.concat(bonusLabels, ", ") .. ")"
	end

	self:_notify(player, "Served " .. RecipeDefinitions.GetRecipeDisplayName(customer.orderRecipeId) .. " for $" .. money .. " and " .. viralPoints .. " VP" .. bonusText .. ".", "Success")
end

function CustomerService:SendExistingCustomers(player)
	for _, customer in pairs(self._customers) do
		self._remotes.CustomerSpawned:FireClient(player, self:_buildCustomerPayload(customer))
	end
end

function CustomerService:Init(remotes, services)
	if self._initialized then
		return
	end
	self._initialized = true
	self._remotes = remotes
	self._playerDataService = services.PlayerDataService
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

	task.spawn(function()
		task.wait(2)
		local lastSpawnAt = 0
		while true do
			local now = workspace:GetServerTimeNow()
			if now - lastSpawnAt >= self:_getSpawnInterval() then
				self:_spawnCustomer()
				lastSpawnAt = now
			end

			task.wait(0.5)
		end
	end)
end

return CustomerService
