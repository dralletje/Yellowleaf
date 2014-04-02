EventFlow = require 'eventflow'

class Reducer extends EventFlow  
    reduce: (arr) ->
        this.fire('reduce', values: arr).then (aha) ->
            console.log aha
            
reducer = new Reducer()
reducer.at 'reduce', (event) ->
    event.values = event.values.join '.'
    event.next()
reducer.reduce [
    'test',
    'jawh'
]
