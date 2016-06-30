var newMenuItem = document.createElement('div');
newMenuItem.className = "yt-uix-menu";
var newButton = document.createElement('button');
newButton.title = "MotorBot";
newButton.id = "action-panel-overflow-button-motorbot";
newButton.className = "yt-uix-button yt-uix-button-size-default yt-uix-button-has-icon yt-uix-button-opacity pause-resume-autoplay yt-uix-menu-trigger yt-uix-tooltip motorbot";
newButton.type = "button";
newButton.innerHTML = "<span class=\"yt-uix-button-content\" style='vertical-align: middle;'>MotorBot</span> <style type='text/css'>.motorbot{opacity: 0.5; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; background-image:url('"+chrome.extension.getURL("icon_20x20.png")+"'); background-size: cover; height: 20px; width: 20px; margin-left: 6px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>";
newMenuItem.appendChild(newButton);

function addExtraButton(){
  var element =  document.getElementById('watch8-secondary-actions');
  if (typeof(element) != 'undefined' && element != null){
    document.getElementById('watch8-secondary-actions').appendChild(newMenuItem);
    document.getElementById('action-panel-overflow-button-motorbot').addEventListener('click', function(evt){
      $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity","1").html("<span class=\"yt-uix-button-content\" style='color: rgba(22, 122, 198, 1.00); vertical-align: middle;'>Loading</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('"+chrome.extension.getURL("icon_20x20.png")+"'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>")
      var videoId = getParameterByName("v", window.location.href);
      if(videoId != "" && videoId != null && videoId != 'undefined'){
        console.log("We got the videoId: "+videoId);
        xhttp = new XMLHttpRequest();
        xhttp.open("GET", "https://mb.lolstat.net/api/playlist/"+videoId, true);
        console.log("Sending to API");
        xhttp.onreadystatechange = function(){
          if (xhttp.readyState == 4) {
              $("#action-panel-overflow-button-motorbot").attr("disabled", "true").css("opacity","1").html("<span class=\"yt-uix-button-content\" style='color: rgba(113, 198, 142, 1.00); vertical-align: middle;'>Added</span> <style type='text/css'>.motorbot{opacity: 1; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; opacity: 0.5; background-image:url('"+chrome.extension.getURL("icon_20x20.png")+"'); background-size: cover; height: 20px; width: 20px; margin-left: 4px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>");
          }
        };
        xhttp.send();
      }
    });
  }
}
var target = document.getElementById("movie_player");
var observer = new MutationObserver(function( mutations ) {
   mutations.forEach(function( mutation ) {
     var motorbotButton = document.getElementById('action-panel-overflow-button-motorbot');
     if(motorbotButton == null){
       var element =  document.getElementById('watch8-secondary-actions');
       if (typeof(element) != 'undefined' && element != null){
         addExtraButton();
       }
     }
   });
});

// Configuration of the observer:
var config = {
attributes: false,
childList: true,
characterData: false
};
// Pass in the target node, as well as the observer options
observer.observe(target, config);

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
