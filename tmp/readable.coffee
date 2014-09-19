Readable = require('readable-stream').Readable
Readable2 = require('stream').Readable

stream = new Readable
console.log stream instanceof Readable2

stream = new Readable2
console.log stream instanceof Readable
