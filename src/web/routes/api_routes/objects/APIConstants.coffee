
keys = require './../../../../../keys.json'

APIConstants = APIConstants || {}

APIConstants.baseUrl = keys.baseURL+"/api"


# ERRORS

APIConstants.errors = {
  playlist: {
    private: {
      error: "PLAYLIST_PRIVATE",
      message: "This playlist is set to private, only the owner can view it"
    }
  }
}

module.exports = APIConstants