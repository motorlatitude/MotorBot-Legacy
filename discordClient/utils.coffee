
class Utils
  constructor: () ->

  debug: (msg,level = "debug") ->
    if (process.env.NODE_ENV == 'test')
      if level == "info"
        level = "\x1b[34m[INFO ]\x1b[0m"
      else if level == "error"
        level = "\x1b[31m[ERROR]\x1b[0m"
      else if level == "warn"
        level = "\x1b[5m\x1b[33m[WARN ]\x1b[0m"
      else if level == "debug"
        level = "\x1b[2m[DEBUG]"
      d = new Date()
      time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] "
      console.log(level+time+msg+"\x1b[0m")

module.exports = Utils
