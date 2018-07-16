APIConstants = APIConstants || {}

APIConstants.baseUrl = "https://mb.lolstat.net"


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