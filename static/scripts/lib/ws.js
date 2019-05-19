define(["constants", "wsEventHandler"], function(c, wsEventHandler){
    let wss = undefined;
    let HEARTBEAT_INTERVAL = undefined;
    let WebSocketConnection = {
        init: function () {
            wss = new WebSocket("wss://wss.motorbot.io");
            wss.session = undefined;
            wss.onopen = function (event) {
                console.info("websocket connection opened");
                //[C] HELLO -> [S] WELCOME -> [C] JOIN GUILD -> [S] GUILD STATE
                WebSocketConnection.send("HELLO",{
                    api_key: "caf07b8b-366e-44ab-9bda-623f94a9c2df",
                    client_id: "7c78862088c0228ca226f4462df3d4ff",
                    user_id: c.user_id
                });
                HEARTBEAT_INTERVAL = setInterval(function(){
                    WebSocketConnection.send("HEARTBEAT")
                },41250);
                document.getElementById("websocketDisconnectOverlay").style.display = "none";
                document.querySelector(".flexContainer").style.filter = "blur(0)";
                document.querySelector(".playerBar").style.filter = "blur(0)";
                document.querySelector(".errorList").style.filter = "blur(0)";
                document.querySelector(".modalityOverlay").style.display = "none";
            };

            wss.onmessage = function (event) {
                wsEventHandler(wss, event);
            };

            wss.onclose = function (event) {
                console.error("WEBSOCKET_CONNECTION_CLOSED");
                document.querySelector(".flexContainer").style.filter = "blur(5px)";
                document.querySelector(".playerBar").style.filter = "blur(5px)";
                document.querySelector(".errorList").style.filter = "blur(5px)";
                document.querySelector(".modalityOverlay").style.display = "block";
                document.getElementById("newPlaylistModal").style.display = "none"; //INFO: make sure no other modals are open
                document.getElementById("websocketDisconnectOverlay").style.display = "block";
                setTimeout(function(){
                    WebSocketConnection.init();
                },5000);
            };

            return wss;
        },
        send: function (type, message) {
            if(!message){
                message = {};
            }
            message.session = c.websocketSession
            let p = {
                op: c.op[type],
                type: type,
                d: message
            }
            console.log("[WEBSOCKET] ~> : %@",p)
            wss.send(JSON.stringify(p));
        }
    };
    return WebSocketConnection
});