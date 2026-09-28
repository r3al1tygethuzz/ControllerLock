--// CONTROLLER-ONLY CAMERA LOCK
--// ButtonY = Lock / Unlock
--// Sticky Target System
--// Camera aims 7 studs below target

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--==================================================
-- SETTINGS
--==================================================

local LOCK_BUTTON = Enum.KeyCode.ButtonY

-- Camera aims this many studs below the target
local AIM_OFFSET = Vector3.new(0, -7, 0)

-- Maximum distance for selecting a target
local MAX_TARGET_DISTANCE = 500

-- Camera smoothness
local CAMERA_SMOOTHNESS = 0.25

-- Set to true if teammates shouldn't be targetable
local TEAM_CHECK = false

--==================================================
-- STATE
--==================================================

local IsLocked = false

-- IMPORTANT:
-- This is the ONLY player we follow while locked.
local LockedTarget = nil

--==================================================
-- CHARACTER
--==================================================

local function GetCharacterInfo(Player)

	if not Player then
		return nil
	end

	local Character = Player.Character

	if not Character then
		return nil
	end

	local Humanoid =
		Character:FindFirstChildOfClass("Humanoid")

	local Root =
		Character:FindFirstChild("HumanoidRootPart")

	if not Humanoid or not Root then
		return nil
	end

	if Humanoid.Health <= 0 then
		return nil
	end

	return Character, Humanoid, Root
end

--==================================================
-- TARGET VALIDATION
--==================================================

local function IsValidTarget(Player)

	if not Player then
		return false
	end

	-- Never target yourself
	if Player == LocalPlayer then
		return false
	end

	-- Optional team check
	if TEAM_CHECK then
		if Player.Team == LocalPlayer.Team then
			return false
		end
	end

	local Character, Humanoid, Root =
		GetCharacterInfo(Player)

	if not Character or not Humanoid or not Root then
		return false
	end

	-- Make sure the target isn't too far away
	local LocalCharacter = LocalPlayer.Character

	if not LocalCharacter then
		return false
	end

	local LocalRoot =
		LocalCharacter:FindFirstChild("HumanoidRootPart")

	if not LocalRoot then
		return false
	end

	local Distance =
		(Root.Position - LocalRoot.Position).Magnitude

	if Distance > MAX_TARGET_DISTANCE then
		return false
	end

	return true
end

--==================================================
-- FIND CLOSEST PLAYER TO CONTROLLER CURSOR
--==================================================

local function FindClosestTarget()

	local ViewportSize = Camera.ViewportSize

	-- Center of the screen.
	-- This is where the controller camera cursor is.
	local CursorPosition = Vector2.new(
		ViewportSize.X / 2,
		ViewportSize.Y / 2
	)

	local ClosestPlayer = nil
	local ClosestDistance = math.huge

	for _, Player in ipairs(Players:GetPlayers()) do

		if IsValidTarget(Player) then

			local Character, Humanoid, Root =
				GetCharacterInfo(Player)

			if Character and Humanoid and Root then

				local ScreenPosition, OnScreen =
					Camera:WorldToViewportPoint(
						Root.Position
					)

				if OnScreen and ScreenPosition.Z > 0 then

					local TargetScreenPosition =
						Vector2.new(
							ScreenPosition.X,
							ScreenPosition.Y
						)

					local DistanceFromCursor =
						(TargetScreenPosition - CursorPosition).Magnitude

					if DistanceFromCursor < ClosestDistance then

						ClosestDistance =
							DistanceFromCursor

						ClosestPlayer = Player
					end
				end
			end
		end
	end

	return ClosestPlayer
end

--==================================================
-- UNLOCK
--==================================================

local function Unlock()

	IsLocked = false

	-- Completely forget the old target.
	LockedTarget = nil
end

--==================================================
-- LOCK
--==================================================

local function Lock()

	-- Find the target ONLY when the player presses Y
	local Target = FindClosestTarget()

	if not Target then
		return
	end

	-- Save this exact player.
	-- We do NOT run FindClosestTarget again while locked.
	LockedTarget = Target

	IsLocked = true
end

--==================================================
-- BUTTON Y
--==================================================

UserInputService.InputBegan:Connect(function(Input, GameProcessed)

	-- Controller ONLY
	if Input.UserInputType ~= Enum.UserInputType.Gamepad1 then
		return
	end

	if GameProcessed then
		return
	end

	if Input.KeyCode == LOCK_BUTTON then

		-- Y while unlocked = LOCK
		if not IsLocked then

			Lock()

		-- Y while locked = UNLOCK
		else

			Unlock()
		end
	end
end)

--==================================================
-- CAMERA
--==================================================

RunService:BindToRenderStep(
	"ControllerStickyCameraLock",
	Enum.RenderPriority.Camera.Value + 1,
	function(DeltaTime)

		if not IsLocked then
			return
		end

		-- IMPORTANT:
		-- We NEVER search for another player here.
		--
		-- LockedTarget remains the original target.
		if not LockedTarget then
			Unlock()
			return
		end

		-- Check ONLY the original target.
		local Character, Humanoid, Root =
			GetCharacterInfo(LockedTarget)

		-- If the original target dies/disappears,
		-- unlock instead of switching to someone else.
		if not Character or not Humanoid or not Root then

			Unlock()

			return
		end

		--==================================================
		-- 7 STUDS BELOW TARGET
		--==================================================

		local AimPosition =
			Root.Position + AIM_OFFSET

		-- Keep the camera's current position.
		local CameraPosition =
			Camera.CFrame.Position

		-- Look toward the point 7 studs below target.
		local DesiredCFrame =
			CFrame.lookAt(
				CameraPosition,
				AimPosition
			)

		-- Smooth camera rotation
		local Alpha =
			1 - math.pow(
				1 - CAMERA_SMOOTHNESS,
				DeltaTime * 60
			)

		Camera.CFrame =
			Camera.CFrame:Lerp(
				DesiredCFrame,
				Alpha
			)
	end
)
