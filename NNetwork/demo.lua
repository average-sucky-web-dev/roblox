local NNetwork = require(script.Parent.NNetwork)

local AI = NNetwork.new({4, 10, 4})

-- creates a dataset that trains an AI to predict an output based off the mean of the 4 objects together
local function createDataset(n)
	local dataset = {}
	for i = 1, n do
		local x = {}
		local sum = 0
		for j = 1, 4 do
			local val = math.random()
			table.insert(x, {val})
			sum = sum + val
		end
		local mean = sum / 4
		local y = {}
		if mean < 0.25 then
			y = {{1},{0},{0},{0}}
		elseif mean < 0.5 then
			y = {{0},{1},{0},{0}}
		elseif mean < 0.75 then
			y = {{0},{0},{1},{0}}
		else
			y = {{0},{0},{0},{1}}
		end
		table.insert(dataset, {x, y})
	end
	return dataset
end

local dataset = createDataset(100)
print(AI:train(dataset, 0.1, 200))

-- should print {0, 1, 0, 0}
print(AI:predict({0.4, 0.2, 1, 0.35}))
