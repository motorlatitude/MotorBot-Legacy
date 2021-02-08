
class ReactionEvent

  constructor: (@App, @Client, @Logger, type, data) ->
    self = @
    if data.user_id != "169554882674556930"
      d = new Date()
      time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
      if data.emoji.name == "downvote" || data.emoji.name == "upvote"
        if type == "add"
          self.Client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> has added the `"+data.emoji.name+"` reaction to message `"+data.message_id+"` in channel <#"+data.channel_id+">")
          #find message for user
          self.Client.channels[data.channel_id].getMessage(data.message_id).then((message) ->
            author_id = message.author.id
            karmaCollection = self.App.Database.collection("karma_points")
            karmaCollection.find({"author": author_id}).toArray((err, results) ->
              if err then return console.log err
              if results[0]
                author_karma = results[0].karma
              else
                author_karma = 0
              if data.emoji.name == "upvote"
                author_karma += 1
              else if data.emoji.name == "downvote"
                author_karma -= 1
              karma_obj = {
                author: author_id,
                karma: author_karma
              }
              self.Client.channels["432351112616738837"].sendMessage(time+"<@"+author_id+"> now has "+author_karma+" karma")
              karmaCollection.update({author: author_id}, karma_obj, {upsert: true})
            )
          ).catch((err) ->
            console.log "Couldn't retrieve message"
            console.log err
          )
        else if type == "remove"
          self.Client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> has removed the `"+data.emoji.name+"` reaction on message `"+data.message_id+"` in channel <#"+data.channel_id+">")
          #find message for user
          self.Client.channels[data.channel_id].getMessage(data.message_id).then((message) ->
            author_id = message.author.id
            karmaCollection = self.app.database.collection("karma_points")
            karmaCollection.find({"author": author_id}).toArray((err, results) ->
              if err then return console.log err
              if results[0]
                author_karma = results[0].karma
              else
                author_karma = 0
              if data.emoji.name == "upvote"
                author_karma -= 1
              else if data.emoji.name == "downvote"
                author_karma += 1
              karma_obj = {
                author: author_id,
                karma: author_karma
              }
              self.Client.channels["432351112616738837"].sendMessage(time+"<@"+author_id+"> now has "+author_karma+" karma")
              karmaCollection.update({author: author_id}, karma_obj, {upsert: true})
              self.changeNickname(message.guild_id , author_id, message.author.username, author_karma)
            )
          ).catch((err) ->
            console.log "Couldn't retrieve message"
            console.log err
          )

module.exports = ReactionEvent