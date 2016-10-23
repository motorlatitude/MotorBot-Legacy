function addExtraButton(){
  var element =  document.getElementById('watch8-secondary-actions');
  var searchElement = document.getElementById('results');
  if (typeof(element) != 'undefined' && element != null) {
    var newMenuItem = document.createElement('div');
    newMenuItem.className = "yt-uix-menu";
    var newButton = document.createElement('button');
    newButton.title = "Add to MotorBot";
    newButton.id = "action-panel-overflow-button-motorbot";
    newButton.className = "yt-uix-button yt-uix-button-size-default yt-uix-button-has-icon yt-uix-button-opacity pause-resume-autoplay yt-uix-menu-trigger yt-uix-tooltip motorbot";
    newButton.type = "button";
    newButton.innerHTML = "<span class=\"yt-uix-button-content\" style='vertical-align: middle;'>MotorBot</span> <style type='text/css'>.motorbot{opacity: 0.5; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 6px; margin-right: 6px; display: inline-block; vertical-align: middle;} .loader{width: 11px; height: 11px; border: 2px solid transparent; border-top-color: rgba(22, 122, 198, 1.00); border-left-color: rgba(22, 122, 198, 1.00); border-radius: 50%; box-sizing: border-box; display: inline-block; margin-left: 8px; vertical-align: middle; animation: spinner 0.5s infinite linear} @keyframes spinner{0%{transform: rotate(0deg)} 100%{transform: rotate(360deg);}}</style>";
    newMenuItem.appendChild(newButton);
    $("body").append("<div class='yt-ui-menu-content yt-uix-menu-content yt-uix-menu-content-external yt-uix-kbd-nav' style='min-width: 260px; max-width: 260px;  left: 560px; top: 920px; display: none;' id='motorbotDropDown'><ul id='motorbot-user-playlists'></ul></div>");
    dropDownMenu = $("#motorbotDropDown");
    document.getElementById('watch8-secondary-actions').appendChild(newMenuItem);
    document.getElementById('action-panel-overflow-button-motorbot').addEventListener('click', function (evt) {
      //drop down list
      if ($("#motorbotDropDown").css("display") == "none") {
        chrome.storage.sync.get('userInfo', function (value) {
          if (value.userInfo == null) {
            $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(230, 33, 23, 1.00); vertical-align: middle;'>Authentication Error</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
            console.error("[Motorbot] Error Occurred Sending Video to motorbot: You're not authenticated :(");
          }
          else {
            dropDownMenu.css("display", "block");
            dropDownMenu.html("<div class='loader'></div>");
            var videoId = getParameterByName("v", window.location.href);
            $.ajax({
              url: "https://mb.lolstat.net/api/getPlaylistsForUser/" + value.userInfo.id,
              dataType: "json",
              success: function (data) {
                dropDownMenu.html("<h3 class='motorbot-user-h3'>Add to</h3><div class='motorbot-user-scrollview'><ul id='motorbot-user-playlists' class='yt-uix-kbd-nav yt-uix-kbd-nav-list'></ul></div><div id='motorbot-create-new-playlist'>Create a new playlist</div></div><style type='text/css'>.motorbot-user-h3{padding: 0 15px; height: 25px; line-height: 25px; width: calc(100% - 30px);} .motorbot-user-scrollview{overflow-y: auto; overflow-x: hidden; width: 100%; max-height: 155px; border-bottom: 1px solid #ccc; margin-top: 10px; padding-bottom: 10px;} #motorbot-user-playlists li{font-size: 13px; padding: 0 15px; height: 30px; line-height: 30px; width: calc(100% - 30px); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; cursor: pointer;} #motorbot-user-playlists li:hover{background: #efefef;} #motorbot-create-new-playlist{margin-top: 10px; padding: 0 15px; height: 25px; line-height: 25px; width: calc(100% - 30px); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; cursor: pointer;} #motorbot-create-new-playlist:hover{background: #efefef;}</style>");
                $.each(data, function (i, item) {
                  $("#motorbot-user-playlists").append("<li class='motorbot-playlist-item' data-playlistId='" + item.id + "'>" + item.name + "</li>");
                });
                $("#motorbot-create-new-playlist").click(function(e){
                  $(this).css("display","none");
                  dropDownMenu.append("<input type='text' class='yt-uix-form-input-text title-input' style='width: 210px; margin: 15px;' title='Enter name of new playlist' id='motorbot-create-new-playlist-textfield'/><br/><button type='button' id='motorbot-create-new-playlist-button' class='yt-uix-button yt-uix-button-size-default yt-uix-button-primary create-button disabled' disabled style='float: right; margin-right: 15px;'><span class='yt-uix-button-content disabled'>Create</span></button>");
                  $("#motorbot-create-new-playlist-textfield").on("keyup", function(e){
                    if($(this).val().length > 1){
                      $("#motorbot-create-new-playlist-button").prop("disabled",false)
                    }
                    else{
                      $("#motorbot-create-new-playlist-button").prop("disabled",true)
                    }
                  });
                  $("#motorbot-create-new-playlist-button").click(function(e){
                    if(!$(this).prop("disabled")){
                      console.log("[Motorbot] Create new playlists named: "+$("#motorbot-create-new-playlist-textfield").val());
                      var videoId = getParameterByName("v", window.location.href);
                      chrome.storage.sync.get('userInfo', function (value) {
                        if (value.userInfo == null) {
                          $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(230, 33, 23, 1.00); vertical-align: middle;'>Authentication Error</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
                          console.error("[Motorbot] Error Occurred Sending Video to motorbot: You're not authenticated :(");
                        }
                        else {
                          $.ajax({
                            url: "https://mb.lolstat.net/api/addToNewPlaylistFromSource/ytb/" + videoId + "/" + encodeURIComponent($("#motorbot-create-new-playlist-textfield").val()) + "/" + value.userInfo.id,
                            dataType: "json",
                            success: function(data){
                              if (data.added) {
                                $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity", "1").html("<span class=\"yt-uix-button-content\" style='color: rgba(46, 177, 111, 1.00); vertical-align: middle;'>Added</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('" + chrome.extension.getURL("icon_20x20.png") + "'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
                              }
                              $("#motorbotDropDown").css("display", "none");
                            },
                            error: function(err){
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
                          url: "https://mb.lolstat.net/api/addToPlaylistFromSource/ytb/" + videoId + "/" + playlistId + "/" + value.userInfo.id,
                          type: "GET",
                          dataType: "json",
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
      /*
       $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity","1").html("<div class='loader'></div> <style type='text/css'> .motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('"+chrome.extension.getURL("icon_20x20.png")+"'); background-size: cover; height: 20px; width: 20px; margin-left: 6px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>")
       var videoId = getParameterByName("v", window.location.href);
       if(videoId != "" && videoId != null && videoId != 'undefined'){
       chrome.storage.sync.get('userInfo', function(value) {
       if(value.userInfo == null){
       $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity","1").html("<span class=\"yt-uix-button-content\" style='color: rgba(230, 33, 23, 1.00); vertical-align: middle;'>Authentication Error</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('"+chrome.extension.getURL("icon_20x20.png")+"'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
       console.error("Error Occured Sending Video to motorbot: You're not authenticated :(");
       }
       else{
       $.ajax({
       url: "https://mb.lolstat.net/api/playlist/"+videoId+"?userId="+value.userInfo.id,
       type: "GET",
       dataType: "json",
       success: function(data){
       if(data.added){
       $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity","1").html("<span class=\"yt-uix-button-content\" style='color: rgba(46, 177, 111, 1.00); vertical-align: middle;'>Added</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('"+chrome.extension.getURL("icon_20x20.png")+"'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
       }
       },
       error: function(err){
       $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity","1").html("<span class=\"yt-uix-button-content\" style='color: rgba(230, 33, 23, 1.00); vertical-align: middle;'>Error</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('"+chrome.extension.getURL("icon_20x20.png")+"'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
       console.error("Error Occured Sending Video to motorbot: "+err);
       }
       });
       }
       });
       }*/
    });
  }
}

var target = document.getElementsByTagName("body")[0];
var observer = new MutationObserver(function( mutations ) {
   mutations.forEach(function( mutation ) {
     var motorbotButton = document.getElementById('action-panel-overflow-button-motorbot');
     if(motorbotButton == null){
        addExtraButton();
     }
   });
});
observer.observe(target, {attributes: false,childList: true,characterData: false});

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
