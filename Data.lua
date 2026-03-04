local addonName, addon = ...

-- Currency data definitions
addon.Data = {}

-- Category constants
local CATEGORY = {
	MIDNIGHT = "Midnight",
	WARWITHIN = "War Within",
	PVP = "PvP Currencies",
	DRAGONFLIGHT = "Dragonflight",
	SHADOWLANDS = "Shadowlands",
	BFA = "Battle for Azeroth",
	LEGION = "Legion",
	WOD = "Warlords of Draenor",
	MOP = "Mists of Pandaria",
	CATACLYSM = "Cataclysm",
	WOTLK = "Wrath of the Lich King",
	BC = "Burning Crusade",
	SEASONAL = "Seasonal Events",
}

addon.Data.Categories = CATEGORY

-- Currency definitions
-- Format: [categoryKey] = { {id, name, weeklyMax, icon}, ... }
addon.Data.Currencies = {
	[CATEGORY.MIDNIGHT] = {
		{3383, "Adventurer Dawncrest", nil, nil},
		{3341, "Veteran Dawncrest", nil, nil},
		{3343, "Champion Dawncrest", nil, nil},
		{3345, "Hero Dawncrest", nil, nil},
		{3348, "Myth Dawncrest", nil, nil},
		{3319, "Twilight's Blade Insignia", nil, nil},
		{3379, "Brimming Arcana", nil, nil},
		{3316, "Voidlight Marl", nil, nil},
		{3363, "Community Coupons", nil, nil},
	},

	[CATEGORY.WARWITHIN] = {
		{3008, "Valorstones", nil, 5872034},
		{3284, "Weathered Ethereal Crest", nil, 5927678},
		{3286, "Carved Ethereal Crest", nil, 5927679},
		{3288, "Runed Ethereal Crest", nil, 5927680},
		{3290, "Gilded Ethereal Crest", nil, 5927681},
		{2815, "Resonance Crystals", 3000, 5899503},
		{3028, "Restored Coffer Key", nil, 237446},
		{3056, "Kej", nil, 5899557},
		{2803, "Undercoin", nil, 2065568},
		{3089, "Residual Memories", nil, 5899501},
		{3090, "Flame-Blessed Iron", nil, 133224},
		{3093, "Nerub-ar Finery", nil, 134532},
		{3218, "Empty Kaja'Cola Can", nil, 348522},
		{3226, "Market Research", nil, 134332},
		{3149, "Displaced Corrupted Mementos", nil, 237282},
		{3303, "Untethered Coin", nil, 133784},
		{3269, "Ethereal Voidsplinter", nil, nil},
		{3116, "Essence of Kaja'mite", nil, nil},
		{2813, "Harmonized Silk", nil, nil},
		{2533, "Renascent Shadowflame", nil, nil},
		{2796, "Renascent Dream", nil, nil},
	},

	[CATEGORY.PVP] = {
		{1602, "Conquest", nil, 1523630},
		{1792, "Honor", nil, 1455894},
	},

	[CATEGORY.DRAGONFLIGHT] = {
		{2245, "Flightstones", 2000, 5172976},
		{2118, "Elemental Overflow", nil, 2065624},
		{2594, "Paracausal Flakes", nil, 5172978},
		{2003, "Dragon Isles Supplies", nil, 4622500},
		{2122, "Storm Sigil", nil, 2065574},
	},

	[CATEGORY.SHADOWLANDS] = {
		{1906, "Soul Ash", nil, 3743738},
		{1907, "Soul Cinders", nil, 3743739},
		{1810, "Reservoir Anima", nil, 3528288},
		{1828, "Cosmic Flux", nil, 4038106},
		{1767, "Stygia", nil, 3743731},
		{1977, "Stygian Ember", nil, 4067611},
		{1931, "Cataloged Research", nil, 1506458},
		{1979, "Cyphers of the First Ones", nil, 4066373},
		{1813, "Grateful Offering", nil, 3089810},
		{1885, "Infused Ruby", nil, 133250},
		{1816, "Sinstone Fragments", nil, 3743738},
	},

	[CATEGORY.BFA] = {
		{1560, "War Resources", nil, 2032592},
		{1716, "Coalescing Visions", nil, 3084135},
		{1721, "Prismatic Manapearl", nil, 2101977},
		{1718, "Echoes of Ny'alotha", nil, 3193844},
		{1553, "Seafarer's Dubloon", nil, 2032600},
		{1579, "Honorbound Service Medal", nil, 2032593},
	},

	[CATEGORY.LEGION] = {
		{1220, "Order Resources", nil, 1397630},
		{1226, "Ancient Mana", nil, 1417744},
		{1155, "Curious Coin", nil, 1604167},
		{1508, "Veiled Argunite", nil, 1064188},
		{1342, "Nethershard", nil, 1417744},
	},

	[CATEGORY.WOD] = {
		{823, "Apexis Crystal", nil, 1064188},
		{824, "Garrison Resources", nil, 1005027},
		{994, "Seal of Tempered Fate", nil, 1129161},
		{1129, "Seal of Inevitable Fate", nil, 1129161},
		{980, "Dingy Iron Coins", nil, 1064188},
	},

	[CATEGORY.MOP] = {
		{777, "Timeless Coin", nil, 237282},
		{402, "Ironpaw Token", nil, 537444},
		{738, "Lesser Charm of Good Fortune", nil, 237282},
		{697, "Elder Charm of Good Fortune", nil, 237282},
		{752, "Mogu Rune of Fate", nil, 237282},
		{776, "Warforged Seal", nil, 237282},
		{789, "Bloody Coin", nil, 237282},
	},

	[CATEGORY.CATACLYSM] = {
		{416, "Mark of the World Tree", nil, 133439},
		{391, "Tol Barad Commendation", nil, 133441},
		{614, "Mote of Darkness", nil, 463450},
		{361, "Illustrious Jewelcrafter's Token", nil, 134071},
		{615, "Essence of Corrupted Deathwing", nil, 463852},
	},

	[CATEGORY.WOTLK] = {
		{241, "Champion's Seal", nil, 133441},
		{61, "Dalaran Jewelcrafter's Token", nil, 134071},
		{42, "Badge of Justice", nil, 133441},
	},

	[CATEGORY.BC] = {
		{1101, "Spirit Shard", nil, 463858},
	},

	[CATEGORY.SEASONAL] = {
		{515, "Darkmoon Prize Ticket", nil, 134481},
		{1166, "Timewarped Badge", nil, 1129674},
		{81, "Epicurean's Award", nil, 133886},
		{2588, "Riders of Azeroth Badge", nil, 4622500},
		{2123, "Bloody Token", nil, 1945738},
	},
}

-- Weekly reset time (US: Tuesday 3pm UTC)
addon.Data.WeeklyResetDay = 3
addon.Data.WeeklyResetHour = 15

function addon.Data:GetTimeUntilWeeklyReset()
	local serverTime = GetServerTime()
	local currentDay = date("%w", serverTime) + 1
	local currentHour = tonumber(date("%H", serverTime))

	local daysUntilReset = (self.WeeklyResetDay - currentDay) % 7
	if daysUntilReset == 0 and currentHour >= self.WeeklyResetHour then
		daysUntilReset = 7
	end

	local resetTime = serverTime + (daysUntilReset * 86400)
	local resetDate = date("*t", resetTime)
	resetDate.hour = self.WeeklyResetHour
	resetDate.min = 0
	resetDate.sec = 0

	local exactResetTime = time(resetDate)
	return exactResetTime - serverTime
end

function addon.Data:FormatTimeRemaining(seconds)
	if seconds <= 0 then return "Reset!" end

	local days = floor(seconds / 86400)
	local hours = floor((seconds % 86400) / 3600)
	local mins = floor((seconds % 3600) / 60)

	if days > 0 then
		return format("%dd %dh", days, hours)
	elseif hours > 0 then
		return format("%dh %dm", hours, mins)
	else
		return format("%dm", mins)
	end
end

addon.Data.Colors = {
	PLENTY = {0, 1, 0},
	WARNING = {1, 1, 0},
	DANGER = {1, 0, 0},
	NORMAL = {1, 1, 1},
}

function addon.Data:GetCurrencyColor(amount, maxAmount)
	if not maxAmount or maxAmount == 0 then
		return self.Colors.NORMAL
	end

	local percent = amount / maxAmount
	if percent >= 0.95 then
		return self.Colors.DANGER
	elseif percent >= 0.70 then
		return self.Colors.WARNING
	else
		return self.Colors.PLENTY
	end
end
