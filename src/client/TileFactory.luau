--!strict
--[=[
	TileFactory.luau
	Pabrik pembuatan dan manajemen pool kartu domino 3D.
	Sumber: WORLD_ART_AUDIO.md §3, FIRST_PERSON_HANDS.md §6.

	Spesifikasi:
	- Balok gading (ukuran dari BoardLayout / GameConfig: 1.0 x 0.15 x 0.5 stud).
	- Satu SurfaceGui per kartu dengan resolusi tajam (200x100 px).
	- Titik bulat tegas (0–6), garis pemisah tengah, kontras tinggi.
	- Punggung kartu warna gelap polos.
	- Fitur: CreateTile, FlipFaceDown, SetGlow, RecycleTile.
	- Menggunakan Object Pool untuk performa bebas stutter di mobile.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local BoardLayout = require(sharedFolder:WaitForChild("BoardLayout"))
local TablePropsHelper = require(sharedFolder:WaitForChild("TablePropsHelper"))

export type TileInstance = BasePart

local TILE_SIZE = BoardLayout.GetTileSize() -- Vector3(1.0, 0.15, 0.5)
local IVORY_COLOR = Color3.fromRGB(246, 242, 230)
local BACK_COLOR = Color3.fromRGB(36, 36, 42)
local PIP_COLOR = Color3.fromRGB(25, 25, 30)
local LINE_COLOR = Color3.fromRGB(50, 50, 55)

-- Koordinat normalisasi (0..1) untuk titik domino 0-6
local PIP_COORDS: { [number]: { Vector2 } } = {
	[0] = {},
	[1] = { Vector2.new(0.50, 0.50) },
	[2] = { Vector2.new(0.28, 0.28), Vector2.new(0.72, 0.72) },
	[3] = { Vector2.new(0.28, 0.28), Vector2.new(0.50, 0.50), Vector2.new(0.72, 0.72) },
	[4] = { Vector2.new(0.28, 0.28), Vector2.new(0.72, 0.28), Vector2.new(0.28, 0.72), Vector2.new(0.72, 0.72) },
	[5] = { Vector2.new(0.28, 0.28), Vector2.new(0.72, 0.28), Vector2.new(0.50, 0.50), Vector2.new(0.28, 0.72), Vector2.new(0.72, 0.72) },
	[6] = { Vector2.new(0.28, 0.22), Vector2.new(0.72, 0.22), Vector2.new(0.28, 0.50), Vector2.new(0.72, 0.50), Vector2.new(0.28, 0.78), Vector2.new(0.72, 0.78) },
}

local TileFactory = {}

-- Pool penyimpanan kartu yang tidak terpakai
local tilePool: { TileInstance } = {}
local activeTiles: { [TileInstance]: boolean } = {}

-- Pool penyimpanan Frame titik pip kartu (bebas GC churn)
local pipPool: { Frame } = {}

-- Folder wadah kartu di Workspace (dibuat saat runtime via TablePropsHelper)
local function getTilesFolder(): Folder
	return TablePropsHelper.GetTilesContainer()
end

-- Folder penampung pool kartu tidak aktif
local function getPoolFolder(): Folder
	local existing = workspace:FindFirstChild("TilePoolCache")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "TilePoolCache"
	folder.Parent = workspace
	return folder
end

-- Helper mengambil pip dari pool atau membuat baru
local function acquirePip(pos: Vector2, parent: Frame): Frame
	local dot: Frame
	if #pipPool > 0 then
		dot = table.remove(pipPool, #pipPool) :: Frame
		dot.Position = UDim2.new(pos.X, 0, pos.Y, 0)
		dot.Parent = parent
	else
		dot = Instance.new("Frame")
		dot.Name = "Pip"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(pos.X, 0, pos.Y, 0)
		dot.Size = UDim2.new(0, 16, 0, 16)
		dot.BackgroundColor3 = PIP_COLOR
		dot.BorderSizePixel = 0

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot

		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 1.0
		aspect.AspectType = Enum.AspectType.FitWithinMaxSize
		aspect.DominantAxis = Enum.DominantAxis.Width
		aspect.Parent = dot
		dot.Parent = parent
	end
	return dot
end

-- Helper mengembalikan pip ke pool (tanpa destroy)
local function releasePip(dot: Frame)
	dot.Parent = nil
	table.insert(pipPool, dot)
end

-- Helper mengelola titik pip pada satu sisi kartu dengan sistem pooling / reuse Frame & UICorner (bebas GC churn)
local function updateHalfPips(half: Frame, val: number)
	local targetPips = PIP_COORDS[val] or {}
	local targetCount = #targetPips

	local currentPips: { Frame } = {}
	for _, child in ipairs(half:GetChildren()) do
		if child:IsA("Frame") and child.Name == "Pip" then
			table.insert(currentPips, child)
		end
	end

	-- Jika ada kelebihan pip di half, kembalikan ke pipPool (tanpa ClearAllChildren / destroy)
	while #currentPips > targetCount do
		local excess = table.remove(currentPips)
		if excess then
			releasePip(excess)
		end
	end

	-- Perbarui posisi pip yang sudah ada
	for i = 1, #currentPips do
		local coord = targetPips[i]
		local dot = currentPips[i]
		dot.Position = UDim2.new(coord.X, 0, coord.Y, 0)
	end

	-- Jika kurang, ambil dari pipPool atau buat baru
	for i = #currentPips + 1, targetCount do
		local coord = targetPips[i]
		acquirePip(coord, half)
	end
end

-- Helper membangun elemen GUI pada SurfaceGui kartu (dioptimalkan me-reuse kontainer & pip agar bebas GC churn)
local function setupTileGUI(gui: SurfaceGui, leftVal: number, rightVal: number)
	local container = gui:FindFirstChild("FaceContainer") :: Frame?
	local leftHalf: Frame?
	local rightHalf: Frame?

	if not container then
		container = Instance.new("Frame")
		container.Name = "FaceContainer"
		container.Size = UDim2.new(1, 0, 1, 0)
		container.BackgroundColor3 = IVORY_COLOR
		container.BorderSizePixel = 0
		container.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = container

		leftHalf = Instance.new("Frame")
		leftHalf.Name = "LeftHalf"
		leftHalf.BackgroundTransparency = 1
		leftHalf.Size = UDim2.new(0.5, 0, 1, 0)
		leftHalf.Position = UDim2.new(0, 0, 0, 0)
		leftHalf.Parent = container

		rightHalf = Instance.new("Frame")
		rightHalf.Name = "RightHalf"
		rightHalf.BackgroundTransparency = 1
		rightHalf.Size = UDim2.new(0.5, 0, 1, 0)
		rightHalf.Position = UDim2.new(0.5, 0, 0, 0)
		rightHalf.Parent = container

		local divider = Instance.new("Frame")
		divider.Name = "Divider"
		divider.AnchorPoint = Vector2.new(0.5, 0.5)
		divider.Position = UDim2.new(0.5, 0, 0.5, 0)
		divider.Size = UDim2.new(0, 4, 0.85, 0)
		divider.BackgroundColor3 = LINE_COLOR
		divider.BorderSizePixel = 0
		divider.Parent = container

		local divCorner = Instance.new("UICorner")
		divCorner.CornerRadius = UDim.new(1, 0)
		divCorner.Parent = divider
	else
		leftHalf = container:FindFirstChild("LeftHalf") :: Frame?
		rightHalf = container:FindFirstChild("RightHalf") :: Frame?
	end

	-- Perbarui titik pada sisi kiri dan kanan menggunakan pool frame/corner yang sudah ada
	if leftHalf then
		updateHalfPips(leftHalf, leftVal)
	end
	if rightHalf then
		updateHalfPips(rightHalf, rightVal)
	end
end

--[=[
	Membuat atau mengambil kartu dari pool dengan angka pip (leftVal, rightVal).
]=]
function TileFactory.CreateTile(leftVal: number, rightVal: number, faceUp: boolean?): TileInstance
	local isFaceUp = if faceUp ~= nil then faceUp else true
	local tile: TileInstance

	if #tilePool > 0 then
		tile = table.remove(tilePool, #tilePool) :: TileInstance
		tile.Parent = getTilesFolder()
	else
		-- Buat BasePart kartu balok
		local part = Instance.new("Part")
		part.Name = "DominoTile"
		part.Size = TILE_SIZE
		part.Material = Enum.Material.SmoothPlastic
		part.Color = IVORY_COLOR
		part.Anchored = true
		part.CanCollide = true
		part.CastShadow = true

		-- SurfaceGui di permukaan atas (NormalId.Top)
		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "TileGui"
		surfaceGui.Face = Enum.NormalId.Top
		surfaceGui.CanvasSize = Vector2.new(200, 100)
		surfaceGui.LightInfluence = 0.25
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surfaceGui.Parent = part

		-- SelectionBox untuk efek glow / hover / selection
		local selectionBox = Instance.new("SelectionBox")
		selectionBox.Name = "GlowBox"
		selectionBox.Adornee = part
		selectionBox.Visible = false
		selectionBox.Color3 = Color3.fromRGB(255, 230, 100)
		selectionBox.LineThickness = 0.03
		selectionBox.Transparency = 0.3
		selectionBox.Parent = part

		part.Parent = getTilesFolder()
		tile = part
	end

	-- Perbarui atribut nilai kartu
	tile:SetAttribute("LeftVal", leftVal)
	tile:SetAttribute("RightVal", rightVal)
	tile:SetAttribute("IsDouble", leftVal == rightVal)

	-- Perbarui SurfaceGui
	local surfaceGui = tile:FindFirstChild("TileGui") :: SurfaceGui?
	if surfaceGui then
		setupTileGUI(surfaceGui, leftVal, rightVal)
	end

	-- Atur tampilan telentang (face up) atau tertutup (face down)
	TileFactory.FlipFaceDown(tile, not isFaceUp)
	TileFactory.SetGlow(tile, "none")

	activeTiles[tile] = true
	return tile
end

--[=[
	Membalik kartu tertutup (punggung gelap) atau terbuka (tampak angka pip).
]=]
function TileFactory.FlipFaceDown(tile: TileInstance, isDown: boolean)
	local surfaceGui = tile:FindFirstChild("TileGui") :: SurfaceGui?
	if surfaceGui then
		surfaceGui.Enabled = not isDown
	end

	if isDown then
		tile.Color = BACK_COLOR
	else
		tile.Color = IVORY_COLOR
	end
end

--[=[
	Mengatur efek cahaya / glow pada kartu:
	- "none": Tanpa glow.
	- "hover": Kuning emas tipis saat kursor melayang di atas kartu legal.
	- "selected": Cyan terang saat kartu dipilih siap dipasang.
]=]
function TileFactory.SetGlow(tile: TileInstance, state: "none" | "hover" | "selected")
	local glow = tile:FindFirstChild("GlowBox") :: SelectionBox?
	if not glow then return end

	if state == "none" then
		glow.Visible = false
	elseif state == "hover" then
		glow.Visible = true
		glow.Color3 = Color3.fromRGB(255, 225, 90)
		glow.Transparency = 0.35
		glow.LineThickness = 0.03
	elseif state == "selected" then
		glow.Visible = true
		glow.Color3 = Color3.fromRGB(90, 220, 255)
		glow.Transparency = 0.15
		glow.LineThickness = 0.05
	end
end

--[=[
	Mengembalikan kartu ke pool untuk digunakan kembali tanpa alokasi baru.
]=]
function TileFactory.RecycleTile(tile: TileInstance)
	if not activeTiles[tile] then return end
	activeTiles[tile] = nil

	local ok = pcall(function()
		TileFactory.SetGlow(tile, "none")
		tile.Size = TILE_SIZE
		tile.CFrame = CFrame.new(0, -500, 0)
		tile.Parent = getPoolFolder()
	end)

	if ok then
		table.insert(tilePool, tile)
	end
end

--[=[
	Mengembalikan seluruh kartu aktif kembali ke pool.
]=]
function TileFactory.RecycleAll()
	for tile in pairs(activeTiles) do
		TileFactory.RecycleTile(tile)
	end
end

--[=[
	Menghitung jumlah kartu aktif dan kartu yang tersedia di pool.
]=]
function TileFactory.GetStats(): { activeCount: number, poolCount: number }
	local count = 0
	for _ in pairs(activeTiles) do
		count += 1
	end
	return {
		activeCount = count,
		poolCount = #tilePool,
	}
end

return TileFactory
