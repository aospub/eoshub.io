module Page.Account.Create exposing (Message(..), Model, createEosAccountBodyParams, initModel, update, view)

import Html exposing (Html, button, div, input, li, p, text, ul, ol, h1, img, text, br, form, article, span)
import Html.Attributes exposing (placeholder, class, attribute, alt, src, type_, style)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode exposing (Decoder, string)
import Json.Decode.Pipeline exposing (decode, required)
import Json.Encode as Encode
import Util.Flags exposing (Flags)
import Util.Urls as Urls
import Navigation
import Util.Validation exposing (checkAccountName)


-- MODEL


type alias Model =
    { accountName : String
    , requestStatus : Response
    , pubkey : String
    , validation : Bool
    , validationMsg : String
    , requestSuccess : Bool
    }


initModel : String -> Model
initModel pubkey =
    { accountName = ""
    , requestStatus = { msg = "" }
    , pubkey = pubkey
    , validation = False
    , validationMsg = ""
    , requestSuccess = False
    }



-- UPDATES


type Message
    = ValidateAccountName String
    | CreateEosAccount
    | NewUser (Result Http.Error Response)


update : Message -> Model -> Flags -> String -> ( Model, Cmd Message )
update msg model flags confirmToken =
    case msg of
        ValidateAccountName accountName ->
            let
                newModel =
                    { model | accountName = accountName }

                ( validateMsg, validate ) =
                    if checkAccountName accountName then
                        ( "가능한 ID에요", True )
                    else
                        ( "불가능한 ID에요", False )
            in
                ( { newModel | validation = validate, validationMsg = validateMsg }, Cmd.none )

        CreateEosAccount ->
            ( model, createEosAccountRequest model flags confirmToken )

        NewUser (Ok res) ->
            ( { model | requestStatus = res, requestSuccess = True }, Navigation.newUrl ("/account/created") )

        NewUser (Err error) ->
            case error of
                Http.BadStatus response ->
                    ( { model | requestStatus = { msg = toString response.body }, requestSuccess = False }, Cmd.none )

                Http.BadPayload debugMsg response ->
                    ( { model | requestStatus = { msg = ("debugMsg: " ++ debugMsg ++ ", body: " ++ response.body) }, requestSuccess = False }, Cmd.none )

                _ ->
                    ( { model | requestStatus = { msg = toString error }, requestSuccess = False }, Cmd.none )



-- VIEW


view : Model -> Html Message
view model =
    div [ class "container join" ]
        [ ol [ class "progress bar" ]
            [ li [ class "done" ]
                [ text "인증하기" ]
            , li [ class "done" ]
                [ text "키 생성" ]
            , li [ class "ing" ]
                [ text "계정생성" ]
            ]
        , article [ attribute "data-step" "4" ]
            [ h1 []
                [ text "원하는 계정의 이름을 입력해주세요!    " ]
            , p []
                [ text "계정명은 1~5 사이의 숫자와 영어 소문자의 조합으로 12글자만 가능합니다!"
                , br []
                    []
                , text "ex) eoshuby12345"
                ]
            , form []
                [ input
                    [ class "account_name"
                    , placeholder "계정이름은 반드시 12글자로 입력해주세요"
                    , attribute "required" ""
                    , attribute
                        (if model.validation then
                            "valid"
                         else
                            "invalid"
                        )
                        ""
                    , type_ "text"
                    , onInput ValidateAccountName
                    ]
                    []
                , span
                    [ style
                        [ ( "visibility"
                          , if String.isEmpty model.accountName then
                                "hidden"
                            else
                                "visible"
                          )
                        ]
                    ]
                    [ text model.validationMsg ]
                ]
            ]
        , div [ class "btn_area" ]
            [ button
                [ class "middle blue_white button"
                , attribute
                    (if model.validation && not model.requestSuccess then
                        "enabled"
                     else
                        "disabled"
                    )
                    ""
                , type_ "button"
                , onClick CreateEosAccount
                ]
                [ text "다음" ]
            ]
        ]



-- HTTP


type alias Response =
    { msg : String }


responseDecoder : Decoder Response
responseDecoder =
    decode Response
        |> required "msg" string


createEosAccountBodyParams : Model -> Http.Body
createEosAccountBodyParams model =
    Encode.object
        [ ( "account_name", Encode.string model.accountName )
        , ( "pubkey", Encode.string model.pubkey )
        ]
        |> Http.jsonBody


postCreateEosAccount : Model -> Flags -> String -> Http.Request Response
postCreateEosAccount model flags confirmToken =
    let
        url =
            Urls.createEosAccountUrl ( flags, confirmToken )

        params =
            createEosAccountBodyParams model
    in
        Http.post url params responseDecoder


createEosAccountRequest : Model -> Flags -> String -> Cmd Message
createEosAccountRequest model flags confirmToken =
    Http.send NewUser <| postCreateEosAccount model flags confirmToken
