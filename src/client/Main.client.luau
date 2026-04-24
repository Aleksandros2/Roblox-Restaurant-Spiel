local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local screenGui = script.Parent
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RecipeDefinitions = require(Shared:WaitForChild("RecipeDefinitions"))

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

local PANELS = {
	Inventory = "Inventory",
	Recipes = "Recipes",
	Orders = "Orders",
	Upgrades = "Upgrades",
	Shop = "Shop",
	Settings = "Settings",
}

local HUD_COLORS = {
	blue = Color3.fromRGB(66, 144, 219),
	blueDark = Color3.fromRGB(39, 91, 150),
	orange = Color3.fromRGB(255, 170, 78),
	orangeDark = Color3.fromRGB(214, 123, 33),
	green = Color3.fromRGB(108, 200, 125),
	greenDark = Color3.fromRGB(66, 145, 82),
	red = Color3.fromRGB(244, 113, 92),
	redDark = Color3.fromRGB(183, 73, 56),
	panel = Color3.fromRGB(247, 250, 255),
	panelDark = Color3.fromRGB(233, 240, 248),
	panelLine = Color3.fromRGB(177, 193, 214),
	text = Color3.fromRGB(36, 45, 58),
	subtext = Color3.fromRGB(98, 109, 124),
	white = Color3.fromRGB(255, 255, 255),
	shadow = Color3.fromRGB(17, 24, 34),
	vp = Color3.fromRGB(112, 205, 255),
}

local RECIPE_COLORS = {
	SpicyRamen = Color3.fromRGB(255, 140, 92),
	BubbleTea = Color3.fromRGB(109, 210, 255),
	KoreanCornDog = Color3.fromRGB(255, 205, 95),
}

local NOTIFICATION_COLORS = {
	Info = HUD_COLORS.blue,
	Success = HUD_COLORS.green,
	Warning = HUD_COLORS.orange,
	Error = HUD_COLORS.red,
}

local NAVIGATION = {
	{
		panel = PANELS.Inventory,
		hotkey = "1",
		short = "INV",
		title = "Dish",
		color = HUD_COLORS.blue,
	},
	{
		panel = PANELS.Recipes,
		hotkey = "2",
		short = "REC",
		title = "Recipes",
		color = HUD_COLORS.orange,
	},
	{
		panel = PANELS.Orders,
		hotkey = "3",
		short = "ORD",
		title = "Orders",
		color = HUD_COLORS.green,
	},
	{
		panel = PANELS.Upgrades,
		hotkey = "4",
		short = "UPG",
		title = "Truck",
		color = Color3.fromRGB(159, 141, 255),
	},
	{
		panel = PANELS.Shop,
		hotkey = "5",
		short = "SHOP",
		title = "Shop",
		color = Color3.fromRGB(255, 194, 108),
	},
}

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

local questState = {
	text = "Cook 5 dishes",
	current = 0,
	target = 5,
}

local uiState = {
	activePanel = nil,
	musicEnabled = true,
	compactScale = false,
	toastCounter = 0,
}

local ui = {
	panels = {},
	navButtons = {},
	shortcutButtons = {},
	recipeButtons = {},
	upgradeButtons = {},
	orderRows = {},
	toasts = {},
}

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
		CornerRadius = UDim.new(0, radius or 12),
		Parent = parent,
	})
end

local function addStroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		Parent = parent,
	})
end

local function addPadding(parent, horizontal, vertical)
	return create("UIPadding", {
		PaddingBottom = UDim.new(0, vertical or horizontal),
		PaddingLeft = UDim.new(0, horizontal),
		PaddingRight = UDim.new(0, horizontal),
		PaddingTop = UDim.new(0, vertical or horizontal),
		Parent = parent,
	})
end

local function setText(object, text)
	if object then
		object.Text = text
	end
end

local function formatDuration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return string.format("%d:%02d", minutes, remainder)
end

local function formatGameTime()
	local totalMinutes = (8 * 60) + math.floor(workspace:GetServerTimeNow() / 2)
	local day = math.floor(totalMinutes / (24 * 60)) + 1
	local minuteOfDay = totalMinutes % (24 * 60)
	local hour24 = math.floor(minuteOfDay / 60)
	local minute = minuteOfDay % 60
	local period = if hour24 >= 12 then "pm" else "am"
	local hour12 = hour24 % 12
	if hour12 == 0 then
		hour12 = 12
	end

	return string.format("Day %d - %d:%02d%s", day, hour12, minute, period)
end

local function makeLabel(parent, name, text, size, color, font)
	return create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Font = font or Enum.Font.Gotham,
		Text = text,
		TextColor3 = color or HUD_COLORS.text,
		TextSize = size or 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = parent,
	})
end

local function makeButton(parent, name, backgroundColor)
	local button = create("TextButton", {
		Name = name,
		AutoButtonColor = true,
		BackgroundColor3 = backgroundColor,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "",
		TextColor3 = HUD_COLORS.white,
		Parent = parent,
	})
	addCorner(button, 14)
	addStroke(button, Color3.new(1, 1, 1), 1, 0.7)
	return button
end

local function clearDynamicChildren(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "Layout" and child.Name ~= "EmptyState" then
			child:Destroy()
		end
	end
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

local function getCustomerRemainingTime(customer)
	if not customer or not customer.expiresAt then
		return 0
	end

	return math.max(0, customer.expiresAt - workspace:GetServerTimeNow())
end

local function getFirstCustomerId()
	for _, customerId in ipairs(customerOrder) do
		if customers[customerId] then
			return customerId
		end
	end

	return nil
end

local function getOnlyActiveCustomerId()
	local foundId = nil
	local count = 0
	for _, customerId in ipairs(customerOrder) do
		if customers[customerId] then
			count += 1
			foundId = customerId
		end
	end

	if count == 1 then
		return foundId
	end

	return nil
end

local function applyUiScale()
	if ui.rootScale then
		ui.rootScale.Scale = if uiState.compactScale then 0.92 else 1
	end
end

local function refreshNavSelection()
	for panelName, entry in pairs(ui.navButtons) do
		local selected = uiState.activePanel == panelName
		entry.button.BackgroundColor3 = selected and entry.color or HUD_COLORS.blueDark
		entry.button.BackgroundTransparency = selected and 0 or 0.12
		entry.title.TextColor3 = selected and HUD_COLORS.white or HUD_COLORS.white
		entry.hotkey.BackgroundColor3 = selected and HUD_COLORS.white or HUD_COLORS.panel
		entry.hotkey.TextColor3 = selected and HUD_COLORS.text or HUD_COLORS.text
	end
end

local function closeAllPanels()
	for _, panel in pairs(ui.panels) do
		panel.Visible = false
	end
	uiState.activePanel = nil
	refreshNavSelection()
end

local function togglePanel(panelName)
	if uiState.activePanel == panelName and ui.panels[panelName] and ui.panels[panelName].Visible then
		closeAllPanels()
		return
	end

	closeAllPanels()
	local panel = ui.panels[panelName]
	if panel then
		panel.Visible = true
		uiState.activePanel = panelName
	end
	refreshNavSelection()
end

local function showPanel(panelName)
	if uiState.activePanel == panelName and ui.panels[panelName] and ui.panels[panelName].Visible then
		refreshNavSelection()
		return
	end

	closeAllPanels()
	local panel = ui.panels[panelName]
	if panel then
		panel.Visible = true
		uiState.activePanel = panelName
	end
	refreshNavSelection()
end

local function removeToast(toast)
	for index, activeToast in ipairs(ui.toasts) do
		if activeToast == toast then
			table.remove(ui.toasts, index)
			break
		end
	end

	if toast and toast.Parent then
		toast:Destroy()
	end
end

local function pushNotification(message, notificationType)
	if not ui.notificationContainer then
		return
	end

	uiState.toastCounter += 1
	local accent = NOTIFICATION_COLORS[notificationType or "Info"] or HUD_COLORS.blue

	local toast = create("Frame", {
		Name = "Toast",
		BackgroundColor3 = HUD_COLORS.panel,
		BorderSizePixel = 0,
		LayoutOrder = -uiState.toastCounter,
		Size = UDim2.new(1, 0, 0, 54),
		Parent = ui.notificationContainer,
	})
	addCorner(toast, 16)
	addStroke(toast, accent, 1, 0.35)

	local accentBar = create("Frame", {
		Name = "Accent",
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 6, 1, 0),
		Parent = toast,
	})
	addCorner(accentBar, 16)

	local title = makeLabel(toast, "Title", string.upper(notificationType or "Info"), 11, accent, Enum.Font.GothamBold)
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.new(1, -24, 0, 12)

	local body = makeLabel(toast, "Body", message, 13, HUD_COLORS.text, Enum.Font.Gotham)
	body.Position = UDim2.fromOffset(16, 23)
	body.Size = UDim2.new(1, -24, 0, 22)
	body.TextYAlignment = Enum.TextYAlignment.Top

	table.insert(ui.toasts, toast)
	while #ui.toasts > 3 do
		removeToast(ui.toasts[#ui.toasts])
	end

	task.delay(3.5, function()
		removeToast(toast)
	end)
end

local function refreshQuest()
	if not ui.questTitle then
		return
	end

	local progress = math.clamp(questState.current / math.max(1, questState.target), 0, 1)
	setText(ui.questTitle, questState.text)
	setText(ui.questProgress, string.format("%d / %d", questState.current, questState.target))
	ui.questFill.Size = UDim2.new(progress, 0, 1, 0)
end

local function refreshDayTime()
	setText(ui.dayTimeLabel, formatGameTime())
end

local function refreshCurrencies()
	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("Money")
	local viralPoints = leaderstats and leaderstats:FindFirstChild("ViralPoints")

	setText(ui.moneyValue, tostring(if money then money.Value else 0))
	setText(ui.vpValue, tostring(if viralPoints then viralPoints.Value else 10))
end

local function refreshTrendBadge()
	if not ui.trendBadge then
		return
	end

	local visible = trendState.trendRecipeId ~= nil
	ui.trendBadge.Visible = visible
	if visible then
		setText(ui.trendLabel, "Trend: " .. (trendState.trendDisplayName or "Loading..."))
	end
end

local function refreshTrendTimer()
	if not ui.trendBadge or not ui.trendTimer then
		return
	end

	if trendState.trendRecipeId then
		local timeLeft = trendState.endsAt - workspace:GetServerTimeNow()
		setText(ui.trendTimer, formatDuration(timeLeft))
	end
end

local function refreshViralRushBadge()
	if not ui.viralRushBadge then
		return
	end

	ui.viralRushBadge.Visible = viralRushState.isActive and viralRushState.endsAt ~= nil
	if ui.viralRushBadge.Visible then
		local timeLeft = viralRushState.endsAt - workspace:GetServerTimeNow()
		setText(ui.viralRushLabel, "Viral Rush!")
		setText(ui.viralRushTimer, formatDuration(timeLeft))
	end
end

local function refreshRecipeButtons()
	for recipeId, entry in pairs(ui.recipeButtons) do
		local selected = currentDish.recipeId == recipeId
		entry.button.BackgroundColor3 = selected and (RECIPE_COLORS[recipeId] or HUD_COLORS.orange) or HUD_COLORS.panelDark
		entry.button.BackgroundTransparency = selected and 0 or 0.05
		entry.title.TextColor3 = selected and HUD_COLORS.white or HUD_COLORS.text
		entry.subtitle.TextColor3 = selected and HUD_COLORS.white or HUD_COLORS.subtext
	end
end

local function refreshInventoryPanel()
	if not ui.inventoryRecipeName then
		return
	end

	local recipeName = currentDish.recipeDisplayName or "No recipe selected"
	setText(ui.inventoryRecipeName, recipeName)

	local nextStep = getNextStep()
	if currentDish.isComplete then
		setText(ui.inventoryNextStep, "Ready to serve at the counter.")
	elseif currentDish.recipeId and nextStep then
		local stationType = RecipeDefinitions.GetStepStationType(currentDish.recipeId, nextStep) or "station"
		setText(ui.inventoryNextStep, "Next step: " .. nextStep .. " at the " .. stationType .. " station.")
	else
		setText(ui.inventoryNextStep, "Use Recipes to choose a dish, then visit the correct station.")
	end

	clearDynamicChildren(ui.inventoryStepsList)
	ui.inventoryEmptyState.Visible = not currentDish.recipeId

	if currentDish.recipeId then
		local completedLookup = getCompletedLookup()
		for _, stepName in ipairs(currentDish.requiredSteps or {}) do
			local row = create("Frame", {
				Name = "StepRow",
				BackgroundColor3 = HUD_COLORS.panelDark,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 34),
				Parent = ui.inventoryStepsList,
			})
			addCorner(row, 12)

			local prefix = if completedLookup[stepName] then "[x] " else "[ ] "
			local label = makeLabel(row, "StepLabel", prefix .. stepName, 13, HUD_COLORS.text, Enum.Font.Gotham)
			label.Position = UDim2.fromOffset(10, 0)
			label.Size = UDim2.new(1, -20, 1, 0)
		end
	end
end

local function refreshOrderSelection()
	if not ui.ordersSelectedLabel then
		return
	end

	local customer = selectedCustomerId and customers[selectedCustomerId]
	if customer then
		setText(ui.ordersSelectedLabel, "Selected: " .. customer.orderDisplayName)
	else
		setText(ui.ordersSelectedLabel, "Selected: none")
	end
end

local function refreshOrderTimers()
	for customerId, row in pairs(ui.orderRows) do
		local customer = customers[customerId]
		if customer then
			local remaining = getCustomerRemainingTime(customer)
			row.timer.Text = formatDuration(remaining)
		end
	end
end

local function refreshOrdersPanel()
	if not ui.ordersList then
		return
	end

	local filteredOrder = {}
	for _, customerId in ipairs(customerOrder) do
		if customers[customerId] then
			table.insert(filteredOrder, customerId)
		end
	end
	customerOrder = filteredOrder

	if selectedCustomerId and not customers[selectedCustomerId] then
		selectedCustomerId = nil
	end

	clearDynamicChildren(ui.ordersList)
	ui.orderRows = {}
	ui.ordersEmptyState.Visible = #customerOrder == 0

	for _, customerId in ipairs(customerOrder) do
		local customer = customers[customerId]
		if customer then
			local selected = selectedCustomerId == customerId
			local row = makeButton(ui.ordersList, customerId, selected and HUD_COLORS.blue or HUD_COLORS.panelDark)
			row.Size = UDim2.new(1, 0, 0, 58)
			row.BackgroundTransparency = selected and 0 or 0.04

			local title = makeLabel(row, "OrderName", customer.orderDisplayName, 14, selected and HUD_COLORS.white or HUD_COLORS.text, Enum.Font.GothamBold)
			title.Position = UDim2.fromOffset(12, 6)
			title.Size = UDim2.new(1, -104, 0, 16)

			local timer = makeLabel(row, "OrderTimer", "0:00", 12, selected and HUD_COLORS.white or HUD_COLORS.subtext, Enum.Font.Gotham)
			timer.AnchorPoint = Vector2.new(1, 0)
			timer.Position = UDim2.new(1, -12, 0, 8)
			timer.Size = UDim2.fromOffset(52, 14)
			timer.TextXAlignment = Enum.TextXAlignment.Right

			local subtitleText = if customer.isInfluencer then "Influencer order" else "Festival customer"
			local subtitle = makeLabel(row, "OrderSubtitle", subtitleText, 12, selected and HUD_COLORS.white or HUD_COLORS.subtext, Enum.Font.Gotham)
			subtitle.Position = UDim2.fromOffset(12, 26)
			subtitle.Size = UDim2.new(1, -24, 0, 14)

			if customer.isInfluencer then
				local vipBadge = create("TextLabel", {
					Name = "VipBadge",
					BackgroundColor3 = HUD_COLORS.orange,
					BorderSizePixel = 0,
					Font = Enum.Font.GothamBold,
					Text = "VIP",
					TextColor3 = HUD_COLORS.white,
					TextSize = 11,
					Position = UDim2.new(1, -70, 0, 30),
					Size = UDim2.fromOffset(44, 18),
					Parent = row,
				})
				addCorner(vipBadge, 9)
			end

			row.MouseButton1Click:Connect(function()
				selectedCustomerId = customerId
				refreshOrdersPanel()
			end)

			ui.orderRows[customerId] = {
				timer = timer,
			}
		end
	end

	refreshOrderSelection()
	refreshOrderTimers()
end

local function refreshUpgradesPanel()
	for upgradeId, entry in pairs(ui.upgradeButtons) do
		local level = upgradeLevels[upgradeId] or 0
		local cost = 100 * (level + 1)
		if level >= 5 then
			setText(entry.level, "Level: " .. level .. " / MAX")
			setText(entry.cost, "Cost: Complete")
		else
			setText(entry.level, "Level: " .. level)
			setText(entry.cost, "Cost: $" .. cost)
		end
	end
end

local function refreshSettingsPanel()
	if not ui.musicToggleLabel then
		return
	end

	setText(ui.musicToggleLabel, "Music: " .. (uiState.musicEnabled and "On" or "Off"))
	setText(ui.scaleToggleLabel, "UI Scale: " .. (uiState.compactScale and "Compact" or "Normal"))

	if ui.shortcutButtons.Music then
		setText(ui.shortcutButtons.Music, uiState.musicEnabled and "Music On" or "Music Off")
	end
end

local function makePanel(name, title, alignRight, panelHeight)
	local panel = create("Frame", {
		Name = name .. "Panel",
		AnchorPoint = alignRight and Vector2.new(1, 1) or Vector2.new(0.5, 1),
		BackgroundColor3 = HUD_COLORS.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = alignRight and UDim2.new(1, -88, 1, -108) or UDim2.new(0.5, 0, 1, -108),
		Size = alignRight and UDim2.new(0.68, 0, 0.26, 0) or UDim2.new(0.82, 0, 0.42, 0),
		Visible = false,
		ZIndex = 5,
		Parent = ui.root,
	})
	addCorner(panel, 20)
	addStroke(panel, HUD_COLORS.panelLine, 1, 0.1)

	create("UISizeConstraint", {
		MaxSize = alignRight and Vector2.new(280, 210) or Vector2.new(360, panelHeight or 360),
		MinSize = alignRight and Vector2.new(220, 160) or Vector2.new(260, 240),
		Parent = panel,
	})

	local titleLabel = makeLabel(panel, "Title", title, 18, HUD_COLORS.text, Enum.Font.GothamBold)
	titleLabel.Position = UDim2.fromOffset(16, 10)
	titleLabel.Size = UDim2.new(1, -58, 0, 24)
	titleLabel.ZIndex = 6

	local closeButton = create("TextButton", {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = HUD_COLORS.panelDark,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(30, 24),
		Text = "X",
		TextColor3 = HUD_COLORS.text,
		TextSize = 12,
		ZIndex = 6,
		Parent = panel,
	})
	addCorner(closeButton, 10)
	closeButton.MouseButton1Click:Connect(closeAllPanels)

	local body = create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 42),
		Size = UDim2.new(1, -28, 1, -56),
		ZIndex = 6,
		Parent = panel,
	})

	ui.panels[name] = panel
	return panel, body
end

local function buildQuestFrame()
	local frame = create("Frame", {
		Name = "TopQuestFrame",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = HUD_COLORS.panel,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(350, 55),
		ZIndex = 2,
		Parent = ui.root,
	})
	addCorner(frame, 18)
	addStroke(frame, HUD_COLORS.panelLine, 1, 0.12)
	create("UISizeConstraint", {
		MaxSize = Vector2.new(380, 64),
		MinSize = Vector2.new(280, 52),
		Parent = frame,
	})

	local icon = create("Frame", {
		Name = "Icon",
		BackgroundColor3 = HUD_COLORS.orange,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 3,
		Parent = frame,
	})
	addCorner(icon, 10)
	local iconLabel = makeLabel(icon, "IconLabel", "GOAL", 9, HUD_COLORS.white, Enum.Font.GothamBold)
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.TextXAlignment = Enum.TextXAlignment.Center

	ui.questTitle = makeLabel(frame, "QuestTitle", "", 15, HUD_COLORS.text, Enum.Font.GothamBold)
	ui.questTitle.Position = UDim2.fromOffset(52, 8)
	ui.questTitle.Size = UDim2.new(1, -112, 0, 18)
	ui.questProgress = makeLabel(frame, "QuestProgress", "", 13, HUD_COLORS.subtext, Enum.Font.Gotham)
	ui.questProgress.AnchorPoint = Vector2.new(1, 0)
	ui.questProgress.Position = UDim2.new(1, -12, 0, 8)
	ui.questProgress.Size = UDim2.fromOffset(64, 18)
	ui.questProgress.TextXAlignment = Enum.TextXAlignment.Right

	local progressBack = create("Frame", {
		Name = "ProgressBack",
		BackgroundColor3 = HUD_COLORS.panelDark,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(52, 30),
		Size = UDim2.new(1, -64, 0, 12),
		ZIndex = 3,
		Parent = frame,
	})
	addCorner(progressBack, 999)

	ui.questFill = create("Frame", {
		Name = "QuestFill",
		BackgroundColor3 = HUD_COLORS.green,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 4,
		Parent = progressBack,
	})
	addCorner(ui.questFill, 999)
end

local function buildTopRightHud()
	local dayTimeFrame = create("Frame", {
		Name = "DayTimeFrame",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = HUD_COLORS.panel,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -12, 0, 14),
		Size = UDim2.fromOffset(160, 38),
		ZIndex = 2,
		Parent = ui.root,
	})
	addCorner(dayTimeFrame, 14)
	addStroke(dayTimeFrame, HUD_COLORS.panelLine, 1, 0.15)
	ui.dayTimeLabel = makeLabel(dayTimeFrame, "DayTimeLabel", "", 13, HUD_COLORS.text, Enum.Font.GothamBold)
	ui.dayTimeLabel.Size = UDim2.new(1, -18, 1, 0)
	ui.dayTimeLabel.Position = UDim2.fromOffset(9, 0)
	ui.dayTimeLabel.TextXAlignment = Enum.TextXAlignment.Center
end

local function buildBadgeRow()
	local row = create("Frame", {
		Name = "BadgeRow",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(420, 28),
		ZIndex = 2,
		Parent = ui.root,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})

	ui.trendBadge = create("Frame", {
		Name = "TrendBadge",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = HUD_COLORS.orange,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
		Parent = row,
	})
	addCorner(ui.trendBadge, 12)
	addPadding(ui.trendBadge, 10, 6)
	ui.trendLabel = makeLabel(ui.trendBadge, "TrendLabel", "", 12, HUD_COLORS.white, Enum.Font.GothamBold)
	ui.trendLabel.AutomaticSize = Enum.AutomaticSize.XY
	ui.trendLabel.Position = UDim2.fromOffset(0, 0)
	ui.trendTimer = makeLabel(ui.trendBadge, "TrendTimer", "", 11, HUD_COLORS.white, Enum.Font.Gotham)
	ui.trendTimer.AutomaticSize = Enum.AutomaticSize.XY
	ui.trendTimer.Position = UDim2.fromOffset(0, 14)

	ui.viralRushBadge = create("Frame", {
		Name = "ViralRushBadge",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = HUD_COLORS.red,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
		Parent = row,
	})
	addCorner(ui.viralRushBadge, 12)
	addPadding(ui.viralRushBadge, 10, 6)
	ui.viralRushLabel = makeLabel(ui.viralRushBadge, "ViralRushLabel", "Viral Rush!", 12, HUD_COLORS.white, Enum.Font.GothamBold)
	ui.viralRushLabel.AutomaticSize = Enum.AutomaticSize.XY
	ui.viralRushTimer = makeLabel(ui.viralRushBadge, "ViralRushTimer", "", 11, HUD_COLORS.white, Enum.Font.Gotham)
	ui.viralRushTimer.AutomaticSize = Enum.AutomaticSize.XY
	ui.viralRushTimer.Position = UDim2.fromOffset(0, 14)
end

local function buildNotifications()
	ui.notificationContainer = create("Frame", {
		Name = "NotificationContainer",
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 88),
		Size = UDim2.fromOffset(250, 188),
		ZIndex = 8,
		Parent = ui.root,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Parent = ui.notificationContainer,
	})
end

local function buildStarterPackButton()
	local button = makeButton(ui.root, "StarterPackButton", HUD_COLORS.orange)
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.Position = UDim2.new(0, 12, 0.5, -10)
	button.Size = UDim2.fromOffset(72, 54)
	button.ZIndex = 2

	local title = makeLabel(button, "Title", "Starter", 12, HUD_COLORS.white, Enum.Font.GothamBold)
	title.Position = UDim2.fromOffset(8, 7)
	title.Size = UDim2.new(1, -16, 0, 14)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local subtitle = makeLabel(button, "Subtitle", "Pack", 11, HUD_COLORS.white, Enum.Font.Gotham)
	subtitle.Position = UDim2.fromOffset(8, 24)
	subtitle.Size = UDim2.new(1, -16, 0, 12)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center

	button.MouseButton1Click:Connect(function()
		showPanel(PANELS.Shop)
		pushNotification("Starter Pack items are coming soon.", "Info")
	end)
end

local function buildCurrencyFrame()
	local frame = create("Frame", {
		Name = "CurrencyFrame",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = HUD_COLORS.panel,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 1, -16),
		Size = UDim2.fromOffset(186, 66),
		ZIndex = 2,
		Parent = ui.root,
	})
	addCorner(frame, 18)
	addStroke(frame, HUD_COLORS.panelLine, 1, 0.12)
	addPadding(frame, 12, 10)

	local vpRow = create("Frame", {
		Name = "VpRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = frame,
	})
	ui.vpValue = makeLabel(vpRow, "VpValue", "0", 13, HUD_COLORS.text, Enum.Font.GothamBold)
	ui.vpValue.AnchorPoint = Vector2.new(1, 0)
	ui.vpValue.Position = UDim2.new(1, 0, 0, 0)
	ui.vpValue.Size = UDim2.fromOffset(64, 18)
	ui.vpValue.TextXAlignment = Enum.TextXAlignment.Right
	local vpLabel = makeLabel(vpRow, "VpLabel", "Diamonds", 13, HUD_COLORS.vp, Enum.Font.GothamBold)
	vpLabel.Size = UDim2.new(1, -70, 1, 0)

	local moneyRow = create("Frame", {
		Name = "MoneyRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = frame,
	})
	ui.moneyValue = makeLabel(moneyRow, "MoneyValue", "0", 13, HUD_COLORS.text, Enum.Font.GothamBold)
	ui.moneyValue.AnchorPoint = Vector2.new(1, 0)
	ui.moneyValue.Position = UDim2.new(1, 0, 0, 0)
	ui.moneyValue.Size = UDim2.fromOffset(64, 18)
	ui.moneyValue.TextXAlignment = Enum.TextXAlignment.Right
	local moneyLabel = makeLabel(moneyRow, "MoneyLabel", "Money", 13, HUD_COLORS.greenDark, Enum.Font.GothamBold)
	moneyLabel.Size = UDim2.new(1, -70, 1, 0)
end

local function buildBottomNav()
	local frame = create("Frame", {
		Name = "BottomNavFrame",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(340, 78),
		ZIndex = 2,
		Parent = ui.root,
	})
	create("UISizeConstraint", {
		MaxSize = Vector2.new(390, 86),
		MinSize = Vector2.new(300, 72),
		Parent = frame,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})

	for _, definition in ipairs(NAVIGATION) do
		local button = makeButton(frame, definition.panel .. "NavButton", HUD_COLORS.blueDark)
		button.Size = UDim2.fromOffset(60, 60)
		button.ZIndex = 2

		local short = makeLabel(button, "Short", definition.short, 11, HUD_COLORS.white, Enum.Font.GothamBold)
		short.Position = UDim2.fromOffset(8, 11)
		short.Size = UDim2.new(1, -16, 0, 14)
		short.TextXAlignment = Enum.TextXAlignment.Center
		short.TextYAlignment = Enum.TextYAlignment.Center

		local title = makeLabel(button, "Title", definition.title, 10, HUD_COLORS.white, Enum.Font.Gotham)
		title.Position = UDim2.fromOffset(4, 30)
		title.Size = UDim2.new(1, -8, 0, 12)
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.TextYAlignment = Enum.TextYAlignment.Center

		local hotkey = create("TextLabel", {
			Name = "Hotkey",
			AnchorPoint = Vector2.new(1, 1),
			BackgroundColor3 = HUD_COLORS.panel,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(1, -4, 1, -4),
			Size = UDim2.fromOffset(18, 18),
			Text = definition.hotkey,
			TextColor3 = HUD_COLORS.text,
			TextSize = 10,
			ZIndex = 3,
			Parent = button,
		})
		addCorner(hotkey, 9)

		button.MouseButton1Click:Connect(function()
			togglePanel(definition.panel)
		end)

		ui.navButtons[definition.panel] = {
			button = button,
			color = definition.color,
			title = title,
			hotkey = hotkey,
		}
	end
end

local function buildRightShortcuts()
	local frame = create("Frame", {
		Name = "RightShortcutFrame",
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -12, 0.58, 0),
		Size = UDim2.fromOffset(74, 240),
		ZIndex = 2,
		Parent = ui.root,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = frame,
	})

	local function addShortcut(name, labelText, callback)
		local button = makeButton(frame, name .. "Button", HUD_COLORS.blue)
		button.Size = UDim2.fromOffset(62, 34)
		button.ZIndex = 2
		local label = makeLabel(button, "Label", labelText, 10, HUD_COLORS.white, Enum.Font.GothamBold)
		label.Size = UDim2.fromScale(1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Center
		button.MouseButton1Click:Connect(callback)
		ui.shortcutButtons[name] = label
	end

	addShortcut("Music", "Music On", function()
		uiState.musicEnabled = not uiState.musicEnabled
		refreshSettingsPanel()
		pushNotification("Music toggled locally.", "Info")
	end)
	addShortcut("Trophy", "Trophy", function()
		pushNotification("Achievements are coming soon.", "Info")
	end)
	addShortcut("Quest", "Quest", function()
		pushNotification(string.format("%s (%d/%d)", questState.text, questState.current, questState.target), "Info")
	end)
	addShortcut("Map", "Map", function()
		pushNotification("Map shortcuts are coming soon.", "Info")
	end)
	addShortcut("Settings", "Settings", function()
		togglePanel(PANELS.Settings)
	end)
end

local function buildInventoryPanel()
	local _, body = makePanel(PANELS.Inventory, "Current Dish", false, 360)

	ui.inventoryRecipeName = makeLabel(body, "RecipeName", "No recipe selected", 16, HUD_COLORS.text, Enum.Font.GothamBold)
	ui.inventoryRecipeName.Size = UDim2.new(1, 0, 0, 20)

	ui.inventoryNextStep = makeLabel(body, "NextStep", "", 13, HUD_COLORS.subtext, Enum.Font.Gotham)
	ui.inventoryNextStep.Position = UDim2.fromOffset(0, 24)
	ui.inventoryNextStep.Size = UDim2.new(1, 0, 0, 34)
	ui.inventoryNextStep.TextYAlignment = Enum.TextYAlignment.Top

	ui.inventoryStepsList = create("ScrollingFrame", {
		Name = "StepsList",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		Position = UDim2.fromOffset(0, 66),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = HUD_COLORS.blue,
		Size = UDim2.new(1, 0, 1, -110),
		Parent = body,
	})
	create("UIListLayout", {
		Name = "Layout",
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ui.inventoryStepsList,
	})

	ui.inventoryEmptyState = makeLabel(ui.inventoryStepsList, "EmptyState", "Use the Recipes button to choose a dish.", 13, HUD_COLORS.subtext, Enum.Font.Gotham)
	ui.inventoryEmptyState.Size = UDim2.new(1, 0, 0, 20)

	local helpText = makeLabel(body, "HelpText", "Use the correct station to add the next step.", 12, HUD_COLORS.subtext, Enum.Font.Gotham)
	helpText.AnchorPoint = Vector2.new(0, 1)
	helpText.Position = UDim2.new(0, 0, 1, 0)
	helpText.Size = UDim2.new(1, 0, 0, 18)
end

local function buildRecipesPanel()
	local _, body = makePanel(PANELS.Recipes, "Recipes", false, 340)

	local subtitle = makeLabel(body, "Subtitle", "Pick a recipe to start cooking.", 13, HUD_COLORS.subtext, Enum.Font.Gotham)
	subtitle.Size = UDim2.new(1, 0, 0, 18)

	local list = create("Frame", {
		Name = "RecipeList",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 1, -28),
		Parent = body,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})

	for _, recipeId in ipairs(RecipeDefinitions.RECIPE_ORDER) do
		local recipe = RecipeDefinitions.GetRecipe(recipeId)
		local button = makeButton(list, recipeId .. "RecipeButton", HUD_COLORS.panelDark)
		button.Size = UDim2.new(1, 0, 0, 60)

		local title = makeLabel(button, "Title", recipe.displayName, 14, HUD_COLORS.text, Enum.Font.GothamBold)
		title.Position = UDim2.fromOffset(12, 10)
		title.Size = UDim2.new(1, -24, 0, 16)

		local subtitleLabel = makeLabel(button, "Subtitle", table.concat(recipe.steps, " / "), 11, HUD_COLORS.subtext, Enum.Font.Gotham)
		subtitleLabel.Position = UDim2.fromOffset(12, 28)
		subtitleLabel.Size = UDim2.new(1, -24, 0, 16)

		button.MouseButton1Click:Connect(function()
			StartRecipeRequest:FireServer({
				recipeId = recipeId,
			})
			togglePanel(PANELS.Recipes)
		end)

		ui.recipeButtons[recipeId] = {
			button = button,
			title = title,
			subtitle = subtitleLabel,
		}
	end
end

local function buildOrdersPanel()
	local _, body = makePanel(PANELS.Orders, "Orders", false, 360)

	ui.ordersSelectedLabel = makeLabel(body, "SelectedLabel", "Selected: none", 13, HUD_COLORS.text, Enum.Font.GothamBold)
	ui.ordersSelectedLabel.Size = UDim2.new(1, 0, 0, 18)

	ui.ordersList = create("ScrollingFrame", {
		Name = "OrdersList",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		Position = UDim2.fromOffset(0, 26),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = HUD_COLORS.green,
		Size = UDim2.new(1, 0, 1, -72),
		Parent = body,
	})
	create("UIListLayout", {
		Name = "Layout",
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ui.ordersList,
	})
	ui.ordersEmptyState = makeLabel(ui.ordersList, "EmptyState", "No customer orders yet.", 13, HUD_COLORS.subtext, Enum.Font.Gotham)
	ui.ordersEmptyState.Size = UDim2.new(1, 0, 0, 18)

	local serveButton = makeButton(body, "ServeSelectedButton", HUD_COLORS.green)
	serveButton.AnchorPoint = Vector2.new(0, 1)
	serveButton.Position = UDim2.new(0, 0, 1, 0)
	serveButton.Size = UDim2.new(1, 0, 0, 36)
	local serveLabel = makeLabel(serveButton, "ServeLabel", "Serve Selected", 13, HUD_COLORS.white, Enum.Font.GothamBold)
	serveLabel.Size = UDim2.fromScale(1, 1)
	serveLabel.TextXAlignment = Enum.TextXAlignment.Center
	serveButton.MouseButton1Click:Connect(function()
		local customerId = selectedCustomerId or getOnlyActiveCustomerId()
		if not customerId then
			pushNotification("Select a customer in Orders.", "Warning")
			return
		end

		ServeRequest:FireServer({
			customerId = customerId,
		})
	end)
end

local function buildUpgradesPanel()
	local _, body = makePanel(PANELS.Upgrades, "Upgrades", false, 360)

	local list = create("Frame", {
		Name = "UpgradeList",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = body,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})

	local definitions = {
		{
			id = "FasterCooking",
			title = "Faster Cooking",
			subtitle = "Reduces station delay.",
			color = HUD_COLORS.blue,
		},
		{
			id = "BetterMarketing",
			title = "Better Marketing",
			subtitle = "Adds extra ViralPoints.",
			color = HUD_COLORS.orange,
		},
		{
			id = "BiggerCounter",
			title = "Bigger Counter",
			subtitle = "Brings customers faster.",
			color = HUD_COLORS.green,
		},
	}

	for _, definition in ipairs(definitions) do
		local button = makeButton(list, definition.id .. "UpgradeButton", definition.color)
		button.Size = UDim2.new(1, 0, 0, 68)

		local title = makeLabel(button, "Title", definition.title, 14, HUD_COLORS.white, Enum.Font.GothamBold)
		title.Position = UDim2.fromOffset(12, 8)
		title.Size = UDim2.new(1, -24, 0, 16)

		local subtitle = makeLabel(button, "Subtitle", definition.subtitle, 11, HUD_COLORS.white, Enum.Font.Gotham)
		subtitle.Position = UDim2.fromOffset(12, 24)
		subtitle.Size = UDim2.new(1, -24, 0, 14)

		local level = makeLabel(button, "Level", "", 11, HUD_COLORS.white, Enum.Font.Gotham)
		level.Position = UDim2.fromOffset(12, 40)
		level.Size = UDim2.new(0.5, 0, 0, 14)

		local cost = makeLabel(button, "Cost", "", 11, HUD_COLORS.white, Enum.Font.GothamBold)
		cost.AnchorPoint = Vector2.new(1, 0)
		cost.Position = UDim2.new(1, -12, 0, 40)
		cost.Size = UDim2.new(0.5, -4, 0, 14)
		cost.TextXAlignment = Enum.TextXAlignment.Right

		button.MouseButton1Click:Connect(function()
			UpgradeRequest:FireServer({
				upgradeId = definition.id,
			})
		end)

		ui.upgradeButtons[definition.id] = {
			level = level,
			cost = cost,
		}
	end
end

local function buildShopPanel()
	local _, body = makePanel(PANELS.Shop, "Shop", false, 320)

	local lines = {
		"Starter Pack: Coming soon",
		"Truck Skins: Coming soon",
		"Boosts: Coming soon",
		"",
		"Robux items will be added later.",
	}

	for index, line in ipairs(lines) do
		local label = makeLabel(body, "Line" .. index, line, if index == 5 then 13 else 14, if line == "" then HUD_COLORS.panel else HUD_COLORS.text, if index <= 3 then Enum.Font.GothamBold else Enum.Font.Gotham)
		label.Position = UDim2.fromOffset(0, (index - 1) * 34)
		label.Size = UDim2.new(1, 0, 0, 24)
		label.TextYAlignment = Enum.TextYAlignment.Top
	end
end

local function buildSettingsPanel()
	local _, body = makePanel(PANELS.Settings, "Settings", true, 200)

	local musicButton = makeButton(body, "MusicToggle", HUD_COLORS.blue)
	musicButton.Size = UDim2.new(1, 0, 0, 36)
	ui.musicToggleLabel = makeLabel(musicButton, "MusicToggleLabel", "", 13, HUD_COLORS.white, Enum.Font.GothamBold)
	ui.musicToggleLabel.Size = UDim2.fromScale(1, 1)
	ui.musicToggleLabel.TextXAlignment = Enum.TextXAlignment.Center
	musicButton.MouseButton1Click:Connect(function()
		uiState.musicEnabled = not uiState.musicEnabled
		refreshSettingsPanel()
		pushNotification("Music toggled locally.", "Info")
	end)

	local scaleButton = makeButton(body, "ScaleToggle", HUD_COLORS.orange)
	scaleButton.Position = UDim2.fromOffset(0, 46)
	scaleButton.Size = UDim2.new(1, 0, 0, 36)
	ui.scaleToggleLabel = makeLabel(scaleButton, "ScaleToggleLabel", "", 13, HUD_COLORS.white, Enum.Font.GothamBold)
	ui.scaleToggleLabel.Size = UDim2.fromScale(1, 1)
	ui.scaleToggleLabel.TextXAlignment = Enum.TextXAlignment.Center
	scaleButton.MouseButton1Click:Connect(function()
		uiState.compactScale = not uiState.compactScale
		applyUiScale()
		refreshSettingsPanel()
	end)
end

local function buildUi()
	for _, child in ipairs(screenGui:GetChildren()) do
		if child ~= script then
			child:Destroy()
		end
	end

	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.DisplayOrder = 5

	ui.root = create("Frame", {
		Name = "HudRoot",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	ui.rootScale = create("UIScale", {
		Scale = 1,
		Parent = ui.root,
	})

	buildQuestFrame()
	buildTopRightHud()
	buildBadgeRow()
	buildNotifications()
	buildStarterPackButton()
	buildCurrencyFrame()
	buildBottomNav()
	buildRightShortcuts()
	buildInventoryPanel()
	buildRecipesPanel()
	buildOrdersPanel()
	buildUpgradesPanel()
	buildShopPanel()
	buildSettingsPanel()

	applyUiScale()
	refreshQuest()
	refreshDayTime()
	refreshCurrencies()
	refreshTrendBadge()
	refreshTrendTimer()
	refreshViralRushBadge()
	refreshRecipeButtons()
	refreshInventoryPanel()
	refreshOrdersPanel()
	refreshUpgradesPanel()
	refreshSettingsPanel()
	refreshNavSelection()
	closeAllPanels()
end

local function connectLeaderstats()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then
		return
	end

	for _, valueName in ipairs({ "Money", "ViralPoints" }) do
		local value = leaderstats:WaitForChild(valueName, 10)
		if value then
			value.Changed:Connect(refreshCurrencies)
		end
	end

	refreshCurrencies()
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

local function handlePromptInteraction(prompt)
	local stationPart = getStationPartFromPrompt(prompt)
	if not stationPart then
		return
	end

	local stationType = stationPart:GetAttribute("StationType")
	if stationType == "Serving" then
		local customerId = selectedCustomerId or getOnlyActiveCustomerId()
		if not customerId then
			pushNotification("Select a customer in Orders.", "Warning")
			showPanel(PANELS.Orders)
			return
		end

		ServeRequest:FireServer({
			customerId = customerId,
		})
		return
	end

	if stationType == "Upgrade" then
		showPanel(PANELS.Upgrades)
		return
	end

	if not currentDish.recipeId then
		pushNotification("Select a recipe first.", "Warning")
		showPanel(PANELS.Recipes)
		return
	end

	local nextStep = getNextStep()
	if not nextStep then
		pushNotification("Dish is ready. Serve it at the counter.", "Info")
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
	refreshTrendBadge()
	refreshTrendTimer()
end)

DishStateChanged.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	currentDish = payload
	refreshRecipeButtons()
	refreshInventoryPanel()
end)

CustomerSpawned.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.customerId) ~= "string" then
		return
	end

	if not customers[payload.customerId] then
		table.insert(customerOrder, payload.customerId)
	end

	payload.receivedAt = workspace:GetServerTimeNow()
	payload.expiresAt = payload.receivedAt + (payload.timeoutSeconds or 0)
	customers[payload.customerId] = payload

	if not selectedCustomerId then
		selectedCustomerId = payload.customerId
	end

	refreshOrdersPanel()
end)

CustomerRemoved.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.customerId) ~= "string" then
		return
	end

	customers[payload.customerId] = nil
	if selectedCustomerId == payload.customerId then
		selectedCustomerId = nil
	end
	refreshOrdersPanel()
end)

NotificationEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.message) ~= "string" then
		return
	end

	pushNotification(payload.message, payload.notificationType)

	if string.find(payload.message, "^Served ") then
		questState.current = math.min(questState.target, questState.current + 1)
		refreshQuest()
	end

	local upgradedName, level = string.match(payload.message, "^(.-) upgraded to level (%d+)%.")
	if upgradedName and level then
		for upgradeId, upgrade in pairs(RecipeDefinitions.UPGRADES) do
			if upgrade.displayName == upgradedName then
				upgradeLevels[upgradeId] = tonumber(level) or upgradeLevels[upgradeId]
				refreshUpgradesPanel()
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
	refreshViralRushBadge()
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	handlePromptInteraction(prompt)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then
		return
	end

	if input.KeyCode == Enum.KeyCode.One then
		togglePanel(PANELS.Inventory)
	elseif input.KeyCode == Enum.KeyCode.Two then
		togglePanel(PANELS.Recipes)
	elseif input.KeyCode == Enum.KeyCode.Three then
		togglePanel(PANELS.Orders)
	elseif input.KeyCode == Enum.KeyCode.Four then
		togglePanel(PANELS.Upgrades)
	elseif input.KeyCode == Enum.KeyCode.Five then
		togglePanel(PANELS.Shop)
	elseif input.KeyCode == Enum.KeyCode.Escape then
		closeAllPanels()
	end
end)

buildUi()
task.spawn(connectLeaderstats)

task.spawn(function()
	while true do
		refreshDayTime()
		refreshTrendTimer()
		refreshViralRushBadge()
		refreshOrderTimers()
		task.wait(0.5)
	end
end)
