const fs = require('fs')
const path = require('path')
const chokidar = require('chokidar')
const bus = require('statebus').serve({file_store:false})
bus.net_mount('/*', 'http://localhost:3006')
bus.honk = false

const WRITE_TO_FS = true

const fs_root = '/Users/davisfoote/Documents/obsidian/Personal notes/'

const note_key_prefix = '/note/'

const save_note = (rel_path, msg_on_save=null) => {
	const abs_path = path.join(fs_root, rel_path)
	const content = fs.readFileSync(abs_path, 'utf8')

	const note_obj = bus.fetch(note_key_prefix + rel_path)
	bus.fetch_once(note_key_prefix + rel_path, (note_obj) => {
		if (content !== note_obj.content) {
			Object.assign(note_obj, {
				content: content,
				location: rel_path,
			})
			bus.save(note_obj)

			if (msg_on_save !== null) {
				console.log(msg_on_save)
			}
		}
	})
}

const delete_note = (rel_path) => {
	bus.delete(note_key_prefix + rel_path)
}

const register_deletions = () => {
	const to_delete = []
	bus.fetch('/all_notes').list.forEach((note_key) => {
		const rel_path = bus.fetch(note_key).location
		const abs_path = path.join(fs_root, rel_path)
		if (!fs.existsSync(abs_path)) {
			console.log(
				`Deleting ${rel_path} on server, which does not exist locally.`)
			to_delete.push(rel_path)
		}
	})
	if (!bus.loading()) {
		to_delete.forEach(delete_note)
	}
}

const check_deletions = () => {
	return bus.fetch('/all_notes').list.every((note_key) => {
		return fs.existsSync(path.join(fs_root, bus.fetch(note_key).location))
	})
}

const watch_local_files = () => {
	chokidar.watch(fs_root, {ignored: watcher_should_ignore, cwd: fs_root})
		.on('add', (rel_path) => {
			save_note(rel_path, `Local added file ${rel_path}`)})
		.on('change', (rel_path) => {
			save_note(rel_path, `Local edit to file ${rel_path}`)})
		.on('unlink', (rel_path) => {
			console.log(`Local deleted file ${rel_path}`)
			delete_note(rel_path)
		})
	}

write_back_changes = () => {
	bus.fetch('/all_notes').list.forEach((note_key) => {
		note_obj = bus.fetch(note_key)
		if (typeof(note_obj.location) === 'undefined') {
			// Can't write a change without a location to write.
			// In practice, this occurs during race conditions from batch
			// deletions executed locally.
			return
		}
		const abs_path = path.join(fs_root, note_obj.location)
		if (fs.existsSync(abs_path)) {
			const local_version = fs.readFileSync(abs_path, 'utf-8')
			const server_version = note_obj.content

			if (local_version !== server_version) {
				console.log(`Server edit to file ${note_obj.location}`)
				if (WRITE_TO_FS) {
					fs.writeFileSync(abs_path, server_version)
				} else {
					console.log('local :', local_version)
					console.log('server:', server_version)
				}
			}
		}
		else {
			// For now, server doesn't create new files, so this only happens on
			// local batch delete/rename. If server creates files in the future,
			// have to somehow disambiguate here.
			return
		}
	})
}

// Utils

const is_private = filepath => /^\.|\/\./.test(filepath)
const is_md = filepath => path.extname(filepath) === '.md'
const is_dir = (filepath) => {
	return fs.existsSync(filepath) && fs.lstatSync(filepath).isDirectory()
}
const watcher_should_ignore = (filepath) => {
	return is_private(filepath) || !['', '.md'].includes(path.extname(filepath))
}

// Execution

bus.once(register_deletions)
bus(() => {
	if (check_deletions()) {
		watch_local_files()
		bus(write_back_changes)
		bus.forget()
	}
})

