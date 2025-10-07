local NLArray = {}
NLArray.__index = NLArray

local function copy(old, new)
	for key, value in old do
		if typeof(value) == "table" then
			local result = {}
			copy(value, result)
			new[key] = result
		else
			new[key] = value
		end
	end
end
local function copyTable(input: {})
	local output = {}
	copy(input, output)
	return output
end
local function flattenTable(tbl, result)
	result = result or {}

	for _, v in tbl do
		if type(v) == "table" then
			flattenTable(v, result) 
		else
			table.insert(result, v)
		end
	end
	return result
end
local function applyToNested(tbl, func, depth, current)
	current = current or 1
	if current == depth then
		for i, v in tbl do
			
			tbl[i] = func(v)
		end
	else
		for _, v in tbl do
			if type(v) == "table" then
				applyToNested(v, func, depth, current + 1)
			end
		end
	end
end
local function getDimension(item)
	local count = 0
	local subject = item
	local finished = false
	while finished == false do
		if typeof(subject) == 'table' then
			count += 1
			subject = subject[1]
		else
			finished = true
		end
	end
	return count
end
local function isScalarLike(x)
	return type(x) == "table" and #x == 1 and type(x[1]) == "number"
end

local function processArgs(args: {})
	local result = {}
	for _, argu in args do
		local dimen
		if type(argu) == "number" or isScalarLike(argu) then
			dimen = 0
		else
			dimen = getDimension(argu)
		end

		local key = tostring(dimen) .. "D"
		if result[key] then
			table.insert(result[key], argu)
		else
			result[key] = {argu}
		end
	end
	return result
end

local function matmul(A, B)
	local colsA = #A[1]
	for i = 2, #A do
		if #A[i] ~= colsA then
			error("Matrix A is not rectangular")
		end
	end
	local colsB = #B[1]
	for i = 2, #B do
		if #B[i] ~= colsB then
			error("Matrix B is not rectangular")
		end
	end
	local rowsA, rowsB = #A, #B
	if colsA ~= rowsB then
		error("Matrix dimensions do not match for multiplication: " .. colsA .. "x" .. rowsB)
	end
	local C = {}
	for i = 1, rowsA do
		C[i] = {}
		for j = 1, colsB do
			C[i][j] = 0
			for k = 1, colsA do
				C[i][j] = C[i][j] + A[i][k] * B[k][j]
			end
		end
	end

	return C
end
local function getDimensionLength(a: {})
	if typeof(a) == "number" then
		return {}
	end
	local dims = {}
	local subject = a
	while true do
		table.insert(dims, #subject)
		if typeof(subject[1]) == "table" then
			subject = subject[1]
		else
			break
		end
	end
	return dims
end
local function duplicateIntoArray(array, item, count)
	for key, _ in array do
		array[key] = nil
	end
	for i = 1, count do
		table.insert(array, item)
	end
end
local function getFinalArrayDimen(a: {}, b: {})
	local dimsA = getDimensionLength(a)
	local dimsB = getDimensionLength(b)

	local lenDiff = #dimsA - #dimsB
	if lenDiff > 0 then
		for i = 1, lenDiff do table.insert(dimsB, 1) end
	elseif lenDiff < 0 then
		for i = 1, -lenDiff do table.insert(dimsA, 1) end
	end
	local result = {}
	for i = 1, #dimsA do
		if dimsA[i] == dimsB[i] then
			result[i] = dimsA[i]
		elseif dimsA[i] == 1 then
			result[i] = dimsB[i]
		elseif dimsB[i] == 1 then
			result[i] = dimsA[i]
		else
			error("Arrays are incompatible for broadcasting: "..dimsA[i].." vs "..dimsB[i])
		end
	end

	return result
end



local function broadcast(a, b)
	if typeof(a) == "number" then
		a = {a}
	else
		a = copyTable(a)
	end
	if typeof(b) == "number" then
		b  = {b}
	else
		b = copyTable(b)
	end
	local dimens = getFinalArrayDimen(a, b)
	local dimena = getDimensionLength(a)
	local dimenb = getDimensionLength(b)
	while #dimena < #dimens do
		a = {a}
		dimena = getDimensionLength(a)
	end
	while #dimenb < #dimens do
		b = {b}
		dimenb = getDimensionLength(b)
	end
	for i = #dimens, 1, -1 do
		local aitem = dimena[i]
		local bitem = dimenb[i]
		local sitem = dimens[i]
		if aitem and aitem ~= sitem then
			if i == 1 then
				duplicateIntoArray(a, a[1], sitem)
			else
				local subject = a
				for j = 1, i - 2 do subject = subject[1] end
				for key, item in subject do
					duplicateIntoArray(item, item[1], sitem)
				end
			end
		end
		if bitem and bitem ~= sitem then
			if i == 1 then
				duplicateIntoArray(b, b[1], sitem)
			else
				local subject = b
				for j = 1, i - 2 do subject = subject[1] end
				for key, item in subject do
					duplicateIntoArray(item, item[1], sitem)
				end
			end
		end
	end
	return a, b
end
local function arrayOperate(a, b, func)
	if typeof(a) ~= "table" and typeof(b) ~= "table" then
		return func(a, b)
	end

	local result = {}
	for i = 1, #a do
		result[i] = arrayOperate(a[i], b[i], func)
	end
	return result
end
function dot1D_2D(vector, matrix)
	local rows, cols = #matrix, #matrix[1]
	assert(cols == #vector, "Matrix column count must match vector length")

	local result = {}
	for i = 1, rows do
		result[i] = 0
		for j = 1, cols do
			result[i] = result[i] + matrix[i][j] * vector[j]
		end
	end
	return result
end
function dot1D(a, b)
	assert(#a == #b, "Vectors must be the same length")
	local result = 0
	for i = 1, #a do
		result = result + a[i] * b[i]
	end
	return result
end
local np = {}

function NLArray.new(tbl)
	if getmetatable(tbl) == NLArray then
		return tbl
	end
	return setmetatable(tbl or {}, NLArray)
end

np.exp = function(a)
	local result = copyTable(a)
	local dimen = getDimension(result)
	applyToNested(result, function(item)
		return math.exp(item)
	end, dimen)
	return NLArray.new(result)
end
np.multiply = function(a, b)
	if typeof(a) == "number" then
		local result = copyTable(b)
		applyToNested(result, function(item) return item * a end, getDimension(result))
		return NLArray.new(result)
	elseif typeof(b) == "number" then
		local result = copyTable(a)
		applyToNested(result, function(item) return item * b end, getDimension(result))
		return NLArray.new(result)
	end
	if getDimensionLength(a) ~= getDimensionLength(b) then
		a, b = broadcast(a, b)
	end
	return NLArray.new(arrayOperate(a, b, function(x, y) return x * y end))
end
np.add = function(a, b)
	if typeof(a) == "number" then
		local result = copyTable(b)
		applyToNested(result, function(item) return item + a end, getDimension(result))
		return NLArray.new(result)
	elseif typeof(b) == "number" then
		local result = copyTable(a)
		applyToNested(result, function(item) return item + b end, getDimension(result))
		return NLArray.new(result)
	end
	if getDimensionLength(a) ~= getDimensionLength(b) then
		a, b = broadcast(a, b)
	end
	return NLArray.new(arrayOperate(a, b, function(x, y) return x + y end))
end
np.subtract = function(a, b)
	if typeof(a) == "number" then
		local result = copyTable(b)
		applyToNested(result, function(item) return item - a end, getDimension(result))
		return NLArray.new(result)
	elseif typeof(b) == "number" then
		local result = copyTable(a)
		applyToNested(result, function(item) return item - b end, getDimension(result))
		return NLArray.new(result)
	end
	if getDimensionLength(a) ~= getDimensionLength(b) then
		a, b = broadcast(a, b)
	end
	return NLArray.new(arrayOperate(a, b, function(x, y) return x - y end))
end
np.divide = function(a, b)
	if typeof(a) == "number" then
		local result = copyTable(b)
		applyToNested(result, function(item) return a / item end, getDimension(result))
		return NLArray.new(result)
	elseif typeof(b) == "number" then
		local result = copyTable(a)
		applyToNested(result, function(item) return item / b end, getDimension(result))
		return NLArray.new(result)
	end
	if getDimensionLength(a) ~= getDimensionLength(b) then
		a, b = broadcast(a, b)
	end
	return NLArray.new(arrayOperate(a, b, function(x, y) return x / y end))
end
np.dot = function(a, b)
	local result = {}
	local args = processArgs({a, b})
	if args["0D"] then
		result = np.multiply(a, b)
	elseif #args["2D"] == 2 then
		result = matmul(args["2D"][1], args["2D"][2])
	elseif #args["1D"] == 2 then
		result = dot1D(args["1D"][1], args["1D"][2])
	elseif args["2D"] and args["1D"] then
		result = dot1D_2D(args["1D"][1], args["2D"][1])
	end
	return NLArray.new(result)
end
np.log = function(a, epsilon)
	epsilon = epsilon or 1e-15
	local result = copyTable(a)
	local dimen = getDimension(result)
	applyToNested(result, function(item)
		local safeItem = math.max(item, epsilon)
		return math.log(safeItem)
	end, dimen)
	return NLArray.new(result)
end
np.transpose = function(mat)
	local rows = #mat
	local cols = #mat[1]
	local result = {}
	for j = 1, cols do
		result[j] = {}
		for i = 1, rows do
			result[j][i] = mat[i][j]
		end
	end
	return NLArray.new(result)
end
np.max = function(a, b)
	if typeof(a) == "number" then
		local result = copyTable(b)
		applyToNested(result, function(item) return math.max(a, item) end, getDimension(result))
		return NLArray.new(result)
	elseif typeof(b) == "number" then
		local result = copyTable(a)
		applyToNested(result, function(item) return math.max(item, b) end, getDimension(result))
		return NLArray.new(result)
	end
	if getDimensionLength(a) ~= getDimensionLength(b) then
		a, b = broadcast(a, b)
	end
	return NLArray.new(arrayOperate(a, b, function(x, y) return math.max(x, y) end))
end


function NLArray.__unm(self)
	local result = copyTable(self)
	local dimen = getDimension(result)
	applyToNested(result, function(item)
		return -item
	end, dimen)
	return NLArray.new(result)
end

function NLArray.__add(self, other)
	return NLArray.new(np.add(self, other))
end

function NLArray.__sub(self, other)
	return NLArray.new(np.subtract(self, other))
end

function NLArray.__mul(self, other)
	return NLArray.new(np.multiply(self, other))
end

function NLArray.__div(self, other)
	return NLArray.new(np.divide(self, other))
end

function NLArray.dot(self, other)
	return NLArray.new(np.dot(self, other))
end

function NLArray.log(self)
	return NLArray.new(np.log(self))
end

function NLArray.exp(self)
	return NLArray.new(np.exp(self))
end

function NLArray.transpose(self)
	return NLArray.new(np.transpose(self))
end

np.NLArray = NLArray

return np
