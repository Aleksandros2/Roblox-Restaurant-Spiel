local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.GameConstants)
local RecipeDefinitions = require(ReplicatedStorage.Shared.RecipeDefinitions)

local UpgradeService = {}

UpgradeService._remotes = nil
UpgradeService._playerDataService = nil
UpgradeService._initialized = false

local function getUpgradeCost(currentLevel)
	return GameConstants.UPGRADES.COST_BASE * (currentLevel + 1)
end

function UpgradeService:_notify(player, message, notificationType)
	self._remotes.NotificationEvent:FireClient(player, {
		message = message,
		notificationType = notificationType or "Info",
	})
end

function UpgradeService:GetUpgradeLevel(player, upgradeId)
	return self._playerDataService:GetUpgradeLevel(player, upgradeId)
end

function UpgradeService:HandleUpgradeRequest(player, payload)
	if typeof(payload) ~= "table" or typeof(payload.upgradeId) ~= "string" then
		self:_notify(player, "Invalid upgrade request.", "Error")
		return
	end

	local upgradeId = payload.upgradeId
	local upgradeDefinition = RecipeDefinitions.GetUpgrade(upgradeId)
	if not upgradeDefinition then
		self:_notify(player, "That upgrade does not exist.", "Error")
		return
	end

	local currentLevel = self._playerDataService:GetUpgradeLevel(player, upgradeId)
	if currentLevel >= GameConstants.UPGRADES.MAX_LEVEL then
		self:_notify(player, upgradeDefinition.displayName .. " is already max level.", "Warning")
		return
	end

	local cost = getUpgradeCost(currentLevel)
	if not self._playerDataService:SpendMoney(player, cost) then
		self:_notify(player, "You need $" .. cost .. " for " .. upgradeDefinition.displayName .. ".", "Warning")
		return
	end

	local newLevel = currentLevel + 1
	self._playerDataService:SetUpgradeLevel(player, upgradeId, newLevel)
	self:_notify(player, upgradeDefinition.displayName .. " upgraded to level " .. newLevel .. ".", "Success")
end

function UpgradeService:Init(remotes, playerDataService)
	if self._initialized then
		return
	end
	self._initialized = true
	self._remotes = remotes
	self._playerDataService = playerDataService

	remotes.UpgradeRequest.OnServerEvent:Connect(function(player, payload)
		self:HandleUpgradeRequest(player, payload)
	end)
end

return UpgradeService
