module Component.Main.Sidebar exposing
    ( Message(..)
    , Model
    , State(..)
    , accountCmd
    , accountInfoView
    , getResourceStatusText
    , initCmd
    , initModel
    , loadingView
    , pairWalletView
    , signInView
    , subscriptions
    , update
    , view
    )

import Data.Account
    exposing
        ( Account
        , defaultAccount
        , getResource
        , getResourceColorClass
        , getTotalAmount
        , getUnstakingAmount
        )
import Date
import Date.Extra as Date exposing (Interval(..))
import Html exposing (Html, a, aside, br, button, div, h2, li, p, span, text, ul)
import Html.Attributes exposing (attribute, class, href, target, type_)
import Html.Events exposing (onClick, onMouseEnter, onMouseLeave)
import Http
import Navigation
import Port
import Time exposing (Time)
import Translation exposing (I18n(..), Language(..), toLocale, translate)
import Util.Formatter
    exposing
        ( deleteFromBack
        , floatToAsset
        , getNow
        , larimerToEos
        )
import Util.HttpRequest exposing (getAccount)
import Util.WalletDecoder
    exposing
        ( Wallet
        , WalletResponse
        , WalletStatus(Authenticated, NotFound)
        , decodeWalletResponse
        )



-- MODEL


type State
    = SignIn
    | PairWallet
    | AccountInfo
    | Loading


type alias Model =
    { wallet : Wallet
    , state : State
    , fold : Bool
    , configPanelOpen : Bool
    , account : Account
    , now : Time
    }


initModel : Model
initModel =
    { wallet =
        { status = NotFound
        , account = ""
        , authority = ""
        }
    , state = Loading
    , fold = False
    , configPanelOpen = False
    , account = defaultAccount
    , now = 0
    }



-- MESSAGE


type Message
    = AuthenticateAccount
    | CheckWalletStatus
    | ToggleSidebar
    | InvalidateAccount
    | UpdateWalletStatus WalletResponse
    | UpdateState State
    | ChangeUrl String
    | OpenConfigPanel Bool
    | AndThen Message Message
    | OnFetchAccount (Result Http.Error Account)
    | OnTime Time.Time



-- Cmd


initCmd : Cmd Message
initCmd =
    Cmd.batch
        [ Port.checkWalletStatus ()
        , getNow OnTime
        ]


accountCmd : State -> String -> Cmd Message
accountCmd state accountName =
    case state of
        AccountInfo ->
            accountName
                |> getAccount
                |> Http.send OnFetchAccount

        _ ->
            Cmd.none



-- VIEW


view : Model -> Language -> Html Message
view ({ state, fold } as model) language =
    let
        ( baseClass, htmlContent ) =
            case state of
                SignIn ->
                    ( "log off", signInView language )

                PairWallet ->
                    ( "log unsync", pairWalletView language )

                AccountInfo ->
                    ( "log in", accountInfoView model language )

                Loading ->
                    ( "log off", loadingView language )

        sidebarClass =
            if fold then
                baseClass ++ " shrink"

            else
                baseClass
    in
    aside [ class sidebarClass ] htmlContent


signInView : Language -> List (Html Message)
signInView language =
    [ h2 []
        [ text (translate language Hello)
        , br [] []
        , text (translate language WelcomeEosHub)
        ]
    , p []
        [ text (translate language IfYouHaveEos)
        , br [] []
        , text (translate language IfYouAreNew)
        ]
    , div [ class "btn_area" ]
        [ a
            [ class "login button"
            , onClick (UpdateState PairWallet)
            ]
            [ text (translate language Login) ]
        , a
            [ class "join button"
            , onClick (ChangeUrl ("/account/create?locale=" ++ toLocale language))
            ]
            [ text (translate language NewAccount) ]
        ]
    ]


pairWalletView : Language -> List (Html Message)
pairWalletView language =
    [ button
        [ type_ "button"
        , class "back button"
        , onClick (UpdateState SignIn)
        ]
        [ text (translate language GoBack) ]
    , h2 []
        [ text (translate language AttachableWallet1)
        , br [] []
        , text (translate language AttachableWallet2)
        ]
    , p []
        [ text (translate language FurtherUpdate1)
        , br [] []
        , text (translate language FurtherUpdate2)
        ]
    , ul [ class "available_wallet_list" ]
        [ li [ class "scatter" ]
            [ text "Scatter"
            , button
                [ type_ "button"
                , onClick AuthenticateAccount
                ]
                [ text (translate language Attach) ]
            ]

        -- , li [ class "nova" ]
        --     [ text "NOVA"
        --     , button
        --         [ type_ "button"
        --         ]
        --         [ text (translate language Attach) ]
        --     ]
        ]
    , a [ href (translate language HowToAttachLink), class "go link wallet_sync", target "_blank" ] [ text (translate language HowToAttach) ]
    ]


accountInfoView : Model -> Language -> List (Html Message)
accountInfoView { wallet, account, configPanelOpen, now } language =
    let
        { coreLiquidBalance, voterInfo, refundRequest } =
            account

        totalAmount =
            getTotalAmount
                coreLiquidBalance
                voterInfo.staked
                refundRequest.netAmount
                refundRequest.cpuAmount

        unstakingAmount =
            getUnstakingAmount refundRequest.netAmount refundRequest.cpuAmount

        stakedAmount =
            floatToAsset (larimerToEos voterInfo.staked)

        configPanelClass =
            class
                ("config panel"
                    ++ (if configPanelOpen then
                            " expand"

                        else
                            ""
                       )
                )

        ( _, _, _, _, cpuColorCode ) =
            getResource "cpu" account.cpuLimit.used account.cpuLimit.available account.cpuLimit.max

        ( _, _, _, _, netColorCode ) =
            getResource "net" account.netLimit.used account.netLimit.available account.netLimit.max

        resourceStatusCode =
            Basics.min cpuColorCode netColorCode

        colorClass =
            resourceStatusCode |> getResourceColorClass
    in
    [ h2 []
        [ text wallet.account
        , span [ class "description" ] [ text ("@" ++ wallet.authority) ]
        ]
    , div
        [ configPanelClass
        , onMouseEnter (OpenConfigPanel True)
        , onMouseLeave (OpenConfigPanel False)
        ]
        [ button
            [ type_ "button"
            , class "icon gear button"
            , attribute "wai-aria" "hidden"
            ]
            [ text "option" ]
        , div [ class "menu_list" ]
            [ a
                [ onClick (AndThen (OpenConfigPanel False) (UpdateState PairWallet))
                ]
                [ text (translate language ChangeWallet) ]
            , a
                [ onClick
                    (AndThen (OpenConfigPanel False)
                        (ChangeUrl ("search?query=" ++ wallet.account))
                    )
                ]
                [ text (translate language MyAccount) ]
            , a
                [ onClick (AndThen (OpenConfigPanel False) InvalidateAccount)
                ]
                [ text (translate language SignOut) ]
            ]
        ]
    , ul [ class "wallet status" ]
        [ li []
            [ span [ class "title" ] [ text "total" ]
            , span [ class "amount" ] [ text (deleteFromBack 4 totalAmount) ]
            ]
        , li []
            [ span [ class "title" ] [ text "unstaked" ]
            , span [ class "amount" ] [ text (deleteFromBack 4 coreLiquidBalance) ]
            ]
        , li []
            [ span [ class "title" ] [ text "staked" ]
            , span [ class "amount" ] [ text (deleteFromBack 4 stakedAmount) ]

            -- TODO(boseok): Translation i18n should be decided.
            , span [ class ("status " ++ colorClass) ] [ text (getResourceStatusText language resourceStatusCode) ]

            -- span [ class "status unavailable" ] [ text "" ]
            ]
        , li []
            [ span [ class "title" ] [ text "refunding" ]
            , span [ class "amount" ] [ text (deleteFromBack 4 unstakingAmount) ]
            , span [ class "remaining time" ] [ text (getLeftTime refundRequest.requestTime now) ]
            ]
        ]
    , button
        [ type_ "button"
        , class "resource management"
        , onClick (ChangeUrl "/resource")
        ]
        [ text (translate language ManageStaking) ]
    ]


loadingView : Language -> List (Html Message)
loadingView _ =
    [ h2 [] [ text "Loading..." ] ]



-- UPDATE


update : Message -> Model -> ( Model, Cmd Message )
update message ({ fold, wallet } as model) =
    case message of
        AuthenticateAccount ->
            ( model, Port.authenticateAccount () )

        CheckWalletStatus ->
            ( model, Port.checkWalletStatus () )

        ToggleSidebar ->
            ( { model | fold = not fold }, Cmd.none )

        InvalidateAccount ->
            let
                cmds =
                    Cmd.batch
                        [ Port.invalidateAccount ()
                        , Navigation.reload
                        ]
            in
            ( model, cmds )

        UpdateState state ->
            let
                newCmd =
                    accountCmd state wallet.account
            in
            ( { model | state = state }, newCmd )

        UpdateWalletStatus resp ->
            let
                ({ status } as newWallet) =
                    decodeWalletResponse resp

                newState =
                    case status of
                        Authenticated ->
                            AccountInfo

                        _ ->
                            SignIn
            in
            update (UpdateState newState) { model | wallet = newWallet }

        ChangeUrl url ->
            ( model, Navigation.newUrl url )

        OpenConfigPanel bool ->
            ( { model | configPanelOpen = bool }, Cmd.none )

        AndThen firstMessage secondMessage ->
            let
                ( firstModel, firstCmd ) =
                    update firstMessage model

                ( secondModel, secondCmd ) =
                    update secondMessage firstModel
            in
            ( secondModel, Cmd.batch [ firstCmd, secondCmd ] )

        OnFetchAccount (Ok data) ->
            ( { model | account = data }, Cmd.none )

        OnFetchAccount (Err _) ->
            ( model, Cmd.none )

        OnTime now ->
            ( { model | now = now }, Cmd.none )


getLeftTime : String -> Time -> String
getLeftTime requestTime now =
    case Date.fromIsoString (requestTime ++ "+00:00") of
        Ok time ->
            let
                expectedDate =
                    Date.add Hour 72 time

                nowDate =
                    Date.fromTime now

                leftHours =
                    Date.diff Hour nowDate expectedDate

                leftMinutes =
                    Date.diff Minute nowDate expectedDate
            in
            if leftHours < 1 then
                (leftMinutes |> toString) ++ " minutes"

            else
                (leftHours |> toString) ++ " hours"

        Err _ ->
            ""


getResourceStatusText : Language -> Int -> String
getResourceStatusText language resourceStatusCode =
    case resourceStatusCode of
        1 ->
            translate language TransactionWarning

        2 ->
            translate language TransactionAttention

        3 ->
            translate language TransactionFine

        4 ->
            translate language TransactionOptimal

        _ ->
            ""



-- SUBSCRIPTIONS


subscriptions : Sub Message
subscriptions =
    Port.receiveWalletStatus UpdateWalletStatus
