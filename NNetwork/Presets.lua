local np = require(script.Parent.NumLua)
local function arrayMap(a, func)
	if typeof(a) ~= "table" then
		return func(a)
	end

	local result = {}
	for i = 1, #a do
		result[i] = arrayMap(a[i], func)
	end
	return result
end
local module = {['Activations'] = {
	['softplus'] = {['active'] = function(Z)
		local A = np.log(np.add(1, np.exp(Z)))
		return A
	end, ['deriv'] = function(Z)
		return np.divide(1, np.add(1, np.exp(np.multiply(-1, Z))))
	end},
	['relu'] = {['active'] = function(Z)
		local A = np.max(0, Z)
		return A
	end, ['deriv'] = function(Z)
		return arrayMap(Z, function(a) if a > 0 then return 1 else return 0 end end)
	end},
	}
}

return module
