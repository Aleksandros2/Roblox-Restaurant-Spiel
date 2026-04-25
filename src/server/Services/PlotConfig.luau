local PlotConfig = {}

PlotConfig.MAX_PLOTS = 8

local PLOT_Y = 0.24

PlotConfig.PLOT_SIZE = Vector3.new(86, 0.28, 74)
PlotConfig.RESTAURANT_PIVOT_OFFSET = CFrame.new(0, 0, 0)
PlotConfig.PLAYER_SPAWN_OFFSET = CFrame.new(0, 5, -15) * CFrame.Angles(0, math.rad(180), 0)
PlotConfig.SPECTATOR_CFRAME = CFrame.new(0, 6, 270)

-- Add more player plots here later by increasing MAX_PLOTS and adding a new
-- definition with a unique id and cframe. PlotManager clones the same template
-- for each entry, so the rest of the restaurant systems stay plot-scoped.
PlotConfig.PLOTS = {
	{
		id = 1,
		cframe = CFrame.new(-184, PLOT_Y, -168),
	},
	{
		id = 2,
		cframe = CFrame.new(184, PLOT_Y, -168),
	},
	{
		id = 3,
		cframe = CFrame.new(-206, PLOT_Y, 22),
	},
	{
		id = 4,
		cframe = CFrame.new(206, PLOT_Y, 22),
	},
	{
		id = 5,
		cframe = CFrame.new(-162, PLOT_Y, 172),
	},
	{
		id = 6,
		cframe = CFrame.new(162, PLOT_Y, 172),
	},
	{
		id = 7,
		cframe = CFrame.new(-58, PLOT_Y, 212),
	},
	{
		id = 8,
		cframe = CFrame.new(58, PLOT_Y, 212),
	},
}

return PlotConfig
