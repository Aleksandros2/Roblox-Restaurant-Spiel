local PlotConfig = {}

PlotConfig.MAX_PLOTS = 8

local PLOT_Y = 0.24

PlotConfig.PLOT_SIZE = Vector3.new(86, 0.28, 74)
PlotConfig.RESTAURANT_PIVOT_OFFSET = CFrame.new(0, 0, 0)
PlotConfig.PLAYER_SPAWN_OFFSET = CFrame.new(0, 5, -15) * CFrame.Angles(0, math.rad(180), 0)
PlotConfig.SPECTATOR_CFRAME = CFrame.new(0, 6, 145)

PlotConfig.PLOTS = {
	{
		id = 1,
		cframe = CFrame.new(-144, PLOT_Y, -56),
	},
	{
		id = 2,
		cframe = CFrame.new(-48, PLOT_Y, -56),
	},
	{
		id = 3,
		cframe = CFrame.new(48, PLOT_Y, -56),
	},
	{
		id = 4,
		cframe = CFrame.new(144, PLOT_Y, -56),
	},
	{
		id = 5,
		cframe = CFrame.new(-144, PLOT_Y, 42),
	},
	{
		id = 6,
		cframe = CFrame.new(-48, PLOT_Y, 42),
	},
	{
		id = 7,
		cframe = CFrame.new(48, PLOT_Y, 42),
	},
	{
		id = 8,
		cframe = CFrame.new(144, PLOT_Y, 42),
	},
}

return PlotConfig
