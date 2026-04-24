local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.GameConstants)

local ViralRushService = {}

ViralRushService._remotes = nil
ViralRushService._isActive = false
ViralRushService._endsAt = nil
ViralRushService._token = 0
ViralRushService._initialized = false

function ViralRushService:_buildPayload()
	return {
		isActive = self._isActive,
		endsAt = self._endsAt,
	}
end

function ViralRushService:_broadcast()
	self._remotes.ViralRushChanged:FireAllClients(self:_buildPayload())
end

function ViralRushService:SendStatus(player)
	self._remotes.ViralRushChanged:FireClient(player, self:_buildPayload())
end

function ViralRushService:IsActive()
	if self._isActive and self._endsAt and workspace:GetServerTimeNow() >= self._endsAt then
		self._isActive = false
		self._endsAt = nil
	end

	return self._isActive
end

function ViralRushService:GetEndsAt()
	return self._endsAt
end

function ViralRushService:StartViralRush()
	local now = workspace:GetServerTimeNow()
	self._isActive = true
	self._endsAt = now + GameConstants.VIRAL_RUSH_DURATION_SECONDS
	self._token += 1
	local token = self._token

	self:_broadcast()

	task.delay(GameConstants.VIRAL_RUSH_DURATION_SECONDS, function()
		if token ~= self._token then
			return
		end

		if self._endsAt and workspace:GetServerTimeNow() >= self._endsAt then
			self._isActive = false
			self._endsAt = nil
			self:_broadcast()
		end
	end)
end

function ViralRushService:Init(remotes)
	if self._initialized then
		return
	end
	self._initialized = true
	self._remotes = remotes

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			self:SendStatus(player)
		end)
	end)
end

return ViralRushService
