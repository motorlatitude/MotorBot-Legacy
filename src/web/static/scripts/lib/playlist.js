define(["constants","requester","audioPlayer","simpleBar","eventListener","views","user","ws"], function(c,req,AudioPlayer,SimpleBar,EventListener,v,u,ws){
    let totalPlaylistDuration = 0;
    let playlistObj = {
        init: function(){

        },
        load: function(playlist_id){
            totalPlaylistDuration = 0;
            playlistObj.playlistInformation(playlist_id);
        },
        edit: function(playlist_id, name, description, artwork){

        },
        remove: function (playlist_id) {
            req.delete(c.base_url+"/playlist/" + playlist_id + "?api_key="+c.api_key,{dataType: "json", authorize: true}).then(function(response){
                u.loadPlaylists(0,50, function(){
                    const v = require("views");
                    v.load("home","undefined", function(){
                        document.getElementsByClassName("flexContainer")[0].style.opacity = "1";
                    });
                });
            }).catch(function(error){
                console.warn(error);
            });
        },
        playlistInformation: function(playlist_id){
            req.get(c.base_url+"/playlist/"+playlist_id+"?api_key="+c.api_key,{dataType: "json", authorize: true}).then(function(response){
                let d = response.data;
                if(d.artwork){
                    const elHeaderBackground = document.querySelector(".header .bg");
                    const elHeaderArtwork = document.querySelector(".header .artwork");
                    elHeaderBackground.style.background = "url('"+d.artwork+"') no-repeat center";
                    elHeaderBackground.style.backgroundSize = "cover";
                    elHeaderArtwork.style.background = "url('"+d.artwork+"') no-repeat center";
                    elHeaderArtwork.style.backgroundSize = "cover";
                }
                playlistObj.appendTracks(playlist_id, d.tracks, 0, 100);
                document.getElementById("playlist").setAttribute("data-playlistcreator",d.creator);
                document.title = "MotorBot: "+d.name;
                document.querySelector(".playlistName").innerHTML = d.name;
                if(d.private === false) {
                    document.querySelector(".playlistType").innerHTML = "<i class=\"fas fa-globe-africa\" title='Public Playlist'></i> &nbsp; "+(d.type || "PLAYLIST");
                }
                else if(d.private === true){
                    document.querySelector(".playlistType").innerHTML = "<i class=\"fas fa-user-lock\" title='Private Playlist'></i> &nbsp; "+(d.type || "PLAYLIST");
                }
                document.querySelector(".playlistName").addEventListener("click", function(e){
                   //TODO: EDIT PLAYLIST
                });
                if(d.description && d.description !== ""){
                    document.querySelector(".playlistDescription").innerHTML = d.description;
                }
                else{
                    if(!window.navigator.standalone && !window.matchMedia('(display-mode: standalone)').matches && window.innerWidth >= 600) {
                        document.querySelector(".playlistType").style.top = "75px";
                        document.querySelector(".playlistName").style.top = "110px";
                        document.querySelector(".playlistName").style.fontSize = "45px";
                    }
                }
                document.querySelector(".playlistStats .user").innerHTML = d.owner.username+"#"+d.owner.discriminator;
                if((d.followers.length - 1) === 1) {
                    document.querySelector(".playlistStats .followCount").innerHTML = (d.followers.length - 1).toString();
                    document.querySelector(".playlistStats .numberOfFollowers .txt").innerHTML = "Follower";
                }
                else if((d.followers.length - 1) < 0) {
                    document.querySelector(".playlistStats .followCount").innerHTML = "0";
                }
                else{
                    document.querySelector(".playlistStats .followCount").innerHTML = (d.followers.length - 1).toString();
                }
                if(c.user_id === d.creator.toString()){
                    document.querySelector(".header .followPlaylistButton").style.display = "none";
                }
                document.getElementById("playplaylist").onclick = function(e){
                    if(document.getElementById("playlist").childNodes[1].dataset.songid) {
                        let SongIds = [];
                        let Offset = 0;
                        document.querySelectorAll("#playlist li").forEach(function (element, index){
                            if(element.getAttribute("data-songid")){
                                SongIds.push(element.getAttribute("data-songid"))
                            }
                        })
                        AudioPlayer.playSongsFromPlaylist(SongIds, playlist_id, Offset);
                    }
                };
                ws.send("PLAYER_STATE",{});
                document.querySelector(".songTotal").innerHTML = d.tracks.total.toString();
                document.getElementById("playlistMore").addEventListener("click",function(e){
                    let contextmenu = document.getElementById("contextMenu");
                    contextmenu.style.display = "none";
                    let CurX = (window.Event) ? e.pageX : e.clientX + (document.documentElement.scrollLeft ? document.documentElement.scrollLeft : document.body.scrollLeft);
                    let CurY = (window.Event) ? e.pageY : e.clientY + (document.documentElement.scrollTop ? document.documentElement.scrollTop : document.body.scrollTop);
                    contextmenu.innerHTML = "";
                    contextmenu.style.display = "block";
                    contextmenu.style.top = CurY + "px";
                    contextmenu.style.left = CurX + "px";
                    let elContextMenuList = document.createElement("ul");
                    let elContextMenuListItem_copy = document.createElement("li");
                    elContextMenuListItem_copy.innerHTML = "Copy Playlist Link";
                    elContextMenuList.appendChild(elContextMenuListItem_copy);
                    let elContextMenuListItem_copyID = document.createElement("li");
                    elContextMenuListItem_copyID.innerHTML = "Copy Playlist ID";
                    elContextMenuList.appendChild(elContextMenuListItem_copyID);
                    let elContextMenuListItem_sep = document.createElement("li");
                    elContextMenuListItem_sep.className = "sep";
                    elContextMenuList.appendChild(elContextMenuListItem_sep);
                    if(d.creator === c.user_id) {
                        if(d.private === false) {
                            let elContextMenuListItem_private = document.createElement("li");
                            elContextMenuListItem_private.innerHTML = "Make Private";
                            elContextMenuList.appendChild(elContextMenuListItem_private);
                        }
                        else if(d.private === true){
                            let elContextMenuListItem_public = document.createElement("li");
                            elContextMenuListItem_public.innerHTML = "Make Public";
                            elContextMenuList.appendChild(elContextMenuListItem_public);
                        }
                        let elContextMenuListItem_colab = document.createElement("li");
                        elContextMenuListItem_colab.innerHTML = "Make Collaborative";
                        elContextMenuList.appendChild(elContextMenuListItem_colab);
                        let elContextMenuListItem_sep = document.createElement("li");
                        elContextMenuListItem_sep.className = "sep";
                        elContextMenuList.appendChild(elContextMenuListItem_sep);
                        let elContextMenuListItem_edit = document.createElement("li");
                        elContextMenuListItem_edit.innerHTML = "Edit Playlist";
                        elContextMenuList.appendChild(elContextMenuListItem_edit);
                        let elContextMenuListItem_delete = document.createElement("li");
                        elContextMenuListItem_delete.innerHTML = "Delete";
                        elContextMenuListItem_delete.style.color = "rgba(242, 52, 51, 1.00)";
                        elContextMenuListItem_delete.onclick = function(){
                            playlistObj.remove(playlist_id);
                        };
                        elContextMenuList.appendChild(elContextMenuListItem_delete);
                    }
                    else{
                        let elContextMenuListItem_follow = document.createElement("li");
                        elContextMenuListItem_follow.innerHTML = "Follow / Unfollow";
                        elContextMenuList.appendChild(elContextMenuListItem_follow);
                    }
                    contextmenu.appendChild(elContextMenuList);
                });
                document.getElementById("ajax_contentView").style.display = "flex";
                document.getElementById("playlist_header").style.display = "block";
                document.getElementById("playlist").style.display = "block";
                document.getElementById("ajax_contentView").simplebar = new SimpleBar(document.getElementById("ajax_contentView"));
            }).catch(function(error){
                console.warn(error);
            });
        },
        getPlaylistTracks: function(playlist_id, offset, limit, cb){
            req.get(c.base_url+"/playlist/" + playlist_id + "/tracks?limit="+limit+"&offset="+offset+"&filter=next,prev,offset,limit,total,items(date_added,track(id,title,artwork,album.name,artist.name,duration,explicit))&api_key="+c.api_key, {dataType: "json", authorize: true}).then(function(response){
                let d = response.data;
                if(typeof cb === "function"){
                    cb(d);
                }
            }).catch(function(error){
                console.warn(error);
            });
        },
        sortTracks: function(){
            //setup sorting system
            let sortDirectionChevron = document.getElementById("sortDirectionChevron");
            if(sortDirectionChevron) {
                sortDirectionChevron.parentElement.removeChild(sortDirectionChevron);
            }
            let newSortDirectionChevron = document.createElement("span");
            newSortDirectionChevron.className = "sortDir";
            newSortDirectionChevron.id = "sortDirectionChevron";
            newSortDirectionChevron.setAttribute("data-sort",c.playlistSort);
            let playlistTracks = [].slice.call(document.querySelectorAll("#playlist li:not(.titleRow)"));
            let temporaryTracks = document.createDocumentFragment();
            if (c.playlistSortDirection === 1) {
                newSortDirectionChevron.innerHTML = "<i class=\"fa fa-chevron-down\" aria-hidden=\"true\"></i>";
                newSortDirectionChevron.setAttribute("data-sortdir","-1");
                document.getElementById(c.playlistSort+"_header").appendChild(newSortDirectionChevron);
                playlistTracks.sort(function asc_sort(a, b) {
                    let sortIndex_A = a.getElementsByClassName(c.playlistSort)[0].getAttribute("data-sortindex");
                    let sortIndex_B = b.getElementsByClassName(c.playlistSort)[0].getAttribute("data-sortindex");
                    let n = sortIndex_B - sortIndex_A;
                    if(n !== 0) {
                        return sortIndex_B < sortIndex_A ? 1 : -1;
                    }
                    return (b.getElementsByClassName("title")[0].getAttribute("data-sortindex")) < (a.getElementsByClassName("title")[0].getAttribute("data-sortindex")) ? 1 : -1;
                });
                for (let i = 0; i < playlistTracks.length; i++) {
                    temporaryTracks.appendChild(playlistTracks[i]);
                }
                let sortedPlaylistTracks = [].slice.call(temporaryTracks.querySelectorAll("li:not(.titleRow)"));
                for(let k = 0; k < sortedPlaylistTracks.length; k++){
                    let trackNumber = k + 1;
                    let item = sortedPlaylistTracks[k].getElementsByClassName("trackRow")[0].getElementsByClassName("item")[0];
                    item.setAttribute("data-trackno",trackNumber);
                    item.innerHTML = trackNumber.toString();
                }
            }
            else if (c.playlistSortDirection === -1) {
                newSortDirectionChevron.innerHTML = "<i class=\"fa fa-chevron-up\" aria-hidden=\"true\"></i>";
                newSortDirectionChevron.setAttribute("data-sortdir","1");
                document.getElementById(c.playlistSort+"_header").appendChild(newSortDirectionChevron);
                playlistTracks.sort(function desc_sort(a, b) {
                    let sortIndex_A = a.getElementsByClassName(c.playlistSort)[0].getAttribute("data-sortindex");
                    let sortIndex_B = b.getElementsByClassName(c.playlistSort)[0].getAttribute("data-sortindex");
                    let n = sortIndex_A - sortIndex_B;
                    if(n !== 0) {
                        return sortIndex_B > sortIndex_A ? 1 : -1;
                    }
                    return (b.getElementsByClassName("title")[0].getAttribute("data-sortindex")) > (a.getElementsByClassName("title")[0].getAttribute("data-sortindex")) ? 1 : -1;
                });
                for (let i = 0; i < playlistTracks.length; i++) {
                    temporaryTracks.appendChild(playlistTracks[i]);
                }
                let sortedPlaylistTracks = [].slice.call(temporaryTracks.querySelectorAll("li:not(.titleRow"));
                for(let k = 0; k < sortedPlaylistTracks.length; k++){
                    let trackNumber = k + 1;
                    let item = sortedPlaylistTracks[k].getElementsByClassName("trackRow")[0].getElementsByClassName("item")[0];
                    item.setAttribute("data-trackno",trackNumber);
                    item.innerHTML = trackNumber.toString();
                }
            }
            document.getElementById("playlist").appendChild(temporaryTracks);
        },
        appendTracks: function(playlist_id, tracks, offset, limit){
            if(offset === 0){
                document.getElementById("ajax_contentView").style.opacity = "1";
                document.getElementById("ajax_loader").style.display = "none";
            }
            if(tracks.items){
                for(let i in tracks.items){
                    let data = tracks.items[i];
                    if(data.track && data.track.id){
                        let trackNo = parseInt(i) + 1 + parseInt(offset);
                        totalPlaylistDuration += data.track.duration;
                        let formattedDuration = c.secondsToHms(data.track.duration);
                        let added = "";
                        if (data.date_added >= (new Date().getTime() - 604800000)) {
                            added = c.millisecondsToStr(data.date_added);
                        }
                        else {
                            const a = new Date(data.date_added);
                            added = (a.getDate() < 10 ? "0" + (a.getDate()) : a.getDate()) + " - " + (a.getMonth() + 1 < 10 ? "0" + (a.getMonth() + 1) : a.getMonth() + 1) + " - " + a.getFullYear();
                        }
                        let artist = data.track.artist.name || "";
                        let album = data.track.album.name || "";
                        let explicit = "";
                        if (data.track.explicit) {
                            explicit = "<div class='explicit'>E</div>";
                        }
                        let elPlaylistTrack = document.createElement("li");
                        elPlaylistTrack.id = data.track.id;
                        elPlaylistTrack.setAttribute("data-songid", data.track.id);
                        elPlaylistTrack.setAttribute("data-playlistid", playlist_id);
                        elPlaylistTrack.innerHTML = "<div class='trackRow'>" +
                            "<div class='item' data-trackNo='" + trackNo + "'>" + trackNo + "</div>" +
                            "<div class='title' data-sortIndex='" + data.track.title.toUpperCase() + "'>" + data.track.title + " " + explicit + "</div>" +
                            "<div class='artist' data-sortIndex='" + artist.toUpperCase() + "'>" + artist + "</div>" +
                            "<div class='album' data-sortIndex='" + album.toUpperCase() + "'>" + album + "</div>" +
                            "<div class='timestamp' data-sortIndex='" + data.date_added + "'>" + added + "</div>" +
                            "<div class='time'>" + formattedDuration + "</div>" +
                            "</div>";
                        document.getElementById("playlist").appendChild(elPlaylistTrack);
                    }
                    else {
                        console.warn("Track error: ", data.track);
                    }
                }
                playlistObj.sortTracks(); //TODO can cause issues for user since sorting takes time, look into improving
                if(tracks.next){
                    const hrs = Math.floor((totalPlaylistDuration / 60) / 60);
                    const mins = Math.round((((totalPlaylistDuration / 60) / 60) - hrs) * 60);
                    document.getElementById("songTotalPlaytime").innerHTML = hrs + " hr " + mins + " mins";
                    playlistObj.getPlaylistTracks(playlist_id, (offset + limit), limit, function(nextTracks){
                        playlistObj.appendTracks(playlist_id, nextTracks, (offset + limit), limit);
                    });
                }
                else{
                    //complete load of tracks, update eventListeners etc.
                    const hrs = Math.floor((totalPlaylistDuration / 60) / 60);
                    const mins = Math.round((((totalPlaylistDuration / 60) / 60) - hrs) * 60);
                    document.getElementById("songTotalPlaytime").innerHTML = hrs + " hr " + mins + " mins";
                    ws = require("ws");
                    ws.send("PLAYER_STATE",{});
                    let EventListener = require("eventListener");
                    EventListener.updateEventListeners.playlistTrack();
                    EventListener.updateEventListeners.playlistScroll();
                }
            }
        }
   };
   return playlistObj;
});