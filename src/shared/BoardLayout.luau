--!strict
--[=[
	BoardLayout.luau
	Kalkulator tata letak barisan kartu domino (snake polyline layout).
	Memenuhi WORLD_ART_AUDIO.md §4:
	- Murni Luau: nol Instance, nol side-effect, deterministik.
	- Mengatur barisan zig-zag (snake) berkapasitas >= 28 kartu.
	- Menjamin 0% tumpang tindih (OBB/SAT overlap = 0).
	- Tetap dalam jangkauan meja pos ronda.
]=]

local Types = require(script.Parent.Types)

type Placed = Types.Placed
type Tile = Types.Tile

local BoardLayout = {}

-- Dimensi standar kartu domino (stud)
BoardLayout.TILE_LENGTH = 1.0
BoardLayout.TILE_WIDTH = 0.5
BoardLayout.TILE_THICKNESS = 0.15

-- Dimensi meja kotak gaplek & kursi bakso (stud) — Opsi 1 (Stabilisasi v2 / Batch 2 Varian B)
BoardLayout.TABLE_SIZE = Vector3.new(6.6, 0.28, 6.6)
BoardLayout.TABLE_HALF_EXTENT = 3.30
BoardLayout.SEAT_DISTANCE = 3.45

-- Parameter tata letak zona papan (stud)
BoardLayout.LANE_SPACING_Z = 1.02
BoardLayout.X_LIMIT = 2.40
BoardLayout.BOARD_ZONE_SIZE = Vector3.new(5.6, 0.15, 5.9)
BoardLayout.MAX_TOSS_DISTANCE = 4.0

--[=[
	Mengembalikan ukuran fisik kartu standar: Vector3(1.0, 0.15, 0.5).
	Panjang lokal = X, Tebal = Y, Lebar lokal = Z.
]=]
function BoardLayout.GetTileSize(): Vector3
	return Vector3.new(BoardLayout.TILE_LENGTH, BoardLayout.TILE_THICKNESS, BoardLayout.TILE_WIDTH)
end

--[=[
	Mengembalikan ukuran fisik daun meja (TableTop).
]=]
function BoardLayout.GetTableSize(): Vector3
	return BoardLayout.TABLE_SIZE
end

--[=[
	Mengembalikan setengah lebar/panjang daun meja dari pusat (tepi meja).
]=]
function BoardLayout.GetTableHalfExtent(): number
	return BoardLayout.TABLE_HALF_EXTENT
end

--[=[
	Mengembalikan jarak kursi dari pusat meja.
]=]
function BoardLayout.GetSeatDistance(): number
	return BoardLayout.SEAT_DISTANCE
end

--[=[
	Mengembalikan ukuran zona barisan di meja.
]=]
function BoardLayout.GetBoardZone(): Vector3
	return BoardLayout.BOARD_ZONE_SIZE
end

--[=[
	Menghitung batas terluar (half-extents X dan Z di dunia) dari sebuah kartu pada CFrame tertentu.
]=]
function BoardLayout.GetTileWorldHalfExtents(cf: CFrame, tileSize: Vector3?): (number, number)
	local sz = tileSize or BoardLayout.GetTileSize()
	local hx = sz.X / 2
	local hz = sz.Z / 2
	local _, rotY, _ = cf:ToOrientation()
	local cosY = math.abs(math.cos(rotY))
	local sinY = math.abs(math.sin(rotY))
	return cosY * hx + sinY * hz, sinY * hx + cosY * hz
end

--[=[
	Uji tumpang tindih 2D (Separating Axis Theorem) pada bidang XZ meja.
	Mengembalikan true jika dan hanya jika kedua kotak bertabrakan di ruang interior.
]=]
function BoardLayout.CheckSATOverlap(
	cf1: CFrame,
	size1: Vector3,
	cf2: CFrame,
	size2: Vector3,
	epsilon: number?
): boolean
	local eps = epsilon or 0.005
	local p1 = Vector2.new(cf1.Position.X, cf1.Position.Z)
	local p2 = Vector2.new(cf2.Position.X, cf2.Position.Z)
	local diff = p2 - p1

	local h1 = Vector2.new(size1.X / 2, size1.Z / 2)
	local h2 = Vector2.new(size2.X / 2, size2.Z / 2)

	local _, rotY1, _ = cf1:ToOrientation()
	local _, rotY2, _ = cf2:ToOrientation()

	local axes1 = {
		Vector2.new(math.cos(rotY1), math.sin(rotY1)),
		Vector2.new(-math.sin(rotY1), math.cos(rotY1)),
	}
	local axes2 = {
		Vector2.new(math.cos(rotY2), math.sin(rotY2)),
		Vector2.new(-math.sin(rotY2), math.cos(rotY2)),
	}

	local testAxes = { axes1[1], axes1[2], axes2[1], axes2[2] }

	for _, axis in ipairs(testAxes) do
		local dist = math.abs(diff:Dot(axis))
		local r1 = math.abs(axes1[1]:Dot(axis)) * h1.X + math.abs(axes1[2]:Dot(axis)) * h1.Y
		local r2 = math.abs(axes2[1]:Dot(axis)) * h2.X + math.abs(axes2[2]:Dot(axis)) * h2.Y

		if dist >= (r1 + r2 - eps) then
			return false
		end
	end

	return true
end

-- Tipe internal untuk melacak ujung rantai
type ArmTracker = {
	curX: number,
	curZ: number,
	dirX: number,
	signZ: number,
	lane: number,
}

--[=[
	Menghitung CFrame tiap kartu di meja dari urutan daftar `placed`.
	Input:
	- `placed`: daftar kartu terpasang (indeks 1 adalah pembuka di center).
	- `tableSurfaceY`: ketinggian vertikal permukaan meja (default 0).
	Output:
	- `{ [number]: CFrame }`: CFrame tiap kartu berindeks sama dengan `placed`.
]=]
function BoardLayout.Calculate(placed: { Placed }, tableSurfaceY: number?): { [number]: CFrame }
	local cframes: { [number]: CFrame } = {}
	local surfaceY = tableSurfaceY or 0
	local yPos = surfaceY + BoardLayout.TILE_THICKNESS / 2

	if #placed == 0 then
		return cframes
	end

	-- 1. Kartu pembuka di tengah meja (Center)
	local centerPlaced = placed[1]
	local centerCf: CFrame
	if centerPlaced.isDouble then
		-- Balak melintang di sumbu Z (panjang 1.0 di Z, lebar 0.5 di X)
		centerCf = CFrame.new(0, yPos, 0) * CFrame.Angles(0, math.rad(90), 0)
	else
		-- Membujur di sumbu X
		centerCf = CFrame.new(0, yPos, 0)
	end
	cframes[1] = centerCf

	-- 2. State pelacak lengan kanan dan kiri
	local rightArm: ArmTracker = {
		curX = if centerPlaced.isDouble then BoardLayout.TILE_WIDTH / 2 else BoardLayout.TILE_LENGTH / 2,
		curZ = 0,
		dirX = 1,
		signZ = 1,
		lane = 0,
	}

	local leftArm: ArmTracker = {
		curX = if centerPlaced.isDouble then -BoardLayout.TILE_WIDTH / 2 else -BoardLayout.TILE_LENGTH / 2,
		curZ = 0,
		dirX = -1,
		signZ = -1,
		lane = 0,
	}

	local function advanceArm(arm: ArmTracker, p: Placed): CFrame
		local isDouble = p.isDouble
		local stepLen = if isDouble then BoardLayout.TILE_WIDTH else BoardLayout.TILE_LENGTH

		local nextReach = arm.curX + arm.dirX * stepLen
		local mustTurn = false
		if arm.dirX == 1 and nextReach > (BoardLayout.X_LIMIT + 0.05) then
			mustTurn = true
		elseif arm.dirX == -1 and nextReach < (-BoardLayout.X_LIMIT - 0.05) then
			mustTurn = true
		end

		if mustTurn then
			-- Belok ke lajur berikutnya
			arm.lane += 1
			local nextLaneZ = arm.signZ * (arm.lane * BoardLayout.LANE_SPACING_Z)
			local cornerCenterX = arm.curX + arm.dirX * (BoardLayout.TILE_WIDTH / 2)
			local cornerCenterZ = (arm.curZ + nextLaneZ) / 2
			local cornerCf = CFrame.new(cornerCenterX, yPos, cornerCenterZ) * CFrame.Angles(0, math.rad(90), 0)

			arm.curZ = nextLaneZ
			arm.curX = cornerCenterX - arm.dirX * (BoardLayout.TILE_WIDTH / 2)
			arm.dirX = -arm.dirX
			return cornerCf
		else
			-- Maju lurus dalam lajur
			local cf: CFrame
			if isDouble then
				local centerX = arm.curX + arm.dirX * (BoardLayout.TILE_WIDTH / 2)
				cf = CFrame.new(centerX, yPos, arm.curZ) * CFrame.Angles(0, math.rad(90), 0)
				arm.curX += arm.dirX * BoardLayout.TILE_WIDTH
			else
				local centerX = arm.curX + arm.dirX * (BoardLayout.TILE_LENGTH / 2)
				cf = CFrame.new(centerX, yPos, arm.curZ)
				arm.curX += arm.dirX * BoardLayout.TILE_LENGTH
			end
			return cf
		end
	end

	for i = 2, #placed do
		local p = placed[i]
		local arm = if p.side == "right" then rightArm else leftArm
		cframes[i] = advanceArm(arm, p)
	end

	-- 3. Auto-centering XZ: pusatkan bounding box seluruh barisan agar tidak berat sebelah
	--    atau meluber keluar meja saat rantai tumbuh asimetris di satu sisi saja.
	local tileSize = BoardLayout.GetTileSize()
	local minEdgeX = math.huge
	local maxEdgeX = -math.huge
	local minEdgeZ = math.huge
	local maxEdgeZ = -math.huge

	for i = 1, #cframes do
		local cf = cframes[i]
		local extX, extZ = BoardLayout.GetTileWorldHalfExtents(cf, tileSize)
		local px = cf.Position.X
		local pz = cf.Position.Z
		if px - extX < minEdgeX then minEdgeX = px - extX end
		if px + extX > maxEdgeX then maxEdgeX = px + extX end
		if pz - extZ < minEdgeZ then minEdgeZ = pz - extZ end
		if pz + extZ > maxEdgeZ then maxEdgeZ = pz + extZ end
	end

	local shiftX = -(minEdgeX + maxEdgeX) / 2
	local shiftZ = -(minEdgeZ + maxEdgeZ) / 2
	if math.abs(shiftX) > 0.0001 or math.abs(shiftZ) > 0.0001 then
		local offset = Vector3.new(shiftX, 0, shiftZ)
		for i = 1, #cframes do
			cframes[i] = cframes[i] + offset
		end
	end

	return cframes
end

-- Alias untuk kemudahan pemanggilan
BoardLayout.ComputeLayout = BoardLayout.Calculate

return BoardLayout
