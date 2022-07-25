const fs = require('fs')
const http = require('http')
const path = require('path')
const crypto = require('crypto')
const bus = require('statebus').serve({file_store:false})
bus.net_mount('/*', 'http://localhost:3006')

const fs_root = '/Users/davisfoote/Documents/obsidian/Personal notes/'

const note_key_prefix = '/note/'

const save_note = (rel_path) => {
	const abs_path = path.join(fs_root, rel_path)

	const key = note_key_prefix + hash_filepath(rel_path)
	const content = fs.readFileSync(abs_path, 'utf8')

	const note_obj = {
		content: content,
		location: rel_path,
	}
	bus.state[key] = note_obj
	console.log(bus.state['/all_notes']())
	bus.state['/all_notes'].notes[key] = note_obj
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
bus.state['/all_notes'] = {notes: {}}
recursive_save()

// Watch source for changes and keep server synchronized with source.
//
// In some brief testing, the eventType arg doesn't work. Easy to handle
// manually. Docs say filename is also unreliable. I haven't seen issues yet,
// but I will at least add logging to catch if filename is null. If this
// happens, I can implement some kind of full sync.
// fs.watch(fsRoot, {recursive: true}, (eventType, filename) => {
// 	if (Array.from(filename)[0] === '.') {
// 		// Private file; ignore.
// 		return
// 	}
// 	if (filename) {
// 		// console.log(`Change to file ${filename}`)
// 		const sourcePath = path.join(fsRoot, filename)
// 		if (fs.existsSync(sourcePath)) {
// 			// Edit was not a path deletion.
// 			putAddition(filename)
// 		} else {
// 			// Edit was a path deletion.
// 			// Note: file renames trigger two events, one for the old name and one
// 			// for the new name. This will process the deletion of the old name.
// 			putDeletion(filename)
// 		}
// 	} else {
// 		console.error(`Change to file, but filename not known. No action taken.`)
// 	}
// })
