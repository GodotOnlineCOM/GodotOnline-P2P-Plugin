extends Node
# INFO
# CURRENT VERSIONS: "version_local" for local test.
# CURRENT VERSIONS: "version_roma" for production.
# INFO
# API_KEY is currently under development. Enter a value not exceeding 128 bytes.
# If you keep 'default_apikey' as the API key, you might find that other users are testing out the system too.
# INFO
# You can set your own version control server by changing VERSION_CONTROL_URL.
# INFO
# If you set SERVER_MODE to True, you can host the server on your own machine.
#  -QUICK TIP-
# if you want to test your code, set SERVER_MODE to True and VERSION to “version_local”.

var DEBUGGER : bool = true
var SERVER_MODE : bool = false
var AUTO_CONNECT : bool = true
var API_KEY : String = "default_apikey"
var VERSION : String = "version_roma"
var VERSION_CONTROL_URL : String = "https://godotonline.com/versions.json"
var PREFIX : String = "ws://"
