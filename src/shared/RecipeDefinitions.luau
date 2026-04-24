local RecipeDefinitions = {}

RecipeDefinitions.RECIPES = {
	SpicyRamen = {
		id = "SpicyRamen",
		displayName = "Spicy Ramen",
		steps = {
			"Bowl",
			"Noodles",
			"Broth",
			"Chili",
			"Topping",
		},
		stationTypes = {
			Bowl = "Ingredient",
			Noodles = "Ingredient",
			Broth = "Cooking",
			Chili = "Cooking",
			Topping = "Ingredient",
		},
	},

	BubbleTea = {
		id = "BubbleTea",
		displayName = "Bubble Tea",
		steps = {
			"Cup",
			"Tea",
			"Milk",
			"Boba",
			"Ice",
		},
		stationTypes = {
			Cup = "Drink",
			Tea = "Drink",
			Milk = "Drink",
			Boba = "Drink",
			Ice = "Drink",
		},
	},

	KoreanCornDog = {
		id = "KoreanCornDog",
		displayName = "Korean Corn Dog",
		steps = {
			"Stick",
			"Sausage",
			"Batter",
			"Fry",
			"Sauce",
		},
		stationTypes = {
			Stick = "Ingredient",
			Sausage = "Ingredient",
			Batter = "Cooking",
			Fry = "Cooking",
			Sauce = "Cooking",
		},
	},
}

RecipeDefinitions.RECIPE_ORDER = {
	"SpicyRamen",
	"BubbleTea",
	"KoreanCornDog",
}

RecipeDefinitions.UPGRADES = {
	FasterCooking = {
		id = "FasterCooking",
		displayName = "Faster Cooking",
	},
	BetterMarketing = {
		id = "BetterMarketing",
		displayName = "Better Marketing",
	},
	BiggerCounter = {
		id = "BiggerCounter",
		displayName = "Bigger Counter",
	},
}

local function copyArray(source)
	local copy = {}
	for index, value in ipairs(source) do
		copy[index] = value
	end
	return copy
end

function RecipeDefinitions.GetRecipe(recipeId)
	return RecipeDefinitions.RECIPES[recipeId]
end

function RecipeDefinitions.IsValidRecipeId(recipeId)
	return RecipeDefinitions.RECIPES[recipeId] ~= nil
end

function RecipeDefinitions.GetRecipeDisplayName(recipeId)
	local recipe = RecipeDefinitions.GetRecipe(recipeId)
	return if recipe then recipe.displayName else "Unknown"
end

function RecipeDefinitions.GetRecipeSteps(recipeId)
	local recipe = RecipeDefinitions.GetRecipe(recipeId)
	if not recipe then
		return {}
	end

	return copyArray(recipe.steps)
end

function RecipeDefinitions.GetStepStationType(recipeId, stepName)
	local recipe = RecipeDefinitions.GetRecipe(recipeId)
	if not recipe then
		return nil
	end

	return recipe.stationTypes[stepName]
end

function RecipeDefinitions.IsValidStationForStep(recipeId, stepName, stationType)
	return RecipeDefinitions.GetStepStationType(recipeId, stepName) == stationType
end

function RecipeDefinitions.GetRandomRecipeId(randomGenerator)
	local recipeIds = RecipeDefinitions.RECIPE_ORDER
	return recipeIds[randomGenerator:NextInteger(1, #recipeIds)]
end

function RecipeDefinitions.GetUpgrade(upgradeId)
	return RecipeDefinitions.UPGRADES[upgradeId]
end

function RecipeDefinitions.IsValidUpgradeId(upgradeId)
	return RecipeDefinitions.UPGRADES[upgradeId] ~= nil
end

return RecipeDefinitions
