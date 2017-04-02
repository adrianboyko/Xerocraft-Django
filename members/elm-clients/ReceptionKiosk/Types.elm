module ReceptionKiosk.Types exposing (..)

-- Standard
import Http

-- Third Party
import Material

-- Local
import ReceptionKiosk.Backend exposing (..)

-----------------------------------------------------------------------------
-- FLAGS
-----------------------------------------------------------------------------

type alias Flags =
  { csrfToken: String
  , orgName: String
  , bannerTopUrl: String
  , bannerBottomUrl: String
  , discoveryMethodsUrl: String
  }

-----------------------------------------------------------------------------
-- MODEL TYPES
-----------------------------------------------------------------------------

type Scene
  = CheckIn
  | Done
  | DoYouHaveAcct
  | HowDidYouHear
  | NewMember
  | NewUser
  | ReasonForVisit
  | Waiver
  | Welcome

type alias CheckInModel =
  { flexId : String  -- UserName or surname.
  , matches : List MatchingAcct  -- Matches to username/surname
  , badNews : List String
  }

type alias DoneModel =
  {
  }

type alias DoYouHaveAcctModel =
  {
  }

type alias HowDidYouHearModel =
  { discoveryMethods : List DiscoveryMethod  -- Fetched from backend
  , badNews : List String
  }

type alias NewMemberModel =
  { firstName: String
  , lastName: String
  , email: String
  , isAdult: Bool
  , badNews: List String
  }

type alias NewUserModel =
  { userName: String
  , password1: String
  , password2: String
  , badNews: List String
  }

type ReasonForVisit
  = Curiousity
  | ClassParticipant
  | MemberPrivileges
  | GuestOfMember
  | Volunteer
  | Other

type alias ReasonForVisitModel =
  { reasonForVisit: Maybe ReasonForVisit
  }

type alias WaiverModel =
  { isSigning : Bool
  , signature : String  -- This is a data URL
  , badNews : List String
  }

type alias WelcomeModel =
  {
  }

type alias Model =
  { flags : Flags
  , sceneStack : List Scene -- 1st element is the top of the stack
  -- elm-mdl model:
  , mdl : Material.Model  -- TODO: Should there be one dedicated Material model per scene so index scope is smaller?
  -- Scene models:
  , checkInModel        : CheckInModel
  , doneModel           : DoneModel
  , doYouHaveAcctModel  : DoYouHaveAcctModel
  , howDidYouHearModel  : HowDidYouHearModel
  , newMemberModel      : NewMemberModel
  , newUserModel        : NewUserModel
  , reasonForVisitModel : ReasonForVisitModel
  , waiverModel         : WaiverModel
  , welcomeModel        : WelcomeModel
  }

-----------------------------------------------------------------------------
-- MSG TYPES
-----------------------------------------------------------------------------

type CheckInMsg
  = UpdateMatchingAccts (Result Http.Error MatchingAcctInfo)
  | UpdateFlexId String
  | LogCheckIn Int

type HowDidYouHearMsg
  = AccDiscoveryMethods (Result Http.Error DiscoveryMethodInfo)  -- "Acc" means "accumulate"
  | ToggleDiscoveryMethod DiscoveryMethod

type NewMemberMsg
  = UpdateFirstName String
  | UpdateLastName String
  | UpdateEmail String
  | ToggleIsAdult
  | Validate

type NewUserMsg
  = ValidateUserNameAndPw
  | ValidateUserNameUnique (Result Http.Error MatchingAcctInfo)
  | UpdateUserName String
  | UpdatePassword1 String
  | UpdatePassword2 String

type ReasonForVisitMsg
  = UpdateReasonForVisit ReasonForVisit

type WaiverMsg
  = ShowSignaturePad String
  | ClearSignaturePad String
  | GetSignature
  | UpdateSignature String  -- String is a data URL representation of an image.
  | AccountCreationResult (Result Http.Error String)
  | WaiverSceneWillAppear

type WelcomeMsg
  = WelcomeSceneWillAppear

type Msg
  -- elm-mdl messages:
  = MdlVector (Material.Msg Msg)
  -- Stack manipulation messages:
  | Push Scene
  | Pop
  -- Wixard messages:
  | Reset
  | SceneWillAppear Scene
  -- scene messages:
  | CheckInVector CheckInMsg
  | HowDidYouHearVector HowDidYouHearMsg
  | NewMemberVector NewMemberMsg
  | NewUserVector NewUserMsg
  | ReasonForVisitVector ReasonForVisitMsg
  | WaiverVector WaiverMsg
  | WelcomeVector WelcomeMsg