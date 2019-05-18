define(["constants","requester","views","Sortable"], function(c,req,v, Sortable){
    let usrobj = {
        init: function(){

        },
        submitCreatePlaylist: function(album_art, cb){
            let playlistName = document.querySelector(".playlist_name_input").value;
            let playlistDescription = document.querySelector(".playlist_description_input").value;
            req.post(c.base_url+"/playlist?api_key="+c.api_key,{
                dataType: "json",
                headers: {
                    "Content-Type": "application/json;charset=UTF-8"
                },
                data: {
                    "playlist_name": playlistName,
                    "playlist_description": playlistDescription,
                    "playlist_artwork": album_art
                },
                authorize: true}).then(function(response){
                if(typeof cb === "function"){
                    cb(response.data);
                }
            }).catch(function(error){
                console.warn(error);
            });
        },
        createPlaylist: function(cb){
            if(document.getElementById("newPlaylistArtworkFile").files[0]){
                let reader = new FileReader();
                reader.readAsDataURL(document.getElementById("newPlaylistArtworkFile").files[0]);
                reader.addEventListener("load", function () {
                    let album_art = reader.result;
                    usrobj.submitCreatePlaylist(album_art, cb);
                }, false);
                reader.readAsDataURL(document.getElementById("newPlaylistArtworkFile").files[0]);
            }
            else{
                usrobj.submitCreatePlaylist(undefined, cb);
            }
        },
        loadPlaylists: function(offset, limit, cb){
            if(offset === 0){
                document.getElementById("playlistNav").innerHTML = "";
                let old_element = document.getElementById("playlistNav");
                let new_element = old_element.cloneNode(true);
                old_element.parentNode.replaceChild(new_element, old_element);
            }
            req.get(c.base_url+"/user/playlists?offset="+offset+"&limit="+limit+"&filter=items(id,name,position)&api_key="+c.api_key,{dataType: 'json', authorize: true}).then(function(response){
                let response_data = response.data;
                let data = response_data.items;
                data.sort(function(a, b){
                    return parseFloat(a.position) - parseFloat(b.position);
                });
                for(let i in data) {
                    let item = data[i];
                    if(item) {
                        let playlistItem = document.createElement("li");
                        playlistItem.addEventListener("click", function (e) {
                            const v = require("views");
                            v.load("playlists", item.id.toString());
                            if(document.querySelectorAll(".mainNav li.active")[0]){
                                document.querySelectorAll(".mainNav li.active")[0].className = "";
                            }
                            this.className = "active";
                        });
                        playlistItem.setAttribute("data-playlistid", item.id);
                        playlistItem.innerHTML = item.name;
                        document.getElementById("playlistNav").appendChild(playlistItem);
                    }
                }
                if(response_data.next) {
                    usrobj.loadPlaylists((offset + limit), limit, cb);
                }
                else if(typeof cb === "function") {
                    console.log(Sortable);
                    const s = new Sortable.default(document.querySelectorAll("#playlistNav"), {
                        draggable: "li",
                        delay: 200
                    });
                    s.on("sortable:stop", (e) => {
                        console.log("Drag Released");
                        console.log(e);
                        let newIndex = e.data.newIndex;
                        let playlistId = e.data.dragEvent.data.source.dataset.playlistid;
                        console.log(newIndex+" --> "+playlistId);
                        req.patch(c.base_url+"/user/sort/" + playlistId + "/" + newIndex + "?api_key="+c.api_key,{dataType: 'json', authorize: true}).then(function(response){
                            console.log("Sort Finished");
                        }).catch(function(error){
                            console.warn(error);
                        });
                    });
                    cb();
                }
            }).catch(function(error){
                console.warn(error);
            });
        }
    };
    return usrobj;
});