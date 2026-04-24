local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.GameConstants)
local RecipeDefinitions = require(ReplicatedStorage.Shared.RecipeDefinitions)

local TrendService = {}

TrendService._random = Random.new()
TrendService._trendRecipeId = nil
TrendService._trendDisplayName = nil
TrendService._endsAt = 0
TrendService._remotes = nil
TrendService._initialized = false

function TrendService:_buildPayload()
	return {
		trendRecipeId = self._trendRecipeId,
		trendDisplayName = self._trendDisplayName,
		endsAt = self._endsAt,
	}
end

function TrendService:_chooseTrend()
	self._trendRecipeId = RecipeDefinitions.GetRandomRecipeId(self._random)
	self._trendDisplayName = RecipeDefinitions.GetRecipeDisplayName(self._trendRecipeId)
	self._endsAt = workspace:GetServerTimeNow() + GameConstants.TREND_DURATION_SECONDS

	self._remotes.TrendChanged:FireAllClients(self:_buildPayload())
end

function TrendService:SendCurrentTrend(player)
	if self._trendRecipeId then
		self._remotes.TrendChanged:FireClient(player, self:_buildPayload())
	end
end

function TrendService:GetCurrentTrendRecipeId()
	return self._trendRecipeId
end

function TrendService:Init(remotes)
	if self._initialized then
		return
	end
	self._initialized = true
	self._remotes = remotes

	self:_chooseTrend()

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			self:SendCurrentTrend(player)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:SendCurrentTrend(player)
	end

	task.spawn(function()
		while true do
			local waitTime = math.max(1, self._endsAt - workspace:GetServerTimeNow())
			task.wait(waitTime)
			self:_chooseTrend()
		end
	end)
end

return TrendService
