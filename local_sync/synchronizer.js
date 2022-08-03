const fs = require('fs')
const path = require('path')
const crypto = require('crypto')
const bus = require('statebus').serve({file_store:false})
bus.net_mount('/*', 'http://localhost:3006')

const WRITE_TO_FS = true

const fs_root = '/Users/davisfoote/Documents/obsidian/Personal notes/'

const note_key_prefix = '/note/'

const save_note = (rel_path) => {
	const abs_path = path.join(fs_root, rel_path)
	const content = fs.readFileSync(abs_path, 'utf8')

	const note_obj = bus.fetch(note_key_prefix + hash_filepath(rel_path))
	Object.assign(note_obj, {
		content: content,
		location: rel_path,
	})
	bus.save(note_obj)
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

// Utils

const is_dir = (filepath) => {
	if (!fs.existsSync(filepath)) {
		console.log(`Checked if dir for ${filepath} which does not exist.`)
		return false;
	}
	return fs.lstatSync(filepath).isDirectory()
}

const is_private = filepath => Array.from(path.basename(filepath))[0] === '.'

const is_md = filepath => path.extname(filepath) === '.md'

// Execution

// Start with a full send over. This avoids more complicated diffing for now.
recursive_save()

// Watch source for changes and keep server synchronized with source.
// For now, this cannot handle directories being renamed or deleted.
// In those cases, re-running the synchronizer will fix it.
// TODO: Implement something more graceful.
fs.watch(fs_root, {recursive: true}, (_, rel_path) => {
	if (rel_path) {
		if (is_md(rel_path)) {
			if (fs.existsSync(path.join(fs_root, rel_path))) {
				// Edit was not a path deletion.
				console.log(`Edit to file ${rel_path}`)
				save_note(rel_path)
			} else {
				// Edit was a path deletion.
				// Note: Renames trigger two events, one each for the old name
				// and the new name. This processes the deletion of the old one.
				console.log(`Deleted file ${rel_path}`)
				delete_note(rel_path)
			}
		}
	} else {
		console.error('Change to file, but rel_path unknown. No action taken.')
	}
})

write_back_changes = () => {
	bus.fetch('/all_notes', (all_notes) => {
		all_notes.list.forEach((note_key) => {
			bus.fetch(note_key, (note_obj) => {
				const abs_path = path.join(fs_root, note_obj.location)
				const server_version = note_obj.content

				if (WRITE_TO_FS) {
					fs.writeFileSync(abs_path, server_version)
				} else {
					console.log('local :', fs.readFileSync(abs_path, 'utf-8'))
					console.log('server:', server_version)
				}
			})
		})
	})
}

bus(write_back_changes)
