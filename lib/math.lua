local math = math

function math.distance(x1, y1, x2, y2)
	return math.distancesquared(x1, y1, x2, y2)^0.5
end

function math.distancesquared(x1, y1, x2, y2)
	return ((x1-x2)^2 + (y1-y2)^2)
end

return math
