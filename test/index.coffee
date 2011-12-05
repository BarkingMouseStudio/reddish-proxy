vows = require('vows')
assert = require('assert')

vows.describe('Proxy').addBatch

  'connect':
     topic: true
     
     'connect to redis': (topic) ->
       assert.isTrue(topic)
     
     'connect to reddish': (topic) ->
       assert.isTrue(topic)
    
.export(module)
