chai = require 'chai'
chai.should()

describe 'true should equal boolean', ->
  it 'should equal boolean', ->
    true.should.be.true
