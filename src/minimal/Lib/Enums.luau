

local Enums = {
	DataStores = {
		Players = "Players",
		Test = "TestStore"
	},

	-- Stack-based list of contexts
	-- There are brief ones and lasting ones, the brief ones are reset once the context wraps up
	-- wheras the lasting ones are set permenantly prior to the associated brief contexts being used
	-- Mostly for internal soundness checking
	--
	-- Also allows a thread from some stage to wait for specific stages to pass
	-- 	for example loading players takes time and is "done" at known stages on client
	--
	-- This enum must be numerically sorted acording to the order the steps are executed
	LOAD_CONTEXTS = {
		COLLECTION = 1,
		REQUIRE = 2,
		COLLECTED = 3,

		RUNNING_STAGES = 4,

		FINISHED = 1000
	},

	META_CONTEXTS = {
		CLIENT = 1,
		SERVER = 2,
		AUTO = 3,
		BOTH = 4,
		[1] = "CLIENT",
		[2] = "SERVER",
		[3] = "AUTO",
		[4] = "BOTH",
	},

	-- These values are arbitrary but supposed to be not be used by other Input enums values
	-- 990 seemed like a suitable starting number
	InputGestures = {
		Left = 800,
		Right = 801,
		Up = 802,
		Down = 803,
		None = 804,
	},

	AuxiliaryInputCodes = {
		KeyCodes = {
			Any = 901,
		},
		InputGestures = {
			Any = 1001,
			Total = 1002,
			Last = 1003,
		}
	},

	UserInputType = {
		Gesture = 2001,
		DPad = 2002,
	},

	GestureDisplayMode = {
		Off = 1,
		Last = 2,
		Temp = 3,
	},

	AllInputs = { },

	EmissionShape = {
		Edge = 0,
		Disc = 1,
		Area = 2,
		Center = 3,
	},
	EmissionDirection = {
		Up = 0,
		Down = 1,
		Left = 2,
		Right = 3,
		In = 4,
		Out = 5,
	},
	EmissionEdge = {
		Top = 0,
		Bottom = 1,
		Left = 2,
		Right = 3,
	},
	ForcerType = {
		Collision = 0,
	},
	SpriteSheetMode = {
		Linear = 0,
		Complete = 1,
	},

	CameraMode = {
		Studio = 2,
		Constant = 3,
		ThirdPersonLocked = 4,
	},

	LayoutOrder = {
		Primary = 1,
		Secondary = 2,
		Tertiary = 3,
		Special = 4,
	},

	ResetType = {
		OnDeath = 1,
		EachRound = 2,
		Both = 3,
	},

	DataTypes = {
		RbxEnum = 0,
		EnumItem = 0,

		Enums = 1,
		boolean = 2,
		string = 3,
		Color3 = 4,
		number = 5,
		UDim2 = 6,
	},

	WidgetPositions = {
		TopCenter = 0,
		RightCenter = 1,
		BottomCenter = 2,
		LeftCenter = 3,
		TopRight = 4,
		TopLeft = 5,
		BottomLeft = 6,
		BottomRight = 7,
		Center = 8,
	},

	InputDeclinedReason = {
		TooLong = 0,
		TooShort = 1,
		InvalidCharacters = 2,
		Unchanged = 3,
		NotUnique = 4,
		Spamming = 5,
		FrequencyLimit = 6,
		FilterIssues = 7,
		Unknown = 8,
		Filtered = 9,
		TeamFire = 10
	},

	-- Related to Interactables within the world
	InteractShowType = {
		Enabled = 1,
		Locked = 2,
		Unavailable = 3,
		Disabled = 4,
	},

	ShowInteractType = {
		Hover = 1,
		Range_Hover = 2, -- Hover overrides range
		None = 3,
	},

	InteractBasis = {
		Mouse = 1,
		Range = 2,
	},

	InteractType = {
		Inventory = 2,
		None = 3,			--Useful for interactables with no client behavior because the client won't need to know type.
		PromptString = 4,
		HoverPromptString = 5,
		HoverPromptStringPress = 6,
		Quest = 7,
		Shrine = 8,
		NPC = 9,
		GraveStone = 10,
	}
}

for _, enums in Enum:GetEnums() do
	local items = enums:GetEnumItems()
	local enum_name = tostring(enums)

	Enums[enum_name] = Enums[enum_name] or table.create(#items)
	local these_enums = Enums[enum_name]

	for _, item in enums:GetEnumItems() do
		these_enums[item.Name] = item
	end
end

for _, v in pairs(Enum.KeyCode:GetEnumItems())do
	Enums.AllInputs[ string.split(tostring(v), ".")[3] ] = v
end
for _, v in pairs(Enum.UserInputType:GetEnumItems())do
	Enums.AllInputs[ string.split(tostring(v), ".")[3] ] = v
end
Enums.AllInputs.Unknown = nil

return Enums
