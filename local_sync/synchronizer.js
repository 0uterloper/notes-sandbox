const fs = require('fs')
const path = require('path')
const crypto = require('crypto')
const bus = require('statebus').serve({file_store:false})
bus.net_mount('/*', 'http://localhost:3006')

const WRITE_TO_FS = true

const fs_root = '/Users/davisfoote/Documents/obsidian/Personal notes/'

const note_key_prefix = '/note/'

const save_note = (rel_path, msg_on_save=null) => {
	const abs_path = path.join(fs_root, rel_path)
	const content = fs.readFileSync(abs_path, 'utf8')

	const note_obj = bus.fetch(note_key_prefix + hash_filepath(rel_path))
	bus.fetch_once(note_key_prefix + hash_filepath(rel_path), (note_obj) => {
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
	bus.delete(note_key_prefix + hash_filepath(rel_path))
}

const hash_filepath = (rel_path) => {
	// hex because base64 sometimes uses '/' and I feel like that could be a
	// problem later.
	return crypto.createHash('sha256').update(rel_path).digest('hex')
}

const recursive_save = (rel_path = '.') => {
	const abs_path = path.join(fs_root, rel_path)
	if (is_dir(abs_path)) {
		fs.readdirSync(abs_path).forEach(basename => {
			if (!is_private(basename)) {  // Ignore private directories.
				recursive_save(path.join(rel_path, basename))
			}
		})
	} else if (is_md(abs_path)) {
		save_note(rel_path)
	}
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

// Watch source for changes and keep server synchronized with source.
// For now, this cannot handle directories being renamed or deleted.
// In those cases, re-running the synchronizer will fix it.
// TODO: Implement something more graceful.
const watch_local_files = () => {
	fs.watch(fs_root, {recursive: true}, (_, rel_path) => {
		if (rel_path) {
			if (is_md(rel_path)) {
				if (fs.existsSync(path.join(fs_root, rel_path))) {
					// Edit was not a path deletion.
					save_note(rel_path, `Local edit to file ${rel_path}`)
				} else {
					// Edit was a path deletion.
					// Note: Renames trigger two events, one each for the old
					// name and the new name. This processes the deletion of the
					// old one.
					console.log(`Local deleted file ${rel_path}`)
					delete_note(rel_path)
				}
			}
		} else {
			console.error(
				'Change to file, but rel_path unknown. No action taken.')
		}
	})
}

write_back_changes = () => {
	bus.fetch('/all_notes', (all_notes) => {
		all_notes.list.forEach((note_key) => {
			bus.fetch(note_key, (note_obj) => {
				const abs_path = path.join(fs_root, note_obj.location)
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
			})
		})
	})
}

// Utils

const is_private = filepath => Array.from(path.basename(filepath))[0] === '.'
const is_md = filepath => path.extname(filepath) === '.md'
const is_dir = (filepath) => {
	return fs.existsSync(filepath) && fs.lstatSync(filepath).isDirectory()
}

// Execution

recursive_save()
bus.once(register_deletions)
bus(() => {
	if (check_deletions()) {
		watch_local_files()
		bus(write_back_changes)
		bus.forget()
	}
})

