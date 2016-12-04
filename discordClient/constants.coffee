Constants = Constants || {}

Constants.api = {
  host: "https://discordapp.com/api/v6"
}

Constants.permissions = {
  "CREATE_INSTANT_INVITE":  0x00000001
  "KICK_MEMBERS":           0x00000002
  "BAN_MEMBERS":            0x00000004
  "ADMINISTRATOR":          0x00000008
  "MANAGE_CHANNELS":        0x00000010
  "MANAGE_GUILD":           0x00000020
  "ADD_REACTION":           0x00000040
  "READ_MESSAGES":          0x00000400
  "SEND_MESSAGES":          0x00000800
  "SEND_TTS_MESSAGES":      0x00001000
  "MANAGE_MESSAGES":        0x00002000
  "EMBED_LINKS":            0x00004000
  "ATTACH_FILES":           0x00008000
  "READ_MESSAGE_HISTORY":   0x00010000
  "MENTION_EVERYONE":       0x00020000
  "USE_EXTERNAL_EMOJIS":    0x00040000
  "CONNECT":                0x00100000
  "SPEAK":                  0x00200000
  "MUTE_MEMBERS":           0x00400000
  "DEAFEN_MEMBERS":         0x00800000
  "MOVE_MEMBERS":           0x01000000
  "USE_VAD":                0x02000000
  "CHANGE_NICKNAME":        0x04000000
  "MANAGE_NICKNAMES":       0x08000000
  "MANAGE_ROLES":           0x10000000
  "MANAGE_WEBHOOKS":        0x20000000
  "MANAGE_EMOJIS":          0x40000000
}

Constants.channelTypes = {
  text: 0
  DirectMessage: 1
  voice: 2
  groupDirectMessage: 3
}

Constants.gateway = {
  PacketCodes: {

  }
  PacketTypes: {

  }
}

Constants.voice = {
  PacketCodes: {
    IDENTIFY: 0
    SELECT_PROTOCOL: 1
    READY: 2
    HEARTBEAT: 3
    SESSION_DESC: 4
    SPEAKING: 5
  }
}

module.exports = Constants