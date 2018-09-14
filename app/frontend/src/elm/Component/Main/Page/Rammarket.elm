module Component.Main.Page.Rammarket exposing
    ( Message
    , Model
    , calculateEosRamPrice
    , calculateEosRamYield
    , initCmd
    , initModel
    , subscriptions
    , update
    , view
    )

import Data.Account exposing (Account, getResource)
import Data.Action
    exposing
        ( Action
        , BuyramParameters
        , SellramParameters
        , actionsDecoder
        , initBuyramParameters
        , initSellramParameters
        )
import Data.Table exposing (GlobalFields, RammarketFields, Row, initGlobalFields, initRammarketFields)
import Html
    exposing
        ( Html
        , a
        , button
        , caption
        , div
        , form
        , h2
        , h3
        , i
        , input
        , main_
        , p
        , section
        , span
        , table
        , tbody
        , td
        , text
        , th
        , thead
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , disabled
        , id
        , name
        , placeholder
        , scope
        , style
        , title
        , type_
        )
import Html.Events exposing (onClick)
import Http
import Json.Encode as Encode
import Port
import Round
import Time
import Translation exposing (I18n(..), Language, translate)
import Util.Constant exposing (giga, kilo)
import Util.Formatter exposing (deleteFromBack, resourceUnitConverter, timeFormatter)
import Util.HttpRequest exposing (getFullPath, getTableRows, post)



-- MODEL


type alias BuyModel =
    { params : BuyramParameters
    }


initBuyParameters : BuyModel
initBuyParameters =
    { params = initBuyramParameters
    }


type alias SellModel =
    { params : SellramParameters
    }


initSellParameters : SellModel
initSellParameters =
    { params = initSellramParameters
    }


type RamAction
    = Buy BuyModel
    | Sell SellModel


type alias Model =
    { actions : List Action
    , rammarketTable : RammarketFields
    , globalTable : GlobalFields
    , expandActions : Bool
    , action : RamAction
    , modalOpen : Bool
    }


initModel : Model
initModel =
    { actions = []
    , rammarketTable = initRammarketFields
    , globalTable = initGlobalFields
    , expandActions = False
    , action = Buy initBuyParameters
    , modalOpen = False
    }



-- MESSAGE


type Message
    = OnFetchActions (Result Http.Error (List Action))
    | OnFetchTableRows (Result Http.Error (List Row))
    | ExpandActions
    | UpdateChainData Time.Time
    | SetAction RamAction
    | ToggleModal


getActions : Cmd Message
getActions =
    let
        requestBody =
            [ ( "account_name", "eosio.ram" |> Encode.string )
            , ( "pos", -1 |> Encode.int )
            , ( "offset", -80 |> Encode.int )
            ]
                |> Encode.object
                |> Http.jsonBody
    in
    post ("/v1/history/get_actions" |> getFullPath) requestBody actionsDecoder
        |> Http.send OnFetchActions


getRammarketTable : Cmd Message
getRammarketTable =
    getTableRows "eosio" "eosio" "rammarket"
        |> Http.send OnFetchTableRows


getGlobalTable : Cmd Message
getGlobalTable =
    getTableRows "eosio" "eosio" "global"
        |> Http.send OnFetchTableRows


initCmd : Cmd Message
initCmd =
    Cmd.batch [ Port.loadChart (), getActions, getRammarketTable, getGlobalTable ]



-- UPDATE


update : Message -> Model -> ( Model, Cmd Message )
update message ({ modalOpen } as model) =
    case message of
        OnFetchActions (Ok actions) ->
            ( { model | actions = actions |> List.reverse }, Cmd.none )

        OnFetchActions (Err error) ->
            ( model, Cmd.none )

        OnFetchTableRows (Ok rows) ->
            case rows of
                (Data.Table.Rammarket fields) :: [] ->
                    ( { model | rammarketTable = fields }, Cmd.none )

                (Data.Table.Global fields) :: [] ->
                    ( { model | globalTable = fields }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        OnFetchTableRows (Err error) ->
            ( model, Cmd.none )

        ExpandActions ->
            ( { model | expandActions = True }, Cmd.none )

        UpdateChainData _ ->
            ( model, Cmd.batch [ getActions, getRammarketTable, getGlobalTable ] )

        SetAction buyOrSell ->
            ( { model | action = buyOrSell }, Cmd.none )

        ToggleModal ->
            ( { model | modalOpen = not modalOpen }, Cmd.none )



-- VIEW


view : Language -> Model -> Account -> Html Message
view language { actions, expandActions, rammarketTable, globalTable, action, modalOpen } { ramQuota, ramUsage } =
    main_ [ class "ram_market" ]
        [ h2 [] [ text (translate language RamMarket) ]
        , p [] [ text (translate language RamMarketDesc) ]
        , div [ class "container" ]
            [ section [ class "dashboard" ]
                [ div [ class "ram status" ]
                    [ div [ class "wrapper" ]
                        [ h3 [] [ text "이오스 램 가격" ]
                        , p [] [ text (rammarketTable |> calculateEosRamPrice) ]
                        ]
                    , div [ class "wrapper" ]
                        [ h3 [] [ text "램 점유율" ]
                        , p [] [ text (globalTable |> calculateEosRamYield) ]
                        ]
                    , div [ class "graph", id "tv-chart-container" ] []
                    ]
                , let
                    ( ramUsed, ramAvailable, ramTotal, ramPercent, ramColor ) =
                        getResource "ram" ramUsage (ramQuota - ramUsage) ramQuota

                    ( buyClass, sellClass, buyOthersRamTab ) =
                        case action of
                            Buy _ ->
                                ( " ing", "", a [ onClick ToggleModal ] [ text "타계정 구매" ] )

                            Sell _ ->
                                -- Produce empty html node with text tag.
                                ( "", " ing", text "" )
                  in
                  div [ class "my status" ]
                    [ div [ class "summary" ]
                        [ h3 []
                            [ text "나의 램"
                            , span []
                                [ text (resourceUnitConverter "ram" ramQuota) ]
                            ]
                        , p []
                            [ text
                                ("사용가능한 용량이 "
                                    ++ ramPercent
                                    ++ " 남았어요"
                                )
                            ]
                        , div [ class "status" ]
                            [ span [ class ramColor, style [ ( "height", ramPercent ) ] ]
                                []
                            , text ramPercent
                            ]
                        ]
                    , div [ class "sell_buy" ]
                        [ div [ class "tab" ]
                            [ button
                                [ type_ "button"
                                , class ("buy tab button" ++ buyClass)
                                , onClick (SetAction (Buy initBuyParameters))
                                ]
                                [ text "구매하기"
                                ]
                            , button
                                [ type_ "button"
                                , class ("sell tab button" ++ sellClass)
                                , onClick (SetAction (Sell initSellParameters))
                                ]
                                [ text "판매하기"
                                ]
                            ]
                        , div [ class "unit" ]
                            [ div [ class "select period" ]
                                [ i [ attribute "data-value" "0" ] [ text "EOS" ]

                                -- , button [ type_ "button", class "prev button" ] [ text "이전 단위 고르기" ]
                                -- , button [ type_ "button", class "next button" ] [ text "다음 단위 고르기" ]
                                ]
                            , buyOthersRamTab
                            ]
                        , form [ class "input panel" ]
                            [ div []
                                [ input [ type_ "number", placeholder "구매하실 수량을 입력하세요" ] []
                                , span [ class "unit" ] [ text "EOS" ]
                                ]
                            , div []
                                [ button [ type_ "button" ] [ text "10%" ]
                                , button [ type_ "button" ] [ text "50%" ]
                                , button [ type_ "button" ] [ text "70%" ]
                                , button [ type_ "button" ] [ text "최대" ]
                                ]
                            ]
                        , div [ class "btn_area" ]
                            [ button [ type_ "button", class "ok button", disabled True ] [ text "구매하기" ]
                            ]
                        ]
                    ]
                ]
            , let
                ( actionTableRows, viewMoreButton ) =
                    if expandActions then
                        ( actions |> List.map (actionToTableRow language)
                        , div [] []
                        )

                    else
                        ( actions |> List.take 2 |> List.map (actionToTableRow language)
                        , div [ class "btn_area" ]
                            [ button [ type_ "button", class "view_more button", onClick ExpandActions ]
                                [ text "더 보기" ]
                            ]
                        )
              in
              section [ class "history list" ]
                [ table []
                    [ caption []
                        [ text "구매/판매 거래내역" ]
                    , thead []
                        [ tr []
                            [ th [ scope "col" ]
                                [ text "타입" ]
                            , th [ scope "col" ]
                                [ text "거래량" ]
                            , th [ scope "col" ]
                                [ text "계정" ]
                            , th [ scope "col" ]
                                [ text "시간" ]
                            , th [ scope "col" ]
                                [ text "Tx ID" ]
                            ]
                        ]
                    , tbody [] actionTableRows
                    ]
                , viewMoreButton
                ]
            ]
        , section
            [ attribute "aria-live" "true"
            , class
                ("buy_ram modal popup"
                    ++ (if modalOpen then
                            " viewing"

                        else
                            ""
                       )
                )
            ]
            [ div [ class "wrapper" ]
                [ h2 []
                    [ text "타계정 구매" ]
                , p []
                    [ text "램을 구매해 줄 타계정을 입력하세요." ]
                , form []
                    [ input [ class "user", placeholder "ex) eosbpkorea", type_ "text" ]
                        []
                    ]
                , div [ class "container" ]
                    [ span [ class "true validate description" ]
                        [ text "존재하지 않는 계정입니다." ]
                    , span [ class "false validate description" ]
                        [ text "존재하지 않는 계정입니다." ]
                    ]
                , div [ class "btn_area" ]
                    [ button [ class "ok button", disabled True, type_ "button" ]
                        [ text "확인" ]
                    ]
                , button [ class "close button", type_ "button", onClick ToggleModal ]
                    [ text "닫기" ]
                ]
            ]
        ]


actionToTableRow : Language -> Action -> Html Message
actionToTableRow language { blockTime, data, trxId } =
    case data of
        Ok (Data.Action.Transfer { from, to, quantity }) ->
            let
                ( actionClass, actionType, account ) =
                    if from == "eosio.ram" then
                        ( "log sell", "판매", to )

                    else
                        ( "log buy", "구매", from )

                formattedDateTime =
                    blockTime |> timeFormatter language
            in
            tr [ class actionClass ]
                [ td [] [ text actionType ]
                , td [] [ text quantity ]
                , td [] [ text account ]
                , td [] [ text formattedDateTime ]
                , td [] [ text trxId ]
                ]

        _ ->
            tr [] []


calculateEosRamPrice : RammarketFields -> String
calculateEosRamPrice { base, quote } =
    let
        denominator =
            case base.balance |> deleteFromBack 4 |> String.toFloat of
                Ok baseFloat ->
                    baseFloat

                _ ->
                    -1.0

        numerator =
            case quote.balance |> deleteFromBack 4 |> String.toFloat of
                Ok quoteFloat ->
                    quoteFloat

                _ ->
                    -1.0
    in
    -- This case means no data loaded yet.
    if denominator < 0 || numerator < 0 then
        "Loading..."

    else
        ((numerator / denominator) * toFloat kilo |> Round.round 8) ++ " EOS/KB"


calculateEosRamYield : GlobalFields -> String
calculateEosRamYield { maxRamSize, totalRamBytesReserved } =
    let
        denominator =
            case maxRamSize |> String.toFloat of
                Ok baseFloat ->
                    baseFloat

                _ ->
                    -1.0

        numerator =
            case totalRamBytesReserved |> String.toFloat of
                Ok quoteFloat ->
                    quoteFloat

                _ ->
                    -1.0
    in
    -- This case means no data loaded yet.
    if denominator < 0 || numerator < 0 then
        "Loading..."

    else
        Round.round 2 (numerator / (giga |> toFloat))
            ++ "/"
            ++ Round.round 2 (denominator / (giga |> toFloat))
            ++ "GB ("
            ++ Round.round 2 ((numerator * 100) / denominator)
            ++ "%)"



-- SUBSCRIPTIONS
-- The interval needs to be adjusted. Now, it is set to 2 secs.


subscriptions : Sub Message
subscriptions =
    Time.every (2 * Time.second) UpdateChainData
