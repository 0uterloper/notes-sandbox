const fs = require('fs')
const http = require('http')
const path = require('path')
const bus = require('statebus').serve({file_store:false})
bus.net_mount('/*', 'http://localhost:3006')

const fs_root = '/Users/davisfoote/Documents/obsidian/Personal notes/'

const save_file = (rel_path, create_parent_dirs = true) => {
	if (rel_path === '.') {
		// Special case at top of first recursive write.
		bus.state['/notes'] = mkdir_if_undefined(bus.state['/notes'])
		return
	}

	dir_obj = parse_dir_path_to_obj(path.dirname(rel_path), create_parent_dirs)
	const filepath = path.join(fs_root, rel_path)
	const basename = path.basename(filepath)
	if (is_dir(filepath)) {
		dir_obj.children[basename] = {
			is_dir: true,
			children: {},
			content: null,
		}
			// mkdir_if_undefined(dir_obj.children[basename])
	} else if (is_md(filepath)) {
		// ^Slightly hacky placeholder logic for only wanting to sync .md files.
		dir_obj.children[basename] = {
			is_dir: false,
			children: null,
			content: fs.readFileSync(filepath, 'utf8'),
		}
	}
}

// Returns null if dir doesn't exist and create_parent_dirs is false.
// Otherwise, returns the state object on server corresponding to that dir.
const parse_dir_path_to_obj = (dir_path, create_parent_dirs = false) => {
	var parent_obj = bus.state['/notes']
	if (dir_path == '.') {
		return parent_obj
	}

	dir_path.split(path.sep).forEach((child_dir) => {
		if (create_parent_dirs) {
			parent_obj.children[child_dir] = 
				mkdir_if_undefined(parent_obj.children[child_dir])
		} else if (!(child_dir in parent_obj)) {
			return null
		}
		parent_obj = parent_obj.children[child_dir]
	})

	return parent_obj
}

const mkdir_if_undefined = (x) => {
	if (typeof x === 'undefined') {
		return {
			is_dir: true,
			children: {},
			content: null,
		}
	} else {
		return x
	}
}

// This implementation is a unnecessarily quadratic. This won't matter at all
// at current scale, but could eventually.
const recursive_save = (rel_path) => {
	save_file(rel_path)
	const abs_path = path.join(fs_root, rel_path)
	if (is_dir(abs_path)) {
		fs.readdirSync(abs_path).forEach(basename => {
			if (!is_private(basename)) {
				recursive_save(path.join(rel_path, basename))
			}
		})
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

const is_private = filepath => Array.from(filepath)[0] === '.'

const is_md = filepath => path.extname(filepath) === '.md'

// Execution

// Start with a full send over. This avoids more complicated diffing for now.
recursive_save('.')

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
