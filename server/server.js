const bus = require('statebus').serve({port: 3006})
bus.http.use('/static', require('express').static('static'))

const initialize_key_list = (key) => {
	bus.fetch(key, (obj) => {
		if (typeof obj.list === 'undefined') {
			obj.list = []
		}
	})
}

const push_key_if_new = (list_key, obj) => {
	bus.fetch_once(list_key, (list_obj) => {
		key = '/' + obj.key
		if (!list_obj.list.includes(key)) {
			list_obj.list.push(key)
		}
		bus.save(list_obj)
	})
}

const remove_key_by_value = (list_key, delete_key) => {
	bus.fetch_once(list_key, (list_obj) => {
		list_obj.list = list_obj.list.filter(key => key !== '/' + delete_key)
		bus.save(list_obj)
	})
}

const manage_list_of_keys = (key_pattern, list_key) => {
	initialize_key_list(list_key)
	bus(key_pattern).to_save = (obj) => {
		push_key_if_new(list_key, obj)
		bus.save.fire(obj)
	}
	bus(key_pattern).to_delete = (delete_key, t) => {
		remove_key_by_value(list_key, delete_key)
		t.done()
	}
}

manage_list_of_keys('note/*', 'all_notes')
manage_list_of_keys('metadata_question/*', 'metadata_questions')
