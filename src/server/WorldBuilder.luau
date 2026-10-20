--!strict
--[=[
	WorldBuilder.luau
	Pembangun dunia pos ronda prosedural 3D dari Part murni.
	Memenuhi WORLD_ART_AUDIO.md §1–5, §8–9 dan TECH_SPEC.md §8:
	- Idempotent: dijalankan dua kali tidak menggandakan, membersihkan instans lama.
	- Nol model 3D eksternal: semua dibangun lewat kode dari Part sederhana.
	- Model meja lengkap dengan Attributes (TableId, Mode) dan 4 kursi Seat valid.
	- Anchor per kursi: CameraAnchor, RackAnchor, HandRestAnchor.
	- Anchor meja: BoardCenter, DealOrigin, ShuffleZone.
	- Props malam kampung: termos, gelas kopi lurik, piring gorengan, sarung, radio jadul, obat nyamuk bakar.
	- Tanpa visual tembakau/rokok (patuh kebijakan konten).
	- Total part < 1.500 (hemat mobile).
]=]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoardLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoardLayout"))

local WorldBuilder = {}

-- Helper pembuat Part yang bersih
local function createPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.BrickColor = props.BrickColor or BrickColor.new("Medium stone grey")
	if props.Color then
		p.Color = props.Color
	end
	p.Size = props.Size or Vector3.new(1, 1, 1)
	p.CFrame = props.CFrame or CFrame.new()
	p.Anchored = if props.Anchored ~= nil then props.Anchored else true
	p.CanCollide = if props.CanCollide ~= nil then props.CanCollide else true
	p.CastShadow = if props.CastShadow ~= nil then props.CastShadow else true
	p.Name = props.Name or "Part"
	if props.Transparency then
		p.Transparency = props.Transparency
	end
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Parent = props.Parent
	return p
end

-- Membersihkan dunia pos ronda lama jika sudah ada (idempotent)
function WorldBuilder.Clean()
	local existing = workspace:FindFirstChild("PosRonda")
	if existing then
		existing:Destroy()
	end
end

-- Mengatur pencahayaan malam dan atmosfer kampung
function WorldBuilder.SetupLighting()
	Lighting.ClockTime = 0.5 -- Jam 00:30 malam
	Lighting.Brightness = 1.0
	Lighting.OutdoorAmbient = Color3.fromRGB(45, 55, 75)
	Lighting.Ambient = Color3.fromRGB(40, 48, 65)
	Lighting.ShadowSoftness = 0.2
	Lighting.GlobalShadows = true

	-- Bersihkan efek atmosfer lama buatan builder
	for _, child in ipairs(Lighting:GetChildren()) do
		if child.Name == "PosRondaAtmosphere" or child.Name == "PosRondaColorCorrection" or child.Name == "PosRondaBloom" then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "PosRondaAtmosphere"
	atmosphere.Density = 0.35
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(30, 38, 55)
	atmosphere.Decay = Color3.fromRGB(20, 25, 40)
	atmosphere.Glare = 0.05
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "PosRondaColorCorrection"
	colorCorrection.TintColor = Color3.fromRGB(255, 246, 235)
	colorCorrection.Saturation = 0.08
	colorCorrection.Contrast = 0.05
	colorCorrection.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "PosRondaBloom"
	bloom.Intensity = 0.35
	bloom.Size = 18
	bloom.Threshold = 1.1
	bloom.Parent = Lighting
end

-- Helper pembuat Kursi Bakso Plastik Hijau Anyaman Rattan Realistis (Iconic Indonesian Green Plastic Stool)
local function createKursiBakso(
	tableModel: Model,
	seatIndex: number,
	seatPos: Vector3,
	centerPos: Vector3,
	floorY: number,
	tableId: number
): Seat
	local targetFace = Vector3.new(centerPos.X, seatPos.Y, centerPos.Z)
	local seatCF = CFrame.lookAt(seatPos, targetFace)
	local legHeight = (seatPos.Y - 0.08) - floorY

	-- Palet warna hijau plastik anyaman warung (Lion Star / Napolly Hijau)
	local COLOR_MAIN = Color3.fromRGB(46, 148, 68)      -- Hijau plastik utama
	local COLOR_TOP_WOVEN = Color3.fromRGB(58, 168, 80) -- Hijau anyaman atas (aksen cerah)
	local COLOR_DARK = Color3.fromRGB(30, 105, 46)       -- Aksen celah & foot pads
	local COLOR_RIM = Color3.fromRGB(38, 128, 56)        -- Lis & profil penguat

	-- 1. DUDUKAN UTAMA (Seat instance untuk gameplay & prompt)
	local seatPart = Instance.new("Seat")
	seatPart.Name = "Seat" .. seatIndex
	seatPart.Material = Enum.Material.Plastic
	seatPart.Color = COLOR_MAIN
	seatPart.Size = Vector3.new(1.30, 0.16, 1.30)
	seatPart.CFrame = seatCF
	seatPart.Anchored = true
	seatPart.CanCollide = true
	seatPart.CastShadow = true
	seatPart.Disabled = true -- Cegah karakter tersedot otomatis saat jalan menyenggol kursi; duduk hanya via [E] prompt
	seatPart.SetAttribute(seatPart, "SeatIndex", seatIndex)
	seatPart.SetAttribute(seatPart, "TableId", tableId)

	-- 2. PANEL DUDUKAN ATAS BERMOTIF ANYAMAN RATTAN
	createPart({
		Name = "SeatTopWoven",
		Material = Enum.Material.Fabric, -- Serat mikro menyerupai anyaman rattan plastik
		Color = COLOR_TOP_WOVEN,
		Size = Vector3.new(1.10, 0.03, 1.10),
		CFrame = seatCF * CFrame.new(0, 0.095, 0),
		CanCollide = false,
		Parent = tableModel,
	})

	-- Lis bingkai pelindung di sekeliling anyaman atas
	local rimThickness = 0.10
	local rimHeight = 0.04
	local rimLength = 1.28
	local rimOffset = 0.58
	local rimConfigs = {
		{ name = "RimFront", size = Vector3.new(rimLength, rimHeight, rimThickness), offset = Vector3.new(0, 0.09, -rimOffset) },
		{ name = "RimBack",  size = Vector3.new(rimLength, rimHeight, rimThickness), offset = Vector3.new(0, 0.09, rimOffset) },
		{ name = "RimLeft",  size = Vector3.new(rimThickness, rimHeight, rimLength - 2 * rimThickness), offset = Vector3.new(-rimOffset, 0.09, 0) },
		{ name = "RimRight", size = Vector3.new(rimThickness, rimHeight, rimLength - 2 * rimThickness), offset = Vector3.new(rimOffset, 0.09, 0) },
	}
	for _, r in ipairs(rimConfigs) do
		createPart({
			Name = r.name,
			Material = Enum.Material.SmoothPlastic,
			Color = COLOR_RIM,
			Size = r.size,
			CFrame = seatCF * CFrame.new(r.offset),
			CanCollide = false,
			Parent = tableModel,
		})
	end

	-- 3. BIBIR CETAKAN BAWAH DUDUKAN (Seat Skirt / Bevel)
	createPart({
		Name = "SeatSkirt",
		Material = Enum.Material.SmoothPlastic,
		Color = COLOR_RIM,
		Size = Vector3.new(1.36, 0.10, 1.36),
		CFrame = seatCF * CFrame.new(0, -0.10, 0),
		CanCollide = false,
		Parent = tableModel,
	})

	-- 4. APRON / DINDING LENGKUNG DI ATAS LUBANG KAKI (4 Sisi)
	local apronWidth = 0.86
	local apronHeight = 0.22
	local apronThick = 0.08
	local apronY = -0.22
	local apronDist = 0.52
	local apronConfigs = {
		{ name = "ApronFront", size = Vector3.new(apronWidth, apronHeight, apronThick), offset = Vector3.new(0, apronY, -apronDist) },
		{ name = "ApronBack",  size = Vector3.new(apronWidth, apronHeight, apronThick), offset = Vector3.new(0, apronY, apronDist) },
		{ name = "ApronLeft",  size = Vector3.new(apronThick, apronHeight, apronWidth), offset = Vector3.new(-apronDist, apronY, 0) },
		{ name = "ApronRight", size = Vector3.new(apronThick, apronHeight, apronWidth), offset = Vector3.new(apronDist, apronY, 0) },
	}
	for _, a in ipairs(apronConfigs) do
		createPart({
			Name = a.name,
			Material = Enum.Material.SmoothPlastic,
			Color = COLOR_MAIN,
			Size = a.size,
			CFrame = seatCF * CFrame.new(a.offset),
			CanCollide = false,
			Parent = tableModel,
		})
	end

	-- 5. 4 KAKI PLASTIK MIRING MELEBAR KE BAWAH (TAPERED L-PROFILE LEGS)
	local topRadius = 0.50
	local botRadius = 0.65
	local corners = {
		{ name = "LegFL", signX = -1, signZ = -1 },
		{ name = "LegFR", signX =  1, signZ = -1 },
		{ name = "LegBL", signX = -1, signZ =  1 },
		{ name = "LegBR", signX =  1, signZ =  1 },
	}

	for _, c in ipairs(corners) do
		local topPos = (seatCF * CFrame.new(c.signX * topRadius, -0.14, c.signZ * topRadius)).Position
		local botPos = (seatCF * CFrame.new(c.signX * botRadius, -legHeight, c.signZ * botRadius)).Position
		local legMid = (topPos + botPos) / 2
		local legDir = (botPos - topPos)
		local legLen = legDir.Magnitude
		local legAngleCF = CFrame.lookAt(legMid, botPos) * CFrame.Angles(math.rad(90), 0, 0)

		-- Tiang Kaki Utama
		createPart({
			Name = c.name,
			Material = Enum.Material.Plastic,
			Color = COLOR_MAIN,
			Size = Vector3.new(0.18, legLen, 0.18),
			CFrame = legAngleCF,
			CanCollide = true,
			Parent = tableModel,
		})

		-- Bilah Siku Penguat Luar Kaki (L-Profile Flange khas kursi cetakan)
		createPart({
			Name = c.name .. "_FlangeX",
			Material = Enum.Material.SmoothPlastic,
			Color = COLOR_RIM,
			Size = Vector3.new(0.06, legLen * 0.95, 0.22),
			CFrame = legAngleCF * CFrame.new(c.signX * 0.06, 0, 0),
			CanCollide = false,
			Parent = tableModel,
		})
		createPart({
			Name = c.name .. "_FlangeZ",
			Material = Enum.Material.SmoothPlastic,
			Color = COLOR_RIM,
			Size = Vector3.new(0.22, legLen * 0.95, 0.06),
			CFrame = legAngleCF * CFrame.new(0, 0, c.signZ * 0.06),
			CanCollide = false,
			Parent = tableModel,
		})

		-- Karet / Bantalan Kaki di Lantai (Foot Pad)
		createPart({
			Name = c.name .. "_Pad",
			Material = Enum.Material.SmoothPlastic,
			Color = COLOR_DARK,
			Size = Vector3.new(0.22, 0.07, 0.22),
			CFrame = CFrame.new(botPos.X, floorY + 0.035, botPos.Z),
			CanCollide = true,
			Parent = tableModel,
		})
	end

	-- 6. PENYANGGA KAKI HORIZONTAL BERTINGKAT (FOOTREST STRETCHER BARS)
	-- Sisi Depan & Belakang posisinya sedikit lebih rendah
	local barLowY = floorY + legHeight * 0.28
	local barLowRelY = barLowY - seatPos.Y
	local barLowSpread = topRadius + (botRadius - topRadius) * 0.72
	createPart({
		Name = "FootrestFront",
		Material = Enum.Material.SmoothPlastic,
		Color = COLOR_DARK,
		Size = Vector3.new(barLowSpread * 1.85, 0.12, 0.08),
		CFrame = seatCF * CFrame.new(0, barLowRelY, -barLowSpread),
		CanCollide = true,
		Parent = tableModel,
	})
	createPart({
		Name = "FootrestBack",
		Material = Enum.Material.SmoothPlastic,
		Color = COLOR_DARK,
		Size = Vector3.new(barLowSpread * 1.85, 0.12, 0.08),
		CFrame = seatCF * CFrame.new(0, barLowRelY, barLowSpread),
		CanCollide = true,
		Parent = tableModel,
	})

	-- Sisi Kiri & Kanan posisinya sedikit lebih tinggi (khas kursi plastik tumpuk)
	local barHighY = floorY + legHeight * 0.40
	local barHighRelY = barHighY - seatPos.Y
	local barHighSpread = topRadius + (botRadius - topRadius) * 0.60
	createPart({
		Name = "FootrestLeft",
		Material = Enum.Material.SmoothPlastic,
		Color = COLOR_DARK,
		Size = Vector3.new(0.08, 0.12, barHighSpread * 1.85),
		CFrame = seatCF * CFrame.new(-barHighSpread, barHighRelY, 0),
		CanCollide = true,
		Parent = tableModel,
	})
	createPart({
		Name = "FootrestRight",
		Material = Enum.Material.SmoothPlastic,
		Color = COLOR_DARK,
		Size = Vector3.new(0.08, 0.12, barHighSpread * 1.85),
		CFrame = seatCF * CFrame.new(barHighSpread, barHighRelY, 0),
		CanCollide = true,
		Parent = tableModel,
	})

	-- 7. ATTACHMENT ANCHOR POV FIRST-PERSON & GAMEPLAY
	local camAnchor = Instance.new("Attachment")
	camAnchor.Name = "CameraAnchor"
	camAnchor.CFrame = CFrame.new(0, 1.85, 0)
	camAnchor.Parent = seatPart

	local rackAnchor = Instance.new("Attachment")
	rackAnchor.Name = "RackAnchor"
	rackAnchor.CFrame = CFrame.new(0, 1.45, -0.60)
	rackAnchor.Parent = seatPart

	local handRestAnchor = Instance.new("Attachment")
	handRestAnchor.Name = "HandRestAnchor"
	handRestAnchor.CFrame = CFrame.new(0, 1.35, -0.35)
	handRestAnchor.Parent = seatPart

	seatPart.Parent = tableModel
	return seatPart
end

-- Helper pembuat Meja Kotak Kayu Gaplek Proporsional (6.6 x 6.6 stud) & 4 Kursi Bakso
local function createGaplekTable(
	parent: Instance,
	tableId: number,
	modelName: string,
	centerPos: Vector3,
	floorY: number,
	displayName: string
): Model
	local tableModel = Instance.new("Model")
	tableModel.Name = modelName
	tableModel.SetAttribute(tableModel, "TableId", tableId)
	tableModel.SetAttribute(tableModel, "DisplayName", displayName)
	tableModel.SetAttribute(tableModel, "Mode", "2v2")
	tableModel.Parent = parent

	-- Ketinggian proporsional meja kotak gaplek & dimensi dari BoardLayout
	local tableSize = BoardLayout.GetTableSize()
	local tableSpan = tableSize.X
	local tableHalf = tableSpan / 2
	local seatHeight = floorY + 1.25
	local tableSurfaceY = floorY + 2.70
	local tableThickness = tableSize.Y
	local tableTopCenterY = tableSurfaceY - tableThickness / 2

	-- 1. Daun meja kotak kayu (6.6 x 6.6 stud)
	local tableTop = createPart({
		Name = "TableTop",
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(130, 92, 58),
		Size = Vector3.new(tableSpan, tableThickness, tableSpan),
		CFrame = CFrame.new(centerPos.X, tableTopCenterY, centerPos.Z),
		Parent = tableModel,
	})
	tableModel.PrimaryPart = tableTop

	-- Lis pinggiran meja kayu
	local trimOffset = tableHalf + 0.02
	local trimSizeX = Vector3.new(tableSpan + 0.10, 0.32, 0.10)
	local trimSizeZ = Vector3.new(0.10, 0.32, tableSpan + 0.10)
	createPart({
		Name = "TableTrimF",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(95, 65, 40),
		Size = trimSizeX,
		CFrame = CFrame.new(centerPos.X, tableTopCenterY, centerPos.Z + trimOffset),
		Parent = tableModel,
	})
	createPart({
		Name = "TableTrimB",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(95, 65, 40),
		Size = trimSizeX,
		CFrame = CFrame.new(centerPos.X, tableTopCenterY, centerPos.Z - trimOffset),
		Parent = tableModel,
	})
	createPart({
		Name = "TableTrimL",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(95, 65, 40),
		Size = trimSizeZ,
		CFrame = CFrame.new(centerPos.X - trimOffset, tableTopCenterY, centerPos.Z),
		Parent = tableModel,
	})
	createPart({
		Name = "TableTrimR",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(95, 65, 40),
		Size = trimSizeZ,
		CFrame = CFrame.new(centerPos.X + trimOffset, tableTopCenterY, centerPos.Z),
		Parent = tableModel,
	})

	-- 2. 4 Kaki meja kayu kokoh
	local legHeight = tableTopCenterY - floorY
	local legCenterY = floorY + legHeight / 2
	local legPosOffset = tableHalf - 0.45
	local legOffsets = {
		Vector3.new(-legPosOffset, legCenterY, -legPosOffset),
		Vector3.new(legPosOffset, legCenterY, -legPosOffset),
		Vector3.new(-legPosOffset, legCenterY, legPosOffset),
		Vector3.new(legPosOffset, legCenterY, legPosOffset),
	}
	for i, lOffset in ipairs(legOffsets) do
		createPart({
			Name = "TableLeg" .. i,
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(95, 65, 40),
			Size = Vector3.new(0.55, legHeight, 0.55),
			CFrame = CFrame.new(centerPos.X + lOffset.X, legCenterY, centerPos.Z + lOffset.Z),
			Parent = tableModel,
		})
	end

	-- Palang penyangga bawah meja
	local braceSpan = tableSpan - 0.80
	createPart({
		Name = "TableBraceX",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(85, 58, 36),
		Size = Vector3.new(braceSpan, 0.35, 0.35),
		CFrame = CFrame.new(centerPos.X, floorY + 0.6, centerPos.Z),
		Parent = tableModel,
	})
	createPart({
		Name = "TableBraceZ",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(85, 58, 36),
		Size = Vector3.new(0.35, 0.35, braceSpan),
		CFrame = CFrame.new(centerPos.X, floorY + 0.6, centerPos.Z),
		Parent = tableModel,
	})

	-- 3. Gameplay Anchors (BoardCenter, DealOrigin, ShuffleZone)
	local boardCenter = createPart({
		Name = "BoardCenter",
		Transparency = 1,
		CanCollide = false,
		Size = Vector3.new(1, 0.2, 1),
		CFrame = CFrame.new(centerPos.X, tableSurfaceY, centerPos.Z),
		Parent = tableModel,
	})
	local dealOriginAtt = Instance.new("Attachment")
	dealOriginAtt.Name = "DealOrigin"
	dealOriginAtt.Position = Vector3.new(0, 0.3, 0)
	dealOriginAtt.Parent = boardCenter

	local shuffleZoneAtt = Instance.new("Attachment")
	shuffleZoneAtt.Name = "ShuffleZone"
	shuffleZoneAtt.Position = Vector3.new(0, 0.05, 0)
	shuffleZoneAtt.Parent = boardCenter

	-- 4. 4 Kursi Bakso Plastik Hijau (Jarak SEAT_DISTANCE = 3.55 stud dari pusat meja menghadap ke tengah)
	local seatDist = BoardLayout.GetSeatDistance()
	local seatConfigs = {
		{ id = 1, pos = centerPos + Vector3.new(0, seatHeight, seatDist) },
		{ id = 2, pos = centerPos + Vector3.new(seatDist, seatHeight, 0) },
		{ id = 3, pos = centerPos + Vector3.new(0, seatHeight, -seatDist) },
		{ id = 4, pos = centerPos + Vector3.new(-seatDist, seatHeight, 0) },
	}

	for _, sCfg in ipairs(seatConfigs) do
		createKursiBakso(tableModel, sCfg.id, sCfg.pos, centerPos, floorY, tableId)
	end

	return tableModel
end

-- Membangun seluruh dunia pos ronda
function WorldBuilder.Build(): Model
	WorldBuilder.Clean()
	WorldBuilder.SetupLighting()

	local root = Instance.new("Model")
	root.Name = "PosRonda"

	local floorY = 0.5
	local platformHeight = 0.8
	local platformY = floorY + platformHeight / 2 -- Y = 0.9
	local platformTopY = floorY + platformHeight -- Y = 1.3

	----------------------------------------------------------------------------
	-- 1. TANAH & JALAN GANG KAMPUNG
	----------------------------------------------------------------------------
	local groundFolder = Instance.new("Folder")
	groundFolder.Name = "Ground"
	groundFolder.Parent = root

	-- Tanah tanah liat/rumput gelap sekitar pos
	createPart({
		Name = "GroundDirt",
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(38, 34, 28),
		Size = Vector3.new(60, 1, 60),
		CFrame = CFrame.new(0, 0, 0),
		Parent = groundFolder,
	})

	-- Jalan paving gang di sebelah pos (panjang di sumbu Z)
	createPart({
		Name = "GangPaving",
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(80, 80, 78),
		Size = Vector3.new(12, 0.4, 60),
		CFrame = CFrame.new(16, 0.5, 0),
		Parent = groundFolder,
	})

	-- Selokan kecil di tepi gang
	createPart({
		Name = "SelokanEdge",
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(55, 55, 55),
		Size = Vector3.new(1.2, 0.6, 60),
		CFrame = CFrame.new(9.5, 0.4, 0),
		Parent = groundFolder,
	})

	----------------------------------------------------------------------------
	-- 2. PANGGUNG POS RONDA (12x12 Stud)
	----------------------------------------------------------------------------
	local posFolder = Instance.new("Folder")
	posFolder.Name = "Structure"
	posFolder.Parent = root

	-- Fondasi umpak batu di 4 sudut panggung
	local cornerCoords = {
		Vector3.new(-5.5, 0.5, -5.5),
		Vector3.new(5.5, 0.5, -5.5),
		Vector3.new(-5.5, 0.5, 5.5),
		Vector3.new(5.5, 0.5, 5.5),
	}
	for i, coord in ipairs(cornerCoords) do
		createPart({
			Name = "UmpakBatu" .. i,
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(75, 75, 70),
			Size = Vector3.new(1.4, 1.0, 1.4),
			CFrame = CFrame.new(coord),
			Parent = posFolder,
		})
	end

	-- Lantai panggung kayu balok
	createPart({
		Name = "PlatformFloor",
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(115, 82, 52),
		Size = Vector3.new(12.5, platformHeight, 12.5),
		CFrame = CFrame.new(0, platformY, 0),
		Parent = posFolder,
	})

	-- 4 Tiang kayu penyangga atap
	local tiangHeight = 7.5
	local tiangCenterY = platformTopY + tiangHeight / 2
	for i, coord in ipairs(cornerCoords) do
		-- Tiang kayu dengan sedikit variasi alami
		createPart({
			Name = "TiangKayu" .. i,
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(90, 62, 38),
			Size = Vector3.new(0.85, tiangHeight, 0.85),
			CFrame = CFrame.new(coord.X, tiangCenterY, coord.Z),
			Parent = posFolder,
		})
	end

	-- Balok ring atas pengikat tiang
	createPart({
		Name = "RingBalokFront",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(85, 58, 35),
		Size = Vector3.new(12.2, 0.6, 0.6),
		CFrame = CFrame.new(0, platformTopY + tiangHeight - 0.3, 5.5),
		Parent = posFolder,
	})
	createPart({
		Name = "RingBalokBack",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(85, 58, 35),
		Size = Vector3.new(12.2, 0.6, 0.6),
		CFrame = CFrame.new(0, platformTopY + tiangHeight - 0.3, -5.5),
		Parent = posFolder,
	})
	createPart({
		Name = "RingBalokLeft",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(85, 58, 35),
		Size = Vector3.new(0.6, 0.6, 11.6),
		CFrame = CFrame.new(-5.5, platformTopY + tiangHeight - 0.3, 0),
		Parent = posFolder,
	})
	createPart({
		Name = "RingBalokRight",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(85, 58, 35),
		Size = Vector3.new(0.6, 0.6, 11.6),
		CFrame = CFrame.new(5.5, platformTopY + tiangHeight - 0.3, 0),
		Parent = posFolder,
	})

	-- Atap seng miring khas pos ronda kampung (kemiringan ringan ke arah belakang)
	local roofY = platformTopY + tiangHeight + 0.6
	createPart({
		Name = "AtapSeng",
		Material = Enum.Material.CorrodedMetal,
		Color = Color3.fromRGB(95, 100, 95),
		Size = Vector3.new(14.5, 0.3, 14.5),
		CFrame = CFrame.new(0, roofY, 0) * CFrame.Angles(math.rad(-6), 0, 0),
		Parent = posFolder,
	})

	-- Lis tepi atap
	createPart({
		Name = "LisAtapFront",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(70, 48, 28),
		Size = Vector3.new(14.7, 0.4, 0.3),
		CFrame = CFrame.new(0, roofY - 0.6, 7.1),
		Parent = posFolder,
	})

	-- Pagar pembatas samping rendah (railing kayu di 2 sisi)
	createPart({
		Name = "PagarSampingKiri",
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(100, 70, 42),
		Size = Vector3.new(0.4, 1.8, 11.5),
		CFrame = CFrame.new(-5.9, platformTopY + 0.9, 0),
		Parent = posFolder,
	})
	createPart({
		Name = "PagarSampingBelakang",
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(100, 70, 42),
		Size = Vector3.new(11.5, 1.8, 0.4),
		CFrame = CFrame.new(0, platformTopY + 0.9, -5.9),
		Parent = posFolder,
	})

	----------------------------------------------------------------------------
	-- 3. BALE-BALE BAMBU (Sisi Kiri Pos Ronda)
	----------------------------------------------------------------------------
	local baleFolder = Instance.new("Folder")
	baleFolder.Name = "BaleBale"
	baleFolder.Parent = root

	local baleY = platformTopY + 0.6
	createPart({
		Name = "BalePlatform",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(165, 142, 92),
		Size = Vector3.new(2.4, 0.4, 8.5),
		CFrame = CFrame.new(-4.4, baleY, 0),
		Parent = baleFolder,
	})
	-- Sandaran bale-bale
	createPart({
		Name = "BaleSandaran",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(150, 125, 78),
		Size = Vector3.new(0.4, 1.2, 8.5),
		CFrame = CFrame.new(-5.4, baleY + 0.8, 0),
		Parent = baleFolder,
	})

	----------------------------------------------------------------------------
	-- 4. EMPAT MEJA GAPLEK & KURSI BAKSO PLASTIK HIJAU
	----------------------------------------------------------------------------
	local tablesFolder = Instance.new("Folder")
	tablesFolder.Name = "Tables"
	tablesFolder.Parent = root

	-- A. MEJA 1: POS UTAMA (Di tengah panggung Pos Ronda)
	-- Menggunakan nama "Table" untuk kompatibilitas penuh dengan sistem lama & tes unit
	local tableModel = createGaplekTable(root, 1, "Table", Vector3.new(0, 0, 0), platformTopY, "Meja 1 (Pos Utama)")
	local tableSurfaceY = platformTopY + 2.70

	-- B. MEJA 2: BALE WARKOP (Warung Kopi & Gorengan di samping gang)
	local warkopFolder = Instance.new("Folder")
	warkopFolder.Name = "WarkopStation"
	warkopFolder.Parent = root

	local warkopFloorY = 0.80
	local warkopCenter = Vector3.new(18, 0, -4)
	-- Dek lantai kayu warkop
	createPart({
		Name = "WarkopFloor",
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(110, 80, 50),
		Size = Vector3.new(13.0, 0.5, 13.0),
		CFrame = CFrame.new(warkopCenter.X, warkopFloorY - 0.25, warkopCenter.Z),
		Parent = warkopFolder,
	})
	-- Meja 2 di atas dek warkop
	createGaplekTable(root, 2, "Table_2", warkopCenter, warkopFloorY, "Meja 2 (Bale Warkop)")

	-- Gerobak / Etalase Counter Warkop
	local counterPos = Vector3.new(warkopCenter.X + 5.2, warkopFloorY + 1.6, warkopCenter.Z)
	createPart({
		Name = "WarkopCounter",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(85, 58, 38),
		Size = Vector3.new(1.6, 2.2, 8.0),
		CFrame = CFrame.new(counterPos),
		Parent = warkopFolder,
	})
	-- Spanduk Kain Warkop
	local bannerPart = createPart({
		Name = "SpandukWarkop",
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(235, 230, 215),
		Size = Vector3.new(0.1, 1.4, 7.5),
		CFrame = CFrame.new(counterPos.X, counterPos.Y + 2.8, counterPos.Z),
		Parent = warkopFolder,
	})
	local bannerGui = Instance.new("SurfaceGui")
	bannerGui.Name = "BannerGui"
	bannerGui.Face = Enum.NormalId.Left
	bannerGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	bannerGui.PixelsPerStud = 40
	bannerGui.Parent = bannerPart

	local bannerLabel = Instance.new("TextLabel")
	bannerLabel.Size = UDim2.new(1, 0, 1, 0)
	bannerLabel.BackgroundTransparency = 1
	bannerLabel.Font = Enum.Font.FredokaOne
	bannerLabel.TextSize = 22
	bannerLabel.TextColor3 = Color3.fromRGB(180, 40, 30)
	bannerLabel.Text = "★ WARKOP RONDA RT 05 ★\nKOPI TUBRUK • GORENGAN • TEH TARIK"
	bannerLabel.Parent = bannerGui

	-- Kaleng kerupuk blek biru jadul di counter
	createPart({
		Name = "KalengKerupuk",
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(45, 95, 175),
		Size = Vector3.new(0.8, 1.2, 0.8),
		CFrame = CFrame.new(counterPos.X, counterPos.Y + 1.5, counterPos.Z - 2.0),
		Parent = warkopFolder,
	})

	-- Lampu gantung warm di atas Meja 2
	local warkopBulb = createPart({
		Name = "WarkopBohlam",
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 235, 175),
		Size = Vector3.new(0.4, 0.4, 0.4),
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(warkopCenter.X, warkopFloorY + 5.5, warkopCenter.Z),
		CanCollide = false,
		Parent = warkopFolder,
	})
	local warkopLight = Instance.new("PointLight")
	warkopLight.Color = Color3.fromRGB(255, 215, 145)
	warkopLight.Range = 20
	warkopLight.Brightness = 2.8
	warkopLight.Parent = warkopBulb

	-- C. MEJA 3: GAZEBO BAMBU (Sisi Kiri Pos Ronda)
	local gazeboFolder = Instance.new("Folder")
	gazeboFolder.Name = "GazeboStation"
	gazeboFolder.Parent = root

	local gazeboFloorY = 0.80
	local gazeboCenter = Vector3.new(-18, 0, -4)
	-- Dek bambu gazebo
	createPart({
		Name = "GazeboFloor",
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(150, 125, 78),
		Size = Vector3.new(12.0, 0.5, 12.0),
		CFrame = CFrame.new(gazeboCenter.X, gazeboFloorY - 0.25, gazeboCenter.Z),
		Parent = gazeboFolder,
	})
	-- Meja 3 di atas gazebo
	createGaplekTable(root, 3, "Table_3", gazeboCenter, gazeboCenter.Y + gazeboFloorY, "Meja 3 (Gazebo Bambu)")

	-- 4 Tiang Bambu Gazebo
	local gPosts = {
		Vector3.new(-5.2, 3.2, -5.2),
		Vector3.new(5.2, 3.2, -5.2),
		Vector3.new(-5.2, 3.2, 5.2),
		Vector3.new(5.2, 3.2, 5.2),
	}
	for pIdx, pOffset in ipairs(gPosts) do
		createPart({
			Name = "GazeboPost" .. pIdx,
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(130, 105, 65),
			Size = Vector3.new(0.65, 6.5, 0.65),
			CFrame = CFrame.new(gazeboCenter + pOffset),
			Parent = gazeboFolder,
		})
	end
	-- Atap Ijuk Piramida Gazebo
	createPart({
		Name = "GazeboRoof",
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(55, 45, 35),
		Size = Vector3.new(13.5, 0.8, 13.5),
		CFrame = CFrame.new(gazeboCenter.X, gazeboFloorY + 6.6, gazeboCenter.Z),
		Parent = gazeboFolder,
	})
	-- Lentera teplok di tengah gazebo
	local gazeboBulb = createPart({
		Name = "GazeboLentera",
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 230, 160),
		Size = Vector3.new(0.4, 0.4, 0.4),
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(gazeboCenter.X, gazeboFloorY + 5.2, gazeboCenter.Z),
		CanCollide = false,
		Parent = gazeboFolder,
	})
	local gazeboLight = Instance.new("PointLight")
	gazeboLight.Color = Color3.fromRGB(255, 200, 130)
	gazeboLight.Range = 20
	gazeboLight.Brightness = 2.6
	gazeboLight.Parent = gazeboBulb

	-- D. MEJA 4: PELATARAN DEPAN (Courtyard Terbuka di Bawah Lampu Tali)
	local pelataranFolder = Instance.new("Folder")
	pelataranFolder.Name = "PelataranStation"
	pelataranFolder.Parent = root

	local pelataranFloorY = 0.60
	local pelataranCenter = Vector3.new(0, 0, -18)
	-- Lantai paving pelataran
	createPart({
		Name = "PelataranPaving",
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(75, 75, 75),
		Size = Vector3.new(14.0, 0.3, 14.0),
		CFrame = CFrame.new(pelataranCenter.X, pelataranFloorY - 0.15, pelataranCenter.Z),
		Parent = pelataranFolder,
	})
	-- Meja 4 di pelataran
	createGaplekTable(root, 4, "Table_4", pelataranCenter, pelataranFloorY, "Meja 4 (Pelataran Depan)")

	-- 2 Tiang kabel lampu gantung pelataran
	createPart({
		Name = "TiangLampuPelataran1",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(85, 60, 40),
		Size = Vector3.new(0.5, 6.0, 0.5),
		CFrame = CFrame.new(-6.0, pelataranFloorY + 3.0, -18),
		Parent = pelataranFolder,
	})
	createPart({
		Name = "TiangLampuPelataran2",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(85, 60, 40),
		Size = Vector3.new(0.5, 6.0, 0.5),
		CFrame = CFrame.new(6.0, pelataranFloorY + 3.0, -18),
		Parent = pelataranFolder,
	})
	-- Tali kabel lampu melintang
	createPart({
		Name = "TaliLampuPelataran",
		Material = Enum.Material.Plastic,
		Color = Color3.fromRGB(25, 25, 25),
		Size = Vector3.new(12.0, 0.06, 0.06),
		CFrame = CFrame.new(0, pelataranFloorY + 5.6, -18),
		CanCollide = false,
		Parent = pelataranFolder,
	})
	-- 3 Bohlam gantung pelataran
	for bIdx = -1, 1 do
		local bPart = createPart({
			Name = "BohlamPelataran" .. (bIdx + 2),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 235, 175),
			Size = Vector3.new(0.35, 0.4, 0.35),
			Shape = Enum.PartType.Ball,
			CFrame = CFrame.new(bIdx * 3.8, pelataranFloorY + 5.2, -18),
			CanCollide = false,
			Parent = pelataranFolder,
		})
		local pLight = Instance.new("PointLight")
		pLight.Color = Color3.fromRGB(255, 215, 145)
		pLight.Range = 16
		pLight.Brightness = 2.2
		pLight.Parent = bPart
	end

	----------------------------------------------------------------------------
	-- 6. BOHLAM GANTUNG & PENCAHAYAAN MEJA (2700K Warm Light)
	----------------------------------------------------------------------------
	local lampFolder = Instance.new("Folder")
	lampFolder.Name = "LightingFixtures"
	lampFolder.Parent = root

	local bulbY = platformTopY + tiangHeight - 1.2
	-- Kabel gantung tipis dari atap ke bohlam
	createPart({
		Name = "KabelBohlam",
		Material = Enum.Material.Plastic,
		Color = Color3.fromRGB(20, 20, 20),
		Size = Vector3.new(0.08, 1.6, 0.08),
		CFrame = CFrame.new(0, bulbY + 0.8, 0),
		CanCollide = false,
		Parent = lampFolder,
	})

	-- Fitting bohlam hitam
	createPart({
		Name = "FittingBohlam",
		Material = Enum.Material.Plastic,
		Color = Color3.fromRGB(35, 35, 35),
		Size = Vector3.new(0.35, 0.25, 0.35),
		CFrame = CFrame.new(0, bulbY + 0.15, 0),
		CanCollide = false,
		Parent = lampFolder,
	})

	-- Bohlam kaca bulat menyala (Neon)
	local bulb = createPart({
		Name = "Bohlam",
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 235, 175),
		Size = Vector3.new(0.45, 0.5, 0.45),
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(0, bulbY - 0.15, 0),
		CanCollide = false,
		Parent = lampFolder,
	})

	-- Sumber cahaya PointLight utama
	local light = Instance.new("PointLight")
	light.Name = "MainPointLight"
	light.Color = Color3.fromRGB(255, 210, 140) -- Kuning hangat 2700K
	light.Range = 25
	light.Brightness = 3.5
	light.Shadows = true
	light.Parent = bulb

	----------------------------------------------------------------------------
	-- 7. KENTONGAN & PAPAN JADWAL RONDA
	----------------------------------------------------------------------------
	local propsFolder = Instance.new("Folder")
	propsFolder.Name = "Props"
	propsFolder.Parent = root

	-- Kentongan tergantung di tiang depan kanan (Tiang 2)
	local kentonganCenter = Vector3.new(5.0, platformTopY + 4.2, 5.0)
	createPart({
		Name = "KentonganBody",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(110, 75, 45),
		Size = Vector3.new(0.65, 2.2, 0.65),
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(kentonganCenter) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = propsFolder,
	})
	-- Lubang celah kentongan
	createPart({
		Name = "KentonganSlot",
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(25, 18, 12),
		Size = Vector3.new(0.12, 1.5, 0.35),
		CFrame = CFrame.new(kentonganCenter.X - 0.25, kentonganCenter.Y, kentonganCenter.Z),
		Parent = propsFolder,
	})
	-- Pemukul kentongan kecil
	createPart({
		Name = "PemukulKentongan",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(130, 90, 55),
		Size = Vector3.new(0.15, 1.1, 0.15),
		CFrame = CFrame.new(kentonganCenter.X + 0.3, kentonganCenter.Y - 0.2, kentonganCenter.Z + 0.2) * CFrame.Angles(math.rad(15), 0, math.rad(20)),
		Parent = propsFolder,
	})

	-- Papan jadwal ronda di tiang kiri depan (Tiang 3 / 1)
	local boardPart = createPart({
		Name = "PapanJadwal",
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(140, 120, 95),
		Size = Vector3.new(0.15, 2.0, 1.5),
		CFrame = CFrame.new(-5.4, platformTopY + 3.8, 3.2),
		Parent = propsFolder,
	})
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "JadwalGui"
	surfaceGui.Face = Enum.NormalId.Right
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 50
	surfaceGui.Parent = boardPart

	local jadwalText = Instance.new("TextLabel")
	jadwalText.Size = UDim2.new(1, 0, 1, 0)
	jadwalText.BackgroundTransparency = 1
	jadwalText.Font = Enum.Font.SpecialElite
	jadwalText.TextSize = 14
	jadwalText.TextColor3 = Color3.fromRGB(40, 30, 20)
	jadwalText.Text = "JADWAL RONDA\nRT 03 / RW 05\n---\nSEN: PAK RT\nSEL: JOKO\nRAB: AGUS\nKAM: BUDI\nJUM: SLAMET\nSAB: RONDA BERSAMA"
	jadwalText.TextWrapped = true
	jadwalText.Parent = surfaceGui

	----------------------------------------------------------------------------
	-- 8. PROPS MEJA & POS RONDA (Detail & Kehangatan Suasana)
	----------------------------------------------------------------------------
	-- Termos air panas jadul (merah klasik) di sudut meja
	local termosBase = Vector3.new(2.8, tableSurfaceY, 2.8)
	createPart({
		Name = "TermosBody",
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(175, 40, 40),
		Size = Vector3.new(0.7, 1.2, 0.7),
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(termosBase.X, tableSurfaceY + 0.6, termosBase.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = propsFolder,
	})
	createPart({
		Name = "TermosCap",
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(220, 220, 220),
		Size = Vector3.new(0.5, 0.25, 0.5),
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(termosBase.X, tableSurfaceY + 1.25, termosBase.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = propsFolder,
	})

	-- Gelas kopi lurik / beling di sisi pemain 1
	local cupPos = Vector3.new(-1.6, tableSurfaceY, 3.2)
	createPart({
		Name = "GelasKopi",
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(230, 240, 235),
		Size = Vector3.new(0.45, 0.55, 0.45),
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(cupPos.X, tableSurfaceY + 0.28, cupPos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = propsFolder,
	})
	createPart({
		Name = "KopiHitam",
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(20, 15, 10),
		Size = Vector3.new(0.4, 0.08, 0.4),
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(cupPos.X, tableSurfaceY + 0.48, cupPos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = propsFolder,
	})

	-- Piring seng gorengan (tempe / bakwan kuning keemasan)
	local piringPos = Vector3.new(1.8, tableSurfaceY, -2.8)
	createPart({
		Name = "PiringSeng",
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(215, 215, 215),
		Size = Vector3.new(1.4, 0.08, 1.4),
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(piringPos.X, tableSurfaceY + 0.04, piringPos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = propsFolder,
	})
	-- 3 Potong gorengan di atas piring
	for gIdx = 1, 3 do
		createPart({
			Name = "Gorengan" .. gIdx,
			Material = Enum.Material.Sand,
			Color = Color3.fromRGB(210, 150, 45),
			Size = Vector3.new(0.45, 0.12, 0.35),
			CFrame = CFrame.new(piringPos.X + (gIdx - 2) * 0.28, tableSurfaceY + 0.14, piringPos.Z + (gIdx % 2) * 0.1) * CFrame.Angles(0, math.rad(gIdx * 35), 0),
			Parent = propsFolder,
		})
	end

	-- Sarung tersampir di sandaran bale-bale
	createPart({
		Name = "SarungKotak",
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(50, 95, 75), -- Sarung hijau kotak
		Size = Vector3.new(0.45, 0.8, 1.8),
		CFrame = CFrame.new(-5.4, baleY + 0.7, 1.5),
		Parent = propsFolder,
	})

	-- Radio jadul portabel di ujung bale-bale
	local radioPos = Vector3.new(-4.5, baleY + 0.4, -2.8)
	createPart({
		Name = "RadioJadul",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(120, 80, 50),
		Size = Vector3.new(0.8, 0.55, 0.4),
		CFrame = CFrame.new(radioPos),
		Parent = propsFolder,
	})
	-- Speaker grille radio
	createPart({
		Name = "RadioGrille",
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(40, 35, 30),
		Size = Vector3.new(0.4, 0.35, 0.05),
		CFrame = CFrame.new(radioPos.X, radioPos.Y, radioPos.Z + 0.21),
		Parent = propsFolder,
	})
	-- Antena radio
	createPart({
		Name = "RadioAntenna",
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(180, 180, 180),
		Size = Vector3.new(0.05, 0.9, 0.05),
		CFrame = CFrame.new(radioPos.X + 0.3, radioPos.Y + 0.6, radioPos.Z - 0.1) * CFrame.Angles(0, 0, math.rad(-15)),
		Parent = propsFolder,
	})

	-- Obat nyamuk bakar hijau di lantai sudut panggung (asap tipis partikel)
	local nyamukPos = Vector3.new(4.8, platformTopY, -4.8)
	createPart({
		Name = "ObatNyamukTatakan",
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(160, 160, 160),
		Size = Vector3.new(0.65, 0.04, 0.65),
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(nyamukPos.X, platformTopY + 0.02, nyamukPos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = propsFolder,
	})
	local obatNyamukCoil = createPart({
		Name = "ObatNyamukCoil",
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(45, 90, 55), -- Hijau gelap obat nyamuk
		Size = Vector3.new(0.48, 0.05, 0.48),
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(nyamukPos.X, platformTopY + 0.06, nyamukPos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = propsFolder,
	})

	-- Bara merah kecil & partikel asap tipis halus
	local bara = createPart({
		Name = "ObatNyamukBara",
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 80, 20),
		Size = Vector3.new(0.08, 0.08, 0.08),
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(nyamukPos.X + 0.18, platformTopY + 0.08, nyamukPos.Z),
		CanCollide = false,
		Parent = propsFolder,
	})
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "SmokeParticle"
	smoke.Color = ColorSequence.new(Color3.fromRGB(180, 180, 180))
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.5, 0.18),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	smoke.Lifetime = NumberRange.new(2.5, 4.0)
	smoke.Rate = 6
	smoke.Speed = NumberRange.new(0.4, 0.8)
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.Acceleration = Vector3.new(0.1, 0.3, 0.05)
	smoke.Parent = bara

	----------------------------------------------------------------------------
	-- 9. LINGKUNGAN GANG KAMPUNG (Tembok, Rumah Tetangga, Pohon Pisang, Tiang Listrik)
	----------------------------------------------------------------------------
	local envFolder = Instance.new("Folder")
	envFolder.Name = "Environment"
	envFolder.Parent = root

	-- Tembok pagar bata di belakang pos ronda
	createPart({
		Name = "TembokPagarBelakang",
		Material = Enum.Material.Brick,
		Color = Color3.fromRGB(90, 85, 80),
		Size = Vector3.new(32, 5.5, 1.2),
		CFrame = CFrame.new(2, 2.75, -12),
		Parent = envFolder,
	})

	-- Rumah tetangga berbentuk blok dengan jendela menyala kuning hangat
	local rumahCenter = Vector3.new(-18, 5.0, 0)
	createPart({
		Name = "RumahBlok",
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(70, 72, 75),
		Size = Vector3.new(14, 10, 24),
		CFrame = CFrame.new(rumahCenter),
		Parent = envFolder,
	})
	-- Jendela menyala hangat di rumah tetangga (cahaya sekunder)
	local window = createPart({
		Name = "JendelaRumahMenyala",
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 215, 130),
		Size = Vector3.new(0.2, 2.5, 3.5),
		CFrame = CFrame.new(rumahCenter.X + 7.1, 5.5, rumahCenter.Z + 2),
		Parent = envFolder,
	})
	local windowLight = Instance.new("PointLight")
	windowLight.Name = "WindowLight"
	windowLight.Color = Color3.fromRGB(255, 200, 120)
	windowLight.Range = 14
	windowLight.Brightness = 1.0
	windowLight.Shadows = false
	windowLight.Parent = window

	-- Tiang listrik beton di pinggir gang
	local poleCenter = Vector3.new(18, 9.0, 16)
	createPart({
		Name = "TiangListrikBeton",
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(85, 85, 88),
		Size = Vector3.new(0.9, 18, 0.9),
		CFrame = CFrame.new(poleCenter),
		Parent = envFolder,
	})
	-- Palang tiang listrik
	createPart({
		Name = "PalangTiangListrik",
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(45, 45, 48),
		Size = Vector3.new(3.8, 0.35, 0.35),
		CFrame = CFrame.new(poleCenter.X, poleCenter.Y + 7.5, poleCenter.Z),
		Parent = envFolder,
	})

	-- Pohon pisang sederhana di sudut samping
	local bananaBase = Vector3.new(8.5, 0.5, -8.5)
	createPart({
		Name = "BatangPisang",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(75, 110, 60),
		Size = Vector3.new(1.0, 7.0, 1.0),
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(bananaBase.X, 4.0, bananaBase.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = envFolder,
	})
	-- 4 Daun pisang lebar
	local leafAngles = { 0, 90, 180, 270 }
	for lIdx, angleDeg in ipairs(leafAngles) do
		createPart({
			Name = "DaunPisang" .. lIdx,
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(45, 115, 40),
			Size = Vector3.new(1.2, 0.1, 4.2),
			CFrame = CFrame.new(bananaBase.X, 7.2, bananaBase.Z) * CFrame.Angles(math.rad(-25), math.rad(angleDeg), 0),
			Parent = envFolder,
		})
	end

	-- Konfigurasi SpawnLocation agar pemain muncul di pelataran depan Pos Ronda (menghadap pintu masuk)
	local defaultSpawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if defaultSpawn then
		defaultSpawn.CFrame = CFrame.new(0, 1.25, 14) * CFrame.Angles(0, math.rad(180), 0)
		defaultSpawn.Size = Vector3.new(8, 0.5, 8)
		defaultSpawn.Enabled = true
	end

	root.Parent = workspace
	return root
end

-- Menghitung total part yang dibuat
function WorldBuilder.GetPartCount(): number
	local posRonda = workspace:FindFirstChild("PosRonda")
	if not posRonda then
		return 0
	end
	local count = 0
	for _, desc in ipairs(posRonda:GetDescendants()) do
		if desc:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

return WorldBuilder
