module Component.Main.Page.Index exposing
    ( Message(..)
    , Model
    , initCmd
    , initModel
    , subscriptions
    , update
    , view
    )

import Data.Announcement exposing (Announcement)
import Data.Common exposing (AppState)
import Data.Json exposing (LocalStorageValue, encodeLocalStorageValue)
import Html exposing (Html, a, br, button, div, h2, h3, input, label, main_, p, section, span, text)
import Html.Attributes exposing (attribute, checked, class, for, href, id, target, type_)
import Html.Events exposing (onClick, onMouseOut, onMouseOver)
import Navigation
import Port
import Time
import Translation exposing (I18n(..), Language(..), toLocale, translate)



-- MODEL --


type alias Model =
    { bannerIndex : Int
    , bannerSecondsLeft : Int
    , isTimerOn : Bool
    , showAnnouncement : Bool
    , skipAnnouncement : Bool
    , lastSkippedAnnouncementId : Int
    }


initModel : Model
initModel =
    { bannerIndex = 1
    , bannerSecondsLeft = bannerRollingInterval
    , isTimerOn = True
    , showAnnouncement = False
    , skipAnnouncement = False
    , lastSkippedAnnouncementId = -1
    }


bannerRollingInterval : Int
bannerRollingInterval =
    7


bannerMaxCount : Int
bannerMaxCount =
    3



-- MESSAGE --


type Message
    = ChangeUrl String
    | CloseModal
    | ChangeBanner Int
    | Tick Time.Time
    | ToggleBannerTimer Bool
    | UpdateShowAnnouncement (Maybe LocalStorageValue)
    | ToggleSkipAnnouncement


initCmd : Cmd Message
initCmd =
    Port.checkValueFromLocalStorage ()


update : Message -> Model -> AppState -> ( Model, Cmd Message )
update msg ({ bannerIndex, bannerSecondsLeft, skipAnnouncement } as model) { announcement } =
    case msg of
        ChangeUrl url ->
            ( model, Navigation.newUrl url )

        ChangeBanner index ->
            ( { model
                | bannerSecondsLeft = bannerRollingInterval
                , bannerIndex = index
                , isTimerOn = False
              }
            , Cmd.none
            )

        Tick _ ->
            let
                secondsLeft =
                    bannerSecondsLeft - 1

                newIndex =
                    if bannerIndex + 1 > bannerMaxCount then
                        1

                    else
                        bannerIndex + 1
            in
            if secondsLeft <= 0 then
                ( { model
                    | bannerSecondsLeft = bannerRollingInterval
                    , bannerIndex = newIndex
                  }
                , Cmd.none
                )

            else
                ( { model | bannerSecondsLeft = secondsLeft }, Cmd.none )

        ToggleBannerTimer on ->
            let
                resetInterval =
                    if on then
                        bannerSecondsLeft

                    else
                        bannerRollingInterval
            in
            ( { model | isTimerOn = on, bannerSecondsLeft = resetInterval }, Cmd.none )

        UpdateShowAnnouncement resp ->
            case resp of
                Nothing ->
                    ( { model | showAnnouncement = True }, Cmd.none )

                Just { lastSkippedAnnouncementId } ->
                    ( { model | showAnnouncement = True, lastSkippedAnnouncementId = lastSkippedAnnouncementId }, Cmd.none )

        ToggleSkipAnnouncement ->
            ( { model | skipAnnouncement = not skipAnnouncement }, Cmd.none )

        CloseModal ->
            let
                cmd =
                    if skipAnnouncement then
                        { lastSkippedAnnouncementId = announcement.id }
                            |> encodeLocalStorageValue
                            |> Port.setValueToLocalStorage

                    else
                        Cmd.none
            in
            ( { model | showAnnouncement = False }, cmd )



-- VIEW --


view : Model -> Language -> AppState -> Html Message
view ({ bannerIndex } as model) language appState =
    main_ [ class "index" ]
        [ section [ class "menu_area" ]
            [ h2 [] [ text "Menu" ]
            , div [ class "container" ]
                [ div
                    [ class
                        ("greeting"
                            ++ (if appState.eventActivation then
                                    " event_free"

                                else
                                    ""
                               )
                        )
                    ]
                    [ h3 []
                        [ text (translate language Hello)
                        , br [] []
                        , text (translate language WelcomeEosHub)
                        ]
                    , viewEventClickButton language appState.eventActivation
                    ]
                , a
                    [ onClick (ChangeUrl "/transfer")
                    , class "card transfer"
                    ]
                    [ h3 [] [ text (translate language Transfer) ]
                    , p [] [ text (translate language TransferHereDesc) ]
                    ]
                , a
                    [ onClick (ChangeUrl "/vote")
                    , class "card vote"
                    ]
                    [ h3 [] [ text (translate language Vote) ]
                    , p [] [ text (translate language VoteDesc) ]
                    ]
                , a
                    [ onClick (ChangeUrl "/resource")
                    , class "card resource"
                    ]
                    [ h3 [] [ text "CPU / NET" ]
                    , p [] [ text (translate language ManageResourceDesc) ]
                    ]
                , a
                    [ onClick (ChangeUrl "/rammarket")
                    , class "card ram_market"
                    ]
                    [ h3 [] [ text (translate language RamMarket) ]
                    , p [] [ text (translate language RamMarketDesc) ]
                    ]
                ]
            ]
        , section
            [ class "promotion"
            , attribute "data-display" (toString bannerIndex)
            , attribute "data-max" (toString bannerMaxCount)
            ]
            [ h3 []
                [ text "AD" ]
            , div [ class "rolling banner" ]
                [ viewBanner "eosdaq" "https://eosdaq.com/" "A New Standard of DEX"
                , viewBanner "dapp" (translate language DappContestLink) "Dapp contest"
                , viewBanner "nova" "http://eosnova.io/" "Yout first EOS wallet,NOVA Wallet"
                ]
            , div [ class "banner handler" ]
                [ viewBannerButton "EOSDAQ free account event" 1
                , viewBannerButton "Dapp contest banner" 2
                , viewBannerButton "Nova wallet" 3
                ]
            ]
        , viewAnnouncementSection model language appState
        ]


viewEventClickButton : Language -> Bool -> Html Message
viewEventClickButton language eventActivation =
    if eventActivation then
        p []
            [ a [ onClick (ChangeUrl ("/account/event_creation?locale=" ++ toLocale language)) ]
                [ text (translate language MakeYourAccount) ]
            ]

    else
        span [] []


viewAnnouncementSection : Model -> Language -> AppState -> Html Message
viewAnnouncementSection { showAnnouncement, skipAnnouncement, lastSkippedAnnouncementId } language { announcement } =
    let
        -- TODO(boseok): Resolve conflict with alpha
        isAnnouncementModalOpen =
            announcement.active
                && showAnnouncement
                && (lastSkippedAnnouncementId /= announcement.id)

        ( announcementTitle, announcementBody ) =
            translateAnnouncement language announcement
    in
    section
        [ attribute "aria-live" "true"
        , class
            ("notice modal popup"
                ++ (if isAnnouncementModalOpen then
                        " viewing"

                    else
                        ""
                   )
            )
        , id "popup"
        , attribute "role" "alert"
        ]
        [ div [ class "wrapper" ]
            [ h2 []
                [ text announcementTitle ]
            , p []
                [ text announcementBody ]
            , div [ class "action container" ]
                [ div [ class "confirm area" ]
                    [ input
                        [ id "donotshow"
                        , type_ "checkbox"
                        , checked skipAnnouncement
                        , onClick ToggleSkipAnnouncement
                        ]
                        []
                    , label [ for "donotshow" ]
                        [ text (translate language DoNotShowAgain) ]
                    , button [ class "ok button", type_ "button", onClick CloseModal ]
                        [ text (translate language Close) ]
                    ]
                ]
            ]
        ]


viewBanner : String -> String -> String -> Html Message
viewBanner cls url str =
    a
        [ class cls
        , href url
        , target "_blank"
        , onMouseOver (ToggleBannerTimer False)
        , onMouseOut (ToggleBannerTimer True)
        ]
        [ text str ]


viewBannerButton : String -> Int -> Html Message
viewBannerButton str index =
    button
        [ class "rotate banner circle button"
        , type_ "button"
        , onMouseOver (ChangeBanner index)
        , onMouseOut (ToggleBannerTimer True)
        ]
        [ text str ]


translateAnnouncement : Language -> Announcement -> ( String, String )
translateAnnouncement language announcement =
    case language of
        Korean ->
            ( announcement.titleKo, announcement.bodyKo )

        English ->
            ( announcement.titleEn, announcement.bodyEn )

        Chinese ->
            ( announcement.titleCn, announcement.bodyCn )



-- SUBSCRIPTIONS


tick : Bool -> Sub Message
tick isTimerOn =
    if isTimerOn then
        Time.every Time.second Tick

    else
        Sub.none


subscriptions : Model -> Sub Message
subscriptions { isTimerOn } =
    Sub.batch
        [ tick isTimerOn
        , Port.receiveValueFromLocalStorage UpdateShowAnnouncement
        ]
