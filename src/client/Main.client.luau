local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local screenGui = script.Parent
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RecipeDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RecipeDefinitions"))

local TrendChanged = remotes:WaitForChild("TrendChanged")
local DishStateChanged = remotes:WaitForChild("DishStateChanged")
local CustomerSpawned = remotes:WaitForChild("CustomerSpawned")
local CustomerRemoved = remotes:WaitForChild("CustomerRemoved")
local ServeRequest = remotes:WaitForChild("ServeRequest")
local StartRecipeRequest = remotes:WaitForChild("StartRecipeRequest")
local AddRecipeStepRequest = remotes:WaitForChild("AddRecipeStepRequest")
local UpgradeRequest = remotes:WaitForChild("UpgradeRequest")
local NotificationEvent = remotes:WaitForChild("NotificationEvent")
local ViralRushChanged = remotes:WaitForChild("ViralRushChanged")

local currentDish = {
	recipeId = nil,
	recipeDisplayName = nil,
	completedSteps = {},
	requiredSteps = {},
	isComplete = false,
}

local trendState = {
	trendRecipeId = nil,
	trendDisplayName = "Loading...",
	endsAt = 0,
}

local viralRushState = {
	isActive = false,
	endsAt = nil,
}

local customers = {}
local customerOrder = {}
local selectedCustomerId = nil
local upgradeLevels = {
	FasterCooking = 0,
	BetterMarketing = 0,
	BiggerCounter = 0,
}

local ui = {}

local COLORS = {
	page = Color3.fromRGB(34, 38, 47),
	panel = Color3.fromRGB(255, 250, 232),
	panelAlt = Color3.fromRGB(245, 252, 255),
	text = Color3.fromRGB(33, 30, 29),
	muted = Color3.fromRGB(94, 91, 88),
	yellow = Color3.fromRGB(255, 214, 64),
	coral = Color3.fromRGB(255, 105, 97),
	teal = Color3.fromRGB(72, 203, 180),
	blue = Color3.fromRGB(74, 171, 255),
	purple = Color3.fromRGB(172, 128, 255),
	green = Color3.fromRGB(80, 190, 115),
	white = Color3.fromRGB(255, 255, 255),
}

local function setText(object, text)
	if object then
		object.Text = text
	end
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return string.format("%d:%02d", minutes, remainder)
end

local function create(className, properties, children)
	local instance = Instance.new(className)
	for property, value in pairs(properties or {}) do
		instance[property] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	return instance
end

local function addCorner(parent, radius)
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
		Parent = parent,
	})
end

local function addPadding(parent, padding)
	return create("UIPadding", {
		PaddingBottom = UDim.new(0, padding),
		PaddingLeft = UDim.new(0, padding),
		PaddingRight = UDim.new(0, padding),
		PaddingTop = UDim.new(0, padding),
		Parent = parent,
	})
end

local function makeLabel(parent, name, text, size, color, font)
	local label = create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Font = font or Enum.Font.Gotham,
		Text = text,
		TextColor3 = color or COLORS.text,
		TextSize = size or 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = parent,
	})
	return label
end

local function makeButton(parent, name, text, color)
	local button = create("TextButton", {
		Name = name,
		AutoButtonColor = true,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextColor3 = COLORS.text,
		TextSize = 15,
		TextWrapped = true,
		Parent = parent,
	})
	addCorner(button, 6)
	return button
end

local function makePanel(parent, name, position, size, backgroundColor)
	local panel = create("Frame", {
		Name = name,
		BackgroundColor3 = backgroundColor or COLORS.panel,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Parent = parent,
	})
	addCorner(panel, 8)
	addPadding(panel, 10)
	return panel
end

local function localNotify(message)
	setText(ui.notificationLabel, message)
	task.delay(3, function()
		if ui.notificationLabel and ui.notificationLabel.Text == message then
			ui.notificationLabel.Text = ""
		end
	end)
end

local function getCompletedLookup()
	local lookup = {}
	for _, stepName in ipairs(currentDish.completedSteps or {}) do
		lookup[stepName] = true
	end
	return lookup
end

local function getNextStep()
	local requiredSteps = currentDish.requiredSteps or {}
	local completedCount = #(currentDish.completedSteps or {})
	return requiredSteps[completedCount + 1]
end

local function getFirstCustomerId()
	for _, customerId in ipairs(customerOrder) do
		if customers[customerId] then
			return customerId
		end
	end

	return nil
end

local function refreshStats()
	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("Money")
	local viralPoints = leaderstats and leaderstats:FindFirstChild("ViralPoints")

	setText(ui.moneyLabel, "Money: $" .. tostring(if money then money.Value else 0))
	setText(ui.viralPointsLabel, "ViralPoints: " .. tostring(if viralPoints then viralPoints.Value else 0))
end

local function refreshDish()
	local recipeName = currentDish.recipeDisplayName or "No Recipe"
	local status = if currentDish.isComplete then "Ready to Serve" else "In Prep"
	setText(ui.dishTitle, recipeName .. " - " .. status)

	local completedLookup = getCompletedLookup()
	local lines = {}
	for index, stepName in ipairs(currentDish.requiredSteps or {}) do
		local marker = if completedLookup[stepName] then "[x]" else "[ ]"
		table.insert(lines, marker .. " " .. index .. ". " .. stepName)
	end

	if #lines == 0 then
		table.insert(lines, "Select a recipe to start.")
	end

	local nextStep = getNextStep()
	if nextStep and not currentDish.isComplete then
		table.insert(lines, "")
		table.insert(lines, "Next: " .. nextStep)
	end

	setText(ui.stepsLabel, table.concat(lines, "\n"))
end

local function refreshCustomers()
	for _, child in ipairs(ui.customerList:GetChildren()) do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end

	for _, customerId in ipairs(customerOrder) do
		local customer = customers[customerId]
		if customer then
			local label = customer.orderDisplayName
			if customer.isInfluencer then
				label = "Influencer: " .. label
			end

			local button = makeButton(ui.customerList, customerId, label, if selectedCustomerId == customerId then COLORS.yellow else COLORS.white)
			button.Size = UDim2.new(1, -4, 0, 42)
			button.LayoutOrder = customer.layoutOrder or 0
			button.MouseButton1Click:Connect(function()
				selectedCustomerId = customerId
				refreshCustomers()
			end)
		end
	end

	if not selectedCustomerId or not customers[selectedCustomerId] then
		selectedCustomerId = getFirstCustomerId()
	end

	local count = 0
	for _ in pairs(customers) do
		count += 1
	end
	setText(ui.customerTitle, "Customers (" .. count .. ")")
end

local function refreshTrend()
	local timeLeft = trendState.endsAt - workspace:GetServerTimeNow()
	setText(ui.trendLabel, "Trend: " .. (trendState.trendDisplayName or "Loading...") .. "  " .. formatTime(timeLeft))
end

local function refreshViralRush()
	if viralRushState.isActive and viralRushState.endsAt then
		local timeLeft = viralRushState.endsAt - workspace:GetServerTimeNow()
		setText(ui.viralRushLabel, "Viral Rush: ACTIVE  " .. formatTime(timeLeft))
		ui.viralRushLabel.TextColor3 = COLORS.coral
	else
		setText(ui.viralRushLabel, "Viral Rush: Ready")
		ui.viralRushLabel.TextColor3 = COLORS.text
	end
end

local function refreshUpgrades()
	for upgradeId, button in pairs(ui.upgradeButtons) do
		local upgrade = RecipeDefinitions.GetUpgrade(upgradeId)
		local level = upgradeLevels[upgradeId] or 0
		local cost = 100 * (level + 1)
		if level >= 5 then
			button.Text = upgrade.displayName .. "\nLevel " .. level .. " MAX"
		else
			button.Text = upgrade.displayName .. "\nLevel " .. level .. "  $" .. cost
		end
	end
end

local function serveSelectedCustomer()
	local customerId = selectedCustomerId or getFirstCustomerId()
	if not customerId then
		localNotify("No customers are waiting.")
		return
	end

	ServeRequest:FireServer({
		customerId = customerId,
	})
end

local function buildUi()
	for _, child in ipairs(screenGui:GetChildren()) do
		if child ~= script then
			child:Destroy()
		end
	end

	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false

	local root = create("Frame", {
		Name = "Root",
		BackgroundColor3 = COLORS.page,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})

	local topBar = makePanel(root, "TopBar", UDim2.fromOffset(12, 12), UDim2.new(1, -24, 0, 70), COLORS.panel)
	ui.trendLabel = makeLabel(topBar, "TrendLabel", "Trend: Loading...", 20, COLORS.text, Enum.Font.GothamBold)
	ui.trendLabel.Size = UDim2.new(0.42, 0, 1, 0)
	ui.viralRushLabel = makeLabel(topBar, "ViralRushLabel", "Viral Rush: Ready", 18, COLORS.text, Enum.Font.GothamBold)
	ui.viralRushLabel.Position = UDim2.new(0.44, 0, 0, 0)
	ui.viralRushLabel.Size = UDim2.new(0.25, 0, 1, 0)
	ui.moneyLabel = makeLabel(topBar, "MoneyLabel", "Money: $0", 18, COLORS.text, Enum.Font.GothamBold)
	ui.moneyLabel.Position = UDim2.new(0.7, 0, 0, 0)
	ui.moneyLabel.Size = UDim2.new(0.15, 0, 1, 0)
	ui.viralPointsLabel = makeLabel(topBar, "ViralPointsLabel", "ViralPoints: 0", 18, COLORS.text, Enum.Font.GothamBold)
	ui.viralPointsLabel.Position = UDim2.new(0.84, 0, 0, 0)
	ui.viralPointsLabel.Size = UDim2.new(0.16, 0, 1, 0)

	local recipePanel = makePanel(root, "RecipePanel", UDim2.fromOffset(12, 94), UDim2.fromOffset(260, 248), COLORS.panelAlt)
	local recipeTitle = makeLabel(recipePanel, "Title", "Recipes", 20, COLORS.text, Enum.Font.GothamBold)
	recipeTitle.Size = UDim2.new(1, 0, 0, 28)

	local recipeList = create("Frame", {
		Name = "RecipeList",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 144),
		Parent = recipePanel,
	})
	local recipeLayout = create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = recipeList,
	})

	for index, recipeId in ipairs(RecipeDefinitions.RECIPE_ORDER) do
		local recipe = RecipeDefinitions.GetRecipe(recipeId)
		local button = makeButton(recipeList, recipeId, recipe.displayName, ({ COLORS.coral, COLORS.teal, COLORS.yellow })[index])
		button.Size = UDim2.new(1, 0, 0, 40)
		button.LayoutOrder = index
		button.MouseButton1Click:Connect(function()
			StartRecipeRequest:FireServer({
				recipeId = recipeId,
			})
		end)
	end

	local flow = makeLabel(recipePanel, "Flow", "Prep Flow:\nRecipe -> Stations -> Counter\nTrend + Influencer stack bonuses", 14, COLORS.muted, Enum.Font.Gotham)
	flow.Position = UDim2.fromOffset(0, 190)
	flow.Size = UDim2.new(1, 0, 0, 48)
	recipeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() end)

	local dishPanel = makePanel(root, "DishPanel", UDim2.fromOffset(284, 94), UDim2.fromOffset(300, 248), COLORS.panel)
	ui.dishTitle = makeLabel(dishPanel, "DishTitle", "No Recipe", 19, COLORS.text, Enum.Font.GothamBold)
	ui.dishTitle.Size = UDim2.new(1, 0, 0, 34)
	ui.stepsLabel = makeLabel(dishPanel, "StepsLabel", "Select a recipe to start.", 15, COLORS.text, Enum.Font.Code)
	ui.stepsLabel.Position = UDim2.fromOffset(0, 42)
	ui.stepsLabel.Size = UDim2.new(1, 0, 1, -42)
	ui.stepsLabel.TextYAlignment = Enum.TextYAlignment.Top

	local customerPanel = makePanel(root, "CustomerPanel", UDim2.new(1, -332, 0, 94), UDim2.fromOffset(320, 330), COLORS.panelAlt)
	ui.customerTitle = makeLabel(customerPanel, "CustomerTitle", "Customers (0)", 20, COLORS.text, Enum.Font.GothamBold)
	ui.customerTitle.Size = UDim2.new(1, 0, 0, 30)

	ui.customerList = create("ScrollingFrame", {
		Name = "CustomerList",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		Position = UDim2.fromOffset(0, 38),
		ScrollBarThickness = 6,
		Size = UDim2.new(1, 0, 1, -94),
		Parent = customerPanel,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ui.customerList,
	})

	local serveButton = makeButton(customerPanel, "ServeButton", "Serve Selected", COLORS.green)
	serveButton.Position = UDim2.new(0, 0, 1, -44)
	serveButton.Size = UDim2.new(1, 0, 0, 44)
	serveButton.MouseButton1Click:Connect(serveSelectedCustomer)

	local upgradePanel = makePanel(root, "UpgradePanel", UDim2.new(1, -332, 0, 438), UDim2.fromOffset(320, 206), COLORS.panel)
	local upgradeTitle = makeLabel(upgradePanel, "UpgradeTitle", "Upgrades", 20, COLORS.text, Enum.Font.GothamBold)
	upgradeTitle.Size = UDim2.new(1, 0, 0, 30)

	local upgradeList = create("Frame", {
		Name = "UpgradeList",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 1, -38),
		Parent = upgradePanel,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = upgradeList,
	})
	ui.upgradeButtons = {}
	for index, upgradeId in ipairs({ "FasterCooking", "BetterMarketing", "BiggerCounter" }) do
		local button = makeButton(upgradeList, upgradeId, upgradeId, ({ COLORS.blue, COLORS.purple, COLORS.yellow })[index])
		button.Size = UDim2.new(1, 0, 0, 46)
		button.LayoutOrder = index
		button.MouseButton1Click:Connect(function()
			UpgradeRequest:FireServer({
				upgradeId = upgradeId,
			})
		end)
		ui.upgradeButtons[upgradeId] = button
	end

	local notification = makePanel(root, "Notification", UDim2.new(0.5, -250, 1, -74), UDim2.fromOffset(500, 52), COLORS.white)
	ui.notificationLabel = makeLabel(notification, "NotificationLabel", "", 16, COLORS.text, Enum.Font.GothamBold)
	ui.notificationLabel.Size = UDim2.fromScale(1, 1)
	ui.notificationLabel.TextXAlignment = Enum.TextXAlignment.Center

	refreshDish()
	refreshCustomers()
	refreshStats()
	refreshUpgrades()
	refreshTrend()
	refreshViralRush()
end

local function connectLeaderstats()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then
		return
	end

	for _, valueName in ipairs({ "Money", "ViralPoints" }) do
		local value = leaderstats:WaitForChild(valueName, 10)
		if value then
			value.Changed:Connect(refreshStats)
		end
	end
	refreshStats()
end

local function getStationPartFromPrompt(prompt)
	local current = prompt.Parent
	while current and current ~= workspace do
		if current:GetAttribute("StationType") then
			return current
		end
		current = current.Parent
	end

	return nil
end

local function handleStationPrompt(prompt)
	local stationPart = getStationPartFromPrompt(prompt)
	if not stationPart then
		return
	end

	local stationType = stationPart:GetAttribute("StationType")
	if stationType == "Serving" then
		serveSelectedCustomer()
		return
	end

	if stationType == "Upgrade" then
		localNotify("Upgrade buttons are ready.")
		return
	end

	local nextStep = getNextStep()
	if not currentDish.recipeId then
		localNotify("Select a recipe first.")
		return
	end
	if not nextStep then
		localNotify("Dish is complete. Serve it at the counter.")
		return
	end

	AddRecipeStepRequest:FireServer({
		stepName = nextStep,
		stationType = stationType,
	})
end

TrendChanged.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	trendState = payload
	refreshTrend()
end)

DishStateChanged.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	currentDish = payload
	refreshDish()
end)

CustomerSpawned.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.customerId) ~= "string" then
		return
	end

	if not customers[payload.customerId] then
		table.insert(customerOrder, payload.customerId)
	end

	payload.layoutOrder = #customerOrder
	customers[payload.customerId] = payload
	if not selectedCustomerId then
		selectedCustomerId = payload.customerId
	end
	refreshCustomers()
end)

CustomerRemoved.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.customerId) ~= "string" then
		return
	end

	customers[payload.customerId] = nil
	if selectedCustomerId == payload.customerId then
		selectedCustomerId = nil
	end
	refreshCustomers()
end)

NotificationEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.message) ~= "string" then
		return
	end

	localNotify(payload.message)

	local upgradedName, level = string.match(payload.message, "^(.-) upgraded to level (%d+)%.")
	if upgradedName and level then
		for upgradeId, upgrade in pairs(RecipeDefinitions.UPGRADES) do
			if upgrade.displayName == upgradedName then
				upgradeLevels[upgradeId] = tonumber(level) or upgradeLevels[upgradeId]
				refreshUpgrades()
				break
			end
		end
	end
end)

ViralRushChanged.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	viralRushState = payload
	refreshViralRush()
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	handleStationPrompt(prompt)
end)

buildUi()
task.spawn(connectLeaderstats)

task.spawn(function()
	while true do
		refreshTrend()
		refreshViralRush()
		task.wait(0.5)
	end
end)
