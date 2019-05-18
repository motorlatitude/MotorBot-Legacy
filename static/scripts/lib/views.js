define(["constants","requester","marked","simpleBar","playlist"], function(c,req,marked,SimpleBar,playlist){
   let viewsObj = {
       init: function(){
           window.onpopstate = function(event) {
               if(event){
                   console.log("popstate");
                   //load view
                   const url = window.location.href;
                   const view_params = url.split("dashboard/")[1];
                   const view = view_params.split("/")[0] || "home";
                   const param = view_params.split("/")[1] || "undefined";
                   viewsObj.load(view, param, function () {
                       document.getElementsByClassName("flexContainer")[0].style.opacity = "1";
                   });
               }
               else{
                   // Continue user action through link or button
               }
           }
       },
       load: function(view, param, callback){
           let url = "";
           String.prototype.capitalize = function() {
               return this.charAt(0).toUpperCase() + this.slice(1);
           };
           if(param === "undefined"){
               param = undefined;
               url = "/views/"+view;
               window.history.pushState('MotorBot Dashboard View', view, 'https://motorbot.io/dashboard/'+view);
               document.title = "MotorBot: "+view.capitalize();
           }
           else if(view === "account"){
               url = "/views/"+view;
               window.history.pushState('MotorBot Dashboard View', view, 'https://motorbot.io/dashboard/'+view+'/'+param);
               document.title = "MotorBot: My Account";
           }
           else{
               url = "/views/"+view+"/"+param;
               window.history.pushState('MotorBot Dashboard View', view, 'https://motorbot.io/dashboard/'+view+'/'+param);
               document.title = "MotorBot: "+view.capitalize();
           }
           document.getElementById("ajax_contentView").innerHTML = "";
           document.getElementById("ajax_contentView").style.opacity = "0";
           document.getElementById("ajax_loader").style.display = "block";
           req.get(url, {dataType: "html"}).then(function(response){
               console.log(response);
               document.getElementById("ajax_contentView").innerHTML = response.data;
               switch(view){
                   case "home":
                       req.get("https://api.github.com/repos/motorlatitude/motorbot/commits", {dataType: "json"}).then(function(response){
                           document.getElementById("ajax_loader").style.display = "none";
                           document.getElementById("ajax_contentView").style.opacity = "1";
                           for(let item in response.data){
                               let d = response.data;
                               if(d[item]) {
                                   if (d[item].commit) {
                                       if (d[item].commit.message !== "") {
                                           let elCommit = document.createElement("li");
                                           elCommit.innerHTML = "<li>" +
                                               "<div class='date'>" +
                                               d[item].commit.author.date.replace(/T/gmi, "&nbsp;&bull;&nbsp;").replace(/-/gmi, "/").replace(/Z/gmi, "") +
                                               "&nbsp;&bull;&nbsp;<span class='author'>" +
                                               d[item].author.login +
                                               "</span>" +
                                               "</div>" +
                                               "<div class='commit'>" +
                                               d[item].sha.substr(0, 7) +
                                               "</div>" +
                                               "<div class='container'>" +
                                               marked(d[item].commit.message.replace(/Signed-off-by(.*?)$/gmi, "").replace(/<(.*?)>$/gmi, "&lt;$1&gt;").replace(/FIX/g, "<div class='type fix'>FIX</div>").replace(/NEW/g, "<div class='type new'>NEW</div>").replace(/TODO/g, "<div class='type todo'>TODO</div>").replace(/CODE\sIMPROVEMENT/g, "<div class='type code'>CODE</div>").replace(/CODE/g, "<div class='type code'>CODE</div>").replace(/IMPROVEMENT/g, "<div class='type improvement'>IMPROVEMENT</div>").replace(/DEPRECIATED/g, "<div class='type depreciated'>DEPRECIATED</div>")) + "</div></li>";
                                           document.getElementById("commitHistory").appendChild(elCommit);
                                       }
                                   }
                               }
                           }
                           new SimpleBar(document.getElementById("ajax_contentView"));
                       }).catch(function(error){
                          console.warn(error);
                       });
                       break;
                   case "playlists":
                       document.getElementById("ajax_contentView").style.opacity = "0";
                       document.getElementById("playlist").setAttribute("data-playlistid",param);
                       playlist.load(param);
                       break;
                   case "queue":
                       req.get(c.base_url+"/queue/"+c.currentGuild+"?api_key="+c.api_key,{dataType: "json", authorize: true}).then(function(response){
                           console.log(response);
                           let data = response.data;
                           let l = 0;
                           let x = 0;
                           for(let i in data){
                               let track = data[i];
                               if(track.status === "queued"){
                                   let trackNo = parseInt(l) + 1;
                                   let formattedDuration = c.secondsToHms(track.duration);
                                   let added = "";
                                   if (track.import_date >= (new Date().getTime() - 604800000)) {
                                       added = c.millisecondsToStr(track.import_date);
                                   }
                                   else {
                                       const a = new Date(track.import_date);
                                       added = (a.getDate() < 10 ? "0" + (a.getDate()) : a.getDate()) + " - " + (a.getMonth() + 1 < 10 ? "0" + (a.getMonth() + 1) : a.getMonth() + 1) + " - " + a.getFullYear();
                                   }
                                   let artist = track.artist.name || "";
                                   let album = track.album.name || "";
                                   let explicit = "";
                                   if (track.explicit) {
                                       explicit = "<div class='explicit'>E</div>";
                                   }
                                   let elPlaylistTrack = document.createElement("li");
                                   elPlaylistTrack.id = track.id;
                                   elPlaylistTrack.setAttribute("data-songid", track.id);
                                   elPlaylistTrack.innerHTML = "<div class='trackRow'>" +
                                       //"<div class='item' data-trackNo='" + trackNo + "'>" + trackNo + "</div>" +
                                       "<div class='title' data-sortIndex='" + track.title.toUpperCase() + "'>" + track.title + " " + explicit + "</div>" +
                                       //"<div class='artist' data-sortIndex='" + artist.toUpperCase() + "'>" + artist + "</div>" +
                                       //"<div class='album' data-sortIndex='" + album.toUpperCase() + "'>" + album + "</div>" +
                                       //"<div class='timestamp' data-sortIndex='" + track.import_date + "'>" + added + "</div>" +
                                       "<div class='time'>" + formattedDuration + "</div>" +
                                       "</div>";
                                   document.getElementById("queueList").appendChild(elPlaylistTrack);
                                   l++;
                               }
                               if(track.status === "added"){
                                   let trackNo = parseInt(x) + 1;
                                   let formattedDuration = c.secondsToHms(track.duration);
                                   let added = "";
                                   if (track.import_date >= (new Date().getTime() - 604800000)) {
                                       added = c.millisecondsToStr(track.import_date);
                                   }
                                   else {
                                       const a = new Date(track.import_date);
                                       added = (a.getDate() < 10 ? "0" + (a.getDate()) : a.getDate()) + " - " + (a.getMonth() + 1 < 10 ? "0" + (a.getMonth() + 1) : a.getMonth() + 1) + " - " + a.getFullYear();
                                   }
                                   let artist = track.artist.name || "";
                                   let album = track.album.name || "";
                                   let explicit = "";
                                   if (track.explicit) {
                                       explicit = "<div class='explicit'>E</div>";
                                   }
                                   let elPlaylistTrack = document.createElement("li");
                                   elPlaylistTrack.id = track.id;
                                   elPlaylistTrack.setAttribute("data-songid", track.id);
                                   elPlaylistTrack.innerHTML = "<div class='trackRow'>" +
                                       //"<div class='item' data-trackNo='" + trackNo + "'>" + trackNo + "</div>" +
                                       "<div class='title' data-sortIndex='" + track.title.toUpperCase() + "'>" + track.title + " " + explicit + "</div>" +
                                       //"<div class='artist' data-sortIndex='" + artist.toUpperCase() + "'>" + artist + "</div>" +
                                       //"<div class='album' data-sortIndex='" + album.toUpperCase() + "'>" + album + "</div>" +
                                       //"<div class='timestamp' data-sortIndex='" + track.import_date + "'>" + added + "</div>" +
                                       "<div class='time'>" + formattedDuration + "</div>" +
                                       "</div>";
                                   document.getElementById("nextSongsList").appendChild(elPlaylistTrack);
                                   x++;
                               }
                               if(track.status === "playing"){
                                   if(document.getElementById("currentSong_artwork")){
                                       document.getElementById("currentSong_artwork").style.backgroundImage = "url('"+track.artwork+"')";
                                       document.getElementById("currentSong_artwork").style.backgroundSize = "cover";
                                       document.getElementById("currentSong_artwork").style.backgroundRepeat = "no-repeat";
                                       document.getElementById("currentSong_bgartwork").style.backgroundImage = "url('"+track.artwork+"')";
                                       document.getElementById("currentSong_bgartwork").style.backgroundSize = "cover";
                                       document.getElementById("currentSong_bgartwork").style.backgroundRepeat = "no-repeat";
                                       document.getElementById("currentSong_title").innerHTML = track.title || "";
                                       document.getElementById("currentSong_artist").innerHTML = track.artist.name || "";
                                   }
                               }
                           }
                           document.getElementById("ajax_loader").style.display = "none";
                           document.getElementById("ajax_contentView").style.opacity = "1";
                           new SimpleBar(document.getElementById("ajax_contentView"));
                       }).catch(function(err){
                           console.error("Error Occurred Returning Queue");
                            console.error(err);
                       });
                       break;
                   case "search":
                       req.get(c.base_url+"/search?q="+param+"&api_key="+c.api_key, {dataType: "json"}).then(function(response){
                           console.log(response);
                           let datas = response.data;
                           if(datas.tracks.items) {
                               let tracks = datas.tracks;
                               for (let i in tracks.items) {
                                   let data = tracks.items[i];
                                   let trackNo = parseInt(i) + 1;
                                   let formattedDuration = c.secondsToHms(data.duration);
                                   let added = "";
                                   if (data.import_date >= (new Date().getTime() - 604800000)) {
                                       added = c.millisecondsToStr(data.import_date);
                                   }
                                   else {
                                       const a = new Date(data.import_date);
                                       added = (a.getDate() < 10 ? "0" + (a.getDate()) : a.getDate()) + " - " + (a.getMonth() + 1 < 10 ? "0" + (a.getMonth() + 1) : a.getMonth() + 1) + " - " + a.getFullYear();
                                   }
                                   let artist = data.artist.name || "";
                                   let album = data.album.name || "";
                                   let explicit = "";
                                   if (data.explicit) {
                                       explicit = "<div class='explicit'>E</div>";
                                   }
                                   let elPlaylistTrack = document.createElement("li");
                                   elPlaylistTrack.id = data.id;
                                   elPlaylistTrack.setAttribute("data-songid", data.id);
                                   elPlaylistTrack.innerHTML = "<div class='trackRow'>" +
                                       "<div class='item' data-trackNo='" + trackNo + "'>" + trackNo + "</div>" +
                                       "<div class='title' data-sortIndex='" + data.title.toUpperCase() + "'>" + data.title + " " + explicit + "</div>" +
                                       "<div class='artist' data-sortIndex='" + artist.toUpperCase() + "'>" + artist + "</div>" +
                                       "<div class='album' data-sortIndex='" + album.toUpperCase() + "'>" + album + "</div>" +
                                       "<div class='timestamp' data-sortIndex='" + data.import_date + "'>" + added + "</div>" +
                                       "<div class='time'>" + formattedDuration + "</div>" +
                                       "</div>";
                                   document.getElementById("search_playlist").appendChild(elPlaylistTrack);
                               }
                           }
                           if(datas.playlists.items){
                               if(datas.playlists.items.length > 0) {
                                   let temporaryPlaylist = document.createDocumentFragment();
                                   for (let i in datas.playlists.items) {
                                       let item = datas.playlists.items[i];
                                       let artwork = "";
                                       if (item.artwork !== "") {
                                           artwork = "background: url(\"" + item.artwork + "\") no-repeat center; background-size: cover;";
                                       }
                                       let playlistItem = document.createElement("li");
                                       playlistItem.addEventListener("click", function (e) {
                                           viewsObj.load("playlists", item.id)
                                       });
                                       playlistItem.innerHTML = "<div class='artwork' style='" + artwork + "'>" +
                                           "<div class='playState'><i class=\"fa fa-play\" aria-hidden=\"true\"></i></div>" +
                                           "</div>" +
                                           "<div class='playlistName'>" + item.name + "</div>" +
                                           "<div class='creator'>" + item.creator + "</div>";
                                       temporaryPlaylist.appendChild(playlistItem);
                                   }
                                   let elSpotlightList = document.getElementById("search_playlists");
                                   elSpotlightList.appendChild(temporaryPlaylist);
                                   new SimpleBar(elSpotlightList);
                               }
                               else{
                                   document.querySelector(".contentTitle").style.display = "none";
                                   document.getElementById("search_playlists").style.display = "none";
                               }
                           }
                           document.getElementById("ajax_loader").style.display = "none";
                           document.getElementById("ajax_contentView").style.opacity = "1";
                           new SimpleBar(document.getElementById("ajax_contentView"));
                       }).catch(function(err){
                           console.warn(err)
                       });
                       break;
                   case "browse":
                       req.get(c.base_url+"/browse?api_key="+c.api_key, {dataType: "json", authorize: true}).then(function(response) {
                           let data = response.data;
                           let allowedNumber = Math.floor(((window.innerWidth - 230 - 100) / 180) * 2) - 5;
                           allowedNumber = allowedNumber % 2 != 0 ? (allowedNumber - 1) : allowedNumber;
                           console.log(allowedNumber);
                           if (allowedNumber >= 15) {
                               allowedNumber = Math.floor(((window.innerWidth - 230 - 130) / 180) * 2) - 7;
                               allowedNumber = allowedNumber % 2 == 0 ? (allowedNumber - 1) : allowedNumber;
                           }
                           console.log(allowedNumber);
                           if(data.spotlight){
                               let temporaryPlaylist = document.createDocumentFragment();
                               let total = 0;
                               for(let i in data.spotlight){
                                   total++;
                                   let item = data.spotlight[i];
                                   let artwork = "";
                                   if (item.artwork !== "") {
                                       artwork = "background: url(\"" + item.artwork + "\") no-repeat center; background-size: cover;";
                                   }
                                   let playlistItem = document.createElement("div");
                                   playlistItem.addEventListener("click", function(e){
                                       viewsObj.load("playlists",item.id)
                                   });
                                   playlistItem.innerHTML = "<div class='artwork' style='" + artwork + "'>" +
                                       "<div class='playState'><i class=\"fa fa-play\" aria-hidden=\"true\"></i></div>" +
                                       "</div>" +
                                       "<div class='playlistName'>" + item.name + "</div>";
                                   playlistItem.title = item.name;
                                   temporaryPlaylist.appendChild(playlistItem);
                                   if(total > allowedNumber){
                                       total--;
                                       playlistItem.style.display = "none";
                                   }
                               }
                               let elSpotlightList = document.getElementById("spotlight");
                               elSpotlightList.appendChild(temporaryPlaylist);
                               let rand = Math.random()*10;
                               if(rand > 6 && document.querySelector("#spotlight>div:nth-child(7)")) {
                                   document.querySelector("#spotlight>div:nth-child(7)").classList.add("big");
                               }
                               else{
                                   if(document.querySelector("#spotlight>div:nth-child(3)")){
                                       document.querySelector("#spotlight>div:nth-child(3)").classList.add("big");
                                   }
                               }
                               if(allowedNumber >= 13 && document.querySelector("#spotlight>div:nth-child(10)")) {
                                   document.querySelector("#spotlight>div:nth-child(10)").classList.add("big");
                               }
                           }
                           if(data.heavy_rotation){
                               let temporaryPlaylist = document.createDocumentFragment();
                               let total = 0;
                               for(let k in data.heavy_rotation){
                                   total++;
                                   let item = data.heavy_rotation[k].playlist;
                                   let artwork = "";
                                   if (item.artwork !== "") {
                                       artwork = "background: url(\"" + item.artwork + "\") no-repeat center; background-size: cover;";
                                   }
                                   let playlistItem = document.createElement("div");
                                   playlistItem.addEventListener("click", function(e){
                                       viewsObj.load("playlists",item.id)
                                   });
                                   playlistItem.innerHTML = "<div class='artwork' style='" + artwork + "'>" +
                                       "<div class='playState'><i class=\"fa fa-play\" aria-hidden=\"true\"></i></div>" +
                                       "</div>" +
                                       "<div class='playlistName'>" + item.name + "</div>";
                                   playlistItem.title = item.name;
                                   temporaryPlaylist.appendChild(playlistItem);
                                   if(total > allowedNumber){
                                       total--;
                                       playlistItem.style.display = "none";
                                   }
                               }
                               let elHeavyRotationList = document.getElementById("on_heavy_rotation");
                               elHeavyRotationList.appendChild(temporaryPlaylist);
                               let rand = Math.random()*10;
                               if(rand > 6 && document.querySelector("#on_heavy_rotation>div:nth-child(5)")){
                                   document.querySelector("#on_heavy_rotation>div:nth-child(5)").classList.add("big");
                               }
                               else{
                                   if(document.querySelector("#on_heavy_rotation>div:nth-child(3)")){
                                       document.querySelector("#on_heavy_rotation>div:nth-child(3)").classList.add("big");
                                   }
                               }
                               if(allowedNumber >= 13 && document.querySelector("#on_heavy_rotation>div:nth-child(12)")) {
                                   document.querySelector("#on_heavy_rotation>div:nth-child(12)").classList.add("big");
                               }
                           }
                           document.getElementById("ajax_loader").style.display = "none";
                           document.getElementById("ajax_contentView").style.opacity = "1";
                           new SimpleBar(document.getElementById("ajax_contentView"));
                       }).catch(function(error){
                          console.warn(error)
                       });
                       break;
                   case "podcast":
                       document.getElementById("fullscreen_button").addEventListener("click", function(e){
                           if(document.querySelector(".titlebar").style.display === "none") {
                               document.querySelector(".titlebar").style.display = "block";
                               document.querySelector(".sidebar").style.display = "block";
                               document.querySelector(".playerBar").style.display = "block";
                               document.getElementById("fullscreen_button").classList.remove("toggled");
                           }
                           else{
                               document.querySelector(".titlebar").style.display = "none";
                               document.querySelector(".sidebar").style.display = "none";
                               document.querySelector(".playerBar").style.display = "none";
                               document.getElementById("fullscreen_button").classList.add("toggled");
                           }
                       });
                       document.getElementById("ajax_loader").style.display = "none";
                       document.getElementById("ajax_contentView").style.opacity = "1";
                       break;
                   case "developer":
                       req.get(c.base_url+"/user/apps?api_key="+c.api_key,{dataType: "json", authorize: true}).then(function(response){
                           let data = response.data;
                           let temporaryDeveloperItem = document.createDocumentFragment();
                           for(let i in data){
                               let item = data[i];
                               let developerItem = document.createElement("li");
                               developerItem.innerHTML = "<div class='title'>" + item.title + "</div><br>API Key<pre>" + item.key + "</pre>Client ID<pre>" + item.id + "</pre>Secret<pre>" + item.secret + "</pre>";
                               temporaryDeveloperItem.appendChild(developerItem);
                           }
                           document.getElementById("developer_apps").appendChild(temporaryDeveloperItem);
                           document.getElementById("ajax_loader").style.display = "none";
                           document.getElementById("ajax_contentView").style.opacity = "1";
                           new SimpleBar(document.getElementById("ajax_contentView"));
                       }).catch(function(error){
                           console.warn(error);
                       });
                       break;
                   case "account":
                       req.get("/views/account/"+param, {dataType: "html"}).then(function(response) {
                           document.getElementById("ajax_accountView").innerHTML = response.data;
                           let elAccountOptions = [].slice.call(document.querySelectorAll("#account_navigation li"));
                           let updateEventListeners = function(param){
                               if(document.querySelector("#account_navigation li.active")){
                                   document.querySelector("#account_navigation li.active").classList.remove("active");
                               }
                               document.querySelector("#account_navigation li[data-view='"+param+"']").classList.add("active");
                               let toggles = document.querySelectorAll(".option.toggle");
                               if (toggles.length > 0) {
                                   console.log("We got toggles");
                                   for (let k = 0; k < toggles.length; k++) {
                                       let toggle = toggles[k];
                                       toggle.addEventListener("click", function (e) {
                                           console.log(toggle.getAttribute("data-togglesetting"));
                                           let sync = "true";
                                           if (toggle.getAttribute("data-togglesetting") === "enabled") {
                                               toggle.setAttribute("data-togglesetting", "disabled");
                                               sync = "false";
                                           }
                                           else {
                                               toggle.setAttribute("data-togglesetting", "enabled");
                                               sync = "true";
                                           }
                                           req.patch(c.base_url+"/"+toggle.getAttribute("data-connection")+"/"+toggle.getAttribute("data-setting")+"?sync="+sync+"&api_key="+c.api_key,{dataType: "json", authorize: true}).then(function(response){
                                               console.log("Settings Saved: Sync: "+sync);
                                           }).catch(function(err){
                                               console.warn(err);
                                           })
                                       });
                                   }
                               }
                               let revokeButtons = document.querySelectorAll(".disconnect.revoke");
                               if(revokeButtons.length > 0){
                                   for (let k = 0; k < revokeButtons.length; k++) {
                                       let revokeButton = revokeButtons[k];
                                       revokeButton.onclick = function(e){
                                           req.get(c.base_url+"/"+revokeButton.getAttribute("data-revoke")+"/revoke?api_key="+c.api_key,{dataType: "json", authorize: true}).then(function(e){
                                               console.log("Service Revoked");
                                               req.get("/views/account/connections", {dataType: "html"}).then(function(response) {
                                                   document.getElementById("ajax_accountView").innerHTML = response.data;
                                                   if(document.querySelector("#account_navigation li.active")){
                                                       document.querySelector("#account_navigation li.active").classList.remove("active");
                                                   }
                                                   updateEventListeners(elAccountOptions[k].getAttribute("data-view"));
                                               });
                                           }).catch(function(err){
                                                console.warn(err);
                                           });
                                       }
                                   }
                               }
                               let elPlaylistSelection = document.getElementById("playlistSelection");
                               if(elPlaylistSelection){
                                   req.get(c.base_url+"/spotify/playlists?api_key="+c.api_key, {dataType: "json", authorize: true}).then(function(response){
                                       console.log(response);
                                       let elPlaylistSelectionOptions = document.getElementById("playlistSelectionOptions");
                                       if(response){
                                           if(response.data.length > 0) {
                                               for (let a = 0; a < response.data.length; a++) {
                                                   let f = document.createElement("div");
                                                   f.className = "selectionOption";
                                                   f.innerHTML = response.data[a].name;
                                                   f.setAttribute("data-spotifyplaylistid",response.data[a].id);
                                                   f.onclick = function(e){
                                                       console.info("Clicked Selection Option");
                                                       let elSelectionValue = document.getElementById("playlistSelectionValue");
                                                       elSelectionValue.innerHTML = response.data[a].name;
                                                       elPlaylistSelection.setAttribute("data-spotifyplaylistid",response.data[a].id);
                                                       let elPlaylistSelectioButton = document.getElementById("playlistSelectioButton");
                                                       elPlaylistSelectioButton.onclick = function(e){
                                                           elPlaylistSelectioButton.classList.add("hide");
                                                           elPlaylistSelection.classList.add("hide");
                                                           let elPlaylistimportprogress = document.getElementById("playlistimportprogress");
                                                           if(elPlaylistimportprogress){
                                                               elPlaylistimportprogress.classList.remove("hide")
                                                           }
                                                           req.put(c.base_url+"/spotify/playlist/"+response.data[a].id+"/owner/"+response.data[a].owner.id+"?api_key="+c.api_key, {dataType: "json", authorize: true}).then(function(response){
                                                               console.log(response);
                                                           }).catch(function(err){
                                                              console.warn(err);
                                                           });
                                                       };
                                                       elPlaylistSelectioButton.classList.remove("disabled");
                                                   };
                                                   elPlaylistSelectionOptions.appendChild(f);
                                               }
                                               new SimpleBar(document.getElementById("playlistSelectionOptions"));
                                           }
                                       }
                                   }).catch(function(err){
                                       console.warn(err);
                                   });
                                   elPlaylistSelection.addEventListener("click", function(e) {
                                       console.log("Dropdown Clicked");
                                       if (elPlaylistSelection.classList.contains("selected")){
                                           elPlaylistSelection.classList.remove("selected");
                                       }
                                       else {
                                           elPlaylistSelection.classList.add("selected");
                                       }
                                   });
                               }
                           };
                           for(let k=0;k<elAccountOptions.length;k++) {
                               elAccountOptions[k].addEventListener("click", function (e) {
                                   elAccountOptions[k].classList.add("active");
                                   window.history.pushState('MotorBot Dashboard View', view, 'https://motorbot.io/dashboard/'+view+'/'+elAccountOptions[k].getAttribute("data-view"));
                                   req.get("/views/account/"+elAccountOptions[k].getAttribute("data-view"), {dataType: "html"}).then(function(response) {
                                       document.getElementById("ajax_accountView").innerHTML = response.data;
                                       if(document.querySelector("#account_navigation li.active")){
                                           document.querySelector("#account_navigation li.active").classList.remove("active");
                                       }
                                       updateEventListeners(elAccountOptions[k].getAttribute("data-view"));
                                   });
                               });
                           }
                           updateEventListeners(param);
                       });
                       document.getElementById("ajax_loader").style.display = "none";
                       document.getElementById("ajax_contentView").style.opacity = "1";
                       new SimpleBar(document.getElementById("ajax_contentView"));
                       break;
                   default:
                       document.getElementById("ajax_loader").style.display = "none";
                       document.getElementById("ajax_contentView").style.opacity = "1";
                       new SimpleBar(document.getElementById("ajax_contentView"));
               }
               if(callback){
                   callback()
               }
           }).catch(function(error){
               console.warn(error);
           });
       }
   };
   return viewsObj;
});