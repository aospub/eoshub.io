module Util.Urls exposing (usersApiUrl, createEosAccountUrl, mainnetRpcUrl)

import Util.Flags exposing (Flags)


eoshubHost : Flags -> String
eoshubHost flags =
    if flags.node_env == "development" then
        "http://localhost:3000"
    else if flags.node_env == "test" then
        "http://localhost:3000"
    else if flags.node_env == "alpha" then
        "http://ecs-first-run-alb-1125793223.ap-northeast-2.elb.amazonaws.com"
    else if flags.node_env == "production" then
        ""
    else
        "http://localhost:3000"


usersApiUrl : Flags -> String -> String
usersApiUrl flags locale =
    eoshubHost flags ++ "/users?locale=" ++ locale


createEosAccountUrl : Flags -> String -> String -> String
createEosAccountUrl flags confirmToken locale =
    eoshubHost flags ++ "/users/" ++ confirmToken ++ "/create_eos_account?locale=" ++ locale


mainnetRpcUrl : String
mainnetRpcUrl =
    "https://rpc.eosys.io"
