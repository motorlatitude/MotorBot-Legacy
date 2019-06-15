
class Debug

  constructor: (@debug_level = "verbose") ->


  write: (msg, level = "Debug.coffee") ->
    if (process.env.NODE_ENV != 'test')
      if level == "info"
        level = "\x1b[34m[INFO ]\x1b[0m"
      else if level == "error"
        level = "\x1b[31m[ERROR]\x1b[0m"
      else if level == "warn"
        level = "\x1b[5m\x1b[33m[WARN ]\x1b[0m"
      else if level == "notification"
        level = "\x1b[5m\x1b[35m[NOTIF]\x1b[0m"
      else if level == "Debug.coffee"
        level = "\x1b[38;5;244m[DEBUG]"
      d = new Date()
      time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] "
      if @debug_level == "verbose" then console.log(level+time+msg+"\x1b[0m")
      else if @debug_level == "cmd" then @debug_output_list.push(level+time+msg+"\x1b[0m")

module.exports = Debug