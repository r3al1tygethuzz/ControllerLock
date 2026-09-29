if IsPhone then
	WindowWidth = math.min(
		260,
		math.max(235, screenWidth - 24)
	)

	WindowHeight = math.min(
		305,
		math.max(275, screenHeight - 24)
	)
else
	WindowWidth = 380
	WindowHeight = 520
end
