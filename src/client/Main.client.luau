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

local notificationState = {
	message = "",
	notificationType = "Info",
	expiresAt = 0,
}

local ui = {
	customerCards = {},
	recipeButtons = {},
	upgradeButtons = {},
	cards = {},
}

local THEME = {
	backgroundTop = Color3.fromRGB(11, 18, 31),
	backgroundBottom = Color3.fromRGB(40, 18, 25),
	panel = Color3.fromRGB(23, 30, 44),
	panelAlt = Color3.fromRGB(32, 41, 59),
	panelSoft = Color3.fromRGB(45, 56, 80),
	line = Color3.fromRGB(95, 109, 138),
	text = Color3.fromRGB(248, 243, 229),
	subtext = Color3.fromRGB(196, 204, 218),
	muted = Color3.fromRGB(148, 160, 182),
	coral = Color3.fromRGB(255, 125, 96),
	gold = Color3.fromRGB(255, 208, 88),
	sky = Color3.fromRGB(101, 203, 255),
	mint = Color3.fromRGB(94, 225, 182),
	rose = Color3.fromRGB(255, 107, 154),
	green = Color3.fromRGB(121, 228, 128),
	danger = Color3.fromRGB(255, 98, 98),
	white = Color3.fromRGB(255, 255, 255),
	ink = Color3.fromRGB(16, 21, 31),
}

local RECIPE_COLORS = {
	SpicyRamen = Color3.fromRGB(255, 130, 100),
	BubbleTea = Color3.fromRGB(108, 214, 255),
	KoreanCornDog = Color3.fromRGB(255, 214, 94),
}

local UPGRADE_STYLES = {
	FasterCooking = {
		color = Color3.fromRGB(111, 218, 255),
		description = "Reduces the delay between valid station steps.",
	},
	BetterMarketing = {
		color = Color3.fromRGB(255, 133, 190),
		description = "Adds bonus ViralPoints to every successful serve.",
	},
	BiggerCounter = {
		color = Color3.fromRGB(255, 205, 93),
		description = "Pulls in customers faster for the whole truck.",
	},
}

local NOTIFICATION_STYLES = {
	Info = {
		background = Color3.fromRGB(35, 56, 82),
		accent = THEME.sky,
	},
	Success = {
		background = Color3.fromRGB(30, 77, 56),
		accent = THEME.green,
	},
	Warning = {
		background = Color3.fromRGB(87, 61, 29),
		accent = THEME.gold,
	},
	Error = {
		background = Color3.fromRGB(92, 37, 40),
		accent = THEME.coral,
	},
}

local CARD_HEIGHTS = {
	TrendCard = 304,
	DishCard = 384,
	QueueCard = 368,
	RecipesCard = 330,
	UpgradeCard = 354,
	HelpCard = 184,
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

local function getViewportSize()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end

	return Vector2.new(1280, 720)
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

local function addGradient(parent, colorSequence, rotation, transparencySequence)
	return create("UIGradient", {
		Color = colorSequence,
		Rotation = rotation or 90,
		Transparency = transparencySequence,
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
	return create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Font = font or Enum.Font.Gotham,
		Text = text,
		TextColor3 = color or THEME.text,
		TextSize = size or 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = parent,
	})
end

local function makeBadge(parent, name, text, backgroundColor, textColor)
	local badge = create("TextLabel", {
		Name = name,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextColor3 = textColor or THEME.ink,
		TextSize = 13,
		TextWrapped = false,
		Parent = parent,
	})
	addCorner(badge, 999)
	addStroke(badge, Color3.new(1, 1, 1), 1, 0.7)
	addPadding(badge, 8)
	return badge
end

local function makeCard(parent, name, title, subtitle, accentColor)
	local card = create("Frame", {
		Name = name,
		BackgroundColor3 = THEME.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	})
	addCorner(card, 22)
	addStroke(card, THEME.line, 1, 0.35)
	addGradient(card, ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.panelAlt),
		ColorSequenceKeypoint.new(1, THEME.panel),
	}), 90)

	local topAccent = create("Frame", {
		Name = "TopAccent",
		BackgroundColor3 = accentColor,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 6),
		Parent = card,
	})
	addGradient(topAccent, ColorSequence.new({
		ColorSequenceKeypoint.new(0, accentColor),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	}), 0, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 0.65),
	}))

	local glow = create("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = accentColor,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -24, 0, -18),
		Rotation = 18,
		Size = UDim2.fromOffset(120, 120),
		Parent = card,
	})
	addCorner(glow, 30)

	local titleLabel = makeLabel(card, "TitleLabel", title, 24, THEME.text, Enum.Font.GothamBold)
	titleLabel.Position = UDim2.fromOffset(18, 20)
	titleLabel.Size = UDim2.new(1, -36, 0, 28)
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center

	local subtitleLabel = makeLabel(card, "SubtitleLabel", subtitle, 14, THEME.subtext, Enum.Font.Gotham)
	subtitleLabel.Position = UDim2.fromOffset(18, 48)
	subtitleLabel.Size = UDim2.new(1, -36, 0, 18)
	subtitleLabel.TextYAlignment = Enum.TextYAlignment.Center

	local body = create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 82),
		Size = UDim2.new(1, -36, 1, -100),
		Parent = card,
	})

	return card, body
end

local function makeActionCard(parent, name, backgroundColor)
	local button = create("TextButton", {
		Name = name,
		AutoButtonColor = false,
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "",
		Parent = parent,
	})
	addCorner(button, 18)
	addStroke(button, Color3.new(1, 1, 1), 1, 0.72)
	addGradient(button, ColorSequence.new({
		ColorSequenceKeypoint.new(0, backgroundColor),
		ColorSequenceKeypoint.new(1, THEME.panelSoft),
	}), 90)

	local accent = create("Frame", {
		Name = "Accent",
		BackgroundColor3 = backgroundColor,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 8, 1, 0),
		Parent = button,
	})
	addCorner(accent, 18)

	return button
end

local function clearLayoutChildren(container)
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

local function getFirstCustomerId()
	for _, customerId in ipairs(customerOrder) do
		if customers[customerId] then
			return customerId
		end
	end

	return nil
end

local function getCustomerRemainingTime(customer)
	if not customer or not customer.expiresAt then
		return 0
	end

	return math.max(0, customer.expiresAt - workspace:GetServerTimeNow())
end

local function refreshStats()
	if not ui.moneyValue then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("Money")
	local viralPoints = leaderstats and leaderstats:FindFirstChild("ViralPoints")

	setText(ui.moneyValue, "$" .. tostring(if money then money.Value else 0))
	setText(ui.viralPointsValue, tostring(if viralPoints then viralPoints.Value else 0))
end

local function refreshTrend()
	if not ui.trendName then
		return
	end

	local recipeName = trendState.trendDisplayName or "Loading..."
	setText(ui.trendName, recipeName)
	setText(ui.headerTrendChip, "Trend: " .. recipeName)
	setText(ui.trendDescription, "Serve the live trend for double Money and ViralPoints. Stack it with influencer orders for the biggest pop.")
end

local function refreshTrendTimer()
	if not ui.trendTimer then
		return
	end

	local timeLeft = trendState.endsAt - workspace:GetServerTimeNow()
	local formatted = formatTime(timeLeft)
	setText(ui.trendTimer, "Ends in " .. formatted)
	setText(ui.headerTrendTimer, formatted)
end

local function refreshViralRush()
	if not ui.rushStatus or not ui.headerRushChip then
		return
	end

	if viralRushState.isActive and viralRushState.endsAt then
		local timeLeft = viralRushState.endsAt - workspace:GetServerTimeNow()
		setText(ui.rushStatus, "Viral Rush is LIVE")
		setText(ui.rushTimer, "Spawn boost active for " .. formatTime(timeLeft))
		ui.rushStatus.TextColor3 = THEME.gold
		ui.rushTimer.TextColor3 = THEME.text
		ui.headerRushChip.BackgroundColor3 = THEME.coral
		ui.headerRushChip.TextColor3 = THEME.ink
		setText(ui.headerRushChip, "Rush: ACTIVE")
	else
		setText(ui.rushStatus, "Influencers can ignite Viral Rush")
		setText(ui.rushTimer, "Serve a VIP order correctly to cut customer spawn times.")
		ui.rushStatus.TextColor3 = THEME.text
		ui.rushTimer.TextColor3 = THEME.subtext
		ui.headerRushChip.BackgroundColor3 = THEME.panelSoft
		ui.headerRushChip.TextColor3 = THEME.text
		setText(ui.headerRushChip, "Rush: Ready")
	end
end

local function refreshRecipeButtons()
	for recipeId, entry in pairs(ui.recipeButtons) do
		local recipe = RecipeDefinitions.GetRecipe(recipeId)
		local accent = RECIPE_COLORS[recipeId] or THEME.sky
		local isSelected = currentDish.recipeId == recipeId
		local isTrend = trendState.trendRecipeId == recipeId
		local badgeText = "Start"
		local badgeColor = accent
		local backgroundColor = THEME.panelSoft

		if isSelected and currentDish.isComplete then
			badgeText = "Ready"
			badgeColor = THEME.green
			backgroundColor = accent
		elseif isSelected then
			badgeText = "Active"
			badgeColor = accent
			backgroundColor = accent
		elseif isTrend then
			badgeText = "Trend x2"
			badgeColor = THEME.gold
		end

		entry.button.BackgroundColor3 = backgroundColor
		entry.button.BackgroundTransparency = if isSelected then 0.02 else 0.12
		entry.stroke.Color = if isTrend then THEME.gold else accent
		entry.title.TextColor3 = if isSelected then THEME.ink else THEME.text
		entry.detail.TextColor3 = if isSelected then Color3.fromRGB(58, 35, 31) else THEME.subtext
		entry.badge.BackgroundColor3 = badgeColor
		entry.badge.TextColor3 = THEME.ink
		entry.badge.Text = badgeText
		entry.detail.Text = table.concat(recipe.steps, " / ")
	end
end

local function refreshDish()
	if not ui.dishTitle then
		return
	end

	local recipeName = currentDish.recipeDisplayName or "Pick a recipe"
	local completedCount = #(currentDish.completedSteps or {})
	local totalSteps = math.max(1, #(currentDish.requiredSteps or {}))
	local progress = if currentDish.recipeId then completedCount / totalSteps else 0
	local nextStep = getNextStep()

	setText(ui.dishTitle, recipeName)
	setText(ui.dishStatus, if currentDish.isComplete then "Ready to serve" else "Kitchen prep")
	ui.dishStatus.BackgroundColor3 = if currentDish.isComplete then THEME.green else THEME.sky
	ui.dishStatus.TextColor3 = THEME.ink
	ui.progressFill.Size = UDim2.new(progress, 0, 1, 0)
	setText(ui.progressLabel, if currentDish.recipeId then string.format("%d / %d steps complete", completedCount, totalSteps) else "Select one of the three recipes to start.")

	if currentDish.recipeId and nextStep and not currentDish.isComplete then
		local stationType = RecipeDefinitions.GetStepStationType(currentDish.recipeId, nextStep) or "Station"
		setText(ui.nextStepLabel, "Next step: " .. nextStep .. " at the " .. stationType .. " station.")
	elseif currentDish.isComplete then
		setText(ui.nextStepLabel, "Dish complete. Head to the counter and serve a matching customer.")
	else
		setText(ui.nextStepLabel, "Use the recipe buttons, then follow the highlighted prep flow.")
	end

	clearLayoutChildren(ui.stepList)
	ui.emptyStepState.Visible = not currentDish.recipeId

	if currentDish.recipeId then
		local completedLookup = getCompletedLookup()
		for index, stepName in ipairs(currentDish.requiredSteps or {}) do
			local state = "Pending"
			local accent = THEME.panelSoft
			local textColor = THEME.text

			if completedLookup[stepName] then
				state = "Done"
				accent = THEME.green
				textColor = THEME.ink
			elseif nextStep == stepName and not currentDish.isComplete then
				state = "Next"
				accent = THEME.gold
				textColor = THEME.ink
			end

			local row = create("Frame", {
				Name = "StepRow",
				BackgroundColor3 = accent,
				BackgroundTransparency = if state == "Pending" then 0.72 else 0.08,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 44),
				Parent = ui.stepList,
			})
			addCorner(row, 14)
			addStroke(row, Color3.new(1, 1, 1), 1, 0.8)

			local indexPill = makeBadge(row, "IndexPill", tostring(index), accent, textColor)
			indexPill.Position = UDim2.fromOffset(10, 9)
			indexPill.Size = UDim2.fromOffset(30, 26)
			indexPill.AutomaticSize = Enum.AutomaticSize.None
			indexPill.TextXAlignment = Enum.TextXAlignment.Center
			indexPill.TextYAlignment = Enum.TextYAlignment.Center

			local title = makeLabel(row, "StepTitle", stepName, 16, textColor, Enum.Font.GothamBold)
			title.Position = UDim2.fromOffset(52, 8)
			title.Size = UDim2.new(1, -160, 0, 18)
			title.TextYAlignment = Enum.TextYAlignment.Center

			local stationType = if currentDish.recipeId then RecipeDefinitions.GetStepStationType(currentDish.recipeId, stepName) else nil
			local subtitle = makeLabel(row, "StepSubtitle", stationType or "Station", 13, if state == "Pending" then THEME.subtext else textColor, Enum.Font.Gotham)
			subtitle.Position = UDim2.fromOffset(52, 23)
			subtitle.Size = UDim2.new(1, -160, 0, 14)
			subtitle.TextYAlignment = Enum.TextYAlignment.Center

			local stateBadge = makeBadge(row, "StateBadge", state, if state == "Pending" then THEME.panelAlt else accent, textColor)
			stateBadge.AnchorPoint = Vector2.new(1, 0)
			stateBadge.Position = UDim2.new(1, -10, 0, 9)
		end
	end

	refreshRecipeButtons()
end

local function refreshCustomerSelectionSummary()
	if not ui.selectedCustomerLabel then
		return
	end

	local customer = selectedCustomerId and customers[selectedCustomerId]
	if not customer then
		setText(ui.selectedCustomerLabel, "No active customer selected.")
		setText(ui.serveButtonLabel, "Serve Selected")
		return
	end

	local prefix = if customer.isInfluencer then "Selected VIP: " else "Selected order: "
	setText(ui.selectedCustomerLabel, prefix .. customer.orderDisplayName)
	setText(ui.serveButtonLabel, "Serve " .. customer.orderDisplayName)
end

local function refreshCustomerTimers()
	for customerId, card in pairs(ui.customerCards) do
		local customer = customers[customerId]
		if customer then
			local remaining = getCustomerRemainingTime(customer)
			local total = math.max(1, customer.timeoutSeconds or 1)
			card.timeLabel.Text = formatTime(remaining)
			card.progressFill.Size = UDim2.new(math.clamp(remaining / total, 0, 1), 0, 1, 0)
			card.progressFill.BackgroundColor3 = if remaining <= 10 then THEME.coral else if customer.isInfluencer then THEME.gold else THEME.mint
		end
	end
end

local function refreshCustomers()
	if not ui.customerList then
		return
	end

	local filteredOrder = {}
	for _, customerId in ipairs(customerOrder) do
		if customers[customerId] then
			table.insert(filteredOrder, customerId)
		end
	end
	customerOrder = filteredOrder

	if not selectedCustomerId or not customers[selectedCustomerId] then
		selectedCustomerId = getFirstCustomerId()
	end

	clearLayoutChildren(ui.customerList)
	ui.customerCards = {}
	ui.emptyCustomerState.Visible = #customerOrder == 0

	for _, customerId in ipairs(customerOrder) do
		local customer = customers[customerId]
		if customer then
			local accent = if customer.isInfluencer then THEME.gold else (RECIPE_COLORS[customer.orderRecipeId] or THEME.sky)
			local selected = selectedCustomerId == customerId
			local card = create("TextButton", {
				Name = customerId,
				AutoButtonColor = false,
				BackgroundColor3 = if selected then accent else THEME.panelSoft,
				BackgroundTransparency = if selected then 0.08 else 0.18,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 78),
				Text = "",
				Parent = ui.customerList,
			})
			addCorner(card, 18)
			local stroke = addStroke(card, if selected then accent else THEME.line, 1, if selected then 0.12 else 0.55)
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

			local topBar = create("Frame", {
				Name = "TopBar",
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 8),
				Parent = card,
			})
			addCorner(topBar, 18)

			local title = makeLabel(card, "Title", customer.orderDisplayName, 18, if selected then THEME.ink else THEME.text, Enum.Font.GothamBold)
			title.Position = UDim2.fromOffset(16, 15)
			title.Size = UDim2.new(1, -150, 0, 20)
			title.TextYAlignment = Enum.TextYAlignment.Center

			local subtitle = makeLabel(card, "Subtitle", if customer.isInfluencer then "Influencer guest" else "Festival customer", 13, if selected then Color3.fromRGB(63, 43, 33) else THEME.subtext, Enum.Font.Gotham)
			subtitle.Position = UDim2.fromOffset(16, 38)
			subtitle.Size = UDim2.new(1, -150, 0, 16)
			subtitle.TextYAlignment = Enum.TextYAlignment.Center

			if customer.isInfluencer then
				local vipBadge = makeBadge(card, "VipBadge", "VIP", THEME.gold, THEME.ink)
				vipBadge.Position = UDim2.new(1, -146, 0, 14)
			end

			local timeLabel = makeLabel(card, "TimeLabel", "0:00", 16, if selected then THEME.ink else THEME.text, Enum.Font.GothamBold)
			timeLabel.AnchorPoint = Vector2.new(1, 0)
			timeLabel.Position = UDim2.new(1, -16, 0, 15)
			timeLabel.Size = UDim2.fromOffset(72, 18)
			timeLabel.TextXAlignment = Enum.TextXAlignment.Right
			timeLabel.TextYAlignment = Enum.TextYAlignment.Center

			local progressBar = create("Frame", {
				Name = "ProgressBar",
				BackgroundColor3 = THEME.panelAlt,
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(16, 60),
				Size = UDim2.new(1, -32, 0, 8),
				Parent = card,
			})
			addCorner(progressBar, 999)

			local progressFill = create("Frame", {
				Name = "Fill",
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, 0),
				Parent = progressBar,
			})
			addCorner(progressFill, 999)

			card.MouseButton1Click:Connect(function()
				selectedCustomerId = customerId
				refreshCustomers()
			end)

			ui.customerCards[customerId] = {
				button = card,
				timeLabel = timeLabel,
				progressFill = progressFill,
			}
		end
	end

	setText(ui.customerCountLabel, tostring(#customerOrder) .. " waiting")
	refreshCustomerSelectionSummary()
	refreshCustomerTimers()
end

local function refreshUpgrades()
	for upgradeId, entry in pairs(ui.upgradeButtons) do
		local level = upgradeLevels[upgradeId] or 0
		local cost = 100 * (level + 1)
		local style = UPGRADE_STYLES[upgradeId]

		setText(entry.title, RecipeDefinitions.GetUpgrade(upgradeId).displayName)
		setText(entry.description, style.description)
		if level >= 5 then
			setText(entry.meta, "Level " .. level .. " / MAX")
			setText(entry.badge, "Maxed")
			entry.badge.BackgroundColor3 = THEME.green
		else
			setText(entry.meta, "Level " .. level .. "  |  Next cost $" .. cost)
			setText(entry.badge, "Upgrade")
			entry.badge.BackgroundColor3 = style.color
		end
	end
end

local function refreshNotification()
	if not ui.notificationFrame then
		return
	end

	if notificationState.message == "" or workspace:GetServerTimeNow() >= notificationState.expiresAt then
		ui.notificationFrame.Visible = false
		return
	end

	local palette = NOTIFICATION_STYLES[notificationState.notificationType] or NOTIFICATION_STYLES.Info
	ui.notificationFrame.Visible = true
	ui.notificationFrame.BackgroundColor3 = palette.background
	ui.notificationAccent.BackgroundColor3 = palette.accent
	ui.notificationStroke.Color = palette.accent
	setText(ui.notificationTitle, string.upper(notificationState.notificationType))
	setText(ui.notificationBody, notificationState.message)
end

local function localNotify(message, notificationType)
	notificationState.message = message
	notificationState.notificationType = notificationType or "Info"
	notificationState.expiresAt = workspace:GetServerTimeNow() + 4
	refreshNotification()
end

local function serveSelectedCustomer()
	local customerId = selectedCustomerId or getFirstCustomerId()
	if not customerId then
		localNotify("No customers are waiting.", "Warning")
		return
	end

	ServeRequest:FireServer({
		customerId = customerId,
	})
end

local function layoutUi()
	if not ui.root or not ui.header or not ui.dashboardContent then
		return
	end

	local viewport = getViewportSize()
	local width = viewport.X
	local headerHeight

	if width >= 980 then
		headerHeight = 176
		ui.brandFrame.Position = UDim2.fromOffset(18, 18)
		ui.brandFrame.Size = UDim2.new(0.58, -10, 1, -36)
		ui.statsFrame.Position = UDim2.new(0.6, 6, 0, 18)
		ui.statsFrame.Size = UDim2.new(0.4, -24, 1, -36)
		ui.statsLayout.FillDirection = Enum.FillDirection.Horizontal
		ui.statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		ui.statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		ui.statsLayout.Padding = UDim.new(0, 12)
	elseif width >= 700 then
		headerHeight = 224
		ui.brandFrame.Position = UDim2.fromOffset(18, 18)
		ui.brandFrame.Size = UDim2.new(1, -36, 0, 126)
		ui.statsFrame.Position = UDim2.fromOffset(18, 154)
		ui.statsFrame.Size = UDim2.new(1, -36, 0, 56)
		ui.statsLayout.FillDirection = Enum.FillDirection.Horizontal
		ui.statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		ui.statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		ui.statsLayout.Padding = UDim.new(0, 10)
	else
		headerHeight = 360
		ui.brandFrame.Position = UDim2.fromOffset(18, 18)
		ui.brandFrame.Size = UDim2.new(1, -36, 0, 178)
		ui.statsFrame.Position = UDim2.fromOffset(18, 212)
		ui.statsFrame.Size = UDim2.new(1, -36, 0, 124)
		ui.statsLayout.FillDirection = Enum.FillDirection.Vertical
		ui.statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		ui.statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		ui.statsLayout.Padding = UDim.new(0, 8)
	end

	if width >= 980 then
		ui.titleLabel.TextSize = 34
		ui.subtitleLabel.Position = UDim2.fromOffset(0, 72)
		ui.subtitleLabel.Size = UDim2.new(1, -8, 0, 32)
		ui.headerTrendChip.Position = UDim2.fromOffset(0, 112)
		ui.headerTrendTimer.Position = UDim2.fromOffset(164, 112)
		ui.headerRushChip.Position = UDim2.fromOffset(250, 112)
	elseif width >= 700 then
		ui.titleLabel.TextSize = 30
		ui.subtitleLabel.Position = UDim2.fromOffset(0, 68)
		ui.subtitleLabel.Size = UDim2.new(1, -8, 0, 32)
		ui.headerTrendChip.Position = UDim2.fromOffset(0, 104)
		ui.headerTrendTimer.Position = UDim2.fromOffset(164, 104)
		ui.headerRushChip.Position = UDim2.fromOffset(250, 104)
	else
		ui.titleLabel.TextSize = 26
		ui.subtitleLabel.Position = UDim2.fromOffset(0, 74)
		ui.subtitleLabel.Size = UDim2.new(1, -8, 0, 44)
		ui.headerTrendChip.Position = UDim2.fromOffset(0, 128)
		ui.headerTrendTimer.Position = UDim2.fromOffset(160, 128)
		ui.headerRushChip.Position = UDim2.fromOffset(0, 160)
	end

	ui.header.Size = UDim2.new(1, -32, 0, headerHeight)
	ui.dashboard.Position = UDim2.fromOffset(16, headerHeight + 28)
	ui.dashboard.Size = UDim2.new(1, -32, 1, -(headerHeight + 112))
	if width < 420 then
		ui.notificationFrame.Position = UDim2.new(0, 16, 1, -86)
		ui.notificationFrame.Size = UDim2.new(1, -32, 0, 62)
	else
		ui.notificationFrame.Position = UDim2.new(1, -344, 1, -86)
		ui.notificationFrame.Size = UDim2.fromOffset(328, 62)
	end

	local padding = 20
	local gap = 14
	local availableWidth = math.max(280, ui.dashboard.AbsoluteSize.X - (padding * 2))
	local row1Height = math.max(CARD_HEIGHTS.TrendCard, CARD_HEIGHTS.DishCard, CARD_HEIGHTS.QueueCard)
	local row2Height = math.max(CARD_HEIGHTS.RecipesCard, CARD_HEIGHTS.UpgradeCard)
	local currentY = 0

	local function place(cardName, x, y, cardWidth, cardHeight)
		local card = ui.cards[cardName]
		card.Position = UDim2.fromOffset(x, y)
		card.Size = UDim2.fromOffset(cardWidth, cardHeight)
	end

	if availableWidth >= 1260 then
		local thirdWidth = math.floor((availableWidth - gap * 2) / 3)
		place("TrendCard", 0, currentY, thirdWidth, CARD_HEIGHTS.TrendCard)
		place("DishCard", thirdWidth + gap, currentY, thirdWidth, CARD_HEIGHTS.DishCard)
		place("QueueCard", (thirdWidth + gap) * 2, currentY, thirdWidth, CARD_HEIGHTS.QueueCard)
		currentY += row1Height + gap

		local halfWidth = math.floor((availableWidth - gap) / 2)
		place("RecipesCard", 0, currentY, halfWidth, CARD_HEIGHTS.RecipesCard)
		place("UpgradeCard", halfWidth + gap, currentY, halfWidth, CARD_HEIGHTS.UpgradeCard)
		currentY += row2Height + gap

		place("HelpCard", 0, currentY, availableWidth, CARD_HEIGHTS.HelpCard)
		currentY += CARD_HEIGHTS.HelpCard
	elseif availableWidth >= 840 then
		local halfWidth = math.floor((availableWidth - gap) / 2)
		place("TrendCard", 0, currentY, halfWidth, CARD_HEIGHTS.TrendCard)
		place("DishCard", halfWidth + gap, currentY, halfWidth, CARD_HEIGHTS.DishCard)
		currentY += math.max(CARD_HEIGHTS.TrendCard, CARD_HEIGHTS.DishCard) + gap

		place("QueueCard", 0, currentY, availableWidth, CARD_HEIGHTS.QueueCard)
		currentY += CARD_HEIGHTS.QueueCard + gap

		place("RecipesCard", 0, currentY, halfWidth, CARD_HEIGHTS.RecipesCard)
		place("UpgradeCard", halfWidth + gap, currentY, halfWidth, CARD_HEIGHTS.UpgradeCard)
		currentY += math.max(CARD_HEIGHTS.RecipesCard, CARD_HEIGHTS.UpgradeCard) + gap

		place("HelpCard", 0, currentY, availableWidth, CARD_HEIGHTS.HelpCard)
		currentY += CARD_HEIGHTS.HelpCard
	else
		for _, cardName in ipairs({ "TrendCard", "DishCard", "QueueCard", "RecipesCard", "UpgradeCard", "HelpCard" }) do
			local height = CARD_HEIGHTS[cardName]
			place(cardName, 0, currentY, availableWidth, height)
			currentY += height + gap
		end
		currentY -= gap
	end

	ui.dashboardContent.Size = UDim2.new(1, -(padding * 2), 0, currentY)
	ui.dashboard.CanvasSize = UDim2.new(0, 0, 0, currentY + 12)
	ui.dashboardContent.Position = UDim2.fromOffset(padding, 0)
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
		BackgroundColor3 = THEME.backgroundTop,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	addGradient(root, ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.backgroundTop),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(18, 24, 37)),
		ColorSequenceKeypoint.new(1, THEME.backgroundBottom),
	}), 90)
	ui.root = root

	local glowLeft = create("Frame", {
		Name = "GlowLeft",
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = THEME.coral,
		BackgroundTransparency = 0.84,
		BorderSizePixel = 0,
		Position = UDim2.new(-0.04, 0, 0.06, 0),
		Rotation = -18,
		Size = UDim2.new(0.28, 0, 0.3, 0),
		Parent = root,
	})
	addCorner(glowLeft, 120)

	local glowRight = create("Frame", {
		Name = "GlowRight",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = THEME.sky,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Position = UDim2.new(1.04, 0, 0.12, 0),
		Rotation = 18,
		Size = UDim2.new(0.3, 0, 0.34, 0),
		Parent = root,
	})
	addCorner(glowRight, 120)

	local header = create("Frame", {
		Name = "Header",
		BackgroundColor3 = THEME.panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.new(1, -32, 0, 150),
		Parent = root,
	})
	addCorner(header, 26)
	addStroke(header, THEME.line, 1, 0.28)
	addGradient(header, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 42, 60)),
		ColorSequenceKeypoint.new(1, THEME.panel),
	}), 90)
	ui.header = header

	local headerAccent = create("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = THEME.gold,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 6),
		Parent = header,
	})
	addGradient(headerAccent, ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.coral),
		ColorSequenceKeypoint.new(0.45, THEME.gold),
		ColorSequenceKeypoint.new(1, THEME.sky),
	}), 0)

	ui.brandFrame = create("Frame", {
		Name = "BrandFrame",
		BackgroundTransparency = 1,
		Parent = header,
	})

	local banner = makeBadge(ui.brandFrame, "FestivalBadge", "Food Truck Frenzy", THEME.gold, THEME.ink)
	banner.Position = UDim2.fromOffset(0, 0)

	local title = makeLabel(ui.brandFrame, "Title", "Viral Kitchen Festival Control", 34, THEME.text, Enum.Font.GothamBold)
	title.Position = UDim2.fromOffset(0, 30)
	title.Size = UDim2.new(1, 0, 0, 42)
	ui.titleLabel = title

	local subtitle = makeLabel(ui.brandFrame, "Subtitle", "Catch the trend, prep the right steps, and turn influencer visits into a full-on rush.", 15, THEME.subtext, Enum.Font.Gotham)
	subtitle.Position = UDim2.fromOffset(0, 72)
	subtitle.Size = UDim2.new(1, -8, 0, 36)
	ui.subtitleLabel = subtitle

	ui.headerTrendChip = makeBadge(ui.brandFrame, "HeaderTrendChip", "Trend: Loading...", THEME.coral, THEME.ink)
	ui.headerTrendChip.Position = UDim2.fromOffset(0, 116)

	ui.headerTrendTimer = makeBadge(ui.brandFrame, "HeaderTrendTimer", "0:00", THEME.panelSoft, THEME.text)
	ui.headerTrendTimer.Position = UDim2.fromOffset(164, 116)

	ui.headerRushChip = makeBadge(ui.brandFrame, "HeaderRushChip", "Rush: Ready", THEME.panelSoft, THEME.text)
	ui.headerRushChip.Position = UDim2.fromOffset(250, 116)

	ui.statsFrame = create("Frame", {
		Name = "StatsFrame",
		BackgroundTransparency = 1,
		Parent = header,
	})
	ui.statsLayout = create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = ui.statsFrame,
	})

	local function makeStatPill(name, titleText, accentColor)
		local pill = create("Frame", {
			Name = name,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = THEME.panelSoft,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Parent = ui.statsFrame,
		})
		addCorner(pill, 18)
		addStroke(pill, accentColor, 1, 0.52)
		addPadding(pill, 12)

		local accent = create("Frame", {
			Name = "Accent",
			BackgroundColor3 = accentColor,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(8, 50),
			Parent = pill,
		})
		addCorner(accent, 18)

		local label = makeLabel(pill, "Label", titleText, 13, THEME.subtext, Enum.Font.Gotham)
		label.Position = UDim2.fromOffset(18, 0)
		label.Size = UDim2.fromOffset(96, 18)
		label.TextYAlignment = Enum.TextYAlignment.Center

		local value = makeLabel(pill, "Value", "0", 24, THEME.text, Enum.Font.GothamBold)
		value.Position = UDim2.fromOffset(18, 18)
		value.Size = UDim2.fromOffset(110, 28)
		value.TextYAlignment = Enum.TextYAlignment.Center

		return value
	end

	ui.moneyValue = makeStatPill("MoneyPill", "Money", THEME.gold)
	ui.viralPointsValue = makeStatPill("ViralPill", "ViralPoints", THEME.sky)

	local dashboard = create("ScrollingFrame", {
		Name = "Dashboard",
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		Position = UDim2.fromOffset(16, 178),
		ScrollBarImageColor3 = THEME.gold,
		ScrollBarThickness = 6,
		Size = UDim2.new(1, -32, 1, -262),
		Parent = root,
	})
	ui.dashboard = dashboard

	ui.dashboardContent = create("Frame", {
		Name = "DashboardContent",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -40, 0, 0),
		Parent = dashboard,
	})

	local trendCard, trendBody = makeCard(ui.dashboardContent, "TrendCard", "Festival Trend", "The hottest menu item on the grounds", THEME.coral)
	ui.cards.TrendCard = trendCard
	ui.trendName = makeLabel(trendBody, "TrendName", "Loading...", 32, THEME.text, Enum.Font.GothamBold)
	ui.trendName.Size = UDim2.new(1, 0, 0, 38)
	ui.trendName.TextYAlignment = Enum.TextYAlignment.Center
	ui.trendTimer = makeBadge(trendBody, "TrendTimer", "Ends in 0:00", THEME.gold, THEME.ink)
	ui.trendTimer.Position = UDim2.fromOffset(0, 50)
	ui.trendDescription = makeLabel(trendBody, "TrendDescription", "", 15, THEME.subtext, Enum.Font.Gotham)
	ui.trendDescription.Position = UDim2.fromOffset(0, 92)
	ui.trendDescription.Size = UDim2.new(1, 0, 0, 54)
	ui.rushStatus = makeLabel(trendBody, "RushStatus", "", 18, THEME.text, Enum.Font.GothamBold)
	ui.rushStatus.Position = UDim2.fromOffset(0, 154)
	ui.rushStatus.Size = UDim2.new(1, 0, 0, 22)
	ui.rushStatus.TextYAlignment = Enum.TextYAlignment.Center
	ui.rushTimer = makeLabel(trendBody, "RushTimer", "", 14, THEME.subtext, Enum.Font.Gotham)
	ui.rushTimer.Position = UDim2.fromOffset(0, 178)
	ui.rushTimer.Size = UDim2.new(1, 0, 0, 20)
	ui.rushTimer.TextYAlignment = Enum.TextYAlignment.Center

	local dishCard, dishBody = makeCard(ui.dashboardContent, "DishCard", "Current Dish", "Track each prep step and your next station", THEME.sky)
	ui.cards.DishCard = dishCard
	ui.dishTitle = makeLabel(dishBody, "DishTitle", "Pick a recipe", 28, THEME.text, Enum.Font.GothamBold)
	ui.dishTitle.Size = UDim2.new(1, -120, 0, 32)
	ui.dishTitle.TextYAlignment = Enum.TextYAlignment.Center
	ui.dishStatus = makeBadge(dishBody, "DishStatus", "Kitchen prep", THEME.sky, THEME.ink)
	ui.dishStatus.AnchorPoint = Vector2.new(1, 0)
	ui.dishStatus.Position = UDim2.new(1, 0, 0, 0)

	local progressBar = create("Frame", {
		Name = "ProgressBar",
		BackgroundColor3 = THEME.panelAlt,
		BackgroundTransparency = 0.16,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 12),
		Parent = dishBody,
	})
	addCorner(progressBar, 999)
	ui.progressFill = create("Frame", {
		Name = "ProgressFill",
		BackgroundColor3 = THEME.sky,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = progressBar,
	})
	addCorner(ui.progressFill, 999)

	ui.progressLabel = makeLabel(dishBody, "ProgressLabel", "", 14, THEME.subtext, Enum.Font.Gotham)
	ui.progressLabel.Position = UDim2.fromOffset(0, 64)
	ui.progressLabel.Size = UDim2.new(1, 0, 0, 18)
	ui.progressLabel.TextYAlignment = Enum.TextYAlignment.Center

	ui.nextStepLabel = makeLabel(dishBody, "NextStepLabel", "", 15, THEME.text, Enum.Font.GothamBold)
	ui.nextStepLabel.Position = UDim2.fromOffset(0, 88)
	ui.nextStepLabel.Size = UDim2.new(1, 0, 0, 36)

	ui.stepList = create("ScrollingFrame", {
		Name = "StepList",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		Position = UDim2.fromOffset(0, 132),
		ScrollBarImageColor3 = THEME.sky,
		ScrollBarThickness = 4,
		Size = UDim2.new(1, 0, 1, -132),
		Parent = dishBody,
	})
	create("UIListLayout", {
		Name = "Layout",
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ui.stepList,
	})
	ui.emptyStepState = makeLabel(ui.stepList, "EmptyState", "No dish in progress yet. Pick Spicy Ramen, Bubble Tea, or Korean Corn Dog to begin.", 15, THEME.subtext, Enum.Font.Gotham)
	ui.emptyStepState.Size = UDim2.new(1, 0, 0, 40)

	local queueCard, queueBody = makeCard(ui.dashboardContent, "QueueCard", "Customer Queue", "Keep the line moving before patience runs out", THEME.gold)
	ui.cards.QueueCard = queueCard
	ui.customerCountLabel = makeBadge(queueBody, "CustomerCountLabel", "0 waiting", THEME.panelSoft, THEME.text)
	ui.customerCountLabel.Position = UDim2.fromOffset(0, 0)
	ui.selectedCustomerLabel = makeLabel(queueBody, "SelectedCustomerLabel", "No active customer selected.", 17, THEME.text, Enum.Font.GothamBold)
	ui.selectedCustomerLabel.Position = UDim2.fromOffset(0, 42)
	ui.selectedCustomerLabel.Size = UDim2.new(1, 0, 0, 22)
	ui.selectedCustomerLabel.TextYAlignment = Enum.TextYAlignment.Center

	ui.customerList = create("ScrollingFrame", {
		Name = "CustomerList",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		Position = UDim2.fromOffset(0, 74),
		ScrollBarImageColor3 = THEME.gold,
		ScrollBarThickness = 5,
		Size = UDim2.new(1, 0, 1, -136),
		Parent = queueBody,
	})
	create("UIListLayout", {
		Name = "Layout",
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ui.customerList,
	})
	ui.emptyCustomerState = makeLabel(ui.customerList, "EmptyState", "No customers yet. The festival crowd will arrive shortly.", 15, THEME.subtext, Enum.Font.Gotham)
	ui.emptyCustomerState.Size = UDim2.new(1, -4, 0, 34)

	local serveButton = makeActionCard(queueBody, "ServeButton", THEME.green)
	serveButton.AnchorPoint = Vector2.new(0, 1)
	serveButton.Position = UDim2.new(0, 0, 1, 0)
	serveButton.Size = UDim2.new(1, 0, 0, 48)
	serveButton.MouseButton1Click:Connect(serveSelectedCustomer)
	ui.serveButton = serveButton
	ui.serveButtonLabel = makeLabel(serveButton, "ServeButtonLabel", "Serve Selected", 18, THEME.ink, Enum.Font.GothamBold)
	ui.serveButtonLabel.Position = UDim2.fromOffset(18, 12)
	ui.serveButtonLabel.Size = UDim2.new(1, -36, 0, 22)
	ui.serveButtonLabel.TextYAlignment = Enum.TextYAlignment.Center

	local recipesCard, recipesBody = makeCard(ui.dashboardContent, "RecipesCard", "Recipe Picks", "Start one of the three viral crowd favorites", THEME.rose)
	ui.cards.RecipesCard = recipesCard
	local recipeList = create("Frame", {
		Name = "RecipeList",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = recipesBody,
	})
	create("UIListLayout", {
		Name = "Layout",
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = recipeList,
	})

	for index, recipeId in ipairs(RecipeDefinitions.RECIPE_ORDER) do
		local accent = RECIPE_COLORS[recipeId] or THEME.sky
		local button = makeActionCard(recipeList, recipeId, accent)
		button.LayoutOrder = index
		button.Size = UDim2.new(1, 0, 0, 70)
		button.MouseButton1Click:Connect(function()
			StartRecipeRequest:FireServer({
				recipeId = recipeId,
			})
		end)

		local titleLabel = makeLabel(button, "Title", RecipeDefinitions.GetRecipe(recipeId).displayName, 19, THEME.text, Enum.Font.GothamBold)
		titleLabel.Position = UDim2.fromOffset(18, 12)
		titleLabel.Size = UDim2.new(1, -120, 0, 22)
		titleLabel.TextYAlignment = Enum.TextYAlignment.Center

		local detailLabel = makeLabel(button, "Detail", "", 13, THEME.subtext, Enum.Font.Gotham)
		detailLabel.Position = UDim2.fromOffset(18, 38)
		detailLabel.Size = UDim2.new(1, -120, 0, 16)
		detailLabel.TextYAlignment = Enum.TextYAlignment.Center

		local badge = makeBadge(button, "Badge", "Start", accent, THEME.ink)
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -16, 0, 16)

		ui.recipeButtons[recipeId] = {
			button = button,
			title = titleLabel,
			detail = detailLabel,
			badge = badge,
			stroke = button:FindFirstChildOfClass("UIStroke"),
		}
	end

	local upgradeCard, upgradeBody = makeCard(ui.dashboardContent, "UpgradeCard", "Truck Upgrades", "Spend Money on sharper service and stronger reach", THEME.mint)
	ui.cards.UpgradeCard = upgradeCard
	local upgradeList = create("Frame", {
		Name = "UpgradeList",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = upgradeBody,
	})
	create("UIListLayout", {
		Name = "Layout",
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = upgradeList,
	})

	for index, upgradeId in ipairs({ "FasterCooking", "BetterMarketing", "BiggerCounter" }) do
		local style = UPGRADE_STYLES[upgradeId]
		local button = makeActionCard(upgradeList, upgradeId, style.color)
		button.LayoutOrder = index
		button.Size = UDim2.new(1, 0, 0, 78)
		button.MouseButton1Click:Connect(function()
			UpgradeRequest:FireServer({
				upgradeId = upgradeId,
			})
		end)

		local titleLabel = makeLabel(button, "Title", "", 18, THEME.text, Enum.Font.GothamBold)
		titleLabel.Position = UDim2.fromOffset(18, 10)
		titleLabel.Size = UDim2.new(1, -150, 0, 20)
		titleLabel.TextYAlignment = Enum.TextYAlignment.Center

		local descriptionLabel = makeLabel(button, "Description", "", 13, THEME.subtext, Enum.Font.Gotham)
		descriptionLabel.Position = UDim2.fromOffset(18, 34)
		descriptionLabel.Size = UDim2.new(1, -150, 0, 16)
		descriptionLabel.TextYAlignment = Enum.TextYAlignment.Center

		local metaLabel = makeLabel(button, "Meta", "", 13, THEME.text, Enum.Font.GothamBold)
		metaLabel.Position = UDim2.fromOffset(18, 56)
		metaLabel.Size = UDim2.new(1, -150, 0, 14)
		metaLabel.TextYAlignment = Enum.TextYAlignment.Center

		local badge = makeBadge(button, "Badge", "Upgrade", style.color, THEME.ink)
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -16, 0, 24)

		ui.upgradeButtons[upgradeId] = {
			title = titleLabel,
			description = descriptionLabel,
			meta = metaLabel,
			badge = badge,
		}
	end

	local helpCard, helpBody = makeCard(ui.dashboardContent, "HelpCard", "Prep Flow", "The MVP loop at a glance", THEME.sky)
	ui.cards.HelpCard = helpCard
	ui.helpLabel = makeLabel(helpBody, "HelpLabel", "1. Pick a recipe.\n2. Use the matching station for the next highlighted step.\n3. Select a customer whose order matches your finished dish.\n4. Serve trend food for 2x rewards and influencer orders to trigger Viral Rush.", 15, THEME.subtext, Enum.Font.Gotham)
	ui.helpLabel.Size = UDim2.fromScale(1, 1)

	ui.notificationFrame = create("Frame", {
		Name = "NotificationFrame",
		BackgroundColor3 = NOTIFICATION_STYLES.Info.background,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -344, 1, -86),
		Size = UDim2.fromOffset(328, 62),
		Visible = false,
		Parent = root,
	})
	addCorner(ui.notificationFrame, 18)
	ui.notificationStroke = addStroke(ui.notificationFrame, NOTIFICATION_STYLES.Info.accent, 1, 0.18)

	ui.notificationAccent = create("Frame", {
		Name = "NotificationAccent",
		BackgroundColor3 = NOTIFICATION_STYLES.Info.accent,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(8, 62),
		Parent = ui.notificationFrame,
	})
	addCorner(ui.notificationAccent, 18)

	ui.notificationTitle = makeLabel(ui.notificationFrame, "NotificationTitle", "INFO", 13, THEME.text, Enum.Font.GothamBold)
	ui.notificationTitle.Position = UDim2.fromOffset(20, 11)
	ui.notificationTitle.Size = UDim2.new(1, -30, 0, 14)
	ui.notificationTitle.TextYAlignment = Enum.TextYAlignment.Center

	ui.notificationBody = makeLabel(ui.notificationFrame, "NotificationBody", "", 14, THEME.text, Enum.Font.Gotham)
	ui.notificationBody.Position = UDim2.fromOffset(20, 28)
	ui.notificationBody.Size = UDim2.new(1, -30, 0, 22)
	ui.notificationBody.TextYAlignment = Enum.TextYAlignment.Center

	layoutUi()

	ui.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutUi)

	refreshTrend()
	refreshTrendTimer()
	refreshViralRush()
	refreshDish()
	refreshCustomers()
	refreshStats()
	refreshUpgrades()
	refreshNotification()
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
		localNotify("Upgrade cards are ready in the dashboard.", "Info")
		return
	end

	local nextStep = getNextStep()
	if not currentDish.recipeId then
		localNotify("Select a recipe first.", "Warning")
		return
	end
	if not nextStep then
		localNotify("Dish is complete. Serve it at the counter.", "Info")
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
	refreshTrendTimer()
	refreshRecipeButtons()
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

	payload.receivedAt = workspace:GetServerTimeNow()
	payload.expiresAt = payload.receivedAt + (payload.timeoutSeconds or 0)
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

	localNotify(payload.message, payload.notificationType)

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
		refreshTrendTimer()
		refreshViralRush()
		refreshCustomerTimers()
		refreshNotification()
		task.wait(0.25)
	end
end)
