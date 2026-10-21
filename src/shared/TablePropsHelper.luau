--!strict
--[=[
	TablePropsHelper.luau
	Helper sentral pencari objek meja, props (gelas kopi, termos, piring),
	bohlam pencahayaan, dan kontainer kartu per TableId (batch 1 blocker runtime).
]=]

local Workspace = game:GetService("Workspace")

local TablePropsHelper = {}

-- Mengambil Model Meja berdasarkan TableId (1..4)
function TablePropsHelper.GetTableModel(tableId: number): Model?
	local posRonda = Workspace:FindFirstChild("PosRonda")
	if not posRonda then return nil end

	-- Cek di folder Tables
	local tablesFolder = posRonda:FindFirstChild("Tables")
	if tablesFolder then
		for _, child in ipairs(tablesFolder:GetChildren()) do
			if child:IsA("Model") and child:GetAttribute("TableId") == tableId then
				return child
			end
		end
	end

	-- Fallback: Meja 1 dinamai "Table", lainnya "Table_N"
	local directName = if tableId == 1 then "Table" else ("Table_" .. tableId)
	local direct = posRonda:FindFirstChild(directName, true)
	if direct and direct:IsA("Model") then
		return direct
	end

	return nil
end

-- Mengambil kontainer kartu di meja (GameBoardTiles / TilesContainer)
function TablePropsHelper.GetTilesContainer(): Folder
	local existing = Workspace:FindFirstChild("TilesContainer") or Workspace:FindFirstChild("GameBoardTiles")
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = "TilesContainer"
	folder.Parent = Workspace
	return folder
end

-- Mengambil prop GelasKopi untuk meja tertentu (TableId)
function TablePropsHelper.GetCoffeeCup(tableId: number?): BasePart?
	local tid = tableId or 1
	local tbl = TablePropsHelper.GetTableModel(tid)
	if tbl then
		local cup = tbl:FindFirstChild("GelasKopi", true)
		if cup and cup:IsA("BasePart") then
			return cup
		end
	end

	-- Fallback ke PosRonda.Props (untuk Meja 1)
	local posRonda = Workspace:FindFirstChild("PosRonda")
	if posRonda then
		local cup = posRonda:FindFirstChild("GelasKopi", true)
		if cup and cup:IsA("BasePart") then
			return cup
		end
	end

	return nil
end

-- Mengambil Bohlam lampu untuk meja tertentu (TableId)
function TablePropsHelper.GetBulb(tableId: number?): BasePart?
	local tid = tableId or 1
	local tbl = TablePropsHelper.GetTableModel(tid)
	if tbl then
		local bulb = tbl:FindFirstChild("Bohlam", true)
		if bulb and bulb:IsA("BasePart") then
			return bulb
		end
	end

	local posRonda = Workspace:FindFirstChild("PosRonda")
	if not posRonda then return nil end

	if tid == 1 then
		local fixtures = posRonda:FindFirstChild("LightingFixtures")
		local bulb = fixtures and fixtures:FindFirstChild("Bohlam", true)
		if bulb and bulb:IsA("BasePart") then return bulb end
		local direct = posRonda:FindFirstChild("Bohlam", true)
		if direct and direct:IsA("BasePart") then return direct end
	elseif tid == 2 then
		local struct = posRonda:FindFirstChild("Structures")
		local bulb = struct and struct:FindFirstChild("WarkopBohlam", true)
		if bulb and bulb:IsA("BasePart") then return bulb end
	elseif tid == 3 then
		local bulb = posRonda:FindFirstChild("GazeboBohlam", true)
		if bulb and bulb:IsA("BasePart") then return bulb end
	elseif tid == 4 then
		local bulb = posRonda:FindFirstChild("BohlamPelataran1", true) or posRonda:FindFirstChild("BohlamPelataran", true)
		if bulb and bulb:IsA("BasePart") then return bulb end
	end

	-- Fallback umum
	local fallbackBulb = posRonda:FindFirstChild("Bohlam", true)
	if fallbackBulb and fallbackBulb:IsA("BasePart") then
		return fallbackBulb
	end

	return nil
end

return table.freeze(TablePropsHelper)
