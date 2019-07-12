define(["constants", "playerbar", "serverSelection","notification","audioPlayer","simpleBar"], function(c, pb, ss, Notification, AudioPlayer, SimpleBar){
    let wsConstants = {};
    let speaking_users = {};
    let users = {};
    return function(ws, wsCon, event) {
        let data = JSON.parse(event.data);
        let packet = data.d;
        if (data.type) {
            switch (data.type) {
                case "HEARTBEAT_ACK":
                    break;
                case "WELCOME":
                    console.info("Welcome Package Received");
                    wsConstants = packet;
                    console.log(packet);
                    console.log(event);
                    let guilds = packet.guilds;
                    c.websocketSession = packet.session;
                    if(guilds){
                        let guild_names = [];
                        let i = 0;
                        for(let guild_id in guilds) {
                            let guild = guilds[guild_id];
                            if (guild.members) {
                                for (let i = 0; i < guild.members.length; i++) {
                                    let id = guild.members[i].user.id;
                                    users[id] = guild.members[i].user;
                                }
                            }
                            if(guild.name){
                                guild_names.push({name: guild.name, id: guild.id, icon: guild.icon, connected_voice_channel: guild.connected_voice_channel})
                            }
                            if(i === 0){
                                console.log("Connecting to Guild: "+guild_id)
                                ss.connectToGuild(guild_id, guild.name, ws);
                            }
                            i++;
                        }
                        ss.setGuilds(guild_names, ws);
                    }
                    break;
                case "GUILD_STATE":
                    console.info("GUILD_STATE Package Received");
                    wsConstants = packet;
                    console.log(packet);
                    let playing = packet.playing;
                    let channel = packet.channel;
                    if(playing){
                        pb.updateArtwork(playing.artwork);
                        pb.updateDetails(playing.title, playing.artist, playing.album);
                        pb.updateSeek((parseFloat(playing.position) / 1000), playing.duration);
                        let elPlayButton = document.getElementById("playStop");
                        let playlist = document.getElementById("playlist");
                        let back = document.getElementById("playerBack");
                        let skip = document.getElementById("playerSkip");
                        if(playing.currently_playing) {
                            elPlayButton.innerHTML = "<i class=\"fa fa-pause\" aria-hidden=\"true\" style=\"cursor: pointer;\"></i>";
                            elPlayButton.onclick = function(){
                                AudioPlayer.pause();
                            };
                            if(playing.player_state.previous_tracks[0]){
                                back.classList.remove("disabled");
                                back.onclick = function(e){
                                    AudioPlayer.back()
                                };
                            }
                            else{
                                back.classList.add("disabled");
                                back.onclick = undefined;
                            }
                            if(playing.player_state.next_tracks[0]){
                                skip.classList.remove("disabled");
                                skip.onclick = function(e){
                                    AudioPlayer.skip()
                                };
                            }
                            else{
                                skip.classList.add("disabled");
                                skip.onclick = undefined;
                            }
                        }
                        else{//paused
                            elPlayButton.innerHTML = "<i class=\"fa fa-play\" aria-hidden=\"true\" style=\"cursor: pointer;\"></i>";
                            elPlayButton.onclick = function(){
                                AudioPlayer.resume();
                            };
                            back.classList.add("disabled");
                            back.onclick = undefined;
                            skip.classList.add("disabled");
                            skip.onclick = undefined;
                            clearInterval(c.seekInterval);
                        }
                    }
                    ss.setEnviromentSelection(packet.guild, packet.channel, ws)
                    wsCon.send("GET_TRACK_WAVEFORM",{})
                    break;
                case "SPOTIFY_IMPORT":
                    if(packet.event_type) {
                        let elPlaylistimportprogress = document.getElementById("playlistimportprogress");
                        let elPlaylistimportprogressMessage = document.getElementById("playlistimportprogressMessage");
                        let elPlaylistimportprogressProgress = document.getElementById("playlistimportprogressProgress");
                        let elPlaylistSelection = document.getElementById("playlistSelection");
                        let elPlaylistSelectioButton = document.getElementById("playlistSelectioButton");
                        if(elPlaylistimportprogressProgress && elPlaylistimportprogressMessage && elPlaylistimportprogress) {
                            if(elPlaylistimportprogress.classList.contains("hide")){
                                elPlaylistSelectioButton.classList.add("hide");
                                elPlaylistSelection.classList.add("hide");
                                elPlaylistimportprogress.classList.remove("hide");
                            }
                            switch (packet.event_type) {
                                case "START":
                                    elPlaylistimportprogressProgress.style.width = 0;
                                    elPlaylistimportprogressMessage.innerHTML = packet.event_data.message;
                                    break;
                                case "UPDATE":
                                    elPlaylistimportprogressProgress.style.width = (packet.event_data.progress * 276) + "px";
                                    elPlaylistimportprogressMessage.innerHTML = packet.event_data.message;
                                    break;
                                case "END":
                                    elPlaylistimportprogressProgress.style.width = (276) + "px";
                                    elPlaylistimportprogressMessage.innerHTML = packet.event_data.message;
                                    setTimeout(function () {
                                        elPlaylistSelectioButton.classList.remove("hide");
                                        elPlaylistSelection.classList.remove("hide");
                                        if (elPlaylistimportprogress) {
                                            elPlaylistimportprogress.classList.add("hide");
                                        }
                                        let u = require("user");
                                        u.loadPlaylists(0, 50, function(){
                                            console.log("loaded Playlists");
                                        });
                                    },1500);
                                    break;
                            }
                        }
                    }
                    break;
                case "TRACK_UPDATE":
                    if(packet.event_type){
                        switch(packet.event_type){
                            case "CHANGE":
                                // a song change event occurred
                                // - occurs when a new song gets played or the next song gets played
                                pb.updateArtwork(packet.event_data.artwork);
                                pb.updateDetails(packet.event_data.title, packet.event_data.artist, packet.event_data.album);
                                pb.updateSeek(0, packet.event_data.duration);
                                wsCon.send("SET_TRACK_WAVEFORM",{
                                    waveform_packet_size: 1920 * 2 * ((packet.event_data.duration*packet.event_data.duration / 40000) * 10)
                                })
                                if(document.getElementById("currentSong_artwork")){
                                    document.getElementById("currentSong_artwork").style.backgroundImage = "url('"+packet.event_data.artwork+"')";
                                    document.getElementById("currentSong_artwork").style.backgroundSize = "cover";
                                    document.getElementById("currentSong_artwork").style.backgroundRepeat = "no-repeat";
                                    document.getElementById("currentSong_bgartwork").style.backgroundImage = "url('"+packet.event_data.artwork+"')";
                                    document.getElementById("currentSong_bgartwork").style.backgroundSize = "cover";
                                    document.getElementById("currentSong_bgartwork").style.backgroundRepeat = "no-repeat";
                                    document.getElementById("currentSong_title").innerHTML = packet.event_data.title || "";
                                    document.getElementById("currentSong_artist").innerHTML = packet.event_data.artist.name || "";
                                }
                                break;
                        }
                    }
                    break;
                case "TRACK_DOWNLOAD":
                    if(packet.event_type){
                        switch(packet.event_type){
                            case "UPDATE":
                                // a song change event occurred
                                // - occurs when a new song gets played or the next song gets played
                                c.downloadDuration = packet.event_data.download_position;
                                pb.updateDownloadSeek(packet.event_data.download_position,c.duration);
                                break;
                        }
                    }
                    break;
                case "TRACK_WAVEFORM":
                    document.querySelector(".waveform-container").style.width = ((packet.event_data.seconds / c.duration)*(window.innerWidth - 660)) + "px";
                    document.getElementById("waveform-mask").innerHTML = packet.event_data.waveform.map((bucket, i) => {
                        let bucketSVGWidth = (500.0 / packet.event_data.waveform.length);
                        let bucketSVGHeight = bucket * 100.0;
                        let x = bucketSVGWidth * i;
                        let y = (100 - bucketSVGHeight) / 2;
                        return "<rect x='"+x+"' y='"+y+"' width='"+(bucketSVGWidth*0.5)+"' height='"+bucketSVGHeight+"' />";
                    }).join("");
                    break;
                case "PLAYER_UPDATE":
                    if(packet.event_type){
                        let elPlayButton = document.getElementById("playStop");
                        let playlist = document.getElementById("playlist");
                        let back = document.getElementById("playerBack");
                        let skip = document.getElementById("playerSkip");
                        let queueList = document.getElementById("nextSongsList");
                        switch(packet.event_type){
                            case "STOP":
                                elPlayButton.innerHTML = "<i class=\"fa fa-play\" aria-hidden=\"true\" style=\"cursor: pointer;\"></i>";
                                elPlayButton.onclick = function(){
                                    AudioPlayer.play();
                                };
                                back.classList.add("disabled");
                                back.onclick = undefined;
                                skip.classList.add("disabled");
                                skip.onclick = undefined;
                                if(queueList){
                                    queueList.innerHTML = "";
                                }
                                clearInterval(c.seekInterval);
                                if(playlist){
                                    let elPlaylistPlayButton = document.getElementById("playplaylist");
                                    elPlaylistPlayButton.innerHTML = "<i class=\"fa fa-play\" aria-hidden=\"true\"></i> &nbsp; &nbsp;PLAY";
                                    elPlaylistPlayButton.onclick = function(e){
                                        let SongIds = [];
                                        let Offset = 0;
                                        document.querySelectorAll("#playlist li").forEach(function (element, index){
                                            if(element.getAttribute("data-songid")){
                                                SongIds.push(element.getAttribute("data-songid"))
                                            }
                                        })
                                        AudioPlayer.playSongsFromPlaylist(SongIds, playlist.getAttribute("data-playlistid"), Offset);
                                    };
                                    let elPlayingSongRow = document.querySelector("#playlist li.playing");
                                    if(elPlayingSongRow){
                                        document.querySelector("#playlist li.playing").classList.remove("playing");
                                        let elPreviousSpeakerIcon = document.getElementById("SongSpeakerIcon");
                                        elPreviousSpeakerIcon.parentNode.removeChild(elPreviousSpeakerIcon);
                                    }
                                }
                                break;
                            case "PAUSE":
                                elPlayButton.innerHTML = "<i class=\"fa fa-play\" aria-hidden=\"true\" style=\"cursor: pointer;\"></i>";
                                elPlayButton.onclick = function(){
                                    AudioPlayer.resume();
                                };
                                if(packet.player_state){
                                    if(packet.player_state.previous_tracks[0]){
                                        back.classList.remove("disabled");
                                        back.onclick = function(e){
                                            AudioPlayer.back()
                                        };
                                    }
                                    else{
                                        back.classList.add("disabled");
                                        back.onclick = undefined;
                                    }
                                    if(packet.player_state.next_tracks[0]){
                                        skip.classList.remove("disabled");
                                        skip.onclick = function(e){
                                            AudioPlayer.skip()
                                        };
                                        if(queueList){
                                            queueList.innerHTML = "";
                                            for(i in packet.player_state.next_tracks){
                                                let track = packet.player_state.next_tracks[i];
                                                let formattedDuration = c.secondsToHms(track.duration);
                                                let explicit = "";
                                                if (track.explicit) {
                                                    explicit = "<div class='explicit'>E</div>";
                                                }
                                                let elPlaylistTrack = document.createElement("li");
                                                elPlaylistTrack.id = track.id;
                                                elPlaylistTrack.setAttribute("data-songid", track.id);
                                                elPlaylistTrack.innerHTML = "<div class='trackRow'>" +
                                                    "<div class='title' data-sortIndex='" + track.title.toUpperCase() + "'>" + track.title + " " + explicit + "</div>" +
                                                    "<div class='time'>" + formattedDuration + "</div>" +
                                                    "</div>";
                                                queueList.appendChild(elPlaylistTrack);
                                            }
                                        }
                                    }
                                    else{
                                        skip.classList.add("disabled");
                                        skip.onclick = undefined;
                                        if(queueList){
                                            queueList.innerHTML = "";
                                        }
                                    }
                                    pb.updateArtwork(packet.player_state.current_song.artwork);
                                    pb.updateDetails(packet.player_state.current_song.title, packet.player_state.current_song.artist, packet.player_state.current_song.album);
                                    pb.updateSeekBar((packet.player_state.seekPosition / 1000), packet.player_state.current_song.duration);
                                }
                                clearInterval(c.seekInterval);
                                if(playlist){
                                    let currentlyVisiblePlaylist = playlist.getAttribute("data-playlistid");
                                    if(packet.playlist_id === currentlyVisiblePlaylist){
                                        let elPlaylistPlayButton = document.getElementById("playplaylist");
                                        elPlaylistPlayButton.innerHTML = "<i class=\"fa fa-play\" aria-hidden=\"true\"></i> &nbsp; &nbsp;RESUME";
                                        elPlaylistPlayButton.onclick = function(e){
                                            AudioPlayer.resume();
                                        };
                                        let elSongRow = document.getElementById(packet.song_id);
                                        if(elSongRow){
                                            let elPlayingSongRow = document.querySelector("#playlist li.playing");
                                            if(elPlayingSongRow){
                                                document.querySelector("#playlist li.playing").classList.remove("playing");
                                                let elPreviousSpeakerIcon = document.getElementById("SongSpeakerIcon");
                                                if(elPreviousSpeakerIcon) {
                                                    elPreviousSpeakerIcon.parentNode.removeChild(elPreviousSpeakerIcon);
                                                }
                                            }
                                            elSongRow.classList.add("playing");
                                            let elSpeakerIcon = document.createElement("i");
                                            elSpeakerIcon.className = "fa fa-volume-up play";
                                            elSpeakerIcon.id = "SongSpeakerIcon";
                                            elSpeakerIcon.setAttribute("aria-hidden", "true");
                                            elSongRow.getElementsByClassName("trackRow")[0].getElementsByClassName("item")[0].appendChild(elSpeakerIcon);
                                        }
                                        else{
                                            console.warn("Couldn't find the song with id:"+packet.song_id+" in this playlist?");
                                        }
                                    }
                                }
                                else{
                                    let elPlaylistPlayButton = document.getElementById("playplaylist");
                                    if(elPlaylistPlayButton) {
                                        elPlaylistPlayButton.innerHTML = "<i class=\"fa fa-play\" aria-hidden=\"true\"></i> &nbsp; &nbsp;PLAY";
                                        elPlaylistPlayButton.onclick = function (e) {
                                            let SongIds = [];
                                            let Offset = 0;
                                            document.querySelectorAll("#playlist li").forEach(function (element, index) {
                                                if (element.getAttribute("data-songid")) {
                                                    SongIds.push(element.getAttribute("data-songid"))
                                                }
                                            })
                                            AudioPlayer.playSongsFromPlaylist(SongIds, packet.playlist_id, Offset);
                                        };
                                    }
                                }
                                break;
                            case "PLAY":
                                elPlayButton.innerHTML = "<i class=\"fa fa-pause\" aria-hidden=\"true\" style=\"cursor: pointer;\"></i>";
                                elPlayButton.onclick = function(){
                                    AudioPlayer.pause();
                                };
                                if(packet.player_state){
                                    console.log("We have a player_state update");
                                    console.log(packet.player_state.previous_tracks.length);
                                    if(packet.player_state.previous_tracks.length > 0){
                                        back.classList.remove("disabled");
                                        back.onclick = function(e){
                                            AudioPlayer.back()
                                        };
                                    }
                                    else{
                                        back.classList.add("disabled");
                                        back.onclick = undefined;
                                    }
                                    console.log(packet.player_state.next_tracks.length);
                                    if(packet.player_state.next_tracks.length > 0){
                                        skip.classList.remove("disabled");
                                        skip.onclick = function(e){
                                            AudioPlayer.skip()
                                        };
                                        if(queueList){
                                            queueList.innerHTML = "";
                                            for(i in packet.player_state.next_tracks){
                                                let track = packet.player_state.next_tracks[i];
                                                let formattedDuration = c.secondsToHms(track.duration);
                                                let explicit = "";
                                                if (track.explicit) {
                                                    explicit = "<div class='explicit'>E</div>";
                                                }
                                                let elPlaylistTrack = document.createElement("li");
                                                elPlaylistTrack.id = track.id;
                                                elPlaylistTrack.setAttribute("data-songid", track.id);
                                                elPlaylistTrack.innerHTML = "<div class='trackRow'>" +
                                                    "<div class='title' data-sortIndex='" + track.title.toUpperCase() + "'>" + track.title + " " + explicit + "</div>" +
                                                    "<div class='time'>" + formattedDuration + "</div>" +
                                                    "</div>";
                                                queueList.appendChild(elPlaylistTrack);
                                            }
                                        }
                                    }
                                    else{
                                        skip.classList.add("disabled");
                                        skip.onclick = undefined;
                                        if(queueList) {
                                            queueList.innerHTML = "";
                                        }
                                    }
                                    pb.updateArtwork(packet.player_state.current_song.artwork);
                                    pb.updateDetails(packet.player_state.current_song.title, packet.player_state.current_song.artist, packet.player_state.current_song.album);
                                }
                                pb.updateSeekFromPause();
                                if(playlist){
                                    let currentlyVisiblePlaylist = playlist.getAttribute("data-playlistid");
                                    if(packet.playlist_id === currentlyVisiblePlaylist){
                                        let elPlaylistPlayButton = document.getElementById("playplaylist");
                                        elPlaylistPlayButton.innerHTML = "<i class=\"fa fa-pause\" aria-hidden=\"true\"></i> &nbsp; &nbsp;PAUSE";
                                        elPlaylistPlayButton.onclick = function(e){
                                            AudioPlayer.pause();
                                        };
                                        let elSongRow = document.getElementById(packet.song_id);
                                        if(elSongRow){
                                            let elPlayingSongRow = document.querySelector("#playlist li.playing");
                                            if(elPlayingSongRow){
                                                document.querySelector("#playlist li.playing").classList.remove("playing");
                                                let elPreviousSpeakerIcon = document.getElementById("SongSpeakerIcon");
                                                if(elPreviousSpeakerIcon) {
                                                    elPreviousSpeakerIcon.parentNode.removeChild(elPreviousSpeakerIcon);
                                                }
                                            }
                                            elSongRow.classList.add("playing");
                                            let elSpeakerIcon = document.createElement("i");
                                            elSpeakerIcon.className = "fa fa-volume-up play";
                                            elSpeakerIcon.id = "SongSpeakerIcon";
                                            elSpeakerIcon.setAttribute("aria-hidden", "true");
                                            elSongRow.getElementsByClassName("trackRow")[0].getElementsByClassName("item")[0].appendChild(elSpeakerIcon);
                                        }
                                        else{
                                            console.warn("Couldn't find the song with id:"+packet.song_id+" in this playlist?");
                                        }
                                    }
                                    else{
                                        let elPlayingSongRow = document.querySelector("#playlist li.playing");
                                        if(elPlayingSongRow){
                                            document.querySelector("#playlist li.playing").classList.remove("playing");
                                            let elPreviousSpeakerIcon = document.getElementById("SongSpeakerIcon");
                                            if(elPreviousSpeakerIcon) {
                                                elPreviousSpeakerIcon.parentNode.removeChild(elPreviousSpeakerIcon);
                                            }
                                        }
                                        let elPlaylistPlayButton = document.getElementById("playplaylist");
                                        elPlaylistPlayButton.innerHTML = "<i class=\"fa fa-play\" aria-hidden=\"true\"></i> &nbsp; &nbsp;PLAY";
                                        elPlaylistPlayButton.onclick = function(e){
                                            let SongIds = [];
                                            let Offset = 0;
                                            document.querySelectorAll("#playlist li").forEach(function (element, index){
                                                if(element.getAttribute("data-songid")){
                                                    SongIds.push(element.getAttribute("data-songid"))
                                                }
                                            })
                                            AudioPlayer.playSongsFromPlaylist(SongIds, packet.playlist_id, Offset);
                                        };
                                    }
                                }
                                else{
                                    let elPlaylistPlayButton = document.getElementById("playplaylist");
                                    if(elPlaylistPlayButton) {
                                        elPlaylistPlayButton.innerHTML = "<i class=\"fa fa-play\" aria-hidden=\"true\"></i> &nbsp; &nbsp;PLAY";
                                        elPlaylistPlayButton.onclick = function (e) {
                                            let songId = playlist.childNodes[1].dataset.songid;
                                            let SongIds = [];
                                            let Offset = 0;
                                            document.querySelectorAll("#playlist li").forEach(function (element, index){
                                                SongIds.push(element.getAttribute("data-songid"))
                                            })
                                            AudioPlayer.playSongFromPlaylist(SongIds, packet.playlist_id, Offset);
                                        };
                                    }
                                }
                                break;
                        }
                    }
                    break;
                case "YOUTUBE_ERROR":
                    Notification.create("warn","wrench","Youtube Error<br/>"+packet.error);
                    break;
                case "VOICE_UPDATE":
                    console.log("VOICE_UPDATE");
                    if(data.d.status){
                        var elChannelSelector = document.getElementById("selectedChannel");
                        console.log(data.d.status);
                        switch(data.d.status){
                            case "JOIN":
                                console.info("MotorBot Has Joined a Voice Channel");
                                ss.setChannel(data.d.channel, data.d.guild_id);
                                break;
                            case "LEAVE":
                                console.info("MotorBot Has Left a Voice Channel");
                                ss.setChannel(data.d.channel, data.d.guild_id);
                                break;
                            default:
                                console.warn("WEBSOCKET_VOICE_UNKNOWN_STATUS");
                                c.currentChannel = undefined;
                                elChannelSelector.innerHTML = "Unknown";
                                elChannelSelector.className = "selected red";
                                break;
                        }
                    }
                    else{
                        console.warn("WEBSOCKET_VOICE_NO_STATUS");
                    }
                    break;
                case "VOICE_UPDATE_SPEAKING":
                    if(data.d.user_id){
                        var podcast_list = document.getElementById("podcast_list");
                        if(podcast_list != null){
                            var podcast_list_items = podcast_list.getElementsByTagName("li");
                            var user_previously_added = false;
                            for (var i = 0; i < podcast_list_items.length; i++) {
                                var podcast_list_item_user_id = podcast_list_items[i].getAttribute("data-userid");
                                if (data.d.user_id == podcast_list_item_user_id) {
                                    user_previously_added = true;
                                    if (data.d.speaking) {
                                        podcast_list_items[i].className = "speaking"
                                    }
                                    else {
                                        podcast_list_items[i].className = ""
                                    }
                                }
                            }
                            if(!user_previously_added){
                                console.log("Add a new user to the list");
                                var new_user = document.createElement("li");
                                if(users[data.d.user_id]) {
                                    var twitterHandle = "<i class=\"fab fa-twitter\"></i> &nbsp; ";
                                    if(data.d.user_id == "110745225688776704"){
                                        twitterHandle += "@adz_the_wookie"
                                    }
                                    else if(data.d.user_id == "95164972807487488"){
                                        twitterHandle += "@motorlatitude"
                                    }
                                    else if(data.d.user_id == "122072295689682944"){
                                        twitterHandle += "@KariTTV"
                                        twitterHandle += "&nbsp; &bull; &nbsp;<i class=\"fab fa-twitch\"></i> &nbsp; KariTTV"
                                    }
                                    else if(data.d.user_id == "122072558270021633"){
                                        twitterHandle += "@Cronus__"
                                    }
                                    else if(data.d.user_id == "122068247225827330"){
                                        twitterHandle += "@ProbableCos";
                                    }
                                    new_user.innerHTML = "<div class=\"podcast_user_icon\" style=\"background-image: url('https://cdn.discordapp.com/avatars/" + data.d.user_id + "/" + users[data.d.user_id].avatar + ".png?size=1024'); background-repeat: no-repeat; background-position: center; background-size: cover;\"></div><div class='podcast_username'>"+twitterHandle+"</div>";
                                }
                                new_user.setAttribute("data-userid",data.d.user_id);
                                if(data.d.speaking){
                                    new_user.className = "speaking";
                                }
                                podcast_list.appendChild(new_user);
                            }

                        }
                    }
                    break;
                default:
                    console.warn("WEBSOCKET_UNKNOWN_TYPE", data);
            }
        }
        else {
            console.error("WEBSOCKET_MISSING_TYPE", data);
        }
    }
});