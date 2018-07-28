function addExtraButton() {
    if ($('.html5-video-container').length > 0) {
        let mb_element = document.getElementById('motorbot-button');
        let mb_state_element = document.getElementById('motorbot-state');
        if (typeof(mb_element) !== 'undefined' && mb_element != null) {
            console.info("Button Has Already Been Added");
        }
        else if(typeof(mb_state_element) !== 'undefined' && mb_state_element != null){
            console.info("Motorbot State Element is Active");
        }
        else{
            let newMenuItem = document.createElement('div');
            newMenuItem.id = "motorbot-button";
            newMenuItem.innerHTML = '<img style="height: 40px;" src='+chrome.extension.getURL("icon.png")+'>' +
                '</div><style type="text/css">#motorbot-button{opacity: 0.4; cursor: pointer; position: absolute; top: 16px; left: 20px; z-index: 301;} #motorbot-button.active{opacity: 1;} #motorbot-button:hover{opacity: 1;} #motorbot-button:active{opacity: 0.6;} .loader{margin-left: calc(50% - 5px); margin-top: 20px; width: 11px; height: 11px; border: 2px solid transparent; border-top-color: rgba(22, 122, 198, 1.00); border-left-color: rgba(22, 122, 198, 1.00); border-radius: 50%; box-sizing: border-box; display: inline-block; vertical-align: middle; animation: spinner 0.5s infinite linear} @keyframes spinner{0%{transform: rotate(0deg)} 100%{transform: rotate(360deg);}}</style>';
            $('.html5-video-container').append(newMenuItem);
            $('.html5-video-container').append("<div id='motorbot-state'></div>");
            $('.html5-video-container').append("<div style='min-width: 260px; width: 320px; min-height: 53px; left: 10px; top: 10px; border-radius: 4px; background: rgba(35, 35, 35, 0.9); position: absolute; box-shadow: 0 0 10px rgba(0,0,0,0.4); z-index: 300; display: none; transition: height 0.5s ease-in-out;' id='motorbotDropDown'><ul id='motorbot-user-playlists'></ul></div>");
            $('.html5-video-container>video').on("loadstart", function(e){
                console.log("VIDEO PLAYER UPDATE");
                let mb_element = document.getElementById('motorbot-button');
                if (typeof(mb_element) !== 'undefined' && mb_element != null) {
                    $("#motorbotDropDown").remove();
                    $("#motorbot-button").remove();
                }
                if($("#motorbot-state")){
                    $("#motorbot-state").remove();
                }
            });
        }
        document.getElementById('motorbot-button').addEventListener('click', function (evt) {
            //drop down list
            if ($("#motorbotDropDown").css("display") == "none" && !$("#motorbot-button").attr("disabled")) {
                chrome.storage.sync.get('userInfo', function (value) {
                    if (value.userInfo == null) {
                        $(".html5-video-container").append("<style type='text/css'>#motorbot-state{opacity: 1; position: absolute; top: 16px; left: 20px; line-height: 40px; z-index: 301; padding-left: 10px; min-width: 250px; width: 310px; border-radius: 4px; background: rgba(35, 35, 35, 0.9);box-shadow: 0 0 10px rgba(0,0,0,0.3); transition: opacity 0.5s ease-in-out; transition-delay: 3s;} #motorbot-state.active{opacity: 0}</style>");
                        $("#motorbot-state").css("background","rgba(255, 0, 0, 0.9)").html("<span class=\"yt-uix-button-content\" style='color: #fff; vertical-align: middle; font-family: Roboto, Arial, sans-serif; font-size: 13px; font-weight: 500; letter-spacing: 0.007px; line-height: 40px;'>Authentication Error</span>");
                        document.getElementById("motorbot-state").classList.add("active");
                        setTimeout(function(){
                            $("#motorbot-state").remove();
                        },4000);
                        $("#motorbot-button").remove();
                        $("#motorbotDropDown").remove();
                        console.error("[Motorbot] Error Occurred Sending Video to motorbot: You're not authenticated :(");
                    }
                    else {
                        $("#motorbotDropDown").css("display", "block");
                        document.getElementById("motorbot-button").classList.add("active");
                        $("#motorbotDropDown").html("<div class='loader'></div>");
                        $.ajax({
                            url: "https://motorbot.io/api/user/playlists?limit=50&filter=id,name,creator,position&api_key=caf07b8b-366e-44ab-9bda-152a42g8d1ef",
                            dataType: "json",
                            beforeSend: function (xhr) {
                                xhr.setRequestHeader("Authorization", "Bearer " + value.userInfo.token);
                            },
                            success: function (data) {
                                $("#motorbotDropDown").html("<div id=\"header\" class=\"style-scope ytd-add-to-playlist-renderer\">&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Add to...</div>" +
                                    "<div class='motorbot-user-scrollview'>" +
                                        "<ul id='motorbot-user-playlists' class='yt-uix-kbd-nav yt-uix-kbd-nav-list'></ul>" +
                                    "</div>" +
                                    "</div>" +
                                    "<style type='text/css'>#header.ytd-add-to-playlist-renderer {\n" +
                                    "    color: var(--yt-primary-text-color);\n" +
                                    "    padding: 16px 24px;\n" +
                                    "    border-bottom: 1px solid var(--yt-border-color);\n" +
                                    "    font-size: 1.6rem;\n" +
                                    "    font-weight: 400;\n" +
                                    "    line-height: 2rem;\n" +
                                    "    cursor: default;\n" +
                                    "} .motorbot-user-scrollview{overflow-y: auto; overflow-x: hidden; width: 100%; max-height: 300px;} #motorbot-user-playlists{list-style: none; margin: 15px; margin-top: 10px; margin-bottom: 10px; padding: 0;} #motorbot-user-playlists li{font-size: 1.4rem; font-weight: 400; color: #fff; line-height: 40px; width: calc(100% - 20px); padding-left: 10px; padding-right: 10px; font-family: 'Roboto', 'Noto', sans-serif; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; cursor: pointer; -webkit-font-smoothing: antialiased; border-radius: 4px;} #motorbot-user-playlists li:hover{background: rgba(200,200,200,0.1);}</style>");
                                if(data.items) {
                                    let playlists = data.items;
                                    playlists.sort(function(a, b){
                                        return parseFloat(a.position) - parseFloat(b.position);
                                    });
                                    $.each(playlists, function (i, item) {
                                        if (item.creator == value.userInfo.id.toString()) {
                                            $("#motorbot-user-playlists").append("<li class='motorbot-playlist-item' data-playlistId='" + item.id + "'>" + item.name + "</li>");
                                        }
                                    });
                                    $(".motorbot-playlist-item").each(function (index) {
                                        $(this).click(function (e) {
                                            var playlistId = $(this).attr("data-playlistId");
                                            chrome.storage.sync.get('userInfo', function (value) {
                                                if (value.userInfo == null) {
                                                    $(".html5-video-container").append("<style type='text/css'>#motorbot-state{opacity: 1; position: absolute; top: 16px; left: 20px; line-height: 40px; z-index: 301; padding-left: 10px; min-width: 250px; width: 310px; border-radius: 4px; background: rgba(35, 35, 35, 0.9);box-shadow: 0 0 10px rgba(0,0,0,0.3); transition: opacity 0.5s ease-in-out; transition-delay: 3s;} #motorbot-state.active{opacity: 0}</style>");
                                                    $("#motorbot-state").css("background","rgba(255, 0, 0, 0.9)").html("<span class=\"yt-uix-button-content\" style='color: #fff; vertical-align: middle; font-family: Roboto, Arial, sans-serif; font-size: 13px; font-weight: 500; letter-spacing: 0.007px; line-height: 40px;'>Authentication Error</span>");
                                                    document.getElementById("motorbot-state").classList.add("active");
                                                    setTimeout(function(){
                                                        $("#motorbot-state").remove();
                                                    },4000);
                                                    $("#motorbot-button").remove();
                                                    $("#motorbotDropDown").remove();
                                                    console.error("[Motorbot] Error Occurred Sending Video to motorbot: You're not authenticated :(");
                                                }
                                                else {
                                                    var videoId = getParameterByName("v", window.location.href);
                                                    console.info("[Motorbot] " + value.userInfo.id + " Adding video " + videoId + " to playlist " + playlistId);
                                                    $.ajax({
                                                        url: "https://motorbot.io/api/playlist/" + playlistId + "/song?api_key=caf07b8b-366e-44ab-9bda-152a42g8d1ef",
                                                        type: "PUT",
                                                        dataType: "json",
                                                        processData: false,
                                                        contentType: 'application/json',
                                                        data: JSON.stringify({"source": "ytb", "video_id": videoId}),
                                                        beforeSend: function (xhr) {
                                                            xhr.setRequestHeader("Authorization", "Bearer " + value.userInfo.token);
                                                        },
                                                        success: function (data) {
                                                            if (data.added) {
                                                                $(".html5-video-container").append("<style type='text/css'>#motorbot-state{opacity: 1; position: absolute; top: 16px; left: 20px; line-height: 40px; z-index: 301; padding-left: 10px; min-width: 250px; width: 310px; border-radius: 4px; background: rgba(35, 35, 35, 0.9);box-shadow: 0 0 10px rgba(0,0,0,0.3); transition: opacity 0.5s ease-in-out; transition-delay: 3s;} #motorbot-state.active{opacity: 0}</style>");
                                                                $("#motorbot-state").css("background","rgba(0, 200, 83, 0.9)").html("<span class=\"yt-uix-button-content\" style='color: #fff; vertical-align: middle; font-family: Roboto, Arial, sans-serif; font-size: 13px; font-weight: 500; letter-spacing: 0.007px; line-height: 40px;'>Successfully Added</span>");
                                                                document.getElementById("motorbot-state").classList.add("active");
                                                                setTimeout(function(){
                                                                    $("#motorbot-state").remove();
                                                                },4000);
                                                                $("#motorbot-button").remove();
                                                                $("#motorbotDropDown").remove();
                                                            }
                                                        },
                                                        error: function (err) {
                                                            $(".html5-video-container").append("<style type='text/css'>#motorbot-state{opacity: 1; position: absolute; top: 16px; left: 20px; line-height: 40px; z-index: 301; padding-left: 10px; min-width: 250px; width: 310px; border-radius: 4px; background: rgba(35, 35, 35, 0.9);box-shadow: 0 0 10px rgba(0,0,0,0.3); transition: opacity 0.5s ease-in-out; transition-delay: 3s;} #motorbot-state.active{opacity: 0}</style>");
                                                            $("#motorbot-state").css("background","rgba(255, 0, 0, 0.9)").html("<span class=\"yt-uix-button-content\" style='color: #fff; vertical-align: middle; font-family: Roboto, Arial, sans-serif; font-size: 13px; font-weight: 500; letter-spacing: 0.007px; line-height: 40px;'>Error Adding Song :(</span>");
                                                            document.getElementById("motorbot-state").classList.add("active");
                                                            setTimeout(function(){
                                                                $("#motorbot-state").remove();
                                                            },4000);
                                                            $("#motorbot-button").remove();
                                                            $("#motorbotDropDown").remove();
                                                            console.error("Error Occurred Sending Video to motorbot: " + err);
                                                        }
                                                    });
                                                }
                                            });
                                            e.stopPropagation();
                                        });
                                    });
                                }
                            },
                            error: function (err) {
                                $("#motorbot-button").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(255, 0, 0, 1.00); vertical-align: middle; font-family: Roboto, Arial, sans-serif; font-size: 13px; font-weight: 500; letter-spacing: 0.007px; line-height: 21px;'>ERROR</span>");
                                console.error("[Motorbot] Error Occurred Getting Playlists: " + err);
                                $("#motorbotDropDown").css("display", "none");
                            }
                        });
                    }
                });
                evt.stopPropagation();
                return false;
            }
            else {
                $("#motorbotDropDown").css("display", "none");
                document.getElementById("motorbot-button").classList.remove("active");
                evt.stopPropagation();
                evt.preventDefault();
                return false;
            }
        });
    }
}
chrome.runtime.onMessage.addListener(function(message,sender,sendResponse) {
    if (message.type === 'youtube_request') {
        if (document.getElementById('motorbot-button') == null) {
            addExtraButton();
        }
    }
});

function getParameterByName(name, url) {
    if (!url) url = window.location.href;
    name = name.replace(/[\[\]]/g, "\\$&");
    var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)"),
        results = regex.exec(url);
    if (!results) return null;
    if (!results[2]) return '';
    return decodeURIComponent(results[2].replace(/\+/g, " "));
}
