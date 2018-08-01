define(["constants"], function(c){
   serverSelection = {
       setChannel: function(channel){
           var elChannelSelector = document.getElementById("selectedChannel");
           console.log("Switching Channel: "+channel);
           if(channel){
               c.currentChannel = channel;
               elChannelSelector.innerHTML = channel;
               elChannelSelector.className = "selected green";
           }
           else{
               c.currentChannel = undefined;
               elChannelSelector.innerHTML = "Disconnected";
               elChannelSelector.className = "selected yellow";
           }
       },
       setGuilds: function(guilds){
           elGuildSelector = document.getElementById("serverOptions");
           for(var i=0;i<guilds.length;i++){
               var elguild_item = document.createElement("li");
               elguild_item.innerHTML = guilds[i];
               elGuildSelector.appendChild(elguild_item);
           }
       },
       setChannels: function(channels){

       }
   };
   return serverSelection
});