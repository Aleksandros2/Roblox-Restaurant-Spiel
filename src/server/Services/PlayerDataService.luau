local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RecipeDefinitions = require(ReplicatedStorage.Shared.RecipeDefinitions)

local PlayerDataService = {}

local playerData = {}

local function makeIntValue(parent, name, value)
	local intValue = parent:FindFirstChild(name)
	if intValue and not intValue:IsA("IntValue") then
		warn(name .. " leaderstat existed but was not an IntValue. Recreating it.")
		intValue:Destroy()
		intValue = nil
	end

	if not intValue then
		intValue = Instance.new("IntValue")
		intValue.Name = name
		intValue.Parent = parent
	end

	intValue.Value = value
	return intValue
end

function PlayerDataService:SetupPlayer(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	makeIntValue(leaderstats, "Money", 0)
	makeIntValue(leaderstats, "ViralPoints", 0)

	local upgrades = {}
	for upgradeId in pairs(RecipeDefinitions.UPGRADES) do
		upgrades[upgradeId] = 0
	end

	playerData[player] = {
		upgrades = upgrades,
	}
end

function PlayerDataService:CleanupPlayer(player)
	playerData[player] = nil
end

function PlayerDataService:Init()
	Players.PlayerAdded:Connect(function(player)
		self:SetupPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:CleanupPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:SetupPlayer(player)
	end
end

function PlayerDataService:GetLeaderValue(player, valueName)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	return leaderstats:FindFirstChild(valueName)
end

function PlayerDataService:AddCurrency(player, moneyAmount, viralPointsAmount)
	local money = self:GetLeaderValue(player, "Money")
	local viralPoints = self:GetLeaderValue(player, "ViralPoints")
	if money then
		money.Value += moneyAmount
	end
	if viralPoints then
		viralPoints.Value += viralPointsAmount
	end
end

function PlayerDataService:CanAfford(player, cost)
	local money = self:GetLeaderValue(player, "Money")
	return money ~= nil and money.Value >= cost
end

function PlayerDataService:SpendMoney(player, cost)
	local money = self:GetLeaderValue(player, "Money")
	if not money or money.Value < cost then
		return false
	end

	money.Value -= cost
	return true
end

function PlayerDataService:GetUpgradeLevel(player, upgradeId)
	local data = playerData[player]
	if not data then
		return 0
	end

	return data.upgrades[upgradeId] or 0
end

function PlayerDataService:SetUpgradeLevel(player, upgradeId, level)
	local data = playerData[player]
	if not data then
		return
	end

	data.upgrades[upgradeId] = level
end

return PlayerDataService
