define(["constants"], function(c){
    let PlayerBar = {
        loading: {
            start: function(){
                if(c.seekInterval) {
                    clearInterval(c.seekInterval);
                }
                let elTimelineBar = document.getElementById("timelineBar");
                elTimelineBar.style.width = "150px";
                elTimelineBar.classList.add("loading");
                document.getElementById("pb_artwork").setAttribute("style", "background-image: url(''); background-repeat: no-repeat; background-position: center; background-size: cover;");
                document.getElementById("pb_bg_artwork").setAttribute("style", "background-image: url(''); background-repeat: no-repeat; background-position: center; background-size: cover;");
                document.getElementsByClassName("activeTrack")[0].innerHTML = "";
                document.getElementsByClassName("activeArtist")[0].innerHTML = "";
            },
            end: function(){
                let elTimelineBar = document.getElementById("timelineBar");
                elTimelineBar.style.width = "0px";
                elTimelineBar.classList.remove("loading")
            }
        },
        updateArtwork: function(url){
            document.getElementById("pb_artwork").setAttribute("style", "background-image: url('"+url+"'); background-repeat: no-repeat; background-position: center; background-size: cover;");
            document.getElementById("pb_bg_artwork").setAttribute("style", "background-image: url('"+url+"'); background-repeat: no-repeat; background-position: center; background-size: cover;");
        },
        updateDetails: function(title, artist, album){
            let elActiverTrack = document.getElementsByClassName("activeTrack")[0];
            let elActiveArtist = document.getElementsByClassName("activeArtist")[0];
            elActiverTrack.innerHTML = "";
            elActiveArtist.innerHTML = "";
            if(title){
                if (title.length > 32) {
                    elActiverTrack.innerHTML = "<marquee>" + title + "</marquee>";
                }
                else {
                    elActiverTrack.innerHTML = title;
                }
            }
            if(artist) {
                elActiveArtist.innerHTML = artist.name || "";
            }
        },
        updateSeekBar: function(playtime, duration){
            let ptime_h = Math.floor((playtime/60));
            let ptime_m = Math.round(playtime % 60);
            let fPlaytime = (ptime_h < 10 ? "0"+ptime_h : ptime_h) + ":"+(ptime_m < 10 ? "0"+ptime_m : ptime_m);
            let dtime_h = Math.floor((duration/60));
            let dtime_m = Math.round(duration % 60);
            let fDuration = (dtime_h < 10 ? "0"+dtime_h : dtime_h) + ":"+(dtime_m < 10 ? "0"+dtime_m : dtime_m);
            document.getElementById("pb_duration").innerHTML = fPlaytime+" / "+fDuration;
            let elTimelineBar = document.getElementById("timelineBar");
            elTimelineBar.style.width = (playtime/duration)*100+"%";
            let elProgressWave = document.querySelector(".waveform-progress");
            elProgressWave.style.width = (playtime/duration)*500+"px";
        },
        updateSeek: function(playtime, duration){
            let elTimelineBar = document.getElementById("timelineBar");
            elTimelineBar.style.width = (playtime/duration)*100+"%";
            c.playtime = playtime;
            c.duration = duration;
            if(c.seekInterval) {
                clearInterval(c.seekInterval);
            }
            c.seekInterval = setInterval(function(){
                PlayerBar.updateSeekBar(playtime++, duration);
            },1000);
        },
        updateSeekFromPause: function(){
            if(c.seekInterval) {
                clearInterval(c.seekInterval);
            }
            c.seekInterval = setInterval(function(){
                PlayerBar.updateSeekBar(c.playtime++, c.duration);
            },1000);
        },
        updateDownloadSeek: function(seconds, duration){
            let elDownloadTimelineBar = document.getElementById("timelineDownloadBar");
            elDownloadTimelineBar.style.width = Math.ceil((seconds/duration)*100)+"%";
        },
    };
    return PlayerBar;
});