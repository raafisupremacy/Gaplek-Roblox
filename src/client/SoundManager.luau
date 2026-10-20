--!strict
--[=[
	SoundManager.luau
	Pengelola pemutaran efek suara (SFX) audio untuk Gaplek Pos Ronda (GAME_FEEL.md §8, WORLD_ART_AUDIO.md §6).

	Prinsip:
	- Aman (Safe Fallback): Jika Asset ID kosong atau aset belum diunggah, tidak pernah melempar runtime error.
	- Variasi Acak: Pitch bervariasi ±8% dan volume ±5% agar tidak terdengar repetitif/mekanis.
	- Positional Audio: Memutar suara 3D di posisi meja/kartu jika parameter parent/position diberikan.
	- Sound Pooling: Mendaur ulang instance Sound di SoundService untuk mencegah memory leak.
	- Ducking: Suara hentakan berat menurunkan suara latar/ambience sejenak (150 ms).
]=]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

local SoundManager = {}

-- Generator acak lokal untuk jitter pitch/volume
local rng = Rng.fromRandom(Random.new(os.time()))

-- Pool Sound instance: { Sound }
local soundPool: { Sound } = {}
local MAX_POOL_SIZE = 16

-- SoundGroups di bawah SoundService
local masterVolume = 1.0
local groupVolumes: { [string]: number } = {
	sfx = 0.9,
	ambience = 0.7,
	ui = 0.8,
}
local soundGroups: { [string]: SoundGroup } = {}

local function getSoundGroup(name: string): SoundGroup
	if soundGroups[name] and soundGroups[name].Parent then
		return soundGroups[name]
	end
	local existing = SoundService:FindFirstChild("Gaplek_" .. name) :: SoundGroup?
	if existing then
		soundGroups[name] = existing
		return existing
	end
	local grp = Instance.new("SoundGroup")
	grp.Name = "Gaplek_" .. name
	grp.Volume = (groupVolumes[name] or 1.0) * masterVolume
	grp.Parent = SoundService
	soundGroups[name] = grp
	return grp
end

local function getSfxGroup(): SoundGroup
	return getSoundGroup("sfx")
end

--[=[
	Mengatur volume master (0.0 .. 1.0).
]=]
function SoundManager.SetMasterVolume(vol: number?)
	masterVolume = math.clamp(vol or 1.0, 0, 1)
	for grpName, grp in pairs(soundGroups) do
		local base = groupVolumes[grpName] or 1.0
		grp.Volume = base * masterVolume
	end
end

--[=[
	Mengatur volume per grup ("sfx", "ambience", "ui").
]=]
function SoundManager.SetGroupVolume(groupName: string, vol: number?)
	local clamped = math.clamp(vol or 1.0, 0, 1)
	groupVolumes[groupName] = clamped
	local grp = getSoundGroup(groupName)
	grp.Volume = clamped * masterVolume
end

-- Helper mengambil atau membuat Sound instance dari pool
local function acquireSound(parent: Instance?): Sound
	local sound: Sound
	if #soundPool > 0 then
		sound = table.remove(soundPool, #soundPool) :: Sound
	else
		sound = Instance.new("Sound")
		sound.SoundGroup = getSfxGroup()
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 5
		sound.RollOffMaxDistance = 35
	end

	sound.Parent = parent or SoundService
	return sound
end

-- Helper mengembalikan Sound ke pool setelah selesai berbunyi
local function releaseSound(sound: Sound)
	sound:Stop()
	sound.SoundId = ""
	sound.Parent = nil
	if #soundPool < MAX_POOL_SIZE then
		table.insert(soundPool, sound)
	else
		sound:Destroy()
	end
end

--[=[
	Memutar slot suara umum dari FeelConfig.
	Jika slot tidak memiliki ID atau ID kosong, fungsi keluar dengan aman tanpa error.
]=]
function SoundManager.Play(
	slot: string,
	target: (Instance | Vector3)?,
	baseVolume: number?,
	basePitch: number?
): Sound?
	local assetId = FeelConfig.GetSound(slot)
	if not assetId or assetId == "" then
		-- Slot kosong / placeholder: aman tanpa error
		return nil
	end

	local targetParent: Instance? = nil
	local tempAttach: Attachment? = nil

	if target then
		if typeof(target) == "Instance" then
			targetParent = target
		elseif typeof(target) == "Vector3" then
			-- Pasang di attachment sementara di workspace
			local attach = Instance.new("Attachment")
			attach.WorldPosition = target
			attach.Parent = workspace.Terrain
			tempAttach = attach
			targetParent = attach
		end
	end

	local sound = acquireSound(targetParent)
	sound.SoundId = assetId

	-- Terapkan variasi pitch (±8%) dan variasi volume (±5%)
	local pitchJitter = 1.0 + rng:NextNumber(-FeelConfig.HANDS.AUDIO_PITCH_VARIATION, FeelConfig.HANDS.AUDIO_PITCH_VARIATION)
	local volJitter = 1.0 + rng:NextNumber(-0.05, 0.05)

	sound.PlaybackSpeed = (basePitch or 1.0) * pitchJitter
	sound.Volume = (baseVolume or 0.8) * volJitter

	sound:Play()

	-- Sambungkan pembersihan saat selesai
	task.spawn(function()
		sound.Ended:Wait()
		if tempAttach then
			tempAttach:Destroy()
		end
		releaseSound(sound)
	end)

	return sound
end

-- ====================================================================
-- PEMUTAR SFX KHUSUS GRUP A (KARTU & TANGAN)
-- ====================================================================

--[=[
	Memutar suara hentakan keras (Slam) balak atau penempatan klimaks.
	Mendukung variasi preset intensitas dan ducking volume sementara.
]=]
function SoundManager.PlaySlam(presetName: string?, target: (Instance | Vector3)?): Sound?
	local preset = FeelConfig.SLAM_PRESETS[presetName or "MEDIUM"] or FeelConfig.SLAM_PRESETS.MEDIUM
	local vol = if preset.NAME == "Banting Meja (Klimaks)" then 1.0 elseif preset.NAME == "Ringan" then 0.6 else 0.85

	-- Lakukan audio ducking sementara pada sfx/ambience group
	local grp = getSfxGroup()
	if grp then
		task.spawn(function()
			local origVol = grp.Volume
			grp.Volume = origVol * 0.75
			task.wait(FeelConfig.DURATIONS.AUDIO_DUCKING)
			grp.Volume = origVol
		end)
	end

	return SoundManager.Play("tile_slam_heavy", target, vol, 1.0)
end

--[=[
	Memutar suara penempatan kartu lembut / biasa (Soft Place).
]=]
function SoundManager.PlayPlace(target: (Instance | Vector3)?): Sound?
	return SoundManager.Play("tile_place_soft", target, 0.65, 1.0)
end

--[=[
	Memutar suara ketukan meja (Pass / Knock 2x).
]=]
function SoundManager.PlayKnock(target: (Instance | Vector3)?): Sound?
	return SoundManager.Play("knock_pass", target, 0.7, 1.0)
end

--[=[
	Memutar suara hover kartu di rak (klik sangat halus).
]=]
function SoundManager.PlayHover(): Sound?
	return SoundManager.Play("tile_hover", nil, 0.35, 1.1)
end

--[=[
	Memutar suara pemilihan kartu di rak (klik kayu mantap).
]=]
function SoundManager.PlaySelect(): Sound?
	return SoundManager.Play("tile_select", nil, 0.5, 1.0)
end

--[=[
	Memutar suara langkah ilegal (buzz).
]=]
function SoundManager.PlayIllegal(): Sound?
	return SoundManager.Play("buzz_illegal", nil, 0.7, 0.95)
end

--[=[
	Memutar suara geser kartu di meja.
]=]
function SoundManager.PlaySlide(target: (Instance | Vector3)?): Sound?
	return SoundManager.Play("tile_slide", target, 0.5, 1.0)
end

--[=[
	Memutar suara pembagian kartu cepat ("sret").
]=]
function SoundManager.PlayDeal(target: (Instance | Vector3)?): Sound?
	return SoundManager.Play("tile_deal", target, 0.55, 1.05)
end

--[=[
	Memutar suara pengocokan kartu melingkar di meja.
]=]
function SoundManager.PlayShuffle(target: (Instance | Vector3)?): Sound?
	return SoundManager.Play("tile_shuffle", target, 0.75, 1.0)
end

--[=[
	Memutar suara ekspresi emote berdasarkan emoteId ("laugh", "angry", "sad", "yah", "clap", "taunt").
]=]
function SoundManager.PlayEmote(emoteId: string, target: (Instance | Vector3)?): Sound?
	local item = FeelConfig.EMOTE and FeelConfig.EMOTE.ITEMS and FeelConfig.EMOTE.ITEMS[emoteId]
	local slot = if item and item.soundSlot then item.soundSlot else ("emote_" .. tostring(emoteId))
	return SoundManager.Play(slot, target, 0.8, 1.0)
end

-- ====================================================================
-- PEMUTAR SFX KHUSUS GRUP B (KAMERA & UI)
-- ====================================================================

--[=[
	Memutar suara notifikasi pergantian giliran ("turn_ting" - lonceng/ketukan bambu halus).
]=]
function SoundManager.PlayTurnTing(target: (Instance | Vector3)?): Sound?
	return SoundManager.Play("turn_ting", target, 0.65, 1.0)
end

--[=[
	Memutar suara detak peringatan waktu saat sisa <= 10 detik ("timer_tick").
]=]
function SoundManager.PlayTimerTick(isCritical: boolean?): Sound?
	local pitch = if isCritical then 1.12 else 1.0
	local vol = if isCritical then 0.65 else 0.50
	return SoundManager.Play("timer_tick", nil, vol, pitch)
end

--[=[
	Memutar suara detak angka skor saat menghitung naik ("score_tick").
]=]
function SoundManager.PlayScoreTick(stepRatio: number?): Sound?
	local ratio = math.clamp(stepRatio or 0.5, 0, 1)
	local pitch = 0.95 + ratio * 0.20 -- Pitch naik bertahap seiring angka naik
	return SoundManager.Play("score_tick", nil, 0.55, pitch)
end

-- ====================================================================
-- PEMUTAR SFX KHUSUS GRUP C (IDLE KARAKTER & REAKSI)
-- ====================================================================

--[=[
	Memutar suara lembut saat karakter melakukan variasi idle ("sip_coffee", "fan_self", "scratch_head").
]=]
function SoundManager.PlayIdleAction(actionName: string, target: (Instance | Vector3)?): Sound?
	if actionName == "sip_coffee" then
		return SoundManager.Play("sit", target, 0.45, 1.15)
	elseif actionName == "fan_self" then
		return SoundManager.Play("amb_wind", target, 0.40, 1.25)
	else
		return SoundManager.Play("tile_hover", target, 0.35, 0.95)
	end
end

--[=[
	Membersihkan seluruh sound pool saat teardown.
]=]
function SoundManager.Destroy()
	for _, snd in ipairs(soundPool) do
		snd:Destroy()
	end
	table.clear(soundPool)
	if sfxGroup then
		sfxGroup:Destroy()
		sfxGroup = nil
	end
end

return SoundManager
