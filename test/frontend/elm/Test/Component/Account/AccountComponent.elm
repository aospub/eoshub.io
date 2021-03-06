module Test.Component.Account.AccountComponent exposing (location, tests)

import Component.Account.AccountComponent exposing (..)
import Component.Account.Page.Create as Create
import Component.Account.Page.Created as Created
import Component.Account.Page.EventCreation as EventCreation
import Data.Common exposing (AppState, initAppState)
import Expect
import Http
import Navigation exposing (Location)
import Route
import Test exposing (..)
import Translation
import Util.HttpRequest exposing (getAppState)


location : Location
location =
    { href = ""
    , host = ""
    , hostname = ""
    , protocol = ""
    , origin = ""
    , port_ = ""
    , pathname = "/none"
    , search = ""
    , hash = ""
    , username = ""
    , password = ""
    }


tests : Test
tests =
    let
        flags =
            { rails_env = "test" }

        language =
            Translation.Korean
    in
    describe "Page module"
        [ describe "getPage"
            [ test "CreatedRoute" <|
                \() ->
                    let
                        eosAccount =
                            Just "testtesttest"

                        publicKey =
                            Just "lasdihgalsghasldgihasggasdgasdgagsafgas"
                    in
                    Expect.equal (CreatedPage <| Created.initModel eosAccount publicKey) (getPage <| Route.CreatedRoute eosAccount publicKey)
            , test "EventCreationRoute" <|
                \() ->
                    Expect.equal (EventCreationPage EventCreation.initModel) (getPage <| Route.EventCreationRoute <| Just "ko")
            , test "NotFoundRoute" <|
                \() -> Expect.equal NotFoundPage (getPage Route.NotFoundRoute)
            ]
        , describe "initCmd"
            [ test "EventCreationRoute" <|
                \() ->
                    let
                        eventCreationModel =
                            EventCreation.initModel

                        subCmd =
                            EventCreation.initCmd

                        expectedPage =
                            EventCreationPage eventCreationModel

                        expectedCmd =
                            Cmd.batch
                                [ Cmd.map EventCreationMessage subCmd
                                , getAppState flags
                                    |> Http.send OnFetchAppState
                                ]

                        model =
                            { page = expectedPage
                            , language = Translation.Korean
                            , flags = { rails_env = "test" }
                            , appState = initAppState
                            }
                    in
                    Expect.equal (toString expectedCmd) (toString (initCmd model))
            ]
        ]
