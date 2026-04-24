local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local PlotConfig = require(script.Parent:WaitForChild("PlotConfig"))
local StationBillboardManager = require(script.Parent.Parent:WaitForChild("StationBillboardManager"))

local PlotManager = {}

PlotManager._initialized = false
PlotManager._remotes = nil
PlotManager._restaurantTemplate = nil
PlotManager._plots = {}
PlotManager._plotsByPlayer = {}
PlotManager._characterConnections = {}

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
	for property, value in pairs(properties or {}) do
		part[property] = value
	end
	part.Parent = parent
	return part
end

local function applyPlotAttributes(instance, plotId, ownerUserId)
	instance:SetAttribute("PlotId", plotId)
	instance:SetAttribute("OwnerUserId", ownerUserId)

	for _, descendant in ipairs(instance:GetDescendants()) do
		descendant:SetAttribute("PlotId", plotId)
		descendant:SetAttribute("OwnerUserId", ownerUserId)
	end
end

local function notify(remotes, player, message, notificationType)
	if not remotes then
		return
	end

	remotes.NotificationEvent:FireClient(player, {
		message = message,
		notificationType = notificationType or "Info",
	})
end

function PlotManager:_ensureTemplatesFolder()
	local templates = ensureFolder(ServerStorage, "Templates")
	local template = templates:FindFirstChild("PlotTemplate")
	if template and not template:IsA("Model") then
		template:Destroy()
		template = nil
	end

	if not template then
		template = Instance.new("Model")
		template.Name = "PlotTemplate"
		template.Parent = templates
	else
		template:ClearAllChildren()
	end

	local pivot = makePart(template, "PlotPivot", {
		CanCollide = false,
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CFrame = CFrame.new(0, 0, 0),
	})
	template.PrimaryPart = pivot

	makePart(template, "GreenArea", {
		Color = Color3.fromRGB(92, 151, 82),
		Material = Enum.Material.Grass,
		Size = PlotConfig.PLOT_SIZE,
		CFrame = CFrame.new(0, -0.16, -2),
	})

	makePart(template, "BuildArea", {
		CanCollide = false,
		Color = Color3.fromRGB(210, 234, 186),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(62, 0.08, 46),
		CFrame = CFrame.new(0, 0.03, -6),
		Transparency = 0.82,
	})

	makePart(template, "UpgradeArea", {
		CanCollide = false,
		Color = Color3.fromRGB(189, 171, 255),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(18, 0.09, 14),
		CFrame = CFrame.new(25, 0.05, 17),
		Transparency = 0.62,
	})

	makePart(template, "QueueArea", {
		CanCollide = false,
		Color = Color3.fromRGB(255, 232, 166),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(24, 0.09, 14),
		CFrame = CFrame.new(0, 0.06, -24),
		Transparency = 0.55,
	})

	makePart(template, "OwnerSpawn", {
		CanCollide = false,
		Color = Color3.fromRGB(92, 206, 137),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(5, 0.18, 5),
		CFrame = CFrame.new(0, 0.12, -15),
		Transparency = 0.15,
	})

	makePart(template, "PlotBorderBack", {
		Color = Color3.fromRGB(67, 119, 66),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(86, 0.34, 0.6),
		CFrame = CFrame.new(0, 0.05, 35),
	})
	makePart(template, "PlotBorderFront", {
		Color = Color3.fromRGB(67, 119, 66),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(86, 0.34, 0.6),
		CFrame = CFrame.new(0, 0.05, -39),
	})
	makePart(template, "PlotBorderLeft", {
		Color = Color3.fromRGB(67, 119, 66),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(0.6, 0.34, 74),
		CFrame = CFrame.new(-43, 0.05, -2),
	})
	makePart(template, "PlotBorderRight", {
		Color = Color3.fromRGB(67, 119, 66),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(0.6, 0.34, 74),
		CFrame = CFrame.new(43, 0.05, -2),
	})

	makePart(template, "OwnerSignAnchor", {
		CanCollide = false,
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CFrame = CFrame.new(0, 3.1, -39),
	})

	return templates
end

function PlotManager:_ensureSpectatorArea()
	local existing = Workspace:FindFirstChild("SpectatorArea")
	if existing and not existing:IsA("Model") then
		existing:Destroy()
		existing = nil
	end

	local model = existing or Instance.new("Model")
	model.Name = "SpectatorArea"
	model.Parent = Workspace

	local pad = model:FindFirstChild("Pad")
	if not pad or not pad:IsA("Part") then
		if pad then
			pad:Destroy()
		end
		pad = makePart(model, "Pad", {})
	end
	pad.Anchored = true
	pad.Color = Color3.fromRGB(82, 91, 110)
	pad.Material = Enum.Material.Slate
	pad.Size = Vector3.new(30, 0.4, 20)
	pad.CFrame = CFrame.new(0, 0.2, 145)

	StationBillboardManager.EnsureStationSign(pad, {
		backgroundColor = Color3.fromRGB(231, 236, 246),
		maxDistance = 80,
		size = UDim2.fromOffset(210, 48),
		studsOffset = Vector3.new(0, 3.2, 0),
		subtitle = "Waiting Area",
		title = "No Free Plot",
	})
end

function PlotManager:_buildPlots()
	self:_ensureTemplatesFolder()
	self:_ensureSpectatorArea()

	local templates = ServerStorage:WaitForChild("Templates")
	local plotTemplate = templates:WaitForChild("PlotTemplate")
	local plotsFolder = ensureFolder(Workspace, "Plots")
	plotsFolder:ClearAllChildren()
	table.clear(self._plots)
	table.clear(self._plotsByPlayer)

	for _, definition in ipairs(PlotConfig.PLOTS) do
		local plotModel = plotTemplate:Clone()
		plotModel.Name = "Plot" .. definition.id
		plotModel.Parent = plotsFolder
		plotModel:PivotTo(definition.cframe)
		plotModel:SetAttribute("PlotId", definition.id)
		plotModel:SetAttribute("IsOccupied", false)

		local signAnchor = plotModel:FindFirstChild("OwnerSignAnchor", true)
		if signAnchor and signAnchor:IsA("BasePart") then
			StationBillboardManager.EnsureStationSign(signAnchor, {
				backgroundColor = Color3.fromRGB(236, 247, 222),
				maxDistance = 80,
				size = UDim2.fromOffset(220, 56),
				studsOffset = Vector3.new(0, 1.2, 0),
				subtitle = "Plot " .. definition.id,
				title = "Empty Plot",
			})
		end

		self._plots[definition.id] = {
			PlotId = definition.id,
			PlotModel = plotModel,
			OwnerUserId = nil,
			OwnerPlayer = nil,
			IsOccupied = false,
			RestaurantModel = nil,
			BaseCFrame = definition.cframe,
			SpawnCFrame = definition.cframe * PlotConfig.PLAYER_SPAWN_OFFSET,
			RestaurantCFrame = definition.cframe * PlotConfig.RESTAURANT_PIVOT_OFFSET,
			BuildArea = plotModel:FindFirstChild("BuildArea", true),
		}
	end
end

function PlotManager:_getFirstFreePlot()
	for _, plot in ipairs(self._plots) do
		if plot and not plot.IsOccupied then
			return plot
		end
	end

	return nil
end

function PlotManager:_setOwnerSign(plot, title, subtitle)
	local signAnchor = plot.PlotModel and plot.PlotModel:FindFirstChild("OwnerSignAnchor", true)
	if not signAnchor or not signAnchor:IsA("BasePart") then
		return
	end

	StationBillboardManager.EnsureStationSign(signAnchor, {
		backgroundColor = plot.IsOccupied and Color3.fromRGB(218, 246, 208) or Color3.fromRGB(236, 247, 222),
		maxDistance = 80,
		size = UDim2.fromOffset(235, 58),
		studsOffset = Vector3.new(0, 1.2, 0),
		subtitle = subtitle,
		title = title,
	})
end

function PlotManager:_cloneRestaurantForPlot(plot)
	if plot.RestaurantModel then
		plot.RestaurantModel:Destroy()
		plot.RestaurantModel = nil
	end

	local restaurant = self._restaurantTemplate:Clone()
	restaurant.Name = "Restaurant"
	restaurant.Parent = plot.PlotModel
	restaurant:PivotTo(plot.RestaurantCFrame)
	applyPlotAttributes(restaurant, plot.PlotId, plot.OwnerUserId)
	plot.RestaurantModel = restaurant

	return restaurant
end

function PlotManager:_teleportCharacterToCFrame(character, cframe)
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
	if root then
		root.CFrame = cframe
	end
end

function PlotManager:TeleportPlayerToPlot(player)
	local plot = self:GetPlayerPlot(player)
	local character = player.Character
	if not character then
		return
	end

	if plot then
		self:_teleportCharacterToCFrame(character, plot.SpawnCFrame)
	else
		self:_teleportCharacterToCFrame(character, PlotConfig.SPECTATOR_CFRAME)
	end
end

function PlotManager:AssignPlot(player)
	if self._plotsByPlayer[player] then
		return self._plotsByPlayer[player]
	end

	local plot = self:_getFirstFreePlot()
	if not plot then
		if self._characterConnections[player] then
			self._characterConnections[player]:Disconnect()
		end
		self._characterConnections[player] = player.CharacterAdded:Connect(function(character)
			task.defer(function()
				self:_teleportCharacterToCFrame(character, PlotConfig.SPECTATOR_CFRAME)
			end)
		end)

		task.delay(2, function()
			if player.Parent == Players then
				notify(self._remotes, player, "No free plots available. Please join another server.", "Warning")
				self:TeleportPlayerToPlot(player)
			end
		end)
		return nil
	end

	plot.OwnerUserId = player.UserId
	plot.OwnerPlayer = player
	plot.IsOccupied = true
	plot.PlotModel:SetAttribute("IsOccupied", true)
	plot.PlotModel:SetAttribute("OwnerUserId", player.UserId)
	plot.PlotModel:SetAttribute("OwnerName", player.Name)
	applyPlotAttributes(plot.PlotModel, plot.PlotId, player.UserId)
	self._plotsByPlayer[player] = plot

	self:_cloneRestaurantForPlot(plot)
	self:_setOwnerSign(plot, player.Name .. "'s Restaurant", "Plot " .. plot.PlotId)

	if self._characterConnections[player] then
		self._characterConnections[player]:Disconnect()
	end
	self._characterConnections[player] = player.CharacterAdded:Connect(function(character)
		task.defer(function()
			self:_teleportCharacterToCFrame(character, plot.SpawnCFrame)
		end)
	end)

	task.defer(function()
		self:TeleportPlayerToPlot(player)
		notify(self._remotes, player, "Welcome to Plot " .. plot.PlotId .. ".", "Success")
	end)

	return plot
end

function PlotManager:ReleasePlot(player)
	local plot = self._plotsByPlayer[player]
	if not plot then
		if self._characterConnections[player] then
			self._characterConnections[player]:Disconnect()
			self._characterConnections[player] = nil
		end
		return
	end

	if self._characterConnections[player] then
		self._characterConnections[player]:Disconnect()
		self._characterConnections[player] = nil
	end

	if plot.RestaurantModel then
		plot.RestaurantModel:Destroy()
	end

	plot.OwnerUserId = nil
	plot.OwnerPlayer = nil
	plot.IsOccupied = false
	plot.RestaurantModel = nil
	plot.PlotModel:SetAttribute("IsOccupied", false)
	plot.PlotModel:SetAttribute("OwnerUserId", nil)
	plot.PlotModel:SetAttribute("OwnerName", nil)
	applyPlotAttributes(plot.PlotModel, plot.PlotId, nil)
	self:_setOwnerSign(plot, "Empty Plot", "Plot " .. plot.PlotId)

	self._plotsByPlayer[player] = nil
end

function PlotManager:GetPlayerPlot(player)
	return self._plotsByPlayer[player]
end

function PlotManager:GetPlotById(plotId)
	return self._plots[plotId]
end

function PlotManager:IsPlayerOwnerOfInstance(player, instance)
	if not instance then
		return false
	end

	local playerPlot = self:GetPlayerPlot(player)
	if not playerPlot then
		return false
	end

	local current = instance
	while current and current ~= Workspace do
		local plotId = current:GetAttribute("PlotId")
		local ownerUserId = current:GetAttribute("OwnerUserId")
		if plotId then
			return plotId == playerPlot.PlotId and ownerUserId == player.UserId
		end
		current = current.Parent
	end

	return false
end

function PlotManager:Init(remotes, restaurantTemplate)
	if self._initialized then
		return
	end
	self._initialized = true
	self._remotes = remotes
	self._restaurantTemplate = restaurantTemplate

	self:_buildPlots()

	Players.PlayerAdded:Connect(function(player)
		self:AssignPlot(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:ReleasePlot(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:AssignPlot(player)
	end
end

return PlotManager
