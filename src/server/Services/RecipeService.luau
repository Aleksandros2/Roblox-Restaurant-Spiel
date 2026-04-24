local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.GameConstants)
local RecipeDefinitions = require(ReplicatedStorage.Shared.RecipeDefinitions)

local RecipeService = {}

RecipeService._remotes = nil
RecipeService._playerDataService = nil
RecipeService._plotManager = nil
RecipeService._dishes = {}
RecipeService._initialized = false

local function copyArray(source)
	local copy = {}
	for index, value in ipairs(source) do
		copy[index] = value
	end
	return copy
end

function RecipeService:_notify(player, message, notificationType)
	self._remotes.NotificationEvent:FireClient(player, {
		message = message,
		notificationType = notificationType or "Info",
	})
end

function RecipeService:_buildDishPayload(dish)
	if not dish then
		return {
			recipeId = nil,
			recipeDisplayName = nil,
			completedSteps = {},
			requiredSteps = {},
			isComplete = false,
		}
	end

	return {
		recipeId = dish.recipeId,
		recipeDisplayName = RecipeDefinitions.GetRecipeDisplayName(dish.recipeId),
		completedSteps = copyArray(dish.completedSteps),
		requiredSteps = RecipeDefinitions.GetRecipeSteps(dish.recipeId),
		isComplete = dish.isComplete,
	}
end

function RecipeService:_fireDishState(player)
	self._remotes.DishStateChanged:FireClient(player, self:_buildDishPayload(self._dishes[player]))
end

function RecipeService:GetCurrentDish(player)
	return self._dishes[player]
end

function RecipeService:GetCompletedDish(player)
	local dish = self._dishes[player]
	if dish and dish.isComplete then
		return dish
	end

	return nil
end

function RecipeService:ClearDish(player)
	self._dishes[player] = nil
	self:_fireDishState(player)
end

function RecipeService:StartRecipe(player, recipeId)
	if not self._plotManager:GetPlayerPlot(player) then
		self:_notify(player, "No free plots available. Please join another server.", "Warning")
		return
	end

	if not RecipeDefinitions.IsValidRecipeId(recipeId) then
		self:_notify(player, "That recipe is not available.", "Error")
		return
	end

	self._dishes[player] = {
		recipeId = recipeId,
		completedSteps = {},
		isComplete = false,
		lastStepAt = 0,
	}

	self:_fireDishState(player)
	self:_notify(player, "Started " .. RecipeDefinitions.GetRecipeDisplayName(recipeId) .. ".", "Info")
end

function RecipeService:_getStationDelay(player)
	local level = self._playerDataService:GetUpgradeLevel(player, "FasterCooking")
	local delaySeconds = GameConstants.UPGRADES.BASE_STATION_DELAY_SECONDS
		- (level * GameConstants.UPGRADES.FASTER_COOKING_DELAY_REDUCTION_SECONDS)

	return math.max(GameConstants.UPGRADES.MIN_STATION_DELAY_SECONDS, delaySeconds)
end

function RecipeService:_isPlayerNearStation(player, stationType, stationPart)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local plot = self._plotManager:GetPlayerPlot(player)
	if not rootPart or not plot or not plot.RestaurantModel then
		return false
	end

	if stationPart ~= nil then
		if typeof(stationPart) ~= "Instance" then
			return false
		end

		if not stationPart:IsA("BasePart") or not stationPart:GetAttribute("StationType") then
			return false
		end

		if not self._plotManager:IsPlayerOwnerOfInstance(player, stationPart) then
			self:_notify(player, "This is not your restaurant.", "Warning")
			return false, "notOwner"
		end

		if stationPart:GetAttribute("StationType") ~= stationType then
			return false
		end

		return (rootPart.Position - stationPart.Position).Magnitude <= GameConstants.MAX_STATION_INTERACTION_DISTANCE
	end

	for _, descendant in ipairs(plot.RestaurantModel:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("StationType") == stationType then
			local distance = (rootPart.Position - descendant.Position).Magnitude
			if distance <= GameConstants.MAX_STATION_INTERACTION_DISTANCE then
				return true
			end
		end
	end

	return false
end

function RecipeService:AddRecipeStep(player, stepName, stationType, stationPart)
	local dish = self._dishes[player]
	if not dish then
		self:_notify(player, "Choose a recipe first.", "Warning")
		return
	end

	if dish.isComplete then
		self:_notify(player, "This dish is ready. Serve it at the counter.", "Info")
		return
	end

	local recipe = RecipeDefinitions.GetRecipe(dish.recipeId)
	if not recipe then
		self:_notify(player, "Recipe data is missing. Please choose a new recipe.", "Error")
		self:ClearDish(player)
		return
	end

	local now = workspace:GetServerTimeNow()
	local requiredDelay = self:_getStationDelay(player)
	if now - dish.lastStepAt < requiredDelay then
		self:_notify(player, "Give the station a moment.", "Warning")
		return
	end

	local expectedStep = recipe.steps[#dish.completedSteps + 1]
	if stepName ~= expectedStep then
		self:_notify(player, "Next step must be " .. expectedStep .. ".", "Warning")
		return
	end

	if not RecipeDefinitions.IsValidStationForStep(dish.recipeId, stepName, stationType) then
		local expectedStation = RecipeDefinitions.GetStepStationType(dish.recipeId, stepName)
		self:_notify(player, stepName .. " needs the " .. expectedStation .. " station.", "Warning")
		return
	end

	local isNearStation, reason = self:_isPlayerNearStation(player, stationType, stationPart)
	if not isNearStation then
		if reason ~= "notOwner" then
			self:_notify(player, "Move closer to the " .. stationType .. " station.", "Warning")
		end
		return
	end

	dish.lastStepAt = now
	table.insert(dish.completedSteps, stepName)
	dish.isComplete = #dish.completedSteps >= #recipe.steps

	self:_fireDishState(player)

	if dish.isComplete then
		self:_notify(player, RecipeDefinitions.GetRecipeDisplayName(dish.recipeId) .. " is ready to serve!", "Success")
	else
		self:_notify(player, stepName .. " added.", "Success")
	end
end

function RecipeService:Init(remotes, playerDataService, plotManager)
	if self._initialized then
		return
	end
	self._initialized = true
	self._remotes = remotes
	self._playerDataService = playerDataService
	self._plotManager = plotManager

	remotes.StartRecipeRequest.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" or typeof(payload.recipeId) ~= "string" then
			self:_notify(player, "Invalid recipe request.", "Error")
			return
		end

		self:StartRecipe(player, payload.recipeId)
	end)

	remotes.AddRecipeStepRequest.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" or typeof(payload.stepName) ~= "string" or typeof(payload.stationType) ~= "string" then
			self:_notify(player, "Invalid station request.", "Error")
			return
		end

		self:AddRecipeStep(player, payload.stepName, payload.stationType, payload.station)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._dishes[player] = nil
	end)
end

return RecipeService
