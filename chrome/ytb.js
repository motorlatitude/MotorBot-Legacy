function addExtraButton(){
  var element =  document.getElementById('watch8-secondary-actions');
  var searchElement = document.getElementById('results');
  if (typeof(element) != 'undefined' && element != null){
    var newMenuItem = document.createElement('div');
    newMenuItem.className = "yt-uix-menu";
    var newButton = document.createElement('button');
    newButton.title = "Add to MotorBot";
    newButton.id = "action-panel-overflow-button-motorbot";
    newButton.className = "yt-uix-button yt-uix-button-size-default yt-uix-button-has-icon yt-uix-button-opacity pause-resume-autoplay yt-uix-menu-trigger yt-uix-tooltip motorbot";
    newButton.type = "button";
    newButton.innerHTML = "<span class=\"yt-uix-button-content\" style='vertical-align: middle;'>MotorBot</span> <style type='text/css'>.motorbot{opacity: 0.5; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; background-image:url('"+chrome.extension.getURL("icon_20x20.png")+"'); background-size: cover; height: 20px; width: 20px; margin-left: 6px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>";
    newMenuItem.appendChild(newButton);
    document.getElementById('watch8-secondary-actions').appendChild(newMenuItem);
    document.getElementById('action-panel-overflow-button-motorbot').addEventListener('click', function(evt){
      $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity","1").html("<div class='loader'></div> <style type='text/css'>.loader{width: 11px; height: 11px; border: 2px solid transparent; border-top-color: rgba(22, 122, 198, 1.00); border-left-color: rgba(22, 122, 198, 1.00); border-radius: 50%; box-sizing: border-box; display: inline-block; margin-left: 8px; vertical-align: middle; animation: spinner 0.5s infinite linear} @keyframes spinner{0%{transform: rotate(0deg)} 100%{transform: rotate(360deg);}} .motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('"+chrome.extension.getURL("icon_20x20.png")+"'); background-size: cover; height: 20px; width: 20px; margin-left: 6px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>")
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
      }
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
