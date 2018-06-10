$(document).ready(function () {
    /*chrome.storage.sync.clear(function() {
     var error = chrome.runtime.lastError;
     if (error) {
     console.error(error);
     }
     });*/
    $("#signInButton").css("display", "none");
    chrome.runtime.onMessage.addListener(function(message,sender,sendResponse) {
        if (message.type == 'authorizationComplete') {
            console.log("Received AUTHORIZATIONCOMPLETE event for AUTHORIZE request");
            return window.location.reload(true);
        }
        return true;
    });
    chrome.runtime.onMessage.addListener(function(message,sender,sendResponse) {
        if (message.type == 'authorizationComplete2') {
            console.log("Received AUTHORIZATIONCOMPLETE2 event for REFRESH request");
            chrome.storage.sync.get('userInfo', function (value) {
                if (value.userInfo) {
                    $(".frame").css("display", "none");
                    $(".successFrame").css("display", "block");
                    $(".successFrame .title .titleText").html(value.userInfo.username + "<br><span>#" + value.userInfo.discriminator + "</span>");
                    $(".successFrame .title .icon .iconImg").css("background", "url('https://cdn.discordapp.com/avatars/" + value.userInfo.id + "/" + value.userInfo.avatar + ".png?size=256') no-repeat center").css("background-size", "cover");
                    return true;
                }
                return true;
            });
        }
        return true;
    });
    chrome.storage.sync.get('userInfo', function (value) {
        if (value.userInfo == null) {
            console.log("Gotta Authenticate M8");
            $("#signInButton").css("display", "inline-block");
            $("#signInButton").click(function () {
                chrome.runtime.sendMessage({type: 'authorize'}, function (response) {
                    console.log(response);
                });
            });
        }
        else {
            chrome.runtime.sendMessage({type: 'refresh'}, function (response) {
                console.log(response);
            });
        }
    });
});
