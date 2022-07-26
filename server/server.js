const bus = require('statebus').serve({port: 3006})
bus.http.use('/static', require('express').static('static'))
