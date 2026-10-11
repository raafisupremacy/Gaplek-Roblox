--!strict
--[=[
	Main.client.luau
	Bootstrap client untuk Gaplek Pos Ronda (AGENTS.md §6, TECH_SPEC.md §4).

	Tanggung Jawab:
	- Menginisialisasi event bus GameEvents dan UIController.
	- Menginisialisasi CameraController POV first person.
	- Mengelola RackView, BoardView, dan InteractionController.
	- Menghubungkan event jaringan (StateSync, TilePlaced, PlayerPassed, Rejected)
	  dengan tampilan visual dan animasi tangan HandController.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Types = require(sharedFolder:WaitForChild("Types"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local GameConfig = require(sharedFolder:WaitForChild("GameConfig"))
local BoardLayout = require(sharedFolder:WaitForChild("BoardLayout"))

local CameraController = require(script.Parent:WaitForChild("CameraController"))
local HandController = require(script.Parent:WaitForChild("HandController"))
local TileFactory = require(script.Parent:WaitForChild("TileFactory"))
local RackView = require(script.Parent:WaitForChild("RackView"))
local BoardView = require(script.Parent:WaitForChild("BoardView"))
local InteractionController = require(script.Parent:WaitForChild("InteractionController"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local GameEvents = require(script.Parent:WaitForChild("GameEvents"))
local UIController = require(script.Parent:WaitForChild("UIController"))
local TileAnimator = require(script.Parent:WaitForChild("TileAnimator"))
local SoundManager = require(script.Parent:WaitForChild("SoundManager"))
local SettingsController = require(script.Parent:WaitForChild("SettingsController"))

type Tile = Types.Tile
type Placed = Types.Placed

local localPlayer = Players.LocalPlayer

-- Sub-views lokal
local myRackView: any = nil
local mainBoardView: any = nil
local interactionController: any = nil

-- Cache HandController per kursi: [seat] = HandController
local handControllers: { [number]: any } = {}

-- Helper mendapatkan Model Meja aktif tempat pemain duduk (atau default PosRonda.Table)
local function getActiveTable(): Model?
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent:IsA("Model") then
		return hum.SeatPart.Parent :: Model
	end
	local posRonda = workspace:FindFirstChild("PosRonda")
	return posRonda and posRonda:FindFirstChild("Table") :: Model?
end

local function getActiveBoardCenterCFrame(): CFrame
	local tbl = getActiveTable()
	local bc = tbl and tbl:FindFirstChild("BoardCenter") :: BasePart?
	return if bc then bc.CFrame else CFrame.new(0, 4.0, 0)
end

-- Helper menghitung CFrame preview penempatan kandidat kartu
local function computeCandidateCFrame(candidateTile: Tile, side: "left" | "right"): CFrame?
	local tempPlaced: { Placed } = {}
	for _, p in ipairs(ClientState.boardPlaced) do
		table.insert(tempPlaced, {
			tile = p.tile,
			side = p.side,
			isDouble = p.isDouble,
			endLeft = p.endLeft,
			endRight = p.endRight,
		})
	end

	local isDouble = (candidateTile.a == candidateTile.b)
	local candidatePlaced: Placed = {
		tile = candidateTile,
		side = side,
		isDouble = isDouble,
		endLeft = 0,
		endRight = 0,
	}
	table.insert(tempPlaced, candidatePlaced)

	local cframes = BoardLayout.Calculate(tempPlaced)
	local nextRelCF = cframes[#cframes]
	local baseCF = getActiveBoardCenterCFrame()

	return baseCF * nextRelCF
end

-- Inisialisasi utama client
local function bootstrap()
	-- 1. Inisialisasi event bus & kamera POV
	GameEvents.Init()
	SettingsController.Init()
	CameraController.Init()
	UIController.Init()

	-- Sambungkan callback kamera untuk efek hentak & FOV punch
	TileAnimator.SetCameraCallbacks(CameraController.Shake, CameraController.PunchFOV)

	-- 2. Buat BoardView meja
	mainBoardView = BoardView.new()
	interactionController = InteractionController.new()

	-- 3. Listener StateSync (Snap state tanpa animasi)
	GameEvents.On("StateSync", function(
		seat: number,
		privateHand: { { token: string, a: number, b: number } },
		remaining: { [number]: number },
		boardPlaced: { Placed },
		leftEnd: number?,
		rightEnd: number?,
		currentSeat: number,
		passStreak: number,
		scores: { [number]: number },
		mode: any,
		phase: string,
		isHost: boolean,
		turnDeadline: number
	)
		ClientState.ApplyStateSync(
			seat,
			privateHand,
			remaining,
			boardPlaced,
			leftEnd,
			rightEnd,
			currentSeat,
			passStreak,
			scores,
			mode,
			phase,
			isHost,
			turnDeadline
		)

		-- Buat atau perbarui RackView untuk kursi pemain
		if seat > 0 then
			if not myRackView or myRackView.seatIndex ~= seat then
				if myRackView then
					myRackView:Destroy()
				end
				myRackView = RackView.new(seat, true)
				interactionController:SetViews(myRackView, mainBoardView)
			end
			myRackView:RenderRack(ClientState.GetTilesForRack())
		end

		-- Render snap board di meja
		mainBoardView:RenderBoard(boardPlaced, leftEnd, rightEnd)
		interactionController:SetTurnActive(ClientState.IsMyTurn())
	end)

	-- 4. Listener TurnStarted
	GameEvents.On("TurnStarted", function(seat: number, deadline: number)
		interactionController:SetTurnActive(ClientState.mySeat > 0 and seat == ClientState.mySeat)
	end)

	-- 4b. Listener DealStarted & RoundStarted
	GameEvents.On("DealStarted", function(remainingCounts: { [number]: number })
		SoundManager.PlayDeal()
	end)

	GameEvents.On("RoundStarted", function(roundNumber: number, openerSeat: number, reshuffleCount: number)
		SoundManager.PlayShuffle()
	end)

	-- 5. Listener TilePlaced (Animasi 4 Lapisan: Gerakan, Suara, Visual, Lingkungan)
	GameEvents.On("TilePlaced", function(
		seat: number,
		a: number,
		b: number,
		side: "left" | "right" | "center",
		leftEnd: number?,
		rightEnd: number?,
		relCF: CFrame,
		isDouble: boolean,
		remainingCount: number
	)
		local placedTile: Tile = { a = a, b = b }
		table.insert(ClientState.boardPlaced, {
			tile = placedTile,
			side = side,
			isDouble = isDouble,
			endLeft = leftEnd or a,
			endRight = rightEnd or b,
		})
		ClientState.leftEnd = leftEnd
		ClientState.rightEnd = rightEnd

		-- Render board
		mainBoardView:RenderBoard(ClientState.boardPlaced, leftEnd, rightEnd)

		-- Hitung posisi world benturan di meja
		local baseCF = getActiveBoardCenterCFrame()
		local targetWorldCF = baseCF * relCF

		-- Jalankan animasi fisik 4 lapisan kartu
		local targetPart = mainBoardView:GetLastPlacedPart()
		if targetPart then
			if isDouble then
				-- Balak: Aksi Hentak (Slam) Unggulan
				TileAnimator.AnimateSlam(targetPart, targetWorldCF, "MEDIUM")
			else
				-- Pasang biasa (Soft Place)
				TileAnimator.AnimatePlaceNormal(targetPart, targetWorldCF)
			end
		end

		-- Jika pemain lokal yang menaruh kartu:
		if seat == ClientState.mySeat and myRackView then
			-- Hapus kartu yang cocok dari hand
			for i, card in ipairs(ClientState.myHand) do
				if (card.tile.a == a and card.tile.b == b) or (card.tile.a == b and card.tile.b == a) then
					table.remove(ClientState.myHand, i)
					break
				end
			end
			myRackView:RenderRack(ClientState.GetTilesForRack())
			interactionController:ClearSelection()
		end

		-- Gerakkan tangan kursi terkait (animasi tangan IK)
		local hc = handControllers[seat]
		if hc then
			task.spawn(function()
				if isDouble then
					hc:Slam(nil, targetWorldCF, "MEDIUM")
				else
					hc:Place(nil, targetWorldCF, false)
				end
			end)
		end
	end)

	-- 5b. Listener SeatChanged (Update kursi lokal & pembersihan rak)
	GameEvents.On("SeatChanged", function(seatIndex: number, userId: number, username: string, isBot: boolean, action: string, tableId: number?)
		if userId == localPlayer.UserId then
			if action == "sit" then
				ClientState.mySeat = seatIndex
			elseif action == "stand" then
				ClientState.mySeat = 0
				if myRackView then
					myRackView:Destroy()
					myRackView = nil
				end
			end
		end
	end)

	-- 6. Listener PlayerPassed (Ketuk Meja 4 Lapisan)
	GameEvents.On("PlayerPassed", function(seat: number, passStreak: number)
		local tbl = getActiveTable()
		local seatPart = tbl and tbl:FindFirstChild("Seat" .. seat) :: Seat?
		local knockPos = if seatPart then (seatPart.CFrame * CFrame.new(0, 0, -2.0)).Position else Vector3.new(0, 4.0, 0)

		TileAnimator.AnimateKnock(knockPos)

		local hc = handControllers[seat]
		if hc then
			task.spawn(function()
				hc:Knock(2)
			end)
		end
	end)

	-- 7. Listener Rejected (Langkah Ilegal)
	GameEvents.On("Rejected", function(errorCode: string)
		SoundManager.PlayIllegal()
		if interactionController and interactionController.selectedTileIndex then
			local msg = if errorCode == "TILE_NOT_IN_HAND" then "Kartu tidak ada di tangan"
				elseif errorCode == "NOT_YOUR_TURN" then "Bukan giliran Anda"
				elseif errorCode == "NOT_R15_AVATAR" then "Avatar harus bertipe R15"
				else "Langkah tidak legal"
			interactionController:ShowIllegalFeedback(interactionController.selectedTileIndex, msg)
		end
	end)

	-- 8. Hubungkan callback InteractionController
	interactionController:SetCallbacks(
		-- A. Checker apakah kartu legal dimainkan
		function(tileIndex: number)
			local card = ClientState.myHand[tileIndex]
			if not card or not ClientState.IsMyTurn() then
				return { left = false, right = false }
			end

			local tile = card.tile
			if #ClientState.boardPlaced == 0 then
				-- Board kosong: Hanya balak sah yang bisa jalan (ronde 1: 6-6, ronde >= 2: balak)
				local isDouble = (tile.a == tile.b)
				return { left = isDouble, right = isDouble }
			else
				local canLeft = (ClientState.leftEnd ~= nil) and (tile.a == ClientState.leftEnd or tile.b == ClientState.leftEnd)
				local canRight = (ClientState.rightEnd ~= nil) and (tile.a == ClientState.rightEnd or tile.b == ClientState.rightEnd)
				return { left = canLeft, right = canRight }
			end
		end,
		-- B. Getter CFrame Ghost Preview
		function(side: "left" | "right")
			local selIdx = interactionController.selectedTileIndex
			if not selIdx then return nil end
			local card = ClientState.myHand[selIdx]
			if not card then return nil end
			return computeCandidateCFrame(card.tile, side)
		end,
		-- C. Callback saat pemain mengeklik ghost preview untuk menaruh kartu
		function(tileIndex: number, side: "left" | "right")
			local token = ClientState.GetTokenAtIndex(tileIndex)
			if token then
				local playSide: Types.Side = if #ClientState.boardPlaced == 0 then "center" else side
				Remotes.getEvent("RequestPlay"):FireServer(token, playSide)
			end
		end
	)

	-- 9. Dev Tool: Inisialisasi FeelLab jika tersedia di ReplicatedStorage (M5)
	local feelLabModule = ReplicatedStorage:FindFirstChild("FeelLab")
	if feelLabModule then
		local FeelLab = require(feelLabModule :: ModuleScript)
		FeelLab.Init()
	end

	print("[PosGaplek Client] boot ok")
end

bootstrap()
