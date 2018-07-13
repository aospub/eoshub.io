module Response exposing (decodeScatterResponse)

import View.Notification


-- This type should be expanded as Wallet Response.


type alias ScatterResponse =
    { code : Int
    , type_ : String
    , message : String
    }


decodeScatterResponse : ScatterResponse -> View.Notification.Message
decodeScatterResponse { code, type_, message } =
    if code == 200 then
        View.Notification.Ok
    else
        View.Notification.Error { code = code, message = type_ ++ "\n" ++ message }