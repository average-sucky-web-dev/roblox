-- Globals
local np = require(script.Parent.NumLua)
local presets = require(script.Parent.Presets)
local NNetwork = {}
NNetwork.__index = NNetwork

-- Functions
local function softplus(Z)
	local A = np.log(np.add(1, np.exp(Z)))
	return A
end

local function softplusDeriv(Z)
	return np.divide(1, np.add(1, np.exp(np.multiply(-1, Z))))
end


local function initParams(layers)
	local params = {}
	local L = #layers - 1

	for l = 1, L do
		local inputSize = layers[l]
		local outputSize = layers[l+1]

		params["W"..l] = {}
		for i = 1, outputSize do
			params["W"..l][i] = {}
			for j = 1, inputSize do
				params["W"..l][i][j] = math.random() * 0.02 - 0.01
			end
		end

		params["b"..l] = {}
		for i = 1, outputSize do
			params["b"..l][i] = {0}
		end
	end

	return params
end

local function ensure2D(tbl)
	if typeof(tbl[1]) ~= "table" then
		local out = {}
		for i=1,#tbl do
			out[i] = {tbl[i]}
		end
		return out
	end
	return tbl
end

-- Metatable functionality

-- Creates a new neural network based on parameter lengths
function NNetwork.new(params: {}, activation, derivative)
	local self = setmetatable({}, NNetwork)
	self.params = initParams(params)
	if not activation then
		activation = presets.Activations["softplus"].active
	end
	if not derivative then
		derivative = presets.Activations["softplus"].deriv
	end
	self.active = activation
	self.deriv = derivative
	return self
end

function NNetwork.preset(params, preset)
	local self = setmetatable({}, NNetwork)
	self.params = initParams(params)
	self.active = presets.Activations[preset].active
	self.deriv = presets.Activations[preset].deriv
	self.preset = preset
	return self
end

-- Loads an existing neural network based on a generated NN export
function NNetwork.load(params: {})
	local self = setmetatable({}, NNetwork)
	for key, item in params do
		self[key] = item
	end
	return self
end

function NNetwork:export()
	local export = {}
	export.params = self.params
	export.active = self.active
	export.deriv = self.deriv
	if self.preset then
		export.preset = self.preset
	else
		warn("custom functions will not save to datastores! consider mapping your exsisting functions to a custom table")
	end
	return export
end

-- Internal function, runs a forward pass through the network
function NNetwork:forwardprop(X)
	local A = ensure2D(X)
	local caches = {}

	local L = 0
	for k in pairs(self.params) do
		if string.sub(k, 1, 1) == "W" then
			L += 1
		end
	end
	for l = 1, L do
		local Aprev = A
		local W = self.params["W"..l]
		local b = self.params["b"..l]
		local Z = np.add(b, np.dot(W, Aprev))
		A = self.active(Z)
		table.insert(caches, {
			Aprev = Aprev,
			W = W,
			b = b,
			Z = Z,
			A = A
		})
	end

	local AL = A 
	return AL, caches
end

-- Internal function, recomputes weights and biases via the backprop algorithm
function NNetwork:backprop(X, Y, caches)
	local grads = {}

	local X2D = ensure2D(X)
	local Y2D = ensure2D(Y)

	local L = 0
	for k in pairs(self.params) do
		if string.sub(k, 1, 1) == "W" then
			L += 1
		end
	end

	local AL = caches[#caches].A
	local dZ = np.add(AL, np.multiply(-1, Y2D))
	for layer = L, 1, -1 do
		local Aprev
		if layer == 1 then
			Aprev = X2D
		else
			Aprev = caches[layer - 1].A
		end

		grads["dW"..layer] = np.dot(dZ, np.transpose(ensure2D(Aprev)))
		grads["db"..layer] = dZ

		if layer > 1 then
			local dAprev = np.dot(np.transpose(self.params["W"..layer]), dZ)
			local Zprev = caches[layer - 1].Z
			dZ = np.multiply(dAprev, self.deriv(Zprev))
		end
	end

	return grads
end

-- Internal functions, runs forwardprop and backprop
function NNetwork:propagate(X, Y)
	local A, caches = self:forwardprop(X)

	local grads = self:backprop(X, Y, caches)

	return A, grads
end

-- Trains the neural network based off a dataset and a learning rate
function NNetwork:train(dataset, learningRate, iterations)
	local finalLoss
	for i = 1, iterations do
		local totalLoss = 0

		for _, sample in ipairs(dataset) do
			local X, Y = sample[1], sample[2]

			local A, grads = self:propagate(X, Y)

			local L = 0
			for k in pairs(self.params) do
				if string.sub(k, 1, 1) == "W" then
					L += 1
				end
			end

			for layer = 1, L do
				local W = self.params["W"..layer]
				local b = self.params["b"..layer]
				local dW = grads["dW"..layer]
				local db = grads["db"..layer]

				for r = 1, #W do
					for c = 1, #W[r] do
						W[r][c] = W[r][c] - learningRate * dW[r][c]
					end
				end

				for r = 1, #b do
					b[r][1] = b[r][1] - learningRate * db[r][1]
				end
			end


			for j = 1, #Y do
				totalLoss = totalLoss + (A[j][1] - Y[j][1])^2
			end
		end

		totalLoss = totalLoss / (#dataset * #dataset[1][2])
		if i % 5 == 0 then
			task.wait()
		end
		if i % 50 == 0 then
			print("Iteration", i, "Loss:", totalLoss)
		end
		finalLoss = totalLoss
	end
	return finalLoss
end

-- Accepts an input and attempts to predict the result
function NNetwork:predict(X)
	local A, _ = self:forwardprop(X)


	local flatA = {}
	for i, sub in ipairs(A) do
		flatA[i] = sub[1] or sub
	end


	local maxVal = flatA[1]
	local maxIdx = 1
	for i = 2, #flatA do
		if flatA[i] > maxVal then
			maxVal = flatA[i]
			maxIdx = i
		end
	end
	return maxIdx
end


return NNetwork
