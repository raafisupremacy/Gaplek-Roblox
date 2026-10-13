--!strict
--[=[
	UITheme.luau
	Palet warna, tipografi, dan gaya visual warung pos ronda (UI_UX_SPEC.md §1).
	
	Tema: Kayu tua, kertas lusuh, cat pudar ala warung ronda, kontras tinggi.
	Bukan UI default Roblox. Target sentuh tombol >= 48 px.
]=]

local UITheme = {
	COLORS = {
		WOOD_DARK = Color3.fromRGB(32, 22, 15),       -- Kayu pos ronda tua pekat
		WOOD_MEDIUM = Color3.fromRGB(52, 36, 24),     -- Papan kayu warung
		WOOD_LIGHT = Color3.fromRGB(78, 54, 38),      -- Lis kayu terang
		PAPER_BG = Color3.fromRGB(245, 238, 220),     -- Kertas lusuh krem
		PAPER_CARD = Color3.fromRGB(252, 248, 236),   -- Kartu kertas putih gading
		CHILI_RED = Color3.fromRGB(186, 52, 42),      -- Merah cabai / cat pudar
		BULB_YELLOW = Color3.fromRGB(235, 172, 38),   -- Kuning bohlam 5 watt
		LEAF_GREEN = Color3.fromRGB(46, 125, 50),     -- Hijau daun pisang
		CHARCOAL = Color3.fromRGB(28, 22, 18),        -- Teks tinta arang
		CREAM_TEXT = Color3.fromRGB(250, 245, 235),   -- Teks krem kontras tinggi
		MUTED_TEXT = Color3.fromRGB(135, 115, 100),   -- Teks sekunder abu kayu
		GOLD = Color3.fromRGB(245, 195, 45),          -- Bintang host / piala
		
		-- Warna Tim 2v2 (UI_UX_SPEC.md §4: pasangan berhadapan berwarna sama)
		TEAM_1 = Color3.fromRGB(195, 50, 40),         -- ▲ Tim 1 (Kursi 1 & 3: Merah)
		TEAM_2 = Color3.fromRGB(215, 155, 25),        -- ● Tim 2 (Kursi 2 & 4: Kuning Emas)
		
		-- Background overlay modal
		OVERLAY_DIM = Color3.fromRGB(10, 8, 6),
	},

	FONTS = {
		TITLE = Enum.Font.SourceSansBold,
		BODY = Enum.Font.SourceSansBold,
		NUMBERS = Enum.Font.SourceSansBold,
	},

	MIN_TOUCH_SIZE = 48, -- Standar aksesibilitas tombol sentuh mobile (UI_UX_SPEC.md §2)
}

--[=[
	Membuat Frame panel bertekstur kayu warung dengan sudut melengkung dan border lis.
]=]
function UITheme.CreateRusticFrame(
	name: string,
	size: UDim2,
	pos: UDim2,
	parent: Instance,
	bgColor: Color3?,
	strokeColor: Color3?
): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = pos
	frame.BackgroundColor3 = bgColor or UITheme.COLORS.WOOD_DARK
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor or UITheme.COLORS.WOOD_LIGHT
	stroke.Thickness = 2
	stroke.Parent = frame

	frame.Parent = parent
	return frame
end

--[=[
	Membuat Frame kartu bergaya kertas lusuh (paper card) dengan tulisan gelap.
]=]
function UITheme.CreatePaperCard(
	name: string,
	size: UDim2,
	pos: UDim2,
	parent: Instance,
	strokeColor: Color3?
): Frame
	local card = Instance.new("Frame")
	card.Name = name
	card.Size = size
	card.Position = pos
	card.BackgroundColor3 = UITheme.COLORS.PAPER_BG
	card.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor or UITheme.COLORS.WOOD_MEDIUM
	stroke.Thickness = 1.5
	stroke.Parent = card

	card.Parent = parent
	return card
end

--[=[
	Membuat tombol interaktif yang memenuhi standar aksesibilitas touch target >= 48 px.
]=]
function UITheme.CreateButton(
	name: string,
	text: string,
	size: UDim2,
	pos: UDim2,
	parent: Instance,
	btnColor: Color3?,
	textColor: Color3?,
	strokeColor: Color3?
): TextButton
	local safeHeight = if size.Y.Scale == 0 and size.Y.Offset < UITheme.MIN_TOUCH_SIZE
		then UITheme.MIN_TOUCH_SIZE
		else size.Y.Offset
	local safeSize = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, safeHeight)

	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Text = text
	btn.Size = safeSize
	btn.Position = pos
	btn.BackgroundColor3 = btnColor or UITheme.COLORS.WOOD_MEDIUM
	btn.TextColor3 = textColor or UITheme.COLORS.CREAM_TEXT
	btn.Font = UITheme.FONTS.TITLE
	btn.TextScaled = true
	btn.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor or UITheme.COLORS.BULB_YELLOW
	stroke.Thickness = 1.5
	stroke.Parent = btn

	btn.Parent = parent
	return btn
end

--[=[
	Membuat label teks judul tebal.
]=]
function UITheme.CreateHeading(
	name: string,
	text: string,
	size: UDim2,
	pos: UDim2,
	parent: Instance,
	color: Color3?
): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Text = text
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = color or UITheme.COLORS.CREAM_TEXT
	lbl.Font = UITheme.FONTS.TITLE
	lbl.TextScaled = true
	lbl.Parent = parent
	return lbl
end

--[=[
	Membuat label teks isi yang jelas terbaca.
]=]
function UITheme.CreateBodyText(
	name: string,
	text: string,
	size: UDim2,
	pos: UDim2,
	parent: Instance,
	color: Color3?
): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Text = text
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = color or UITheme.COLORS.CREAM_TEXT
	lbl.Font = UITheme.FONTS.BODY
	lbl.TextScaled = false
	lbl.TextSize = 14
	lbl.TextWrapped = true
	lbl.Parent = parent
	return lbl
end

return UITheme
