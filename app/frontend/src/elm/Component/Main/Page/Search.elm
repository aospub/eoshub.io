module Component.Main.Page.Search exposing (..)

import Html
    exposing
        ( Html
        , section
        , div
        , input
        , button
        , text
        , p
        , ul
        , li
        , text
        , strong
        , h3
        , h4
        , span
        , table
        , thead
        , tr
        , th
        , tbody
        , td
        , node
        , main_
        , h2
        , dl
        , dt
        , dd
        , br
        , select
        , option
        , em
        , caption
        )
import Html.Attributes
    exposing
        ( placeholder
        , class
        , title
        , attribute
        , type_
        , scope
        , hidden
        , name
        , value
        , id
        )
import Html.Events exposing (on, onClick, targetValue)
import Translation exposing (I18n(..), Language, translate)
import Http
import Util.HttpRequest exposing (getFullPath, post)
import Json.Decode as Decode
import Json.Encode as Encode
import Data.Action exposing (Message(..), Action, actionsDecoder, refineAction, viewActionInfo)
import Data.Account
    exposing
        ( Account
        , ResourceInEos
        , Resource
        , Refund
        , accountDecoder
        , defaultAccount
        , keyAccountsDecoder
        , getTotalAmount
        , getUnstakingAmount
        , getResource
        )
import Util.Formatter
    exposing
        ( larimerToEos
        , eosFloatToString
        , timeFormatter
        )


-- MODEL


type alias Model =
    { query : String
    , account : Account
    , actions : List Action
    , pagination : Pagination
    , selectedActionCategory : SelectedActionCategory
    , openedActionSeq : Int
    }


type alias Pagination =
    { latestActionSeq : Int
    , nextPos : Int
    , offset : Int
    , isEnd : Bool
    }


type alias SelectedActionCategory =
    String



-- Note(boseok): (EOSIO bug) when only pos = -1, it gets the 'offset' number of actions (intended),
-- otherwise it gets the 'offset+1' number of actions (not intended)
-- it's different from get_actions --help


initModel : String -> Model
initModel accountName =
    { query = accountName
    , account = defaultAccount
    , actions = []
    , pagination =
        { latestActionSeq = 0
        , nextPos = -1
        , offset = -30
        , isEnd = False
        }
    , selectedActionCategory = "all"
    , openedActionSeq = -1
    }


initCmd : String -> Model -> Cmd Message
initCmd query { pagination } =
    let
        accountCmd =
            let
                body =
                    Encode.object
                        [ ( "account_name", Encode.string query ) ]
                        |> Http.jsonBody
            in
                post (getFullPath "/v1/chain/get_account") body accountDecoder
                    |> (Http.send OnFetchAccount)

        actionsCmd =
            getActions query pagination.nextPos pagination.offset
    in
        Cmd.batch [ accountCmd, actionsCmd ]


getActions : String -> Int -> Int -> Cmd Message
getActions query nextPos offset =
    let
        body =
            Encode.object
                [ ( "account_name", Encode.string query )
                , ( "pos", Encode.int nextPos )
                , ( "offset", Encode.int offset )
                ]
                |> Http.jsonBody
    in
        post (getFullPath "/v1/history/get_actions") body actionsDecoder
            |> (Http.send OnFetchActions)



-- UPDATE


type Message
    = OnFetchAccount (Result Http.Error Account)
    | OnFetchActions (Result Http.Error (List Action))
    | SelectActionCategory SelectedActionCategory
    | ShowMore
    | ActionMessage Data.Action.Message


update : Message -> Model -> ( Model, Cmd Message )
update message ({ query, account, actions, pagination, openedActionSeq } as model) =
    case message of
        OnFetchAccount (Ok data) ->
            ( { model | account = data }, Cmd.none )

        OnFetchAccount (Err error) ->
            ( model, Cmd.none )

        OnFetchActions (Ok actions) ->
            let
                refinedAction =
                    List.map (refineAction query) actions

                smallestActionSeq =
                    case List.head actions of
                        Just action ->
                            action.accountActionSeq

                        Nothing ->
                            -1
            in
                if smallestActionSeq > 0 then
                    ( { model | actions = refinedAction ++ model.actions, pagination = { pagination | nextPos = smallestActionSeq - 1, offset = -29 } }, Cmd.none )
                else
                    -- no more action to load
                    ( { model | actions = refinedAction ++ model.actions, pagination = { pagination | isEnd = True } }, Cmd.none )

        OnFetchActions (Err error) ->
            ( model, Cmd.none )

        SelectActionCategory selectedActionCategory ->
            ( { model | selectedActionCategory = selectedActionCategory }, Cmd.none )

        ShowMore ->
            let
                actionsCmd =
                    getActions query pagination.nextPos pagination.offset
            in
                if not pagination.isEnd then
                    ( model, actionsCmd )
                else
                    -- TODO(boseok): alert it is the end of records
                    ( model, Cmd.none )

        ActionMessage (ShowMemo clickedActionSeq) ->
            let
                newOpenedActionSeq =
                    if openedActionSeq == clickedActionSeq then
                        -1
                    else
                        clickedActionSeq
            in
                ( { model | openedActionSeq = newOpenedActionSeq }, Cmd.none )



-- VIEW


view : Language -> Model -> Html Message
view language { account, actions, selectedActionCategory, openedActionSeq } =
    let
        totalAmount =
            getTotalAmount
                account.core_liquid_balance
                account.voter_info.staked
                account.refund_request.net_amount
                account.refund_request.cpu_amount

        unstakingAmount =
            getUnstakingAmount account.refund_request.net_amount account.refund_request.cpu_amount

        stakedAmount =
            eosFloatToString (larimerToEos account.voter_info.staked)

        ( cpuUsed, cpuAvailable, cpuTotal, cpuPercent, cpuColor ) =
            getResource "cpu" account.cpu_limit.used account.cpu_limit.available account.cpu_limit.max

        ( netUsed, netAvailable, netTotal, netPercent, netColor ) =
            getResource "net" account.net_limit.used account.net_limit.available account.net_limit.max

        ( ramUsed, ramAvailable, ramTotal, ramPercent, ramColor ) =
            getResource "ram" account.ram_usage (account.ram_quota - account.ram_usage) account.ram_quota
    in
        main_ [ class "search" ]
            [ h2 []
                [ text (translate language TotalAmount) ]
            , p []
                [ text (translate language SearchResultAccount) ]
            , div [ class "container" ]
                [ section [ class "summary" ]
                    [ dl []
                        [ dt []
                            [ text (translate language Translation.Account) ]
                        , dd []
                            [ text account.account_name ]
                        , dt []
                            [ text (translate language TotalAmount) ]
                        , dd []
                            [ text totalAmount ]
                        ]
                    ]
                , section [ class "account status" ]
                    [ div [ class "wrapper" ]
                        [ div []
                            [ text "Unstaked"
                            , strong [ title account.core_liquid_balance ]
                                [ text account.core_liquid_balance ]
                            ]
                        , div []
                            [ text "staked"
                            , strong [ title stakedAmount ]
                                [ text stakedAmount ]
                            ]
                        , div []
                            [ text "refunding"
                            , strong [ title unstakingAmount ]
                                [ text unstakingAmount ]
                            ]
                        ]
                    ]
                , section [ class "resource" ]
                    [ h3 []
                        [ text (translate language Translation.Resource) ]
                    , div [ class "wrapper" ]
                        [ div []
                            [ h4 []
                                [ text "CPU"
                                ]
                            , p []
                                [ text ("Total: " ++ cpuTotal)
                                , br []
                                    []
                                , text ("Used: " ++ cpuUsed)
                                , br []
                                    []
                                , text ("Available: " ++ cpuAvailable)
                                ]
                            , div [ class "status" ]
                                [ span [ class cpuColor, attribute "style" ("height:" ++ cpuPercent) ]
                                    []
                                , text cpuPercent
                                ]
                            ]
                        , div []
                            [ h4 []
                                [ text "NET"
                                ]
                            , p []
                                [ text ("Total: " ++ netTotal)
                                , br []
                                    []
                                , text ("Used: " ++ netUsed)
                                , br []
                                    []
                                , text ("Available: " ++ netAvailable)
                                ]
                            , div [ class "status" ]
                                [ span [ class netColor, attribute "style" ("height:" ++ netPercent) ]
                                    []
                                , text netPercent
                                ]
                            ]
                        , div []
                            [ h4 []
                                [ text "RAM"
                                ]
                            , p []
                                [ text ("Total: " ++ ramTotal)
                                , br []
                                    []
                                , text ("Used: " ++ ramUsed)
                                , br []
                                    []
                                , text ("Available: " ++ ramAvailable)
                                ]
                            , div [ class "status" ]
                                [ span [ class ramColor, attribute "style" ("height:" ++ ramPercent) ]
                                    []
                                , text ramPercent
                                ]
                            ]
                        ]
                    ]
                , section [ class "transaction history" ]
                    [ h3 []
                        [ text (translate language Transactions) ]
                    , select [ id "", name "", on "change" (Decode.map SelectActionCategory targetValue) ]
                        [ option [ value "all" ]
                            [ text (translate language All) ]
                        , option [ value "transfer" ]
                            [ text (translate language Transfer) ]
                        ]
                    , table []
                        [ caption []
                            [ text "트랜잭션 타입 :: All" ]
                        , thead []
                            [ tr []
                                [ th [ scope "col" ]
                                    [ text (translate language Number) ]
                                , th [ scope "col" ]
                                    [ text (translate language Type) ]
                                , th [ scope "col" ]
                                    [ text (translate language Time) ]
                                , th [ scope "col" ]
                                    [ text (translate language Info) ]
                                ]
                            ]
                        , tbody []
                            (viewActionList language selectedActionCategory account.account_name openedActionSeq actions)
                        ]
                    , div [ class "btn_area" ]
                        [ button [ type_ "button", class "view_more button", onClick ShowMore ]
                            [ text (translate language Translation.ShowMore) ]
                        ]
                    ]
                ]
            ]


viewActionList : Language -> SelectedActionCategory -> String -> Int -> List Action -> List (Html Message)
viewActionList language selectedActionCategory accountName openedActionSeq actions =
    List.map (viewAction language selectedActionCategory accountName openedActionSeq) actions
        |> List.reverse


viewAction : Language -> SelectedActionCategory -> String -> Int -> Action -> Html Message
viewAction language selectedActionCategory accountName openedActionSeq ({ accountActionSeq, blockTime, actionName, actionTag } as action) =
    tr [ hidden (actionHidden selectedActionCategory actionName) ]
        [ td []
            [ text (toString accountActionSeq) ]
        , td []
            [ text actionTag ]
        , td []
            [ text (timeFormatter language blockTime) ]
        , Html.map ActionMessage (viewActionInfo accountName action openedActionSeq)
        ]


actionHidden : SelectedActionCategory -> String -> Bool
actionHidden selectedActionCategory currentAction =
    case selectedActionCategory of
        "all" ->
            False

        _ ->
            if currentAction == selectedActionCategory then
                False
            else
                True
