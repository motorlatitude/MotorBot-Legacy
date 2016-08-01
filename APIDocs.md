# Motorbot - Music API

This is the documentation for the music api. Motorbot's music can be controlled through these endpoints.

### Host
The base host url for the api is
```JSON
https://mb.lolstat.net/api
```
All endpoint calls should be directed via this host.

### Endpoints
List of all endpoints.

#### GET - /stopSong
##### Info
Stops the currently playing song. If no track is playing nothing happens...
##### Response
```JSON
{}
```

#### GET - /playSong
##### Info
Plays the next available song. If a song is already playing it will skip the currently playing song and play the next available song.
##### Response
```JSON
{}
```

#### GET - /prevSong
##### Info
Plays the previous available song. If a song is already playing it will stop playback and go to the previously available song and start playback.
##### Response
```JSON
{}
```

#### GET - /skipSong
##### Info
Plays the one after next available song. If a song is already playing it will stop playback and go to the next available song and start playback.
##### Response
```JSON
{}
```

#### GET - /playSong/{trackId}
##### Info
Plays the song with a specified `trackId`.
##### Response
On success:
```Javascript
{
  success: true
}
```
On failure:
```Javascript
{
  success: false,
  error: "Some Error Message"
}
```

#### GET - /playlist
##### Info
Retrieves a list of all available songs in the playlist, ordered after the timestamp in ascending order.
##### Response
```
[
  Song Objects
]
```
Song Object Format
```JSON
{
  "_id": "5786a610433f804462c6dc65",
  "videoId": "trgR8_ARPcw",
  "title": "AFI - The Embrace",
  "duration": "PT3M26S",
  "channel_id": "169555395860234240",
  "timestamp": 1468442128269,
  "status": "played"
}
```

#### GET - /playlist/{videoId}
##### Info
Adds a youtube video of a certain youtube video id `videoId` to the music playlist, if MotorBot is currently not playing anything, it will start playing from the original end of the playlist. i.e. If you stopped playing songs half way through the playlist, motorbot will continue form there.
##### Response
On success:
```Javascript
{
  added: true
}
```
On failure:
```Javascript
{
  added: false,
  error: "Some Error Message"
}
```
