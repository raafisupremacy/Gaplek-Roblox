--!strict
--[=[
	ClientState.luau
	Salinan state lokal klien untuk Gaplek Pos Ronda.
	Sumber: TECH_SPEC.md §4, §5.

	Prinsip:
	- Menyimpan state publik + kartu milik pemain lokal sendiri.
	- Tidak pernah menyimpan isi tangan pemain lain (hanya jumlah sisa kartu).
	- Menyediakan event listeners untuk pembaruan UI dan visual.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Types = require(sharedFolder:WaitForChild("Types"))

type Mode = Types.Mode
type Tile = Types.Tile
type Side = Types.Side
type Placed = Types.Placed
type Board = Types.Board

export type LocalCard = {
	token: string,
	tile: Tile,
}

local ClientState = {}
_G.LiveClientState = ClientState

-- State lokal
ClientState.mySeat = 0 -- 0 jika belum duduk
ClientState.isHost = false
ClientState.mode = "2v2" :: Mode
ClientState.phase = "idle" -- "idle" | "in_progress" | "dealing" | "playing" | "round_end" | "game_ended"
ClientState.currentPhase = "idle"
ClientState.currentTurn = 0
ClientState.passStreak = 0
ClientState.turnDeadline = 0
ClientState.canPass = false
ClientState.roundNumber = 1

-- Hand sendiri: [index] = { token = string, tile = Tile }
ClientState.myHand = {} :: { LocalCard }

-- Jumlah sisa kartu semua pemain: [seat] = count
ClientState.remainingCounts = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 } :: { [number]: number }

-- State papan di meja
ClientState.boardPlaced = {} :: { Placed }
ClientState.leftEnd = nil :: number?
ClientState.rightEnd = nil :: number?

-- Skor akumulasi game: [side] = score
ClientState.scores = {} :: { [number]: number }

-- Callback listeners
local listeners: { [string]: { (...any) -> () } } = {
	OnStateSynced = {},
	OnHandChanged = {},
	OnTurnChanged = {},
	OnBoardChanged = {},
	OnScoresChanged = {},
	OnPhaseChanged = {},
}

function ClientState.Subscribe(eventName: string, callback: (...any) -> ())
	if not listeners[eventName] then
		listeners[eventName] = {}
	end
	table.insert(listeners[eventName], callback)
end

local function emit(eventName: string, ...: any)
	local list = listeners[eventName]
	if list then
		for _, cb in ipairs(list) do
			task.spawn(cb, ...)
		end
	end
end

--[=[
	Menerapkan pembaruan dari StateSync server (snap state tanpa animasi).
]=]
function ClientState.ApplyStateSync(
	seat: number,
	privateHandPayload: { { token: string, a: number, b: number } },
	remaining: { [number]: number },
	boardPlaced: { Placed },
	leftEnd: number?,
	rightEnd: number?,
	currentSeat: number,
	passStreak: number,
	scores: { [number]: number },
	mode: Mode,
	phase: string,
	isHost: boolean,
	turnDeadline: number
)
	ClientState.mySeat = seat
	ClientState.isHost = isHost
	ClientState.mode = mode
	ClientState.phase = phase
	ClientState.currentPhase = phase
	ClientState.currentTurn = currentSeat
	ClientState.passStreak = passStreak
	ClientState.turnDeadline = turnDeadline
	ClientState.leftEnd = leftEnd
	ClientState.rightEnd = rightEnd
	ClientState.scores = scores
	ClientState.remainingCounts = remaining
	ClientState.boardPlaced = boardPlaced

	-- Update kartu di hand sendiri
	table.clear(ClientState.myHand)
	for _, item in ipairs(privateHandPayload) do
		table.insert(ClientState.myHand, {
			token = item.token,
			tile = { a = item.a, b = item.b },
		})
	end

	ClientState.UpdateCanPass()

	emit("OnStateSynced")
	emit("OnHandChanged", ClientState.myHand)
	emit("OnBoardChanged", ClientState.boardPlaced, leftEnd, rightEnd)
	emit("OnTurnChanged", currentSeat, turnDeadline)
	emit("OnScoresChanged", scores)
	emit("OnPhaseChanged", phase)
end

--[=[
	Mencari token kartu berdasarkan indeks di myHand.
]=]
function ClientState.GetTokenAtIndex(index: number): string?
	local card = ClientState.myHand[index]
	return if card then card.token else nil
end

--[=[
	Mencari kartu berdasarkan token.
]=]
function ClientState.GetCardByToken(token: string): LocalCard?
	for _, card in ipairs(ClientState.myHand) do
		if card.token == token then
			return card
		end
	end
	return nil
end

--[=[
	Menghapus kartu dari hand sendiri setelah dipasang.
]=]
function ClientState.RemoveCardByToken(token: string)
	for i, card in ipairs(ClientState.myHand) do
		if card.token == token then
			table.remove(ClientState.myHand, i)
			emit("OnHandChanged", ClientState.myHand)
			break
		end
	end
end

--[=[
	Mengembalikan daftar kartu mentah {Tile} untuk diberikan ke RackView.
]=]
function ClientState.GetTilesForRack(): { Tile }
	local list: { Tile } = {}
	for _, card in ipairs(ClientState.myHand) do
		table.insert(list, card.tile)
	end
	return list
end

--[=[
	Mengecek apakah saat ini giliran pemain lokal.
]=]
function ClientState.IsMyTurn(): boolean
	return ClientState.mySeat > 0 and ClientState.currentTurn == ClientState.mySeat
end

--[=[
	Mengecek apakah pemain lokal berhak/wajib melakukan pass (tidak ada kartu yang cocok).
]=]
function ClientState.CanPass(): boolean
	if not ClientState.IsMyTurn() then
		return false
	end
	if #ClientState.myHand == 0 then
		return false
	end

	-- Jika belum ada kartu di meja:
	if #ClientState.boardPlaced == 0 then
		for _, card in ipairs(ClientState.myHand) do
			if ClientState.roundNumber == 1 then
				if card.tile.a == 6 and card.tile.b == 6 then
					return false
				end
			else
				if card.tile.a == card.tile.b then
					return false
				end
			end
		end
		return true
	end

	-- Jika sudah ada kartu di meja:
	local leftEnd = ClientState.leftEnd
	local rightEnd = ClientState.rightEnd
	for _, card in ipairs(ClientState.myHand) do
		local a, b = card.tile.a, card.tile.b
		if (leftEnd ~= nil and (a == leftEnd or b == leftEnd)) or (rightEnd ~= nil and (a == rightEnd or b == rightEnd)) then
			return false
		end
	end

	return true
end

function ClientState.UpdateCanPass()
	ClientState.canPass = ClientState.CanPass()
end

return ClientState
