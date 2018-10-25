module Util.Urls exposing
    ( checkeEosAccountCreatedUrl
    , confirmEmailUrl
    , createEosAccountUrl
    , eosAccountProductUrl
    , eosConstitutionUrl
    , getProducersUrl
    , getRecentVoteStatUrl
    , mainnetRpcUrl
    , requestPaymentUrl
    , usersApiUrl
    )

import Util.Flags exposing (Flags)


eoshubHost : Flags -> String
eoshubHost flags =
    if flags.rails_env == "development" then
        "http://localhost:3000"

    else if flags.rails_env == "test" then
        "http://localhost:3000"

    else if flags.rails_env == "alpha" then
        "http://alpha.eoshub.io"

    else if flags.rails_env == "production" then
        "https://eoshub.io"

    else
        "http://localhost:3000"


usersApiUrl : Flags -> String -> String
usersApiUrl flags locale =
    eoshubHost flags ++ "/users?locale=" ++ locale


confirmEmailUrl : Flags -> String -> String -> String
confirmEmailUrl flags confirmToken locale =
    eoshubHost flags ++ "/users/" ++ confirmToken ++ "/confirm_email?locale=" ++ locale


createEosAccountUrl : Flags -> String -> String -> String
createEosAccountUrl flags confirmToken locale =
    eoshubHost flags ++ "/users/" ++ confirmToken ++ "/create_eos_account?locale=" ++ locale


eosAccountProductUrl : Flags -> String -> String
eosAccountProductUrl flags locale =
    eoshubHost flags ++ "/products/eos_account?locale=" ++ locale


requestPaymentUrl : Flags -> String -> String
requestPaymentUrl flags locale =
    eoshubHost flags ++ "/orders/request_payment?locale=" ++ locale


checkeEosAccountCreatedUrl : Flags -> String -> String -> String
checkeEosAccountCreatedUrl flags orderId locale =
    eoshubHost flags ++ "/orders/" ++ orderId ++ "/check_eos_account_created?locale=" ++ locale


getProducersUrl : Flags -> String
getProducersUrl flags =
    eoshubHost flags ++ "/producers/"


getRecentVoteStatUrl : Flags -> String
getRecentVoteStatUrl flags =
    eoshubHost flags ++ "/vote_stats/recent_stat"


mainnetRpcUrl : String
mainnetRpcUrl =
    -- TODO(boseok): Consider to find fastest api node that we can use.
    -- "http://rpc1.eosys.io:8888"
    -- "https://api1.eosasia.one"
    "https://eos.greymass.com"



--"https://api.eosnewyork.io"


eosConstitutionUrl : String
eosConstitutionUrl =
    "https://github.com/EOS-Mainnet/governance/blob/master/eosio.system/eosio.system-clause-constitution-rc.md"
