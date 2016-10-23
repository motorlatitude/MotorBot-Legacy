$(document).ready(function(){
  /*chrome.storage.sync.clear(function() {
    var error = chrome.runtime.lastError;
      if (error) {
          console.error(error);
      }
  });*/
  chrome.storage.sync.get('userInfo', function(value) {
    if(value.userInfo == null){
      console.log("Gotta Authenticate M8");
    }
    else{
      $(".frame").css("display","none");
      $(".successFrame").css("display","block");
      $(".successFrame .title .titleText").html(value.userInfo.username+"<br><span>#"+value.userInfo.discriminator+"</span>");
      $(".successFrame .title .icon .iconImg").css("background","url('https://discordapp.com/api/users/"+value.userInfo.id+"/avatars/"+value.userInfo.avatar+".jpg') no-repeat center").css("background-size","120%");
    }
  });
  $("#signInButton").click(function(){
    chrome.extension.sendRequest({type:'authorize'},function(response) {
      console.log(response);
    });
  });
});
