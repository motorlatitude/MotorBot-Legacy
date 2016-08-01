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

#### GET - /playSong/{trackId}
##### Info
Plays the song with a specified `trackId`.
##### Response
On success:
```JSON
{
  success: true
}
```
On failure:
```JSON
{
  success: false,
  error: "No trackId supplied"
}
```

