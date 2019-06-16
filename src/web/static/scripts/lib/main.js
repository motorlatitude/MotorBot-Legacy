define(["domReady.min","ws","eventListener","audioPlayer","user","views"], function(DOMReady, ws, el, ap, u, v) {
    DOMReady(function() {
        console.info("DOM_LOAD_COMPLETE");
        let socket = ws.init();
        el.init();
        v.init();
        document.oncontextmenu = function () {
            return false;
        };
        let player = ap.init();
        //Get user playlists
        document.getElementsByClassName("flexContainer")[0].style.opacity = "0";
        u.loadPlaylists(0, 50, function () {
            //load view
            const url = window.location.href;
            const view_params = url.split("dashboard/")[1];
            const view = view_params.split("/")[0] || "home";
            const param = view_params.split("/")[1] || "undefined";
            v.load(view, param, function () {
                document.getElementsByClassName("flexContainer")[0].style.opacity = "1";
            });
        });
    });
});
