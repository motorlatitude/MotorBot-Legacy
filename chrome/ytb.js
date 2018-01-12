function addExtraButton() {
    var element = document.getElementById('top-level-buttons');
    var soundcloud_element = document.getElementsByClassName('sc-button-group-medium')[0];
    if (typeof(element) != 'undefined' && element != null) {
        var mb_element = document.getElementById('motorbot-button');
        if (typeof(mb_element) != 'undefined' && mb_element != null) {

        }
        else{
            var newMenuItem = document.createElement('ytd-button-renderer');
            newMenuItem.className = "style-scope ytd-menu-renderer style-default";
            newMenuItem.innerHTML = '<div id="motorbot-button">'+
                '<img style="height: 22px;" src='+chrome.extension.getURL("icon.png")+'>' +
                '</div><style type="text/css">#motorbot-button{opacity: 0.6; cursor: pointer; padding: 8px 12px;} #motorbot-button:hover{opacity: 0.8;} #motorbot-button:active{opacity: 0.4;} .loader{margin-left: calc(50% - 5px); margin-top: 15px; width: 11px; height: 11px; border: 2px solid transparent; border-top-color: rgba(22, 122, 198, 1.00); border-left-color: rgba(22, 122, 198, 1.00); border-radius: 50%; box-sizing: border-box; display: inline-block; vertical-align: middle; animation: spinner 0.5s infinite linear} @keyframes spinner{0%{transform: rotate(0deg)} 100%{transform: rotate(360deg);}} #motorbotDropDown{position: absolute; background: #232323; box-shadow: 0 0 25px #000; min-height: 40px;}</style>';
            dropDownMenu = $("#motorbotDropDown");
            $('#info #top-level-buttons').append(newMenuItem);
            $("body").append("<div style='min-width: 260px; width: 320px; left: " + ($("#motorbot-button").offset().left - 20) + "px; top: " + ($("#motorbot-button").offset().top + 40) + "px; z-index: 300; display: none;' id='motorbotDropDown'><ul id='motorbot-user-playlists'></ul></div>");
        }
        document.getElementById('motorbot-button').addEventListener('click', function (evt) {
            //drop down list
            console.info("Motorbot-Button");
            if ($("#motorbotDropDown").css("display") == "none") {
                chrome.storage.sync.get('userInfo', function (value) {
                    if (value.userInfo == null) {
                        $("#motorbot-button").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(230, 33, 23, 1.00); vertical-align: middle;'>Authentication Error</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
                        console.error("[Motorbot] Error Occurred Sending Video to motorbot: You're not authenticated :(");
                    }
                    else {
                        $("#motorbotDropDown").css("top", ($("#motorbot-button").offset().top + 40) + "px").css("left",($("#motorbot-button").offset().left - 20) + "px").css("display", "block");
                        $("#motorbotDropDown").html("<div class='loader'></div>");
                        var videoId = getParameterByName("v", window.location.href);
                        $.ajax({
                            url: "https://mb.lolstat.net/api/user/playlists?api_key=caf07b8b-366e-44ab-9bda-152a42g8d1ef",
                            dataType: "json",
                            beforeSend: function (xhr) {
                                xhr.setRequestHeader("Authorization", "Bearer " + value.userInfo.token);
                            },
                            success: function (data) {
                                $("#motorbotDropDown").html("<div id=\"header\" class=\"style-scope ytd-add-to-playlist-renderer\">Add to...</div><div class='motorbot-user-scrollview'><ul id='motorbot-user-playlists' class='yt-uix-kbd-nav yt-uix-kbd-nav-list'></ul></div><div id='motorbot-create-new-playlist'>Create a new playlist</div></div><style type='text/css'>#header.ytd-add-to-playlist-renderer {\n" +
                                    "    color: var(--yt-primary-text-color);\n" +
                                    "    padding: 16px 24px;\n" +
                                    "    border-bottom: 1px solid var(--yt-border-color);\n" +
                                    "    font-size: 1.6rem;\n" +
                                    "    font-weight: 400;\n" +
                                    "    line-height: 2rem;\n" +
                                    "} .motorbot-user-scrollview{overflow-y: auto; overflow-x: hidden; width: 100%; max-height: 155px; border-bottom: 1px solid #ccc; margin-top: 10px; padding-bottom: 10px;} #motorbot-user-playlists li{font-size: 13px; padding: 0 15px; height: 30px; line-height: 30px; width: calc(100% - 30px); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; cursor: pointer;} #motorbot-user-playlists li:hover{background: #efefef;} #motorbot-create-new-playlist{margin-top: 10px; padding: 0 15px; height: 25px; line-height: 25px; width: calc(100% - 30px); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; cursor: pointer;} #motorbot-create-new-playlist:hover{background: #efefef;}</style>");
                                $.each(data, function (i, item) {
                                    if (item.creator == value.userInfo.id.toString()) {
                                        $("#motorbot-user-playlists").append("<li class='motorbot-playlist-item' data-playlistId='" + item.id + "'>" + item.name + "</li>");
                                    }
                                });
                                $("#motorbot-create-new-playlist").click(function (e) {
                                    $(this).css("display", "none");
                                    dropDownMenu.append("<input type='text' class='yt-uix-form-input-text title-input' style='width: 210px; margin: 15px;' title='Enter name of new playlist' id='motorbot-create-new-playlist-textfield'/><br/><button type='button' id='motorbot-create-new-playlist-button' class='yt-uix-button yt-uix-button-size-default yt-uix-button-primary create-button disabled' disabled style='float: right; margin-right: 15px;'><span class='yt-uix-button-content disabled'>Create</span></button>");
                                    $("#motorbot-create-new-playlist-textfield").on("keyup", function (e) {
                                        if ($(this).val().length > 1) {
                                            $("#motorbot-create-new-playlist-button").prop("disabled", false)
                                        }
                                        else {
                                            $("#motorbot-create-new-playlist-button").prop("disabled", true)
                                        }
                                    });
                                    $("#motorbot-create-new-playlist-button").click(function (e) {
                                        if (!$(this).prop("disabled")) {
                                            console.log("[Motorbot] Create new playlists named: " + $("#motorbot-create-new-playlist-textfield").val());
                                            var videoId = getParameterByName("v", window.location.href);
                                            chrome.storage.sync.get('userInfo', function (value) {
                                                if (value.userInfo == null) {
                                                    $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(230, 33, 23, 1.00); vertical-align: middle;'>Authentication Error</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
                                                    console.error("[Motorbot] Error Occurred Sending Video to motorbot: You're not authenticated :(");
                                                }
                                                else {
                                                    $.ajax({
                                                        method: "POST",
                                                        url: "https://mb.lolstat.net/api/playlist?api_key=caf07b8b-366e-44ab-9bda-152a42g8d1ef",
                                                        dataType: "json",
                                                        processData: false,
                                                        contentType: 'application/json',
                                                        data: JSON.stringify({"playlist_name": $("#motorbot-create-new-playlist-textfield").val()}),
                                                        beforeSend: function (xhr) {
                                                            xhr.setRequestHeader("Authorization", "Bearer " + value.userInfo.token);
                                                        },
                                                        success: function (data) {
                                                            playlistId = data.id;
                                                            if (playlistId) {
                                                                $.ajax({
                                                                    url: "https://mb.lolstat.net/api/playlist/" + playlistId + "/song?api_key=caf07b8b-366e-44ab-9bda-152a42g8d1ef",
                                                                    type: "PUT",
                                                                    dataType: "json",
                                                                    processData: false,
                                                                    contentType: 'application/json',
                                                                    data: JSON.stringify({
                                                                        "source": "ytb",
                                                                        "video_id": videoId
                                                                    }),
                                                                    beforeSend: function (xhr) {
                                                                        xhr.setRequestHeader("Authorization", "Bearer " + value.userInfo.token);
                                                                    },
                                                                    success: function (data) {
                                                                        if (data.added) {
                                                                            $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(46, 177, 111, 1.00); vertical-align: middle;'>Added</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
                                                                        }
                                                                        $("#motorbotDropDown").css("display", "none");
                                                                    },
                                                                    error: function (err) {
                                                                        $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(230, 33, 23, 1.00); vertical-align: middle;'>Error</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
                                                                        console.error("Error Occurred Sending Video to motorbot: " + err);
                                                                    }
                                                                });
                                                            }
                                                            else {
                                                                $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(230, 33, 23, 1.00); vertical-align: middle;'>Error</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
                                                                console.error("Error Occurred Sending Video to motorbot: " + err);
                                                            }
                                                        },
                                                        error: function (err) {
                                                            $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(230, 33, 23, 1.00); vertical-align: middle;'>Error</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
                                                            console.error("Error Occurred Sending Video to motorbot: " + err);
                                                        }
                                                    });
                                                }
                                            });
                                        }
                                    });
                                });
                                $(".motorbot-playlist-item").each(function (index) {
                                    $(this).click(function (e) {
                                        var playlistId = $(this).attr("data-playlistId");
                                        chrome.storage.sync.get('userInfo', function (value) {
                                            if (value.userInfo == null) {
                                                $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(230, 33, 23, 1.00); vertical-align: middle;'>Authentication Error</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
                                                console.error("[Motorbot] Error Occurred Sending Video to motorbot: You're not authenticated :(");
                                            }
                                            else {
                                                var videoId = getParameterByName("v", window.location.href);
                                                console.info("[Motorbot] " + value.userInfo.id + " Adding video " + videoId + " to playlist " + playlistId);
                                                $.ajax({
                                                    url: "https://mb.lolstat.net/api/playlist/" + playlistId + "/song?api_key=caf07b8b-366e-44ab-9bda-152a42g8d1ef",
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
                                                            $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(46, 177, 111, 1.00); vertical-align: middle;'>Added</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
                                                        }
                                                        $("#motorbotDropDown").css("display", "none");
                                                    },
                                                    error: function (err) {
                                                        $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(230, 33, 23, 1.00); vertical-align: middle;'>Error</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
                                                        console.error("Error Occurred Sending Video to motorbot: " + err);
                                                    }
                                                });
                                            }
                                        });
                                    });
                                });
                            },
                            error: function (err) {
                                $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(230, 33, 23, 1.00); vertical-align: middle;'>Error</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
                                console.error("[Motorbot] Error Occurred Getting Playlists: " + err);
                                $("#motorbotDropDown").css("display", "none");
                            }
                        });
                    }
                });
            }
            else {
                $("#motorbotDropDown").css("display", "none");
            }
        });
    }
    else if (typeof(soundcloud_element) != 'undefined' && soundcloud_element != null) {
        // <button class="sc-button-like sc-button sc-button-medium sc-button-responsive" aria-describedby="tooltip-81" tabindex="0" title="Like">Like</button>
        var new_button = document.createElement("button");
        new_button.className = "sc-button sc-button-medium sc-button-responsive";
        new_button.id = "action-panel-overflow-button-motorbot";
        new_button.tabindex = "0";
        new_button.title = "MotorBot";
        new_button.style = "text-indent: 19px;";
        new_button.setAttribute("aria-own","motorbot_dropdownmenu");
        new_button.setAttribute("aria-haspopup","true");
        new_button.role = "button";
        new_button.innerHTML = "MotorBot <style type='text/css'>#action-panel-overflow-button-motorbot:before{content: ''; display: block; position: absolute; background-repeat: no-repeat; background-position: center center; width: 20px; height: 20px; top: 0; bottom: 0; margin: auto 0; left: 4px;background-size: 20px 20px; background-image: url('chrome-extension://pgkdpldhnmmhpdfmmkgpnpofaaagomab/icon_20x20.png')}</style>";
        new_button.value = "MotorBot";
        soundcloud_element.appendChild(new_button);
        $("body").click(function(e){
            console.log("Document Clicked");
            console.log($("#motorbot_dropdownmenu").length);
            if($("#motorbot_dropdownmenu").length > 0 && e.target.id != "action-panel-overflow-button-motorbot"){
                $("#motorbot_dropdownmenu").remove();
                $("#action-panel-overflow-button-motorbot").removeClass("sc-button-active");
            }
        });
        $("#action-panel-overflow-button-motorbot").click(function(e){
            var soundcloud_trackId = $("meta[property='twitter:app:url:iphone']").attr("content");
            if(soundcloud_trackId.length > 0){
                if($("#motorbot_dropdownmenu").length > 0){
                    $("#motorbot_dropdownmenu").remove();
                    $("#action-panel-overflow-button-motorbot").removeClass("sc-button-active");
                }
                else {
                    var new_button_motorbot = $("#action-panel-overflow-button-motorbot");
                    new_button_motorbot.addClass("sc-button-active");
                    var trackId = soundcloud_trackId.replace("soundcloud://sounds:", "");
                    console.log("[MTRBT] Soundcloud track id: " + trackId);
                    var new_dropdownmenu = document.createElement("div");
                    new_dropdownmenu.className = "dropdownMenu g-z-index-overlay";
                    var x = new_button_motorbot.offset().left;
                    var y = new_button_motorbot.offset().top;
                    new_dropdownmenu.style = "outline: none; width: auto; min-height: auto; position: absolute; top: "+(y+27)+"px; left: "+x+"px; max-width: 345px; overflow: hidden; white-space: nowrap; text-overflow: ellipsis;";
                    new_dropdownmenu.id = "motorbot_dropdownmenu";
                    new_dropdownmenu.innerHTML = '<div class="moreActions sc-list-nostyle sc-border-box"><div class="moreActions__group" id="motorbotplaylists"></div></div>'
                    document.getElementsByTagName("body")[0].appendChild(new_dropdownmenu);
                    chrome.storage.sync.get('userInfo', function (value) {
                        if (value.userInfo == null) {
                            new_button_motorbot.attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(230, 33, 23, 1.00); vertical-align: middle;'>Authentication Error</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
                            console.error("[Motorbot] Error Occurred Sending Video to motorbot: You're not authenticated :(");
                        }
                        else {
                            $.ajax({
                                url: "https://mb.lolstat.net/api/user/playlists?api_key=caf07b8b-366e-44ab-9bda-152a42g8d1ef",
                                dataType: "json",
                                beforeSend: function (xhr) {
                                    xhr.setRequestHeader("Authorization", "Bearer " + value.userInfo.token);
                                },
                                success: function (data) {
                                    $.each(data, function (i, item) {
                                        if (item.creator == value.userInfo.id.toString()) {
                                            $("#motorbotplaylists").append('<button class="moreActions__button sc-button-medium sc-button-addtoset" tabindex="0" aria-describedby="tooltip-17795" title="'+item.name+'" data-playlistId="' + item.id + '">' + item.name + '</li>');
                                        }
                                    });
                                }
                            });
                        }
                    });
                }
            }
            else{
                console.error("[MTRBT] Couldn't establish track ID :(")
            }
        });
    }
}

var target = document.getElementsByTagName("body")[0];
var observer = new MutationObserver(function (mutations) {
    mutations.forEach(function (mutation) {
        var motorbotButton = document.getElementById('motorbot-button');
        if (motorbotButton == null) {
            addExtraButton();
        }
    });
});
observer.observe(target, {attributes: false, childList: true, characterData: false});

addExtraButton();

function getParameterByName(name, url) {
    if (!url) url = window.location.href;
    name = name.replace(/[\[\]]/g, "\\$&");
    var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)"),
        results = regex.exec(url);
    if (!results) return null;
    if (!results[2]) return '';
    return decodeURIComponent(results[2].replace(/\+/g, " "));
}
