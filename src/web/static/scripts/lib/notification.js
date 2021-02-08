define(function(){
    let Notification = {
        create: function (type, icon, content) {
            let elNewNotificiation = document.createElement("li");
            elNewNotificiation.className = type || "info";
            let fa_icon = icon || "wrench";
            elNewNotificiation.innerHTML = "<div class='icon'>" +
                "<div class='iconWrapper'>" +
                "<i class='fas fa-"+fa_icon+"' aria-hidden='true'></i>" +
                "</div></div>" +
                "<div class='content'>" + content + "</div>";
            elNewNotificiation.addEventListener("click", function(e){
               elNewNotificiation.parentElement.removeChild(elNewNotificiation);
            });
            document.getElementById("notificationsList").appendChild(elNewNotificiation);
        }
    };
    return Notification;
});