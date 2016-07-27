var accessToken = null;

var tokenFetcher = (function() {
  var clientId = '169554794376200192';
  var clientSecret = '5XyBGU-YtwVTMOQHKpbxUvmnYF4tx-At';
  var redirectUri = 'https://' + chrome.runtime.id +
                    '.chromiumapp.org/provider_cb';
  var redirectRe = new RegExp(redirectUri + '[#\?](.*)');
  access_token = null

  return {
    getToken: function(interactive, callback) {
      // In case we already have an access_token cached, simply return it.
      if (access_token) {
        callback(null, access_token);
        return;
      }

      var options = {
        'interactive': interactive,
        // url:'https://graph.facebook.com/oauth/access_token?client_id=' + clientId +
        url:'https://discordapp.com/api/oauth2/authorize?client_id=' + clientId +
            '&response_type=token' +
            '&scope=identify%20email%20guilds' +
            '&redirect_uri=' + encodeURIComponent(redirectUri)
      }
      chrome.identity.launchWebAuthFlow(options, function(redirectUri) {
        if (chrome.runtime.lastError) {
          callback(new Error(chrome.runtime.lastError));
          return;
        }
        // Upon success the response is appended to redirectUri, e.g.
        // https://{app_id}.chromiumapp.org/provider_cb#access_token={value}
        //     &refresh_token={value}
        // or:
        // https://{app_id}.chromiumapp.org/provider_cb#code={value}
        var matches = redirectUri.match(redirectRe);
        if (matches && matches.length > 1)
          handleProviderResponse(parseRedirectFragment(matches[1]));
        else
          callback(new Error('Invalid redirect URI'));
      });

      function parseRedirectFragment(fragment) {
        var pairs = fragment.split(/&/);
        var values = {};

        pairs.forEach(function(pair) {
          var nameval = pair.split(/=/);
          values[nameval[0]] = nameval[1];
        });

        return values;
      }

      function handleProviderResponse(values) {
        if (values.hasOwnProperty('access_token'))
          setAccessToken(values.access_token);
        else if (values.hasOwnProperty('code'))
          exchangeCodeForToken(values.code);
        else callback(new Error('Neither access_token nor code avialable.'));
      }

      function exchangeCodeForToken(code) {
        var xhr = new XMLHttpRequest();
        xhr.open('GET',
                 // 'https://www.facebook.com/dialog/oauth?'+
                 'https://discordapp.com/api/oauth2/token?' +
                 'client_id=' + clientId +
                 '&client_secret=' + clientSecret +
                 '&redirect_uri=' + redirectUri +
                 '&code=' + code);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        xhr.setRequestHeader('Accept', 'application/json');
        xhr.onload = function () {
          if (this.status === 200) {
            var response = JSON.parse('"'+this.responseText+'"');
            response = response.substring(0,response.indexOf('&'));
            setAccessToken(response);
            access_token = response;
          }
        };
        xhr.send();
      }

      function setAccessToken(token) {
        access_token = token;
        callback(null, access_token);
      }
    },

    removeCachedToken: function(token_to_remove) {
      if (access_token == token_to_remove)
        access_token = null;
    }
  }
})();

var userInfo = {};

function requestComplete(){
  if(this.status == 200){
    console.log(this.response);
    var username = JSON.parse(this.response).username;
    var userId = JSON.parse(this.response).id;
    var discriminator = JSON.parse(this.response).discriminator;
    var avatar = JSON.parse(this.response).avatar;
    userInfo.username = username;
    userInfo.id = userId;
    userInfo.discriminator = discriminator;
    userInfo.avatar = avatar;
    var xhr = new XMLHttpRequest();
    xhr.open('GET', 'https://discordapp.com/api/users/@me/guilds');
    xhr.setRequestHeader('Authorization', 'Bearer ' + accessToken);
    xhr.onload = guildRequestComplete;
    xhr.send();
  }
  else{
    console.error("Error Occured Getting User Data");
  }
}

function guildRequestComplete(){
  if(this.status == 200){
    userInfo.guilds = JSON.parse(this.response);
    userInfo.worthy = false;
    for(var i=0;i<userInfo.guilds.length;i++){
      if(userInfo.guilds[i].id == "130734377066954752"){
        userInfo.worthy = true;
      }
    }
    chrome.storage.sync.set({'userInfo': userInfo}, function() {
      console.log("Saved userInfo values");
    });
    console.log(userInfo);
  }
  else{
    console.error("Error Occured Getting User Guild Data");
  }
}


chrome.extension.onRequest.addListener(function(message,sender,sendResponse) {
  if (message.type == 'authorize') {
    console.log(chrome.runtime.id);
    console.log("Message From Popup");
    tokenFetcher.getToken(true, function(error, access_token) {
      if (error) {
        console.error(error);
      } else {
        console.log(access_token);
        accessToken = access_token;
        var xhr = new XMLHttpRequest();
        xhr.open('GET', 'https://discordapp.com/api/users/@me');
        xhr.setRequestHeader('Authorization', 'Bearer ' + accessToken);
        xhr.onload = requestComplete;
        xhr.send();
      }
      return true;
    });
    return true;
  }
  else if(message.type == "authorizeCheck"){
    //check if we're still authorized

  }
  return true;
});
