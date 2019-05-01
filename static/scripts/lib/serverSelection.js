define(["constants", "ws"], function(c, ws){
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
       setGuilds: function(guilds, ws){
           elGuildSelector = document.getElementById("serverOptions");
           for(var i=0;i<guilds.length;i++){
               var elguild_item = document.createElement("li");
               elguild_item.innerHTML = guilds[i].name;
               elguild_item.setAttribute("data-guildID",guilds[i].id)
               elguild_item.onclick = function(e){
                   serverSelection.connectToGuild(this.getAttribute("data-guildID"), this.innerHTML, ws)
               }
               elGuildSelector.appendChild(elguild_item);
           }
       },
       connectToGuild: function(guild_id, guild_name, ws){
           c.currentGuild = guild_id
           let elServerSelector = document.getElementById("selectedServer");
           elServerSelector.innerHTML = guild_name;
           ws.send(JSON.stringify({
               op: c.op["GUILD"],
               type: "GUILD",
               d: {
                   id: guild_id,
                   session: c.websocketSession
               }
           }));
       },
       setChannels: function(channels){

       }
   };
   return serverSelection
});