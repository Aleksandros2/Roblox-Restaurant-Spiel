local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local SprintConfig = {
	ActionName = "RestaurantTycoonSprint",
	WalkSpeed = 16,
	SprintSpeed = 24,
}

local humanoid = nil
local sprinting = false

local function getTargetSpeed()
	return if sprinting then SprintConfig.SprintSpeed else SprintConfig.WalkSpeed
end

local function applySpeed()
	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = getTargetSpeed()
	end
end

local function setSprinting(enabled)
	sprinting = enabled
	applySpeed()
end

local function bindCharacter(character)
	humanoid = character:WaitForChild("Humanoid", 10)
	sprinting = false
	applySpeed()
end

local function handleSprintAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		setSprinting(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		setSprinting(false)
	end

	return Enum.ContextActionResult.Pass
end

-- Keyboard users hold Shift; mobile players get the same action as a touch button.
ContextActionService:BindAction(
	SprintConfig.ActionName,
	handleSprintAction,
	true,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift
)
ContextActionService:SetTitle(SprintConfig.ActionName, "Sprint")
ContextActionService:SetPosition(SprintConfig.ActionName, UDim2.new(1, -92, 1, -176))

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	task.defer(bindCharacter, player.Character)
end
