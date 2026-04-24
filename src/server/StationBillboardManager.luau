local StationBillboardManager = {}

local MANAGED_BILLBOARD_NAMES = {
	OrderBillboard = true,
	QueueLabel = true,
	StationLabel = true,
}

local DEFAULT_TEXT_COLOR = Color3.fromRGB(31, 29, 35)
local DEFAULT_PANEL_COLOR = Color3.fromRGB(255, 248, 228)

local function applyProperties(instance, properties)
	for property, value in pairs(properties or {}) do
		instance[property] = value
	end
end

local function ensureChild(parent, className, name)
	local child = parent:FindFirstChild(name)
	if child and not child:IsA(className) then
		child:Destroy()
		child = nil
	end

	if not child then
		child = Instance.new(className)
		child.Name = name
		child.Parent = parent
	end

	return child
end

local function pruneDuplicateBillboards(parent, keptName)
	local kept = nil
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("BillboardGui") and child.Name == keptName then
			if kept then
				child:Destroy()
			else
				kept = child
			end
		end
	end

	return kept
end

local function ensureBillboard(parent, name, options)
	options = options or {}

	local billboard = pruneDuplicateBillboards(parent, name)
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = name
		billboard.Parent = parent
	end

	if parent:IsA("BasePart") or parent:IsA("Attachment") then
		billboard.Adornee = parent
	elseif options.adornee then
		billboard.Adornee = options.adornee
	end

	applyProperties(billboard, {
		AlwaysOnTop = options.alwaysOnTop ~= false,
		ClipsDescendants = true,
		LightInfluence = 0,
		MaxDistance = options.maxDistance or 70,
		Size = options.size or UDim2.fromOffset(190, 52),
		StudsOffset = options.studsOffset or Vector3.new(0, 3.2, 0),
		StudsOffsetWorldSpace = options.studsOffsetWorldSpace or Vector3.zero,
	})

	return billboard
end

local function ensureCard(billboard, backgroundColor, strokeColor, cornerRadius)
	for _, child in ipairs(billboard:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "Card" then
			child:Destroy()
		end
	end

	local card = ensureChild(billboard, "Frame", "Card")
	applyProperties(card, {
		BackgroundColor3 = backgroundColor or DEFAULT_PANEL_COLOR,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	})

	local corner = ensureChild(card, "UICorner", "Corner")
	corner.CornerRadius = UDim.new(0, cornerRadius or 10)

	local stroke = ensureChild(card, "UIStroke", "Stroke")
	applyProperties(stroke, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = strokeColor or Color3.fromRGB(255, 255, 255),
		Thickness = 1,
		Transparency = 0.35,
	})

	local padding = ensureChild(card, "UIPadding", "Padding")
	applyProperties(padding, {
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 6),
	})

	return card
end

local function ensureTextLabel(parent, name, text, properties)
	local label = ensureChild(parent, "TextLabel", name)
	applyProperties(label, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Size = UDim2.fromScale(1, 1),
		Text = text or "",
		TextColor3 = DEFAULT_TEXT_COLOR,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	applyProperties(label, properties)

	local constraint = ensureChild(label, "UITextSizeConstraint", "TextSizeConstraint")
	applyProperties(constraint, {
		MaxTextSize = properties and properties.MaxTextSize or 24,
		MinTextSize = properties and properties.MinTextSize or 10,
	})

	return label
end

function StationBillboardManager.ClearManagedBillboards(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("BillboardGui") and MANAGED_BILLBOARD_NAMES[child.Name] then
			child:Destroy()
		end
	end
end

function StationBillboardManager.EnsureStationSign(part, config)
	config = config or {}
	local billboard = ensureBillboard(part, "StationLabel", {
		maxDistance = config.maxDistance or 70,
		size = config.size or UDim2.fromOffset(176, if config.subtitle then 56 else 44),
		studsOffset = config.studsOffset or Vector3.new(0, 3.85, 0),
	})
	local card = ensureCard(billboard, config.backgroundColor, nil, 10)

	local title = ensureTextLabel(card, "Title", config.title or part.Name, {
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromScale(0, 0),
		Size = if config.subtitle then UDim2.new(1, 0, 0.58, 0) else UDim2.fromScale(1, 1),
		TextColor3 = config.textColor or DEFAULT_TEXT_COLOR,
		MaxTextSize = 22,
		MinTextSize = 11,
	})

	local subtitle = ensureTextLabel(card, "Subtitle", config.subtitle or "", {
		Font = Enum.Font.GothamMedium,
		Position = UDim2.new(0, 0, 0.58, 0),
		Size = UDim2.new(1, 0, 0.42, 0),
		TextColor3 = config.subtitleColor or Color3.fromRGB(62, 57, 62),
		MaxTextSize = 14,
		MinTextSize = 9,
	})
	subtitle.Visible = config.subtitle ~= nil and config.subtitle ~= ""

	return billboard, title, subtitle
end

function StationBillboardManager.EnsureQueueSign(part, text)
	local billboard = ensureBillboard(part, "QueueLabel", {
		maxDistance = 55,
		size = UDim2.fromOffset(148, 34),
		studsOffset = Vector3.new(0, 1.35, 0),
	})
	local card = ensureCard(billboard, Color3.fromRGB(255, 251, 235), nil, 8)

	ensureTextLabel(card, "Title", text or "Customer Queue", {
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(42, 36, 31),
		MaxTextSize = 16,
		MinTextSize = 9,
	})

	return billboard
end

function StationBillboardManager.EnsureOrderCard(part, config)
	config = config or {}
	local billboard = ensureBillboard(part, "OrderBillboard", {
		maxDistance = config.maxDistance or 62,
		size = config.size or UDim2.fromOffset(168, if config.badge then 58 else 46),
		studsOffset = config.studsOffset or Vector3.new(0, 2.85, 0),
		studsOffsetWorldSpace = config.studsOffsetWorldSpace or Vector3.zero,
	})
	local card = ensureCard(billboard, config.backgroundColor or DEFAULT_PANEL_COLOR, nil, 9)

	local badge = ensureTextLabel(card, "Badge", config.badge or "ORDER", {
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.new(1, 0, 0.34, 0),
		TextColor3 = Color3.fromRGB(113, 82, 44),
		MaxTextSize = 11,
		MinTextSize = 8,
	})
	badge.Visible = config.badge ~= nil and config.badge ~= ""

	ensureTextLabel(card, "Title", config.title or "Order", {
		Font = Enum.Font.GothamBold,
		Position = if badge.Visible then UDim2.new(0, 0, 0.32, 0) else UDim2.fromScale(0, 0),
		Size = if badge.Visible then UDim2.new(1, 0, 0.68, 0) else UDim2.fromScale(1, 1),
		TextColor3 = config.textColor or DEFAULT_TEXT_COLOR,
		MaxTextSize = 19,
		MinTextSize = 10,
	})

	return billboard
end

return StationBillboardManager
