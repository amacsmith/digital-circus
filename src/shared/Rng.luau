--!nonstrict
-- Small seeded-random helpers shared by world generation, acts and capsules.

local Rng = {}

-- One seed per UTC day, e.g. 20261113. Used as the public "build number".
function Rng.daySeed(): number
	local t = os.date("!*t")
	return t.year * 10000 + t.month * 100 + t.day
end

function Rng.dayIndex(): number
	return math.floor(os.time() / 86400)
end

function Rng.pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

-- weightOf(item) -> number. Items with weight <= 0 are never chosen.
function Rng.weighted<T>(rng: Random, list: { T }, weightOf: (T) -> number): T?
	local total = 0
	for _, item in list do
		total += math.max(weightOf(item), 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	local last = nil
	for _, item in list do
		local weight = math.max(weightOf(item), 0)
		if weight > 0 then
			last = item
			roll -= weight
			if roll <= 0 then
				return item
			end
		end
	end
	return last
end

function Rng.shuffle<T>(rng: Random, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return Rng
