define(["constants", "requester","notification","playerbar"], function(c, req, Notification, pb){
    let audioPlayerMethods = {
        init: function(){

        },
        play: function(){
            pb.loading.start();
            req.get(c.base_url+"/music/play?api_key="+c.api_key, {dataType: "json", authorize: true}).then(function(response){
                pb.loading.end();
            }).catch(function(error){
                console.warn(error);
            });
        },
        pause: function(){
            req.get(c.base_url+"/music/pause?api_key="+c.api_key, {dataType: "json", authorize: true}).then(function(response){

            }).catch(function(error){
                console.warn(error);
            });
        },
        stop: function(){
            req.get(c.base_url+"/music/stop?api_key="+c.api_key, {dataType: "json", authorize: true}).then(function(response){

            }).catch(function(error){
                console.warn(error);
            });
        },
        resume: function(){
            audioPlayerMethods.play();
        },
        skip: function(){
            pb.loading.start();
            req.get(c.base_url+"/music/skip?api_key="+c.api_key, {dataType: "json", authorize: true}).then(function(response){
                pb.loading.end();
            }).catch(function(error){
                console.warn(error);
            });
        },
        back: function(){
            pb.loading.start();
            req.get(c.base_url+"/music/prev?api_key="+c.api_key, {dataType: "json", authorize: true}).then(function(response){
                pb.loading.end();
            }).catch(function(error){
                console.warn(error);
            });
        },
        playSongsFromPlaylist: function(SongIds, PlaylistId, Offset){
            if(c.currentChannel) {
                pb.loading.start();
                let PlayData = {
                    ids: SongIds,
                    playlist_id: PlaylistId,
                    offset: Offset || 0,
                    guild: c.currentGuild
                }
                req.put(c.base_url+'/music/play/song?api_key=' + c.api_key,{dataType: 'json', authorize: true, data: PlayData, headers: {"Content-Type": "application/json;charset=UTF-8"}}).then(function (response) {
                    if (response.error) {
                        console.error(response.error);
                        pb.loading.end();
                    }
                    else {
                        if(!response.error){
                            pb.loading.end();
                        }
                        else{
                            pb.loading.end();
                            Notification.create("warn","exclamation-triangle",response.error);
                        }
                    }
                }).catch(function (e) {
                    pb.loading.end();
                    console.log(e);
                });
            }
            else{
                console.warn("MotorBot needs to be in a voice channel to play a song :(");
                Notification.create("warn","phone","Motorbot needs to join a voice channel first");
            }
        },
        playSongFromPlaylist: function(songId, playlistId){
            if(c.currentChannel) {
                pb.loading.start();
                req.get(c.base_url+'/music/play/song?id=' + songId + '&playlist_id=' + playlistId + '&guild_id=' + c.currentGuild + '&sort=' + c.playlistSort + '&sort_dir=' + c.playlistSortDirection + '&api_key=' + c.api_key,{dataType: 'json', authorize: true}).then(function (response) {
                    if (response.error) {
                        console.error(response.error);
                        pb.loading.end();
                    }
                    else {
                        if(response.statusCode === 200){
                            pb.loading.end();
                        }
                        else{
                            pb.loading.end();
                            Notification.create("warn","exclamation-triangle",response.data.message);
                        }
                    }
                }).catch(function (e) {
                    pb.loading.end();
                    console.log(e);
                });
            }
            else{
                console.warn("MotorBot needs to be in a voice channel to play a song :(");
                Notification.create("warn","phone","Motorbot needs to join a voice channel first");
            }
        }
    };
    return audioPlayerMethods
});