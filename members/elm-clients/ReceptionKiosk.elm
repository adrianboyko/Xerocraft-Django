port module ReceptionKiosk exposing (..)

import Html exposing (Html, Attribute, a, div, text, span, button, br, p, img, h1, h2, ol, li, b, canvas)
import Html.Attributes exposing (style, src, id, tabindex)
import Regex exposing (regex)
import Http
import Task
import Json.Decode as Dec
import Json.Encode as Enc

import Update.Extra.Infix exposing ((:>))

import Json.Decode.Pipeline exposing (decode, required, hardcoded)

import List.Extra

import Material.Textfield as Textfield
import Material.Button as Button
import Material.Toggles as Toggles
import Material.Chip as Chip
import Material.Options as Options exposing (css)
import Material.List as Lists
import Material


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
-- Utilities
-----------------------------------------------------------------------------

replaceAll : String -> String -> String -> String
replaceAll theString oldSub newSub =
  Regex.replace Regex.All (regex oldSub ) (\_ -> newSub) theString

djangoizeId : String -> String
djangoizeId rawId =
  -- TODO: Replacing spaces handles 90% of cases, but need to handle other forbidden chars.
  replaceAll rawId " " "_"


-----------------------------------------------------------------------------
-- MODEL
-----------------------------------------------------------------------------

-- These are params from the server. Elm docs tend to call them "flags".
type alias Flags =
  { csrfToken: String
  , orgName: String
  , bannerTopUrl: String
  , bannerBottomUrl: String
  , discoveryMethodsUrl: String
  }

type Scene
  = Welcome
  | HaveAcctQ
  | CheckIn
  | LetsCreate
  | ChooseUserNameAndPw
  | HowDidYouHear
  | Waiver
  | Rules
  | Activity
  | SupportUs
  | Done

type alias DiscoveryMethod =
  { id: Int
  , name: String
  , order: Int
  , selected: Bool
  }

type alias DiscoveryMethodInfo =
  { count: Int
  , next: Maybe String
  , previous: Maybe String
  , results: List DiscoveryMethod
  }

type alias Acct =
  { userName: String
  , password: String
  , password2: String  -- The password retyped.
  , memberNum: Maybe Int
  , firstName: String
  , lastName: String
  , email: String
  , isAdult: Bool
  }

blankAcct : Acct
blankAcct = Acct
    ""
    ""
    ""
    Nothing
    ""
    ""
    ""
    False

type alias MatchingAcct =
  { userName: String
  , memberNum: Int
  }

type alias MatchingAcctInfo =
  { target: String
  , matches: List MatchingAcct
  }

type alias Model =
  { csrfToken: String
  , orgName: String
  , bannerTopUrl: String
  , bannerBottomUrl: String
  , discoveryMethodsUrl: String
  , sceneStack: List Scene  -- 1st element is the top of the stack
  , mdl: Material.Model
  , flexId: String  -- UserName, surname, or email.
  , visitor: Acct
  , matches: List MatchingAcct  -- Matches to username/surname
  , discoveryMethods: List DiscoveryMethod  -- Fetched from backend
  , isSigning: Bool
  , error: Maybe String
  }

init : Flags -> (Model, Cmd Msg)
init f =
  ( Model
      f.csrfToken
      f.orgName
      f.bannerTopUrl
      f.bannerBottomUrl
      f.discoveryMethodsUrl
      [Welcome]
      Material.model
      ""
      blankAcct
      []
      []
      False
      Nothing
  , Cmd.none
  )

-- reset restores the model as it was after init.
reset : Model -> (Model, Cmd Msg)
reset m =
    init (Flags m.csrfToken m.orgName m.bannerTopUrl m.bannerBottomUrl m.discoveryMethodsUrl)

-----------------------------------------------------------------------------
-- UPDATE
-----------------------------------------------------------------------------

type Msg
  = Mdl (Material.Msg Msg)  -- For elm-mdl
  | PushScene Scene
  | PopScene
  | AfterSceneChangeTo Scene
  | UpdateFlexId String
  | UpdateFirstName String
  | UpdateLastName String
  | UpdateEmail String
  | ToggleIsAdult
  | UpdateUserName String
  | UpdatePassword String
  | UpdatePassword2 String
  | UpdateMatchingAccts (Result Http.Error MatchingAcctInfo)
  | LogCheckIn Int
  | AccDiscoveryMethods (Result Http.Error DiscoveryMethodInfo)  -- "Acc" means "accumulate"
  | ToggleDiscoveryMethod DiscoveryMethod
  | ShowSignaturePad String


port initSignaturePad : String -> Cmd msg

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of

    Mdl msg2 ->
      Material.update Mdl msg2 model

    PushScene Welcome ->
      -- Segue to "Welcome" is a special case since it resets the model.
      reset model

    PushScene nextScene ->
      -- Push the new scene onto the scene stack.
      let
        newModel = {model | sceneStack = nextScene::model.sceneStack }
      in
        (newModel, Cmd.none) :> update (AfterSceneChangeTo nextScene)

    PopScene ->
      -- Pop the top scene off the stack.
      let
        newModel = {model | sceneStack = Maybe.withDefault [Welcome] (List.tail model.sceneStack) }
        newScene = Maybe.withDefault Welcome (List.head newModel.sceneStack)
      in
        (newModel, Cmd.none) :> update (AfterSceneChangeTo newScene)

    AfterSceneChangeTo LetsCreate ->
      -- This is a good place to start fetching the "discovery methods" from backend.
      let
        url = model.discoveryMethodsUrl ++ "?format=json"  -- Easier than an "Accept" header.
        request = Http.get url decodeDiscoveryMethodInfo
        cmd =
          if List.length model.discoveryMethods == 0
          then Http.send AccDiscoveryMethods request
          else Cmd.none -- Don't fetch if we already have them. Can happen with backward scene navigation.
      in
        (model, cmd)

    AfterSceneChangeTo Waiver ->
      ({model | isSigning=False}, Cmd.none)

    AfterSceneChangeTo newScene ->
      -- The default is to do nothing unusual after a scene change.
      (model, Cmd.none)

    UpdateFlexId rawId ->
      let id = djangoizeId rawId
      in
        if (String.length id) > 1
        then
          let
            url = "/members/reception/matching-accts/"++id++"/"
            request = Http.get url decodeMatchingAcctInfo
            cmd = Http.send UpdateMatchingAccts request
          in
            ({model | flexId = id}, cmd)
        else
          ({model | matches = [], flexId = id}, Cmd.none )

    UpdateFirstName newVal ->
      let v = model.visitor  -- This is necessary because of a bug in PyCharm elm plugin.
      in ({model | visitor = {v | firstName = newVal }}, Cmd.none)

    UpdateLastName newVal ->
      let v = model.visitor  -- This is necessary because of a bug in PyCharm elm plugin.
      in ({model | visitor = {v | lastName = newVal }}, Cmd.none)

    UpdateEmail newVal ->
      let v = model.visitor  -- This is necessary because of a bug in PyCharm elm plugin.
      in ({model | visitor = {v | email = newVal }}, Cmd.none)

    ToggleIsAdult ->
      let v = model.visitor  -- This is necessary because of a bug in PyCharm elm plugin.
      in ({model | visitor = {v | isAdult = not v.isAdult }}, Cmd.none)

    UpdateUserName newVal ->
      let v = model.visitor  -- This is necessary because of a bug in PyCharm elm plugin.
      in ({model | visitor = {v | userName = newVal }}, Cmd.none)

    UpdatePassword newVal ->
      let v = model.visitor  -- This is necessary because of a bug in PyCharm elm plugin.
      in ({model | visitor = {v | password = newVal }}, Cmd.none)

    UpdatePassword2 newVal ->
      let v = model.visitor  -- This is necessary because of a bug in PyCharm elm plugin.
      in ({model | visitor = {v | password2 = newVal }}, Cmd.none)

    UpdateMatchingAccts (Ok {target, matches}) ->
      if target == model.flexId
      then ({model | matches = matches, error = Nothing}, Cmd.none)
      else (model, Cmd.none)

    UpdateMatchingAccts (Err error) ->
      ({model | error = Just (toString error)}, Cmd.none)

    LogCheckIn memberNum ->
      -- TODO: Log the visit. Might be last feature to be implemented to avoid collecting bogus visits during alpha testing.
      (model, Cmd.none) :> update (PushScene Done)

    AccDiscoveryMethods (Ok {count, next, previous, results}) ->
      -- Data from backend might be paged, so we need to accumulate the batches as they come.
      let
        methods = model.discoveryMethods ++ results
      in
        -- Also need to deal with "next", if it's not Nothing.
        ({model | discoveryMethods = methods}, Cmd.none)

    AccDiscoveryMethods (Err error) ->
      ({model | error = Just (toString error)}, Cmd.none)

    ToggleDiscoveryMethod dm ->
      let
        replace = List.Extra.replaceIf
        picker = \x -> x.id == dm.id
        replacement = { dm | selected = not dm.selected }
      in
        -- TODO: This should also add/remove the discovery method choice on the backend.
        ({model | discoveryMethods = replace picker replacement model.discoveryMethods}, Cmd.none)

    ShowSignaturePad canvasId ->
      ({model | isSigning=True}, initSignaturePad canvasId)


-----------------------------------------------------------------------------
-- VIEW
-----------------------------------------------------------------------------

type alias ButtonSpec = { title : String, msg: Msg }

sceneButton : Model -> ButtonSpec -> Html Msg
sceneButton model buttonSpec =
  Button.render Mdl [0] model.mdl
    ([ Button.raised, (Options.onClick buttonSpec.msg)]++viewButtonCss)
    [ text buttonSpec.title ]

sceneTextField : Model -> Int -> String -> String -> (String -> Msg) -> Html Msg
sceneTextField model index hint value msger =
  Textfield.render Mdl [index] model.mdl
    [ Textfield.label hint
    , Textfield.floatingLabel
    , Textfield.value value
    , Options.onInput msger
    , css "width" "500px"
    ]
    (text "spam") -- What is this Html Msg argument?

scenePasswordField : Model -> Int -> String -> String -> (String -> Msg) -> Html Msg
scenePasswordField model index hint value msger =
  Textfield.render Mdl [index] model.mdl
    [ Textfield.label hint
    , Textfield.password
    , Textfield.floatingLabel
    , Textfield.value value
    , Options.onInput msger
    ]
    (text "spam") -- What is this Html Msg argument?

sceneCheckbox : Model -> Int -> String -> Bool -> Msg -> Html Msg
sceneCheckbox model index label value msger =
  -- Toggle.checkbox doesn't seem to handle centering very well. The following div compensates for that.
  div [style ["text-align"=>"left", "display"=>"inline-block", "width"=>"400px"]]
    [ Toggles.checkbox Mdl [index] model.mdl
        [ Options.onToggle msger
        , Toggles.ripple
        , Toggles.value value
        ]
        [span [style ["font-size"=>"24pt"]] [ text label ]]
    ]

navButtons : Model -> Html Msg
navButtons model =
  div [navDivStyle]
    (
    if List.length model.sceneStack > 1
    then
      [ Button.render Mdl [0] model.mdl
          ([Button.flat, Options.onClick PopScene]++navButtonCss)
          [text "Back"]
      , hspace 600
      , Button.render Mdl [0] model.mdl
          ([Button.flat, Options.onClick (PushScene Welcome)]++navButtonCss)
          [text "Quit"]
      ]
    else
      [text ""]
    )

vspace : Int -> Html Msg
vspace amount =
  div [style ["height" => (toString amount ++ "px")]] []

hspace : Int -> Html Msg
hspace amount =
  div [style ["display" => "inline-block", "width" => (toString amount ++ "px")]] []

sceneView: Model -> String -> String -> Html Msg -> List ButtonSpec -> Html Msg
sceneView model inTitle inSubtitle extraContent buttonSpecs =
  let
    title = replaceAll inTitle "ORGNAME" model.orgName
    subtitle = replaceAll inSubtitle "ORGNAME" model.orgName
  in
    canvasView model
      [ p [sceneTitleStyle] [text title]
      , p [sceneSubtitleStyle] [text subtitle]
      , extraContent
      , vspace 50
      , div [] (List.map (sceneButton model) buttonSpecs)
      , case model.error of
          Just err -> text err
          Nothing -> text ""
      ]

canvasView: Model -> List (Html Msg) -> Html Msg
canvasView model scene =
  div [canvasDivStyle]
    [ img [src model.bannerTopUrl, bannerTopStyle] []
    , div [sceneDivStyle] scene
    , navButtons model
    , img [src model.bannerBottomUrl, bannerBottomStyle] []
    ]

howDidYouHearChoices : Model -> Html Msg
howDidYouHearChoices model =
  Lists.ul howDidYouHearCss
    (List.map
      ( \dm ->
          Lists.li [css "font-size" "18pt"]
            [ Lists.content [] [ text dm.name ]
            , Lists.content2 []
              [ Toggles.checkbox Mdl [1000+dm.id] model.mdl  -- 1000 establishes an id range for these.
                  [ Toggles.value dm.selected
                  , Options.onToggle (ToggleDiscoveryMethod dm)
                  ]
                  []
              ]
            ]
      )
      model.discoveryMethods
    )

view : Model -> Html Msg
view model =
  -- Default of "Welcome" elegantly guards against stack underflow, which should not occur.
  case Maybe.withDefault Welcome (List.head model.sceneStack) of

    Welcome ->
      sceneView model
        "Welcome!"
        "Is this your first visit?"
        (text "")
        [ ButtonSpec "First Visit" (PushScene HaveAcctQ)
        , ButtonSpec "Returning" (PushScene CheckIn)
        ]

    HaveAcctQ ->
      sceneView model
        "Great!"
        "Do you already have an account here or on our website?"
        (text "")
        [ ButtonSpec "Yes" (PushScene CheckIn)
        , ButtonSpec "No" (PushScene LetsCreate)
        -- TODO: How about a "I don't know" button, here?
        ]

    CheckIn ->
      sceneView model
        "Let's Get You Checked-In!"
        "Who are you?"
        ( div []
            (List.concat
              [ [sceneTextField model 1 "Your Username or Surname" model.flexId UpdateFlexId, vspace 0]
              , if List.length model.matches > 0
                 then [vspace 30, text "Tap your userid, below:", vspace 20]
                 else [vspace 0]
              , List.map (\acct -> Chip.button [Options.onClick (LogCheckIn acct.memberNum)] [ Chip.content [] [ text acct.userName]]) model.matches
              ]
            )
        )
        []  -- No buttons

    LetsCreate ->
      sceneView model
        "Let's Create an Account!"
        "Please tell us about yourself:"
        ( div []
            [ sceneTextField model 2 "Your first name" model.visitor.firstName UpdateFirstName
            , vspace 0
            , sceneTextField model 3 "Your last name" model.visitor.lastName UpdateLastName
            , vspace 0
            , sceneTextField model 4 "Your email address" model.visitor.email UpdateEmail
            , vspace 30
            , sceneCheckbox model 5 "Check if you are 18 or older!" model.visitor.isAdult ToggleIsAdult
            ]
        )
        [ButtonSpec "OK" (PushScene ChooseUserNameAndPw)]

    ChooseUserNameAndPw ->
      sceneView model
        "Id & Password"
        "Please chooose a user name and password for your account:"
        ( div []
            [ sceneTextField model 6 "Choose a user name" model.visitor.userName UpdateUserName
            , vspace 0
            , scenePasswordField model 7 "Choose a password" model.visitor.password UpdatePassword
            , vspace 0
            , scenePasswordField model 8 "Type password again" model.visitor.password2 UpdatePassword2
            ]
        )
        [ButtonSpec "Create Account" (PushScene HowDidYouHear)]

    HowDidYouHear ->
      sceneView model
        "Just Wondering"
        "How did you hear about us?"
        (howDidYouHearChoices model)
        [ButtonSpec "OK" (PushScene Waiver)]

    Waiver ->
      -- TODO: Don't present this to minors.
      sceneView model
        ("Be Careful at " ++ model.orgName ++ "!")
        "Please read and sign the following waiver"
        (div []
          [ vspace 20
          , div [id "waiver-box", (waiverBoxStyle model.isSigning)]
              waiverHtml
          , div [style ["display"=>if model.isSigning then "block" else "none"]]
              [ p [style ["margin-top"=>"50px", "font-size"=>"16pt", "margin-bottom"=>"5px"]]
                [text "sign in box below:"]
              , canvas [id "signature-pad", signaturePadStyle] []
              ]
          ]
        )
        ( if model.isSigning
          then [ButtonSpec "Accept" (PushScene Rules)]
          else [ButtonSpec "Sign" (ShowSignaturePad "signature-pad")]
        )

    Rules ->
      sceneView model
        "Rules"
        "Please read the rules and check the box to agree."
        (text "")
        [ButtonSpec "I Agree" (PushScene Activity)]

    Activity ->
      sceneView model
        "Today's Activity?"
        "Let us know what you'll be doing:"
        (text "")
        [ButtonSpec "OK" (PushScene SupportUs)]

    SupportUs ->
      sceneView model
        "Please Support Us!"
        "{TODO}"
        (text "")
        [ButtonSpec "OK" (PushScene Done)]

    Done ->
      sceneView model
        "You're Checked In"
        "Have fun!"
        (text "")
        [ButtonSpec "Yay!" (PushScene Welcome)]


-----------------------------------------------------------------------------
-- SUBSCRIPTIONS
-----------------------------------------------------------------------------

subscriptions: Model -> Sub Msg
subscriptions model =
  Sub.batch
    [
    ]


-----------------------------------------------------------------------------
-- JSON
-----------------------------------------------------------------------------

decodeMatchingAcct : Dec.Decoder MatchingAcct
decodeMatchingAcct =
  Dec.map2 MatchingAcct
    (Dec.field "userName" Dec.string)
    (Dec.field "memberNum" Dec.int)

decodeMatchingAcctInfo : Dec.Decoder MatchingAcctInfo
decodeMatchingAcctInfo =
  Dec.map2 MatchingAcctInfo
    (Dec.field "target" Dec.string)
    (Dec.field "matches" (Dec.list decodeMatchingAcct))

decodeDiscoveryMethod : Dec.Decoder DiscoveryMethod
decodeDiscoveryMethod =
  decode DiscoveryMethod
    |> required "id" Dec.int
    |> required "name" Dec.string
    |> required "order" Dec.int
    |> hardcoded False

decodeDiscoveryMethodInfo : Dec.Decoder DiscoveryMethodInfo
decodeDiscoveryMethodInfo =
  Dec.map4 DiscoveryMethodInfo
    (Dec.field "count" Dec.int)
    (Dec.field "next" (Dec.maybe Dec.string))
    (Dec.field "previous" (Dec.maybe Dec.string))
    (Dec.field "results" (Dec.list decodeDiscoveryMethod))


-----------------------------------------------------------------------------
-- Should be in external HTML files
-----------------------------------------------------------------------------

waiverHtml : List (Html Msg)
waiverHtml =
  [ p [style ["font-size"=>"20pt", "font-weight"=>"bold", "margin-top"=>"10px"]]
      [ text "XEROCRAFT INC. RELEASE AND WAIVER OF LIABILITY, ASSUMPTION OF RISK, AND INDEMNITY CONSENT AGREEMENT"
      , br [] []
      , text "('Agreement')"
      ]
  , div [style ["text-align"=>"left", "margin-top"=>"20px"]]
      [ p [style ["font-size"=>"16pt", "line-height"=>"15pt"]] [ text "IN CONSIDERATION of being permitted to participate in any way in the activities of Xerocraft Inc. I, for myself or personal representatives, assigns, heirs, and next of kin:" ]
      , ol [style ["font-size"=>"16pt", "line-height"=>"15pt"]]
          [ li [style ["margin-bottom"=>"15px"]] [text "ACKNOWLEDGE, agree, and represent that I understand the nature of Xerocraft inc.'s activities and that I am sober, qualified, in good health, and in proper physical and mental condition to participate in such Activity. I further agree and warrant that if at any time I believe conditions to be unsafe, I will immediately discontinue further participation in the Activity." ]
          , li [style ["margin-bottom"=>"15px"]]
              [ text "FULLY UNDERSTAND THAT: (a) "
              , b [] [text "THESE ACTIVITIES MAY INVOLVE RISKS AND DANGERS OF SERIOUS BODILY INJURY, INCLUDING PERMANENT DISABILITY, AND DEATH " ]
              , text "('RISKS'); (b) these Risks and dangers may be caused by my own actions or inaction's, the actions or inaction's of others participating in the Activity, the condition(s) under which the Activity takes place, or THE NEGLIGENCE OF THE 'RELEASEES' NAMED BELOW; (c) there may be OTHER RISK AND SOCIAL AND ECONOMIC LOSSES either not known to me or not readily foreseeable at this time; and I FULLY ACCEPT AND ASSUME ALL SUCH RISKS AND ALL RESPONSIBILITY FOR LOSSES, COSTS, AND DAMAGES I incur as a result of my participation or that of the minor in the Activity."
              ]
          , li [] [text "HEREBY RELEASE, DISCHARGE, AND COVENANT NOT TO SUE Xerocraft inc., their respective administrators, directors, agents, officers, members, volunteers, and employees, other participants, any sponsors, advertisers, and, if applicable, owner(s) and lessors of premises on which the Activity takes place, (each considered one of the 'RELEASEES' herein) FROM ALL LIABILITY, CLAIMS, DEMANDS, LOSSES, OR DAMAGES ON OR BY MY ACCOUNT CAUSED OR ALLEGED TO BE CAUSED IN WHOLE OR IN PART BY THE NEGLIGENCE OF THE 'RELEASEES' OR OTHERWISE, INCLUDING NEGLIGENT RESCUE OPERATIONS AND I FURTHER AGREE that if, despite this RELEASE AND WAIVER OF LIABILITY, ASSUMPTION OF RISK, AND INDEMNITY AGREEMENT I, or anyone on my behalf, makes a claim against any of the Releasees, I WILL INDEMNIFY, SAVE, AND HOLD HARMLESS EACH OF THE RELEASEES from any litigation expenses, attorney fees, loss, liability, damage, or cost which may incur as the result of such claim. I have read this Agreement, fully understand its terms, understand that I have given up substantial rights by signing it and have signed it freely and without inducement or assurance of any nature and intend it to be a complete and unconditional release of all liability to the greatest extent allowed by law and agree that if any portion of this Agreement is held to be invalid the balance, notwithstanding, shall continue in full force and effect." ]
          ]
      , p [style ["font-size"=>"16pt", "line-height"=>"15pt"]]
          [ b [] [text "MINOR RELEASE."]
          , text "The minor's parent and/or legal guardian, understand the nature of Xerocraft inc.'s activities and the minor's experience and capabilities and believe the minor to be qualified, in good health, and in proper physical and mental condition to participate in such activity. I hereby release, discharge, covenant not to sue, and agree to indemnify and save and hold harmless each of the releasee's from all liability claims, demands, losses, or damages on the minor's account caused or alleged to be caused in whole or in part by the negligence of the 'releasees' or otherwise, including negligent rescue operation and further agree that if, despite this release, I, the minor, or anyone on the minor's behalf makes a claim against any of the releasees named above, I will indemnify, save, and hold harmless each of the releasees from any litigation expenses, attorney fees, loss liability, damage, or any cost which may incur as the result of any such claim."
          ]
      ]
  ]


-----------------------------------------------------------------------------
-- STYLES
-----------------------------------------------------------------------------

(=>) = (,)

-- The reception kiosk is being designed to run full-screen on Motorola Xooms.
-- These have resolution 1280 x 800 at about 150ppi.
-- When testing on desktop, the scene should be about 13.6cm wide.

sceneWidth = "800px"
sceneHeight = "1280px"
topBannerHeight = "155px"
bottomBannerHeight = "84px"

canvasDivStyle = style
  [ "font-family" => "Roboto Condensed, Arial, Helvetica"
  , "text-align" => "center"
  , "padding-left" => "0"
  , "padding-right" => "0"
  , "padding-top" => topBannerHeight
  , "padding-bottom" => bottomBannerHeight
  , "position" => "absolute"
  , "top" => "0"
  , "bottom" => "0"
  , "left" => "0"
  , "right" => "0"
  ]

sceneDivStyle = style
  [ "margin-left" => "auto"
  , "margin-right" => "auto"
  , "border" => "1px solid #bbbbbb"
  , "background-color" => "white"
  , "width" => sceneWidth
  , "min-height" => "99.8%"
  ]

sceneTitleStyle = style
  [ "font-size" => "32pt"
  , "margin-left" => "auto"
  , "margin-right" => "auto"
  , "margin-top" => "2em"
  , "margin-bottom" => "0.5em"
  ]

sceneSubtitleStyle = style
  [ "font-size" => "24pt"
  , "margin-left" => "auto"
  , "margin-right" => "auto"
  , "margin-bottom" => "1em"
  , "margin-top" => "0"
  ]

bannerTopStyle = style
  [ "display" => "block"
  , "margin-top" => ("-"++topBannerHeight)
  , "margin-left" => "auto"
  , "margin-right" => "auto"
  , "height" => topBannerHeight
  , "width" => sceneWidth
  ]

bannerBottomStyle = style
  [ "display" => "block"
  , "margin-bottom" => ("-"++bottomBannerHeight)
  , "margin-left" => "auto"
  , "margin-right" => "auto"
  , "height" => bottomBannerHeight
  , "width" => sceneWidth
  ]

navDivStyle = bannerBottomStyle

waiverBoxStyle isSigning = style
  [ "height" => if isSigning then "350px" else "650px"
  , "overflow-y" => "scroll"
  , "margin-left" => "20px"
  , "margin-right" => "20px"
  , "border" => "1px solid #bbbbbb"
  , "font-size" => "16pt"
  , "padding" => "5px"
  ]

signaturePadStyle = style
  [ "height" => "200px"
  , "width" => "760px"
  , "border" => "1px solid #bbbbbb"
  , "cursor" => "crosshair"
  , "touch-action" => "none"
  ]

viewButtonCss =
  [ css "margin-left" "10px"
  , css "margin-right" "10px"
  , css "padding-top" "25px"
  , css "padding-bottom" "55px"
  , css "padding-left" "30px"
  , css "padding-right" "30px"
  , css "font-size" "18pt"
  ]

navButtonCss =
  [ css "display" "inline-block"
  , css "margin-top" "30px"
  , css "font-size" "14pt"
  , css "color" "#eeeeee"
  ]

sceneChipCss =
  [ css "margin-left" "3px"
  , css "margin-right" "3px"
  ]

howDidYouHearCss =
  [ css "width" "400px"
  , css "margin-left" "auto"
  , css "margin-right" "auto"
  , css "margin-top" "80px"
  ]