define(["constants", "ws"], function(c, ws){
   serverSelection = {
       setChannel: function(channel, guild_id){
           let elSelectedGuild = document.getElementById("selectedGuild")
           if(elSelectedGuild.getAttribute("data-guildID") === guild_id){
               let elSelectedVoice = document.getElementById("selectedVoice")
               elSelectedVoice.classList.remove("disconnect")
               elSelectedVoice.classList.remove("connected")
               if(channel){
                   elSelectedVoice.innerHTML = channel
                   elSelectedVoice.classList.add("connected")
                   c.currentChannel = channel;
               }
               else{
                   c.currentChannel = undefined;
                   elSelectedVoice.innerHTML = "Not in a voice channel"
                   elSelectedVoice.classList.add("disconnect")
               }
           }
           let elChannelSelector = document.querySelector("#serverOptions li[data-guildID='"+guild_id+"'] .voice");
           console.log("Switching Channel: "+channel+" for guild: "+guild_id);
           if(elChannelSelector){
               elChannelSelector.classList.remove("connected");
               elChannelSelector.classList.remove("disconnect");
               if(channel){
                   elChannelSelector.innerHTML = channel;
                   elChannelSelector.classList.add("connected");
               }
               else{
                   elChannelSelector.innerHTML = "Not in a voice channel";
                   elChannelSelector.classList.add("disconnect");
               }
           }
           else{
               console.warn("A voice status event occurred that this user is not part of, possible security vulnerability")
           }

       },
       setEnviromentSelection: function(guild, channel_name, ws){
           let elSelectedGuildIcon = document.getElementById("selectedGuildIcon");
           elSelectedGuildIcon.setAttribute("style","background: url('https://cdn.discordapp.com/icons/"+guild.id+"/"+guild.icon+".png?size=256') no-repeat center; background-size: cover;")
           let elSelectedGuild = document.getElementById("selectedGuild")
           elSelectedGuild.setAttribute("data-guildID",guild.id)
           elSelectedGuild.innerHTML = guild.name
           let elSelectedVoice = document.getElementById("selectedVoice")
           elSelectedVoice.classList.remove("disconnect")
           elSelectedVoice.classList.remove("connected")
           if(channel_name){
               elSelectedVoice.innerHTML = channel_name
               elSelectedVoice.classList.add("connected")
               c.currentChannel = channel_name;
           }
           else{
               elSelectedVoice.innerHTML = "Not in a voice channel"
               elSelectedVoice.classList.add("disconnect")
               c.currentChannel = undefined;
           }
           let elChannels = document.querySelectorAll("#serverOptions li")
           if(elChannels){
               for(let k = 0; k < elChannels.length; k++){
                   let c = elChannels[k]
                   c.classList.remove("hidden");
               }
               let elChannel = document.querySelector("#serverOptions li[data-guildID='"+guild.id+"']");
               elChannel.classList.add("hidden");
           }
           ws.send(JSON.stringify({
               op: c.op["PLAYER_STATE"],
               type: "PLAYER_STATE",
               d: {
                   session: c.websocketSession
               }
           }));
       },
       setGuilds: function(guilds, ws){
           let elGuildSelector = document.getElementById("serverOptions");
           elGuildSelector.innerHTML = "";
           for(var i=0;i<guilds.length;i++){
               var elguild_item = document.createElement("li");
               let guild_icon = document.createElement("div")
               guild_icon.setAttribute("style","background: url('https://cdn.discordapp.com/icons/"+guilds[i].id+"/"+guilds[i].icon+".png?size=256') no-repeat center; background-size: cover;")
               guild_icon.classList.add("guild_icon")
               elguild_item.appendChild(guild_icon)
               let guild_name = document.createElement("div")
               guild_name.classList.add("guild")
               guild_name.innerHTML = guilds[i].name
               elguild_item.appendChild(guild_name)
               let guild_voice = document.createElement("div")
               if(guilds[i].connected_voice_channel){
                   guild_voice.classList.add("connected")
               }
                else{
                   guild_voice.classList.add("disconnect")
               }
               guild_voice.classList.add("voice")
               guild_voice.innerHTML = guilds[i].connected_voice_channel || "Not in a voice channel"
               elguild_item.appendChild(guild_voice)
               elguild_item.setAttribute("data-guildID",guilds[i].id)
               elguild_item.onclick = function(e){
                   serverSelection.connectToGuild(this.getAttribute("data-guildID"), this.innerHTML, ws)
               }
               elGuildSelector.appendChild(elguild_item);
           }
       },
       connectToGuild: function(guild_id, guild_name, ws){
           c.currentGuild = guild_id
           ws.send(JSON.stringify({
               op: c.op["GUILD"],
               type: "GUILD",
               d: {
                   id: guild_id,
                   session: c.websocketSession
               }
           }));
       }
   };
   return serverSelection
});