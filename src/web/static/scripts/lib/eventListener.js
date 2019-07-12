define(["constants","audioPlayer","views","playlist","user","requester", "simpleBar"], function(c, ap, views, p, u, req, SimpleBar){
    let eventListenerMethods = {
        init: function(){
            let uel = eventListenerMethods.updateEventListeners;
            uel.primaryNavigation();
            uel.accountOptions();
            uel.contextMenu();
            uel.keyboardEvents();
            uel.newPlaylist();
            uel.searchEventListener();
            uel.queue_button();
        },
        updateEventListeners: {
            all: function(){
                let uel = eventListenerMethods.updateEventListeners;
                uel.primaryNavigation();
                uel.playlistTrack();
                uel.accountOptions();
                uel.contextMenu();
                uel.keyboardEvents();
                uel.newPlaylist();
                uel.searchEventListener();
            },
            queue_button: function(){
              document.getElementById("queue_button").onclick = function(e){
                  views.load("queue","undefined");
              }
            },
            searchEventListener: function(){
                let elSearchInput = document.getElementById("motorbotsearch");
                let elSearchAutocomplete = document.getElementById("searchAutocomplete");
                elSearchInput.onkeydown = function(e) {
                    if (e.which === 9) { //tab
                        if (elSearchAutocomplete) {
                            if (elSearchAutocomplete.classList.contains("visible")) {
                                let activeAutocompleteItem = document.querySelector("#searchAutocomplete ul li.active");
                                elSearchInput.value = activeAutocompleteItem.getAttribute("data-displayname");
                                elSearchAutocomplete.classList.remove("visible");
                            }
                        }
                        e.preventDefault();
                        return false;
                    }
                    else if (e.which === 38) { //up
                        if (elSearchAutocomplete) {
                            if (elSearchAutocomplete.classList.contains("visible")) {
                                let x = document.querySelector("#searchAutocomplete ul li.active");
                                if (x) {
                                    let prev = x.previousSibling;
                                    if (prev) {
                                        prev.nextSibling.classList.remove("active");
                                        prev.classList.add("active");
                                    }
                                }
                                else {
                                    let prev = document.querySelector("#searchAutocomplete ul li");
                                    if (prev) {
                                        prev.classList.add("active");
                                    }
                                }
                                e.preventDefault();
                                return false;
                            }
                            e.preventDefault();
                            return false;
                        }
                        e.preventDefault();
                        return false;
                    }
                    else if (e.which === 40) { //down
                        if (elSearchAutocomplete) {
                            if (elSearchAutocomplete.classList.contains("visible")) {
                                let x = document.querySelector("#searchAutocomplete ul li.active");
                                if (x) {
                                    let next = x.nextSibling;
                                    if (next) {
                                        next.previousSibling.classList.remove("active");
                                        next.classList.add("active");
                                    }
                                }
                                else {
                                    let next = document.querySelector("#searchAutocomplete ul li");
                                    if (next) {
                                        next.classList.add("active");
                                    }
                                }
                                e.preventDefault();
                                return false;
                            }
                            e.preventDefault();
                            return false;
                        }
                        e.preventDefault();
                        return false;
                    }
                };
                elSearchInput.onkeyup = function (e){
                    let searchTerm = e.target.value;
                    if(e.which === 13){ //enter
                        elSearchAutocomplete.classList.remove("visible");
                        views.load("search",searchTerm);
                    }
                    else if (e.which === 38 || e.which === 40 || e.which === 9) {

                    }
                    else{
                        if(searchTerm.length > 3){
                            //autocomplete
                            elSearchAutocomplete.classList.add("visible");
                            req.get(c.base_url+"/search?q="+searchTerm+"&offset=0&limit=4&filter=tracks(items(id,title),total),playlists(items(id,name),total)&api_key="+c.api_key, {dataType: "json"}).then(function(response){
                                console.log(response);
                                elSearchAutocomplete.innerHTML = "";
                                let elResultList = document.createElement("ul");
                                if(response.data.tracks.items){
                                    if(response.data.tracks.items.length > 0){
                                        for(let k=0;k<response.data.tracks.items.length;k++){
                                            let searchResult = response.data.tracks.items[k];
                                            let elSearchResultListItem = document.createElement("li");
                                            elSearchResultListItem.setAttribute("data-id",searchResult.id);
                                            elSearchResultListItem.setAttribute("data-displayname",searchResult.title);
                                            elSearchResultListItem.setAttribute("data-searchtype","track");
                                            elSearchResultListItem.innerHTML = "<i class=\"fas fa-music\"></i> &nbsp; "+searchResult.title;
                                            elResultList.appendChild(elSearchResultListItem);
                                        }
                                        elSearchAutocomplete.appendChild(elResultList);
                                    }
                                }

                                if(response.data.playlists.items){
                                    if(response.data.playlists.items.length > 0){
                                        for(let k=0;k<response.data.playlists.items.length;k++){
                                            let searchResult = response.data.playlists.items[k];
                                            let elSearchResultListItem = document.createElement("li");
                                            elSearchResultListItem.setAttribute("data-id",searchResult.id);
                                            elSearchResultListItem.setAttribute("data-displayname",searchResult.name);
                                            elSearchResultListItem.setAttribute("data-searchtype","playlist");
                                            elSearchResultListItem.innerHTML = "<i class=\"fas fa-list-ul\"></i> &nbsp; "+searchResult.name;
                                            elResultList.appendChild(elSearchResultListItem);
                                        }
                                        elSearchAutocomplete.appendChild(elResultList);
                                    }
                                }
                            }).catch(function(err){
                                console.warn(err);
                            })
                        }
                        else{
                            elSearchAutocomplete.classList.remove("visible");
                        }
                    }
                }
            },
            newPlaylist: function(){
                document.getElementById("newPlaylistArtworkFile").onchange = function(e){
                    console.info("album art preview generating...");
                    let elNewPlaylistModalArtwork = document.getElementById("newPlaylistModal_artwork");
                    elNewPlaylistModalArtwork.style.background = "url('" + URL.createObjectURL(e.target.files[0]) + "') no-repeat center";
                    elNewPlaylistModalArtwork.style.backgroundSize = "cover";
                };
                removeModalElements = function(){
                    document.querySelector(".flexContainer").style.filter = "blur(0px)";
                    document.querySelector(".playerBar").style.filter = "blur(0px)";
                    document.getElementById("notificationsList").style.filter = "blur(0px)";
                    document.getElementById("newPlaylistModal").style.display = "none";
                    document.getElementById("modalityOverlay").style.display = "none";
                    document.querySelector(".playlist_name_input").value = "";
                    document.querySelector(".playlist_description_input").value = "";
                    document.getElementById("newPlaylistModal_artwork").style.background = "rgba(0,0,0,0.2)";
                    document.getElementById("newPlaylistArtworkFile").value = "";
                };
                document.getElementById("newPlaylistButton").onclick = function(e){
                    document.querySelector(".flexContainer").style.filter = "blur(5px)";
                    document.querySelector(".playerBar").style.filter = "blur(5px)";
                    document.getElementById("notificationsList").style.filter = "blur(5px)";
                    document.getElementById("newPlaylistModal").style.display = "block";
                    let elModalityOverlay = document.getElementById("modalityOverlay");
                    elModalityOverlay.style.display = "block";
                    elModalityOverlay.onclick = removeModalElements;
                };
                document.getElementById("newPlaylistButton_cancel").onclick = removeModalElements;
                document.getElementById("newPlaylistButton_okay").onclick = function () {
                    let newPlaylistName = document.querySelector(".playlist_name_input").value;
                    if (newPlaylistName && newPlaylistName !== "") {
                        console.info("Submitting New Playlist");
                        u.createPlaylist(function(playlist){
                            console.log(playlist);
                            removeModalElements();
                            u.loadPlaylists(0,50, function(){
                                views.load("playlists",playlist.id, function(){
                                    document.getElementsByClassName("flexContainer")[0].style.opacity = "1";
                                });
                            });
                        });
                    }
                    else {
                        //no name given :(
                        alert("Please give your new playlist a name.");
                    }
                };
            },
            keyboardEvents: function(){
                document.onkeydown = function(e) {
                    let elActiveElement = document.activeElement.tagName.toLowerCase();
                    if(elActiveElement !== "input" &&  elActiveElement !== "textarea"){
                        switch (e.which) {
                            case 38: // up
                                if (document.getElementById("playlist")) {
                                    let prev = document.querySelector("#playlist li.active").previousSibling;
                                    if (prev && prev.className !== "titleRow") {
                                        prev.nextSibling.classList.remove("active");
                                        prev.classList.add("active");
                                        if (prev.getBoundingClientRect().top < 300) {
                                            let cv = document.getElementById("ajax_contentView").simplebar.getScrollElement().scrollTop;
                                            document.getElementById("ajax_contentView").simplebar.getScrollElement().scrollTop = (cv - 40);
                                        }
                                    }
                                }
                                break;
                            case 40: // down
                                if (document.getElementById("playlist")) {
                                    let next = document.querySelector("#playlist li.active").nextSibling;
                                    if (next && next.className !== "titleRow") {
                                        next.previousSibling.classList.remove("active");
                                        next.classList.add("active");
                                        if ((document.documentElement.scrollHeight - next.getBoundingClientRect().top) < 100) {
                                            let cv = document.getElementById("ajax_contentView").simplebar.getScrollElement().scrollTop;
                                            document.getElementById("ajax_contentView").simplebar.getScrollElement().scrollTop = (cv + 40);
                                        }
                                    }
                                }
                                break;
                            case 13: //enter
                                if (document.getElementById("playlist")) {
                                    let elActiveSong = document.querySelector("#playlist li.active");
                                    let SongIds = [];
                                    let Offset = 0;
                                    document.querySelectorAll("#playlist li").forEach(function (element, index){
                                        if(element.getAttribute("data-songid")){
                                            SongIds.push(element.getAttribute("data-songid"))
                                        }
                                        if(element.classList.contains("active")){
                                            Offset = index - 1;
                                        }
                                    })
                                    // ap.playSongFromPlaylist(elActiveSong.getAttribute("data-songid"), elActiveSong.getAttribute("data-playlistid"))
                                    ap.playSongsFromPlaylist(SongIds, elActiveSong.getAttribute("data-playlistid"), Offset);
                                }
                                break;
                            case 32: //space

                                break;
                            case 8: //backspace

                                break;
                            default:
                                //console.log(e.which);
                                return; // exit this handler for other keys
                        }
                        e.preventDefault(); // prevent the default action (scroll / move caret)
                    }
                };
            },
            contextMenu: function(){
                document.addEventListener("click", function(e){
                    if(e.target.className !== "playlistExtraOptions" && e.target.className !== "fas fa-ellipsis-h"){
                        document.getElementById("contextMenu").style.display = "none";
                    }
                });
            },
            primaryNavigation: function(){
                let elNavigationItems = [].slice.call(document.querySelectorAll(".mainNav li"));
                for(let o=0;o<elNavigationItems.length;o++){
                    if(elNavigationItems[o]) {
                        if (elNavigationItems[o].getAttribute("data-view")) {
                            elNavigationItems[o].addEventListener("click", function (e) {
                                views.load(elNavigationItems[o].getAttribute("data-view"), "undefined"); //WARN: CIRCULAR STRUCTURE - all views loaded through here require manual loading of eventListener module before calling any methods
                                if(document.querySelector(".mainNav li.active")) {
                                    document.querySelector(".mainNav li.active").classList.remove("active");
                                }
                                elNavigationItems[o].classList.add("active");
                            });
                        }
                    }
                }
                let elMobilePlayerBarDownButton = document.getElementById("mobile_pb_downButton");
                if(elMobilePlayerBarDownButton){
                    elMobilePlayerBarDownButton.addEventListener("click", function(e){
                        let elPlayerBar = document.getElementById("pb")
                        if(elPlayerBar){
                            if(elPlayerBar.classList.contains("mini")){
                                elPlayerBar.classList.remove("mini");
                                elMobilePlayerBarDownButton.innerHTML = "<i class=\"fas fa-chevron-down\" aria-hidden=\"true\"></i>";
                            }
                            else{
                                elPlayerBar.classList.add("mini");
                                elMobilePlayerBarDownButton.innerHTML = "<i class=\"fas fa-chevron-up\" aria-hidden=\"true\"></i>";
                            }
                        }
                    });
                }
            },
            accountOptions: function(){
                let elAccountOptions = [].slice.call(document.querySelectorAll("#accountOptions li"));
                for(let k=0;k<elAccountOptions.length;k++) {
                    elAccountOptions[k].addEventListener("click", function (e) {
                        if(elAccountOptions[k].getAttribute("data-view") === "account"){
                            views.load("account", "accountView"); //WARN: CIRCULAR STRUCTURE - all views loaded through here require manual loading of eventListener module before calling any methods
                        }
                        else {
                            views.load(elAccountOptions[k].getAttribute("data-view"), "undefined"); //WARN: CIRCULAR STRUCTURE - all views loaded through here require manual loading of eventListener module before calling any methods
                        }
                        if(document.querySelector(".mainNav li.active")) {
                            document.querySelector(".mainNav li.active").classList.remove("active");
                        }
                    });
                }
            },
            playlistSortHeaders: function(){
                document.getElementById("timestamp_header").addEventListener("click",function(e){
                    c.playlistSortDirection = (c.playlistSortDirection) * -1;
                    c.playlistSort = "timestamp";
                    p.sortTracks();
                });
                document.getElementById("album_header").addEventListener("click",function(e){
                    c.playlistSortDirection = (c.playlistSortDirection) * -1;
                    c.playlistSort = "album";
                    p.sortTracks();
                });
                document.getElementById("artist_header").addEventListener("click",function(e){
                    c.playlistSortDirection = (c.playlistSortDirection) * -1;
                    c.playlistSort = "artist";
                    p.sortTracks();
                });
                document.getElementById("title_header").addEventListener("click",function(e){
                    c.playlistSortDirection = (c.playlistSortDirection) * -1;
                    c.playlistSort = "title";
                    p.sortTracks();
                });
            },
            playlistScroll: function(){
                let ph = document.getElementById("playlist_header");
                let plst = document.getElementById("playlist");
                if(ph && !window.navigator.standalone && !window.matchMedia('(display-mode: standalone)').matches && window.innerWidth >= 600) {
                    let elContentView = document.getElementById("ajax_contentView");
                    let sb = new SimpleBar(elContentView);
                    sb.getScrollElement().onscroll = function () {
                        let scrolled = sb.getScrollElement().scrollTop;
                        document.querySelector("#playlist_header .bg").style.filter = "blur("+(Math.round(scrolled/30) > 25 ? 25 : Math.round(scrolled/30))+"px)";
                        document.querySelector("#playlist_header .bg").style.opacity = 1/(Math.round(scrolled/30) > 25 ? 0 : Math.round(scrolled/30));
                        if (scrolled >= 100 && !ph.classList.contains("mini")) {
                            ph.classList.add("mini");
                            plst.classList.add("mini");
                        }
                        else if (scrolled < 100 && ph.classList.contains("mini")) {
                            ph.classList.remove("mini");
                            plst.classList.remove("mini");
                        }
                    }
                }
            },
            playlistTrack: function(){
                let elTracks = document.querySelectorAll("#playlist li:not(.titleRow)");
                for(let i=0;i<elTracks.length;i++){
                    let self = elTracks[i];
                    self.addEventListener("click", function(e){
                        if(document.querySelector("#playlist li.active")){
                            document.querySelector("#playlist li.active").classList.remove("active");
                        }
                        self.classList.add("active");
                    });
                    self.addEventListener("dblclick", function(e){
                        let songId = self.getAttribute("data-songid");
                        let playlistId = self.getAttribute("data-playlistid");
                        let SongIds = [];
                        let Offset = 0;
                        document.querySelectorAll("#playlist li").forEach(function (element, index){
                            let i = element.getAttribute("data-songid");
                            if(i) {
                                SongIds.push(i)
                                if (i === songId) {
                                    Offset = index - 1;
                                }
                            }
                        })
                        ap.playSongsFromPlaylist(SongIds, playlistId, Offset);
                    });
                    self.addEventListener("contextmenu", function(e){
                        let contextmenu = document.getElementById("contextMenu");
                        contextmenu.style.display = "none";
                        let CurX = (window.Event) ? e.pageX : e.clientX + (document.documentElement.scrollLeft ? document.documentElement.scrollLeft : document.body.scrollLeft);
                        let CurY = (window.Event) ? e.pageY : e.clientY + (document.documentElement.scrollTop ? document.documentElement.scrollTop : document.body.scrollTop);
                        contextmenu.innerHTML = "";
                        if(document.querySelector("#playlist li.active")){
                            document.querySelector("#playlist li.active").classList.remove("active");
                        }
                        self.className = "active";
                        if(CurY+200 > document.body.scrollHeight){
                            contextmenu.style.display = "block";
                            contextmenu.style.top = (CurY - 190) + "px";
                            contextmenu.style.left = CurX + "px";
                        }
                        else{
                            contextmenu.style.display = "block";
                            contextmenu.style.top = CurY + "px";
                            contextmenu.style.left = CurX + "px";
                        }
                        if(self.getAttribute("id")) {
                            let elContextMenuList = document.createElement("ul");
                            let elContextMenuListItem_queue= document.createElement("li");
                            elContextMenuListItem_queue.innerHTML = "Add To Queue";
                            elContextMenuListItem_queue.onclick = function(e){
                                req.get(c.base_url+"/music/queue/"+self.getAttribute("data-songid")+"/"+self.getAttribute("data-playlistid")+"?api_key="+c.api_key, {dataType:"json", authorize: true}).then(function(response){
                                    console.log(response);
                                }).catch(function(err){
                                    console.warn(err);
                                });
                            };
                            elContextMenuList.appendChild(elContextMenuListItem_queue);
                            let elContextMenuListItem_sep = document.createElement("li");
                            elContextMenuListItem_sep.className = "sep";
                            elContextMenuList.appendChild(elContextMenuListItem_sep);
                            let elContextMenuListItem_info = document.createElement("li");
                            elContextMenuListItem_info.innerHTML = "Details";
                            elContextMenuListItem_info.onclick = function(){
                                req.get(c.base_url+"/track/"+self.getAttribute("data-songid")+"?api_key="+c.api_key, {dataType:"json"}).then(function(response){
                                    console.log(response);
                                    document.querySelector(".song_info_raw").innerHTML = JSON.stringify(response.data, null, 4)
                                    document.getElementById("song_info").style.display = "block";
                                }).catch(function(err){
                                    console.warn(err);
                                });
                            };
                            elContextMenuList.appendChild(elContextMenuListItem_info);
                            let elContextMenuListItem_sep2 = document.createElement("li");
                            elContextMenuListItem_sep2.className = "sep";
                            elContextMenuList.appendChild(elContextMenuListItem_sep2);
                            let elContextMenuListItem_lib = document.createElement("li");
                            elContextMenuListItem_lib.innerHTML = "Add To Library";
                            elContextMenuList.appendChild(elContextMenuListItem_lib);
                            let elContextMenuListItem_playlist = document.createElement("li");
                            elContextMenuListItem_playlist.innerHTML = "Add To Playlist";
                            elContextMenuList.appendChild(elContextMenuListItem_playlist);
                            if (document.getElementById("playlist").getAttribute("data-playlistCreator") === c.user_id) {
                                let elContextMenuListItem_sep = document.createElement("li");
                                elContextMenuListItem_sep.className = "sep";
                                elContextMenuList.appendChild(elContextMenuListItem_sep);
                                let elContextMenuListItem_delete = document.createElement("li");
                                elContextMenuListItem_delete.innerHTML = "Delete";
                                elContextMenuListItem_delete.style.color = "rgba(242, 52, 51, 1.00)";
                                elContextMenuListItem_delete.onclick = function () {
                                    //Delete song
                                    req.delete(c.base_url+"/playlist/"+self.getAttribute("data-playlistid")+"/song/"+self.getAttribute("data-songid")+"?api_key="+c.api_key, {dataType:"json", authorize: true}).then(function(response){
                                        console.log(response);
                                        self.parentNode.removeChild(self);
                                    }).catch(function(err){
                                        console.warn(err);
                                    });
                                };
                                elContextMenuList.appendChild(elContextMenuListItem_delete);
                            }
                            contextmenu.appendChild(elContextMenuList);
                        }
                        return true;
                    });
                }
                eventListenerMethods.updateEventListeners.playlistSortHeaders();
            }
        }
    };
    return eventListenerMethods
});