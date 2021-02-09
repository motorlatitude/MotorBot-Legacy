define(["moment"], function (moment) {
  return {
    base_url: "http://109.157.12.102/api",
    ws_url: "ws://109.157.12.102:443",
    api_key: "caf07b8b-366e-44ab-9bda-623f94a9c2df",
    client_id: "7c78862088c0228ca226f4462df3d4ff",
    user_id: document.getElementById("store_userId").value,
    accessToken: document.getElementById("store_accessToken").value,
    op: {
      HEARTBEAT: 0,
      HEARTBEAT_ACK: 1,
      HELLO: 2,
      WELCOME: 3,
      VOICE_UPDATE: 4,
      TRACK_UPDATE: 5,
      YOUTUBE_ERROR: 6,
      PLAYER_UPDATE: 7,
      PLAYER_STATE: 8,
      SPOTIFY_IMPORT: 9,
      GUILD: 10,
      GUILD_STATE: 11,
      TRACK_PACKET: 12,
      TRACK_WAVEFORM: 13,
      SET_TRACK_WAVEFORM: 14,
      GET_TRACK_WAVEFORM: 15,
    },
    websocketSession: undefined,
    currentGuild: undefined,
    currentChannel: undefined,
    playlistSort: "timestamp",
    playlistSortDirection: 1,
    secondsToHms: function (d) {
      d = Number(d);
      let h = Math.floor(d / 3600);
      let m = Math.floor((d % 3600) / 60);
      let s = Math.floor((d % 3600) % 60);
      return (
        (h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") +
        m +
        ":" +
        (s < 10 ? "0" : "") +
        s
      );
    },
    millisecondsToStr: function (timestamp) {
      let diff = moment.unix(timestamp / 1000).fromNow();
      return diff;
    },
    seekInterval: undefined,
    playtime: 0,
    duration: 0,
    downloadDuration: 0,
  };
});
