

local Enums: NLEnums = {
	DataStores = {
		Players = "Players",
		Test = "TestStore"
	},

	-- This enum must be numerically sorted acording to the order the steps are executed
	-- These values describe the state of LazyModules startup
	LOAD_CONTEXTS = {
		PRELOAD = 1,
		LOAD_INIT = 2,
		SIGNAL_BUILDING = 4,

		AWAITING_SERVER_DATA = 5,
		LOAD_DATASTORES = 6,
		LOAD_GAMESTATE = 7,

		FINALIZE = 8,
		RUN = 9,

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

	Notifications = {
		TypeWriter = 1,
		Reward = 2,
		Extreme = 3,
	},

	TypeWriter = {
		TeamFull = 1,
		NearFinish = 2,
		Capture = 3,
		Neutralize = 4,
		TeamFire = 5,
		NotInGroup = 6,
		MathAnswer = 11,
		MaxBlueprints = 12,
		OutOfAmmo = 15,
		
		CTFDestination = 16,
		
		TeamWon = 13,
		TeamLost = 14,

		FriendRewardWillWork = 7,
		CannotPromptFriends = 8,
		FriendJoinedReward = 9,

		MustUnequipPowerUp = 10,
	},

	Reward = {
		Kill = 1,
		Major = 2,
		Minor = 3,
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

	MouseIconTypes = {
		Projectile = 1,
	},

	GraphStatOptions = {
		AllTimeKDR = 15,
		AllTimeEDR = 16,
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
	},

	VoteType = {
		Standard = 1,
		Weighted = 2,
	},

	GameState = {
		MapVoting = 1,
		GamemodeVoting = 2,
		Intermission = 3,
		Building = 4,
		Match = 5,
		Siege = 6,
		RoundFinish = 7,
		Cleanup = 8,
	},
	-- Character Hacking
	CheatReason = {
		OffOfYAxis = 1,
		TooFast = 2,
		OutOfBounds = 3,
		Flying = 4,
		NoClipping = 5,
		RemovingParts = 6,
	},
	CheatReasonStrings = {
		[1] = "OffOfYAxis",
		[2] = "TooFast",
		[3] = "OutOfBounds",
		[4] = "Flying",
		[5] = "NoClipping",
		[6] = "RemovingParts",
	},
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
