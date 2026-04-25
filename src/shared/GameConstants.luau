local GameConstants = {
	REMOTE_NAMES = {
		"TrendChanged",
		"DishStateChanged",
		"CustomerSpawned",
		"CustomerRemoved",
		"ServeRequest",
		"StartRecipeRequest",
		"AddRecipeStepRequest",
		"UpgradeRequest",
		"NotificationEvent",
		"ViralRushChanged",
		"DayNightChanged",
	},

	TREND_DURATION_SECONDS = 300,

	CUSTOMER_SPAWN_INTERVAL_NORMAL = 10,
	CUSTOMER_SPAWN_INTERVAL_VIRAL_RUSH = 5,
	CUSTOMER_TIMEOUT_SECONDS = 45,
	MAX_ACTIVE_CUSTOMERS = 3,

	INFLUENCER_CHANCE = 0.10,
	VIRAL_RUSH_DURATION_SECONDS = 60,

	BASE_REWARDS = {
		Money = 20,
		ViralPoints = 5,
	},

	MULTIPLIERS = {
		Trend = 2,
		Influencer = 3,
	},

	UPGRADES = {
		MAX_LEVEL = 5,
		COST_BASE = 100,
		BETTER_MARKETING_VIRAL_BONUS_PER_LEVEL = 1,
		BIGGER_COUNTER_INTERVAL_REDUCTION_SECONDS = 0.5,
		MIN_CUSTOMER_SPAWN_INTERVAL_SECONDS = 3,
		BASE_STATION_DELAY_SECONDS = 0.75,
		FASTER_COOKING_DELAY_REDUCTION_SECONDS = 0.12,
		MIN_STATION_DELAY_SECONDS = 0.15,
	},

	MAX_STATION_INTERACTION_DISTANCE = 18,
}

return GameConstants
