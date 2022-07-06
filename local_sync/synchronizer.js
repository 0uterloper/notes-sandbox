const fs = require('fs')
const http = require('http')
const path = require('path')

const fsRoot = '/Users/davisfoote/Documents/obsidian/Personal notes/'


// Utils

const checkIfDir = (filepath) => {
	if (!fs.existsSync(filepath)) {
		console.log(`Checked if dir for ${filepath} which does not exist.`)
		return false;
	}
	return fs.lstatSync(filepath).isDirectory()
}

const checkIfPrivate = filepath => Array.from(filepath)[0] === '.'


// HTTP code

const recursivelyPutDir = (pathFromRoot) => {
	dirPath = path.join(fsRoot, pathFromRoot)
	fs.readdirSync(dirPath).forEach(filename => {
		if (!checkIfPrivate(filename)) {
			const relPath = path.join(pathFromRoot, filename)
			putAddition(relPath)
			if (checkIfDir(path.join(fsRoot, relPath))) {
				recursivelyPutDir(relPath)
			}
		}
	})
}

const putAddition = (filename) => {
	const isDirectory = checkIfDir(path.join(fsRoot, filename))
	var content = null;
	if (!isDirectory) {
		content = fs.readFileSync(path.join(fsRoot, filename), 'utf8')
	}
	putReq({
		name: filename,
		isDirectory: isDirectory,
		type: 'addition',
		content: content,
	})
}

const putDeletion = (filename) => {
	putReq({
		name: filename,
		type: 'deletion',
	})
}

const putReq = (dataObj) => {
	const options = {
		host: 'localhost',
		port: 3000,
		path: '/upload',
		method: 'PUT',
	}

	const req = http.request(options, res => {
		console.log(
			`${dataObj.type} at ${dataObj.name}. STATUS: ${res.statusCode}`)
	})
	req.on('error', console.error)
	req.write(JSON.stringify(dataObj))
	req.end()
}


// Execution

// Start by doing a full send over. This avoids more complicated diffing for now.
recursivelyPutDir('.')

// Watch source for changes and keep server synchronized with source.
//
// In some brief testing, the eventType arg doesn't work. Easy to handle manually.
// Docs say filename is also unreliable. I haven't seen issues yet, but I will at
// least add logging to catch if filename is null. If this happens, I can implement
// some kind of full sync.
fs.watch(fsRoot, {recursive: true}, (eventType, filename) => {
	if (Array.from(filename)[0] === '.') {
		// Private file; ignore.
		return
	}
	if (filename) {
		// console.log(`Change to file ${filename}`)
		const sourcePath = path.join(fsRoot, filename)
		if (fs.existsSync(sourcePath)) {
			// Edit was not a path deletion.
			putAddition(filename)
		} else {
			// Edit was a path deletion.
			// Note: file renames trigger two events, one for the old name and one
			// for the new name. This will process the deletion of the old name.
			putDeletion(filename)
		}
	} else {
		console.error(`Change to file, but filename not known. No action taken.`)
	}
})
