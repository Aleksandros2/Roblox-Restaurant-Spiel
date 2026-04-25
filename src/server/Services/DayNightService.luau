local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local DayNightService = {}

DayNightService._initialized = false
DayNightService._remotes = nil
DayNightService._day = 1
DayNightService._minuteOfDay = (6 * 60) + 35
DayNightService._broadcastAccumulator = 0

local MINUTES_PER_DAY = 24 * 60
local WORK_START_MINUTE = (7 * 60) + 30
local WORK_END_MINUTE = 21 * 60
local GAME_MINUTES_PER_REAL_SECOND = 0.5
local NIGHT_SPEED_MULTIPLIER = 1.5

local function isNight(minuteOfDay)
	return minuteOfDay >= WORK_END_MINUTE or minuteOfDay < WORK_START_MINUTE
end

local function getDisplayText(day, minuteOfDay)
	local roundedMinute = math.floor(minuteOfDay) % MINUTES_PER_DAY
	local hour = math.floor(roundedMinute / 60)
	local minute = roundedMinute % 60
	return string.format("Day %d - %02d:%02d", day, hour, minute)
end

function DayNightService:_getPayload()
	local minuteOfDay = math.floor(self._minuteOfDay) % MINUTES_PER_DAY
	return {
		day = self._day,
		minuteOfDay = minuteOfDay,
		isNight = isNight(minuteOfDay),
		isWorkingHours = not isNight(minuteOfDay),
		displayText = getDisplayText(self._day, minuteOfDay),
		workStartMinute = WORK_START_MINUTE,
		workEndMinute = WORK_END_MINUTE,
	}
end

function DayNightService:_applyLighting()
	local minuteOfDay = math.floor(self._minuteOfDay) % MINUTES_PER_DAY
	Lighting.ClockTime = minuteOfDay / 60
	Lighting:SetAttribute("GameDay", self._day)
	Lighting:SetAttribute("GameMinuteOfDay", minuteOfDay)
	Lighting:SetAttribute("IsWorkingHours", not isNight(minuteOfDay))

	local deepNight = minuteOfDay >= 22 * 60 or minuteOfDay < 5 * 60
	local transition = isNight(minuteOfDay) and not deepNight

	if deepNight then
		Lighting.Brightness = 1.25
		Lighting.Ambient = Color3.fromRGB(52, 58, 78)
		Lighting.OutdoorAmbient = Color3.fromRGB(72, 82, 106)
		Lighting.FogColor = Color3.fromRGB(168, 184, 202)
	elseif transition then
		Lighting.Brightness = 1.65
		Lighting.Ambient = Color3.fromRGB(91, 88, 108)
		Lighting.OutdoorAmbient = Color3.fromRGB(112, 112, 132)
		Lighting.FogColor = Color3.fromRGB(218, 210, 202)
	else
		Lighting.Brightness = 2
		Lighting.Ambient = Color3.fromRGB(105, 112, 120)
		Lighting.OutdoorAmbient = Color3.fromRGB(138, 146, 148)
		Lighting.FogColor = Color3.fromRGB(232, 232, 222)
	end

	local bloom = Lighting:FindFirstChild("FestivalBloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Intensity = deepNight and 0.04 or 0.07
		bloom.Threshold = deepNight and 2 or 1.85
	end
end

function DayNightService:_broadcast()
	if self._remotes and self._remotes.DayNightChanged then
		self._remotes.DayNightChanged:FireAllClients(self:_getPayload())
	end
end

function DayNightService:_advance(deltaSeconds)
	local speed = GAME_MINUTES_PER_REAL_SECOND
	if isNight(self._minuteOfDay) then
		speed *= NIGHT_SPEED_MULTIPLIER
	end

	self._minuteOfDay += deltaSeconds * speed

	while self._minuteOfDay >= MINUTES_PER_DAY do
		self._minuteOfDay -= MINUTES_PER_DAY
		self._day += 1
	end
end

function DayNightService:Init(remotes)
	if self._initialized then
		return
	end
	self._initialized = true
	self._remotes = remotes

	self:_applyLighting()
	self:_broadcast()

	local lastClock = os.clock()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local deltaSeconds = math.clamp(now - lastClock, 0, 1)
		lastClock = now

		self:_advance(deltaSeconds)
		self._broadcastAccumulator += deltaSeconds

		if self._broadcastAccumulator >= 1 then
			self._broadcastAccumulator = 0
			self:_applyLighting()
			self:_broadcast()
		end
	end)
end

return DayNightService
