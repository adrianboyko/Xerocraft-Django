
module ReceptionKiosk.CreatingAcctScene exposing (init, update, view, tick, CreatingAcctModel)

-- Standard
import Html exposing (..)
import Html.Attributes exposing (..)
import Regex exposing (regex)
import Time exposing (Time)

-- Third Party
import String.Extra exposing (..)

-- Local
import MembersApi as MembersApi
import XerocraftApi as XcApi
import ReceptionKiosk.Types exposing (..)
import ReceptionKiosk.SceneUtils exposing (..)
import ReceptionKiosk.ReasonForVisitScene exposing (ReasonForVisitModel)
import ReceptionKiosk.NewMemberScene exposing (NewMemberModel)
import ReceptionKiosk.NewUserScene exposing (NewUserModel)
import ReceptionKiosk.WaiverScene exposing (WaiverModel)

-----------------------------------------------------------------------------
-- INIT
-----------------------------------------------------------------------------

type alias CreatingAcctModel =
  { waitingForScrape : Bool
  , badNews : List String
  }

-- This type alias describes the type of kiosk model that this scene requires.
type alias KioskModel a =
  (SceneUtilModel
    { a
    | creatingAcctModel : CreatingAcctModel
    , newMemberModel : NewMemberModel
    , newUserModel: NewUserModel
    , reasonForVisitModel: ReasonForVisitModel
    , waiverModel : WaiverModel
    }
  )

init : Flags -> (CreatingAcctModel, Cmd Msg)
init flags =
  let sceneModel =
    { waitingForScrape = False
    , badNews = []
    }
  in (sceneModel, Cmd.none)

-----------------------------------------------------------------------------
-- UPDATE
-----------------------------------------------------------------------------

update : CreatingAcctMsg -> KioskModel a -> (CreatingAcctModel, Cmd Msg)
update msg kioskModel =

  let sceneModel = kioskModel.creatingAcctModel
  in case msg of

    CreatingAcctSceneWillAppear ->
      let
        memberModel = kioskModel.newMemberModel
        userModel = kioskModel.newUserModel
        waiverModel = kioskModel.waiverModel
        fullName = String.join " " [memberModel.firstName, memberModel.lastName]
        cmd = MembersApi.createNewAcct
          fullName userModel.userName memberModel.email userModel.password1 waiverModel.signature
          (CreatingAcctVector << XcAcctCreateResult)
      in
        (sceneModel, cmd)

    XcAcctCreateResult (Ok htmlResponseBody) ->
      let
        successIndicator = "<h1>You have successfully registered your check in! Welcome to Xerocraft!</h1>"
        userNameInUseIndicator = "<h2></h2>"
        -- Seems to present errors in div#Message.
        -- E.g. <div id="Message"><h2>This username is already being used.</h2></div>
        msgRegex = regex "<div id=\\\"Message\\\">.*</div>"
        tagRegex = regex "<[^>]*>"
        msgsFound = Regex.find (Regex.AtMost 1) msgRegex htmlResponseBody
        msg = case List.head msgsFound of
          Nothing -> ""
          Just m -> stripTags m.match
      in
        case msg of

          "You have successfully registered your check in! Welcome to Xerocraft!" ->
            -- This is the result we wanted. Account creation was successful.
            -- Rebase the scene stack since we don't want the user backtracking into acct creation again.
            let
              newModel = {sceneModel | badNews=[], waitingForScrape=True}
              scrapeLogins = XcApi.scrapeXcOrgLogins kioskModel.flags.scrapeLoginsUrl
              cmd = scrapeLogins (CreatingAcctVector << StartXcScrapeResult)
            in
              (newModel, cmd)

          "" ->
            -- Couldn't find a message so dump the entire response body as a debugging aid.
            -- We don't expect this to happen.
            ({sceneModel | badNews = [stripTags htmlResponseBody]}, Cmd.none)

          _ ->
            -- All other messages are treated as errors and reported as such to user.
            -- Many of the possible errors are validation related so we shouldn't see them if
            -- the client-side validation in earlier scenes was effective.
            ({sceneModel | badNews = [msg]}, Cmd.none)

    XcAcctCreateResult (Err error) ->
      -- These will be http errors.
      ({sceneModel | badNews = [toString error]}, Cmd.none)

    StartXcScrapeResult (Ok ignored) ->
      (sceneModel, send (WizardVector <| RebaseTo <| SignUpDone))

    StartXcScrapeResult (Err error) ->
      -- These will be http errors.
      ({sceneModel | badNews = [toString error]}, Cmd.none)

    
-----------------------------------------------------------------------------
-- VIEW
-----------------------------------------------------------------------------

view : KioskModel a -> Html Msg
view kioskModel =
  -- TODO: Don't present this to minors.
  -- TODO: Don't present this to people who have already signed.
  let
    sceneModel = kioskModel.creatingAcctModel
  in
    genericScene kioskModel
      "Creating Your Account!"
      "One moment please"
      ( text "Working..."
      )
      []  -- No buttons. Scene will automatically transition.

-----------------------------------------------------------------------------
-- TICK (called each second)
-----------------------------------------------------------------------------

tick : Time -> KioskModel a -> (CreatingAcctModel, Cmd Msg)
tick time kioskModel =
  let
    sceneModel = kioskModel.creatingAcctModel
  in
    (sceneModel, Cmd.none)