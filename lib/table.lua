local table = table

function table.clone(tbl, deep)
	local newTbl = {}

	for k,v in pairs(tbl) do
		if type(v) == "table" then
			if deep then
				newTbl[k] = table.clone(v, deep)
			end
		else
			newTbl[k] = v
		end
	end

	return newTbl
end

return table
