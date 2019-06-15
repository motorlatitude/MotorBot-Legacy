Main = require './src/main.coffee'

class App

  constructor: () ->
    m = new Main();
    m.run();

new App();