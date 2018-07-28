module DjOps exposing (..)

-- Standard
import Html exposing (Html, div, text, select, option, input, p, br, span, table, tr, td, i)
import Html as Html
import Html.Attributes exposing (style, href, attribute)
import Html.Events exposing (onInput, on, on)
import Http as Http
import Time exposing (Time, second)
import Date exposing (Date)
import Regex
import Char
import Keyboard
import Set exposing (Set)
import Task exposing (Task)
import Process

-- Third Party
import Material
import Material.Button as Button
import Material.Textfield as Textfield
import Material.Table as Table
import Material.Options as Opts exposing (css)
import Material.Icon as Icon
import Material.Layout as Layout
import Material.Color as Color
import Material.Footer as Footer
import DatePicker
import List.Nonempty as NonEmpty exposing (Nonempty)
import List.Extra as ListX
import Hex as Hex
import Dialog as Dialog
import Maybe.Extra as MaybeEx exposing (isJust, isNothing)

-- Local
import ClockTime as CT
import Duration as Dur
import PointInTime as PiT exposing (PointInTime)
import XisRestApi as XisApi
import DjangoRestFramework as DRF


-----------------------------------------------------------------------------
-- CONSTANTS
-----------------------------------------------------------------------------

userIdFieldId = [1000, 1]
passwordFieldId = [1000, 2]

-----------------------------------------------------------------------------
-- MAIN
-----------------------------------------------------------------------------

main =
  Html.programWithFlags
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


-----------------------------------------------------------------------------
-- MODEL
-----------------------------------------------------------------------------

-- These are params from the server. Elm docs tend to call them "flags".

type alias Flags =
  { csrfToken : Maybe String
  , xisRestFlags : XisApi.XisRestFlags
  }

type RfidReaderState
  = Nominal
  | CheckingAnRfid Int  -- Int counts the number of seconds waited
  | HitAnHttpErr Http.Error
  | FoundRfidToBe Bool  -- Bool is True if Rfid was registered, else False.

type alias Model =
  { errMsgs : List String
  , mdl : Material.Model
  , xis : XisApi.Session Msg
  , currTime : PointInTime
  , selectedTab : Int
  , shows : List XisApi.Show
  , chosenShowsId : Maybe Int
  , showDate : Maybe Date
  , datePicker : DatePicker.DatePicker
  , member : Maybe XisApi.Member
  , nowPlaying : Maybe XisApi.NowPlaying
  --- RFID Reader state:
  , state : RfidReaderState
  , typed : String
  , rfidsToCheck : List Int
  , loggedAsPresent : Set Int
  --- Credentials:
  , userid : Maybe String
  , password : Maybe String
  }

init : Flags -> ( Model, Cmd Msg )
init flags =
  let
    auth = case flags.csrfToken of
      Just csrf -> DRF.LoggedIn csrf
      Nothing -> DRF.NoAuthorization
    getShowsCmd = model.xis.listShows ShowList_Result
    nowPlayingCmd = model.xis.nowPlaying NowPlaying_Result
    (datePicker, datePickerCmd ) = DatePicker.init
    model =
      { errMsgs = []
      , mdl = Material.model
      , xis = XisApi.createSession flags.xisRestFlags auth
      , currTime = 0
      , selectedTab = 0
      , shows = []
      , chosenShowsId = Nothing
      , showDate = Nothing
      , datePicker = datePicker
      , member = Nothing
      , nowPlaying = Nothing
      --- RFID Reader state:
      , state = Nominal
      , typed = ""
      , rfidsToCheck = []
      , loggedAsPresent = Set.empty
      --- Credentials:
      , userid = Nothing
      , password = Nothing
      }
  in
    ( model
    , Cmd.batch
      [ getShowsCmd
      , nowPlayingCmd
      , Cmd.map SetDatePicker datePickerCmd
      , Layout.sub0 Mdl
      ]
    )


-----------------------------------------------------------------------------
-- UPDATE
-----------------------------------------------------------------------------


type
  Msg
  = AcknowledgeDialog
  | Authenticate_Result (Result Http.Error XisApi.AuthenticationResult)
  | CheckNowPlaying
  | KeyDownRfid Keyboard.KeyCode
  | KeyDownAuthenticate Keyboard.KeyCode
  | Mdl (Material.Msg Msg)
  | MemberListResult (Result Http.Error (DRF.PageOf XisApi.Member))
  | MemberPresentResult (Result Http.Error XisApi.VisitEvent)
  | NowPlaying_Result (Result Http.Error XisApi.NowPlaying)
  | PasswordInput String
  | ShowList_Result (Result Http.Error (DRF.PageOf XisApi.Show))
  | ShowWasChosen String  -- ID of chosen show, as a String.
  | SelectTab Int
  | SetDatePicker DatePicker.Msg
  | Tick Time
  | UseridInput String



update : Msg -> Model -> ( Model, Cmd Msg )
update action model =
  let xis = model.xis
  in case action of

    AcknowledgeDialog ->
      ( { model
        | errMsgs = []
        , state = Nominal
        , typed = ""
        , rfidsToCheck = []
        , loggedAsPresent = Set.empty
        }
      , Cmd.none
      )

    Mdl msg_ ->
      Material.update Mdl msg_ model

    SelectTab k ->
      ( { model | selectedTab = k }, Cmd.none )

    Tick newTime ->
      let
        seconds = (round newTime) // 1000
        newModel = { model | currTime = newTime }
      in
        ( newModel, Cmd.none )

    UseridInput s ->
      ({model | userid = Just s}, Cmd.none)

    PasswordInput s ->
      ({model | password = Just s}, Cmd.none)

    ShowList_Result (Ok {results}) ->
      ({model | shows=results}, Cmd.none)

    ShowList_Result (Err error) ->
      ({model | errMsgs=[toString error]}, Cmd.none)

    ShowWasChosen idStr ->
      let
        chosenShowsId = String.toInt idStr |> Result.toMaybe
      in
        ({ model | chosenShowsId = chosenShowsId}, Cmd.none)

    SetDatePicker msg ->
      let
        (newDatePicker, datePickerCmd, dateEvent) =
          DatePicker.update DatePicker.defaultSettings msg model.datePicker
        date = case dateEvent of
          DatePicker.NoChange -> model.showDate
          DatePicker.Changed newDate -> newDate
      in
        ( { model | showDate = date, datePicker = newDatePicker}
        , Cmd.map SetDatePicker datePickerCmd
        )

    KeyDownAuthenticate code ->
      case (model.userid, model.password) of
        (Just id, Just pw) ->
          ( model
          , if code==13 then
              model.xis.authenticate id pw Authenticate_Result
            else
              Cmd.none
          )
        _ ->
          (model, Cmd.none)

    Authenticate_Result (Ok {isAuthentic, authenticatedMember}) ->
      let
        errMsgs = if isAuthentic then [] else ["Bad userid and/or password provided.", "Close this dialog and try again."]
      in
        ({model | member=authenticatedMember, errMsgs=errMsgs}, Cmd.none)

    Authenticate_Result (Err error) ->
      ({model | errMsgs=[toString error]}, Cmd.none)

    KeyDownRfid code ->
      let
        typed = case code of
          16 -> model.typed  -- i.e. ignore this shift code.
          190 -> ">"  -- i.e. start char resets the typed buffer.
          c -> model.typed ++ (c |> Char.fromCode |> String.fromChar)
        finds = Regex.find Regex.All delimitedRfidNum typed
      in
        if List.isEmpty finds then
          -- There aren't any delimited rfids
          ({model | typed=typed}, Cmd.none)
        else
          -- There ARE delimited rfids, so pull them out, process them, and pass a modified s through.
          let
            delimitedMatches = List.map .match finds
            hexMatches = List.map (String.dropLeft 1) delimitedMatches
            hexToInt = String.toLower >> Hex.fromString
            resultIntMatches = List.map hexToInt hexMatches
            intMatches = List.filterMap Result.toMaybe resultIntMatches
            newRfidsToCheck = ListX.unique (model.rfidsToCheck++intMatches)
          in
            checkAnRfid {model | typed=typed, rfidsToCheck=newRfidsToCheck}

    MemberListResult (Ok {results}) ->
      case results of

        member :: [] ->  -- Exactly ONE match. Good.
          let
            cmd2 =
              if Set.member member.id model.loggedAsPresent then
                Cmd.none
              else
                model.xis.createVisitEvent
                  { who = model.xis.memberUrl member.id
                  , when = model.currTime
                  , eventType = XisApi.VET_Present
                  , method = XisApi.VEM_FrontDesk
                  , reason = Nothing
                  }
                  MemberPresentResult
            newModel =
              { model
              | state = Nominal
              , rfidsToCheck = []
              , typed = ""
              , loggedAsPresent = Set.insert member.id model.loggedAsPresent
              }
          in
            (newModel, cmd2)

        [] ->  -- ZERO matches. Bad. Should not happen.
          -- TODO: Log something to indicate a program logic error.
          checkAnRfid {model | state=FoundRfidToBe False}

        member :: members ->  -- More than one match. Bad. Should not happen.
          -- TODO: Log something to indicate a program logic error.
          checkAnRfid {model | state=FoundRfidToBe False}

    MemberPresentResult (Ok _) ->
      -- Don't need to do anything when this succeeds.
      (model, Cmd.none)

    NowPlaying_Result (Ok np) ->
      let
        nowPlayingCmd = model.xis.nowPlaying NowPlaying_Result
        delaySeconds = case np.track of
          Just t ->
            let
              rs = t.remainingSeconds
            in
              if rs > 0 then rs * second
              else if rs < 1 && rs > -5 then 0.1 * second
              else 1 * second
          Nothing -> 1 * second
      in
        ( { model | nowPlaying = Just np }
        , delay delaySeconds CheckNowPlaying
        )

    CheckNowPlaying ->
        ( model
        , model.xis.nowPlaying NowPlaying_Result
        )

    -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

    MemberListResult (Err e) ->
      ({model | state=HitAnHttpErr e}, Cmd.none)

    MemberPresentResult (Err e) ->
      ({model | state=HitAnHttpErr e}, Cmd.none)

    NowPlaying_Result (Err e) ->
      ({model | nowPlaying = Nothing}, Cmd.none)


-----------------------------------------------------------------------------
-- VIEW
-----------------------------------------------------------------------------

tabs model =
  (
    [ text "start"
    , text "tracks"
    , text "underwriting"
    , text "finish"
    ]
  , [ Color.background <| Color.color Color.DeepPurple Color.S400
    , Color.text <| Color.color Color.Green Color.S400
    ]
  )


view : Model -> Html Msg
view model =
  div []
  [ Layout.render Mdl model.mdl
    [ Layout.fixedHeader
    , Layout.fixedTabs
    , Layout.onSelectTab SelectTab
    , Layout.selectedTab model.selectedTab
    ]
    { header = layout_header model
    , drawer = []
    , tabs = tabs model
    , main = [layout_main model]
    }
  , Dialog.view <| rfid_dialog_config model
  , Dialog.view <| err_dialog_config model
  ]


err_dialog_config : Model -> Maybe (Dialog.Config Msg)
err_dialog_config model =

  if List.length model.errMsgs > 0 then
    Just
      { closeMessage = Just AcknowledgeDialog
      , containerClass = Nothing
      , containerId = Nothing
      , header = Just (text "😱 Error")
      , body = Just <| div [] <| List.map ((p [])<<List.singleton<<text) model.errMsgs
      , footer = Nothing
      }
  else
    Nothing

tagattr x = attribute x x


showSelector : Model -> Html Msg
showSelector model =
  select
    [ onInput ShowWasChosen
    , style ["margin-left"=>"0px"]
    , attribute "required" ""
    ]
    <|
    ( option
       [ attribute "value" ""
       , tagattr <| if isNothing model.chosenShowsId then "selected" else "dummy"
       , tagattr "disabled"
       , tagattr "hidden"
       ]
       [text "Please pick a show..."]
    )
    ::
    (
      List.map
        (\show ->
          option
            [ attribute "value" (toString show.id)
            , tagattr <| case model.chosenShowsId of
                Just id -> if show.id == id then "selected" else "dummy"
                Nothing -> "dummy"
            ]
            [text show.data.title]
        )
        model.shows
    )


showDateSelector : Model -> Html Msg
showDateSelector model =
  div [style ["margin-left"=>"0px"]]
  [ (DatePicker.view
      model.showDate
      DatePicker.defaultSettings
      model.datePicker
    ) |> Html.map SetDatePicker
  ]

layout_header : Model -> List (Html Msg)
layout_header model =
  [Layout.title []
  [ Layout.row []
    [ layout_header_left model
    , Layout.spacer
    , layout_header_center model
    , Layout.spacer
    , layout_header_right model
    ]
  ]
  ]


layout_header_left : Model -> Html Msg
layout_header_left model =
  div [style ["width"=>"10%"]]
    [ span [style ["margin-right"=>"10px"]] [text "🎶 "]
    , text "DJ Ops"
    ]


layout_header_center : Model -> Html Msg
layout_header_center model =
  let
    children title artist =
      [ text "Title: ", i [] [text title]
      , br [] []
      , text " Artist: ", i [] [text artist]
      ]
  in
    div [style ["width"=>"50%", "font-size"=>"smaller"]]
    ( case model.nowPlaying of
        Just {show, track} ->
          case (show, track) of
            (Nothing, Just t) -> children t.title t.artist
            (_, _) -> [text "Not Yet Implemented"]
        Nothing -> children "..." "..."
    )


layout_header_right : Model -> Html Msg
layout_header_right model =
  div [style ["width"=>"30%"]]
    [ span [style ["margin-right"=>"10px"]]
      [ text "Show Starts in 00:33:34"]
    ]


layout_main : Model -> Html Msg
layout_main model =
  case model.selectedTab of
    0 ->
      tab_start model
    1 ->
      tab_tracks model
    _ ->
      p [] [text <| "Tab " ++ toString model.selectedTab ++ " not yet implemented."]


tab_start : Model -> Html Msg
tab_start model =
  let
    numTd isSet = td [style ["padding-left"=>"5px", "font-size"=>"24pt", "color"=>(if isSet then "green" else "red")]]
    instTd = td [style ["padding-left"=>"15px"]]
    checkTd = td []
    para = p [style ["margin-top"=>"10px"]]
    row = tr []
    break = br [] []
  in
    div [style ["margin"=>"30px", "zoom"=>"1.3"]]
    [ p [] [text "Welcome to the DJ Ops Console!"]
    , table []
      [ row
        [ numTd (isJust model.userid && isJust model.password && isJust model.member) [text "➊ "]
        , instTd
          [ para
            [ text "Log In:"
            , break
            , input
                [ attribute "placeholder" "userid"
                , attribute "value" <| Maybe.withDefault "" model.userid
                , onInput UseridInput
                ]
                []
            , break
            , input
                [ attribute "placeholder" "password"
                , attribute "type" "password"
                , attribute "value" <| Maybe.withDefault "" model.password
                , onInput PasswordInput
                ]
                []
            ]
          ]
        ]
      , row
        [ numTd (isJust model.chosenShowsId) [text "➋ "]
        , instTd [para [text "Choose a show to work on: ", br [] [], showSelector model]]
        ]
      , row
        [ numTd (isJust model.showDate) [text "➌ "]
        , instTd [para [text "Specify the show date: ", showDateSelector model]]
        ]
      ]
    ]



tab_tracks model =
  div []
  [ Table.table [css "margin" "20px"]
    [ Table.tbody []
      (List.map (tableRow model) (List.range 1 60))
    ]
  ]


tableRow : Model -> Int -> Html Msg
tableRow model r =
  let
    aTd s r c opts =
      Table.td restTdStyle
        [Textfield.render Mdl [r,c] model.mdl (opts++[Textfield.label s]) []]
  in
    Table.tr []
    [ Table.td firstTdStyle [text <| toString r]
    , aTd "Artist" r 1 []
    , aTd "Title" r 2 []
    , aTd "MM:SS" r 3 [css "width" "55px"]
    , Table.td firstTdStyle
      [ Button.render Mdl [r] model.mdl
        [ Button.fab
        , Button.plain
        -- , Options.onClick MyClickMsg
        ]
        [ Icon.i "play_arrow"]
      ]

    ]


-----------------------------------------------------------------------------
-- SUBSCRIPTIONS
-----------------------------------------------------------------------------

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ Time.every second Tick
    , Keyboard.downs KeyDownRfid
    , Keyboard.downs KeyDownAuthenticate
    , Layout.subs Mdl model.mdl
    ]


-----------------------------------------------------------------------------
-- UTILITIES
-----------------------------------------------------------------------------

-- From https://stackoverflow.com/questions/40599512/how-to-achieve-behavior-of-settimeout-in-elm
delay : Time.Time -> msg -> Cmd msg
delay time msg = Process.sleep time |> Task.perform (\_ -> msg)


-----------------------------------------------------------------------------
-- STYLES
-----------------------------------------------------------------------------

(=>) = (,)

userIdPwInputStyle =
  style
  [ "margin-left" => "50px"
  ]

firstTdStyle =
  [ css "border-style" "none"
  , css "color" "gray"
  , css "font-size" "26pt"
  , css "font-weight" "bold"
  ]

restTdStyle =
  [ css "border-style" "none"
  , css "padding-top" "0"
  ]


-----------------------------------------------------------------------------
-- RFID
-----------------------------------------------------------------------------

-- Example of RFID data: ">0C00840D"
-- ">" indicates start of data. It is followed by 8 hex characters.
-- "0C00840D" is the big endian representation of the ID

delimitedRfidNum = Regex.regex ">[0-9A-F]{8}"
rfidCharsOnly = Regex.regex "^>[0-9A-F]*$"


checkAnRfid : Model -> (Model, Cmd Msg)
checkAnRfid model =
  case model.state of

    CheckingAnRfid _ ->
      -- We only check one at a time, and a check is already in progress, so do nothing.
      (model, Cmd.none)

    HitAnHttpErr _ ->
      -- We probably shouldn't even get here. Do nothing, since the error kills any progress.
      (model, Cmd.none)

    FoundRfidToBe _ ->
      -- We probably shouldn't even get here. Do nothing.
      (model, Cmd.none)

    Nominal ->
      -- We'll check the first one on the list, if it's non-empty.
      case model.rfidsToCheck of

        rfid :: rfids ->
          let
            newModel = {model | rfidsToCheck=rfids, state=CheckingAnRfid 0}
            memberFilters = [XisApi.RfidNumberEquals rfid]
            listCmd = model.xis.listMembers memberFilters MemberListResult
          in
            (newModel, listCmd)

        [] ->
          -- There aren't any ids to check. Everything we've tried has failed.
          ({model | state=FoundRfidToBe False}, Cmd.none)


rfid_dialog_config : Model -> Maybe (Dialog.Config Msg)
rfid_dialog_config model =

  case model.state of

    Nominal ->
      Nothing

    FoundRfidToBe True ->
      Nothing

    _ ->
      Just
        { closeMessage = Just AcknowledgeDialog
        , containerClass = Nothing
        , containerId = Nothing
        , header = Just (text "🎶 RFID Check-In")
        , body = Just (rfid_dialog_body model)
        , footer = Nothing
        }


rfid_dialog_body : Model -> Html Msg
rfid_dialog_body model =

  case model.state of

    CheckingAnRfid waitCount ->
      p []
        [ text "One moment while we check our database."
        , text (String.repeat waitCount "●")
        ]

    FoundRfidToBe False ->
      p []
        [ text "Couldn't find your RFID in our database."
        , br [] []
        , text "Tap the BACK button and try again or"
        , br [] []
        , text "speak to a staff member for help."
        ]

    HitAnHttpErr e ->
      p []
        [ text "Tap the BACK button and try again or"
        , br [] []
        , text "speak to a staff member for help."
        ]

    _ -> text ""




-----------------------------------------------------------------------------
-- TICK (called each second)
-----------------------------------------------------------------------------

tick : Time -> Model -> (Model, Cmd Msg)
tick time model =
  case model.state of

    CheckingAnRfid wc ->
      ({model | state=CheckingAnRfid (wc+1)}, Cmd.none)

    _ ->
      (model, Cmd.none)


-----------------------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------------------

send : msg -> Cmd msg
send msg =
  Task.succeed msg

  |> Task.perform identity