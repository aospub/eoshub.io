module Component.Main.Page.Transfer exposing (..)

import Action exposing (TransferParameters, encodeAction)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Navigation
import Port
import Regex exposing (regex, contains)
import String.UTF8 as UTF8
import Translation exposing (Language, translate, I18n(..))


-- MODEL


type alias Model =
    { transfer : TransferParameters
    , accountValidation : AccountStatus
    , quantityValidation : QuantityStatus
    , memoValidation : MemoStatus
    , isFormValid : Bool
    }


type AccountStatus
    = EmptyAccount
    | ValidAccount
    | InvalidAccount


type QuantityStatus
    = EmptyQuantity
    | OverTransferableQuantity
    | InvalidQuantity
    | ValidQuantity


type MemoStatus
    = MemoTooLong
    | ValidMemo


initModel : Model
initModel =
    { transfer = { from = "", to = "", quantity = "", memo = "" }
    , accountValidation = EmptyAccount
    , quantityValidation = EmptyQuantity
    , memoValidation = ValidMemo
    , isFormValid = False
    }



-- MESSAGE


type TransferMessageFormField
    = To
    | Quantity
    | Memo


type Message
    = SetTransferMessageField TransferMessageFormField String
    | SubmitAction
    | ChangeUrl String
    | SetFormValidation Bool
    | OpenUnderConstruction



-- VIEW
-- Note(heejae): Current url change logic is so messy.
-- Refactor url change logic using Navigation.urlUpdate.
-- See details of this approach from https://github.com/sircharleswatson/elm-navigation-example
-- TODO(heejae): Consider making nav as a separate component.


view : Language -> Model -> String -> Html Message
view language { transfer, accountValidation, quantityValidation, memoValidation, isFormValid } eosLiquidAmount =
    section [ class "action view panel transfer" ]
        [ nav []
            [ a
                [ style [ ( "cursor", "pointer" ) ]
                , onClick (ChangeUrl "/transfer")
                , class "viewing"
                ]
                [ text (translate language Translation.Transfer) ]
            , a
                [ style [ ( "cursor", "pointer" ) ]
                , onClick OpenUnderConstruction
                ]
                [ text (translate language RamMarket) ]
            , a
                [ style [ ( "cursor", "pointer" ) ]
                , onClick OpenUnderConstruction
                ]
                [ text (translate language Application) ]
            , a
                [ style [ ( "cursor", "pointer" ) ]
                , onClick OpenUnderConstruction
                ]
                [ text (translate language Vote) ]
            , a
                [ style [ ( "cursor", "pointer" ) ]
                , onClick OpenUnderConstruction
                ]
                [ text (translate language ProxyVote) ]
            , a
                [ style [ ( "cursor", "pointer" ) ]
                , onClick OpenUnderConstruction
                ]
                [ text (translate language Faq) ]
            ]
        , h3 [] [ text (translate language Transfer) ]
        , p []
            [ text (translate language TransferInfo1)
            , br [] []
            , text (translate language TransferInfo2)
            ]
        , p [ class "help info" ]
            [ a [ style [ ( "cursor", "pointer" ) ] ] [ text (translate language TransferHelp) ]
            ]
        , let
            { to, quantity, memo } =
                transfer

            accountWarning =
                if accountValidation == InvalidAccount then
                    span [] [ text (translate language CheckAccountName) ]
                else
                    span [] []

            quantityWarning =
                quantityWarningView quantityValidation language

            memoWarning =
                span []
                    [ case memoValidation of
                        MemoTooLong ->
                            text (translate language Translation.MemoTooLong)

                        _ ->
                            text (translate language MemoNotMandatory)
                    ]
          in
            div
                [ class "card" ]
                [ h4 []
                    [ text (translate language TransferableAmount)
                    , br [] []
                    , strong [] [ text eosLiquidAmount ]
                    ]
                , Html.form
                    []
                    [ ul []
                        [ li [ class "account" ]
                            [ input
                                [ id "rcvAccount"
                                , type_ "text"
                                , style [ ( "color", "white" ) ]
                                , placeholder (translate language ReceiverAccountName)
                                , onInput <| SetTransferMessageField To
                                , value to
                                ]
                                []
                            , accountWarning
                            ]
                        , li [ class "eos" ]
                            [ input
                                [ id "eos"
                                , type_ "number"
                                , style [ ( "color", "white" ) ]
                                , placeholder "0.0000"
                                , onInput <| SetTransferMessageField Quantity
                                , value quantity
                                ]
                                []
                            , quantityWarning
                            ]
                        , li [ class "memo" ]
                            [ input
                                [ id "memo"
                                , type_ "text"
                                , style [ ( "color", "white" ) ]
                                , placeholder (translate language Translation.Memo)
                                , onInput <| SetTransferMessageField Memo
                                , value memo
                                ]
                                []
                            , memoWarning
                            ]
                        ]
                    , div
                        [ class "btn_area" ]
                        [ button
                            [ type_ "button"
                            , id "send"
                            , class "middle blue_white"
                            , onClick SubmitAction
                            , disabled (not isFormValid)
                            ]
                            [ text (translate language Transfer) ]
                        ]
                    ]
                ]
        ]


quantityWarningView : QuantityStatus -> Language -> Html Message
quantityWarningView quantityStatus language =
    let
        ( classValue, textValue ) =
            case quantityStatus of
                InvalidQuantity ->
                    ( "warning"
                    , translate language InvalidAmount
                    )

                OverTransferableQuantity ->
                    ( "warning"
                    , translate language OverTransferableAmount
                    )

                _ ->
                    ( "", "" )
    in
        span [ class classValue ] [ text textValue ]



-- UPDATE


update : Message -> Model -> String -> Float -> ( Model, Cmd Message )
update message ({ transfer } as model) accountName eosLiquidAmount =
    case message of
        SubmitAction ->
            let
                cmd =
                    { transfer | from = accountName } |> Action.Transfer |> encodeAction |> Port.pushAction
            in
                ( model, cmd )

        SetTransferMessageField field value ->
            ( setTransferMessageField field value model eosLiquidAmount, Cmd.none )

        ChangeUrl url ->
            ( model, Navigation.newUrl url )

        SetFormValidation validity ->
            ( { model | isFormValid = validity }, Cmd.none )

        _ ->
            ( model, Cmd.none )



-- Utility functions.


setTransferMessageField : TransferMessageFormField -> String -> Model -> Float -> Model
setTransferMessageField field value ({ transfer } as model) eosLiquidAmount =
    case field of
        To ->
            validate { model | transfer = { transfer | to = value } } eosLiquidAmount

        Quantity ->
            validate { model | transfer = { transfer | quantity = value } } eosLiquidAmount

        Memo ->
            validate { model | transfer = { transfer | memo = value } } eosLiquidAmount


validate : Model -> Float -> Model
validate ({ transfer } as model) eosLiquidAmount =
    let
        { to, quantity, memo } =
            transfer

        accountValidation =
            if to == "" then
                EmptyAccount
            else if contains (regex "^[a-z\\.1-5]{1,12}$") to then
                ValidAccount
            else
                InvalidAccount

        -- Change the limit to user's balance.
        quantityValidation =
            if quantity == "" then
                EmptyQuantity
            else
                let
                    maybeQuantity =
                        String.toFloat quantity
                in
                    case maybeQuantity of
                        Ok quantity ->
                            if quantity <= 0 then
                                InvalidQuantity
                            else if quantity > eosLiquidAmount then
                                OverTransferableQuantity
                            else
                                ValidQuantity

                        _ ->
                            InvalidQuantity

        memoValidation =
            if UTF8.length memo > 256 then
                MemoTooLong
            else
                ValidMemo

        isFormValid =
            (accountValidation == ValidAccount)
                && (quantityValidation == ValidQuantity)
                && (memoValidation == ValidMemo)
    in
        { model
            | accountValidation = accountValidation
            , quantityValidation = quantityValidation
            , memoValidation = memoValidation
            , isFormValid = isFormValid
        }