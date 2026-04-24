local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.GameConstants)

local ViralRushService = {}

ViralRushService._remotes = nil
ViralRushService._states = {}
ViralRushService._initialized = false

function ViralRushService:_getState(player)
	local state = self._states[player]
	if not state then
		state = {
			isActive = false,
			endsAt = nil,
			token = 0,
		}
		self._states[player] = state
	end

	return state
end

function ViralRushService:_buildPayload(player)
	local state = self:_getState(player)
	return {
		isActive = state.isActive,
		endsAt = state.endsAt,
	}
end

function ViralRushService:_send(player)
	self._remotes.ViralRushChanged:FireClient(player, self:_buildPayload(player))
end

function ViralRushService:SendStatus(player)
	self:_send(player)
end

function ViralRushService:IsActive(player)
	local state = self:_getState(player)
	if state.isActive and state.endsAt and workspace:GetServerTimeNow() >= state.endsAt then
		state.isActive = false
		state.endsAt = nil
	end

	return state.isActive
end

function ViralRushService:GetEndsAt(player)
	return self:_getState(player).endsAt
end

function ViralRushService:StartViralRush(player)
	local state = self:_getState(player)
	local now = workspace:GetServerTimeNow()
	state.isActive = true
	state.endsAt = now + GameConstants.VIRAL_RUSH_DURATION_SECONDS
	state.token += 1
	local token = state.token

	self:_send(player)

	task.delay(GameConstants.VIRAL_RUSH_DURATION_SECONDS, function()
		if player.Parent ~= Players then
			return
		end

		local activeState = self:_getState(player)
		if token ~= activeState.token then
			return
		end

		if activeState.endsAt and workspace:GetServerTimeNow() >= activeState.endsAt then
			activeState.isActive = false
			activeState.endsAt = nil
			self:_send(player)
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

	Players.PlayerRemoving:Connect(function(player)
		self._states[player] = nil
	end)
end

return ViralRushService
