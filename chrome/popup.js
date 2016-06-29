var classNameInterval;
function addExtraButton(){
  clearInterval(classNameInterval);
  var element =  document.getElementById('watch8-secondary-actions');
  if (typeof(element) != 'undefined' && element != null){
    var newMenuItem = document.createElement('div');
    newMenuItem.className = "yt-uix-menu";
    var newButton = document.createElement('button');
    newButton.title = "MotorBot Playlist";
    newButton.id = "action-panel-overflow-button-motorbot";
    newButton.className = "yt-uix-button yt-uix-button-size-default yt-uix-button-opacity pause-resume-autoplay yt-uix-menu-trigger yt-uix-tooltip motorbot";
    newButton.type = "button";
    newButton.innerHTML = "<span class=\"yt-uix-button-content\">MotorBot</span> <style type='text/css'>.motorbot{opacity: 0.5; cursor: pointer; font-family: Roboto,arial,sans-serif; font-size: 11px; font-style: normal; font-weight: 500;} .motorbot:before{content:''; background-image:url('"+chrome.extension.getURL("icon.png")+"'); background-size: cover; height: 20px; width: 20px; margin-right: 6px; display: inline-block; vertical-align: middle;}</style>";
    newMenuItem.appendChild(newButton);
    document.getElementById('watch8-secondary-actions').appendChild(newMenuItem);
    document.getElementById('action-panel-overflow-button-motorbot').addEventListener('click', function(evt){
      console.log("Motorbot Button Clicked");
      var videoId = getParameterByName("v", window.location.href);
      if(videoId != "" && videoId != null && videoId != 'undefined'){
        console.log("We got the videoId: "+videoId);
        xhttp = new XMLHttpRequest();
        xhttp.open("GET", "https://mb.lolstat.net/api/playlist/"+videoId, true);
        console.log("Sending to API");
        xhttp.onreadystatechange = function(){
          if (xhttp.readyState == 4) {
              console.log(xhttp.responseText);
          }
        };
        xhttp.send();
      }
    });
  }
}
addExtraButton();
window.addEventListener('click',function(){
  console.log("Window Click");
  clearInterval(classNameInterval);
  classNameInterval = setInterval(function(){
    var motorbotButton = document.getElementById('action-panel-overflow-button-motorbot');
    if(motorbotButton == null){
      var element =  document.getElementById('watch8-secondary-actions');
      if (typeof(element) != 'undefined' && element != null){
        addExtraButton();
      }
    }
  },500);
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
