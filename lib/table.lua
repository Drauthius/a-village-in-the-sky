local table = table

function table.clone(tbl, deep)
	local newTbl = {}

	for k,v in pairs(tbl) do
		if type(v) == "table" and deep then
			newTbl[k] = table.clone(v, deep)
		else
			newTbl[k] = v
		end
	end

	return newTbl
end

-- Note: in place
function table.shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = love.math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end

	return tbl
end

return table
