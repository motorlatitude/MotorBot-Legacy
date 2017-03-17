#track obj
{
  _id: ObjectID()
  id: String
  type: String ("youtube" or "soundcloud")
  video_id: String,
  video_title: String,
  title: String,
  artist: {
    name: String,
    id: String
  },
  album: {
    name: String,
    id: String
  },
  composer: {
    name: String,
    id: String
  }
  genre: String,
  album_artist: String
  duration: Number,
  import_date: Number,
  release_date: Number,
  track_number: Number,
  disc_number: Number,
  play_count: Number,
  artwork: String,
  lyrics: String,
  user_id: String,
}

#playlist obj

{
  _id: ObjectID()
  id: String
  name: String
  description: String
  songs: [{
    id: String
    date_added: Number
    play_count: Number
    last_played: Number
  }...]
  creator: String
  create_date: Number
  followers: [user_id...]
  artwork: String
  private: Boolean
  collaborative: Boolean
}