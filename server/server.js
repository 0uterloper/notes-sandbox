const bus = require('statebus').serve({port: 3006})
bus.http.use('/static', require('express').static('static'))

bus.fetch('all_notes', (all_notes) => {
	if (typeof all_notes.list === 'undefined') {
		all_notes.list = []
	}
})


bus('note/*').to_save = (note_obj) => {
	bus.fetch_once('all_notes', (all_notes) => {
		key = '/' + note_obj.key
		if (!all_notes.list.includes(key)) {
			all_notes.list.push(key)
		}
		bus.save(all_notes)
		bus.save.fire(note_obj)
	})
}

bus('note/*').to_delete = (delete_key, t) => {
	bus.fetch_once('all_notes', (all_notes) => {
		all_notes.list = all_notes.list.filter(key => key !== '/' + delete_key)
		bus.save(all_notes)
	})
	t.done()
}
