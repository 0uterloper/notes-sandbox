const fs = require('fs')
const http = require('http')
const path = require('path')
const url = require('url')
const bus = require('statebus').serve({port: 3006})

bus.http.use('/static', require('express').static('static'))

const hostname = '127.0.0.1'
const port = 3000

const rootDir = './storage/'
const mdDir = path.join(rootDir, 'markdown')
const keepDir = path.join(mdDir, 'keep')

const shuffleDir = keepDir

const server = http.createServer((req, res) => {
	if (req.method === 'PUT') {
		handlePutReq(req, res)
	} else if (req.method === 'GET') {
		handleGetReq(req, res)
	}
})

// Being lazy here. This code is in the synchronizer.
// TODO move these to an appropriate utils file.
const checkIfDir = (filepath) => {
	if (!fs.existsSync(filepath)) {
		console.log(`Checked if dir for ${filepath} which does not exist.`)
		return false;
	}
	return fs.lstatSync(filepath).isDirectory()
}

const checkIfMD = (filepath) => filepath.split('.').pop() === 'md'


const handlePutReq = (req, res) => {
	let data = ''
	req.on('data', chunk => {
		data += chunk
	})
	req.on('end', () => {
		const parsedData = JSON.parse(data)
		console.log(`Received ${parsedData.type} at ${parsedData.name}.`)

		const targetFilepath = path.join(mdDir, parsedData.name)

		if (parsedData.type === 'addition') {
			if (parsedData.isDirectory) {
				if (!fs.existsSync(targetFilepath)) {
					fs.mkdirSync(targetFilepath)
				}
			} else {
				fs.writeFileSync(targetFilepath, parsedData.content, 'utf-8')
			}
		} else if (fs.existsSync(targetFilepath)) {
			// Deletion of file/dir that exists.
			if (fs.lstatSync(targetFilepath).isDirectory()) {
				// TODO: this crashes if the directory is not empty.
				fs.rmdirSync(targetFilepath)
			} else {
				fs.unlinkSync(targetFilepath)
			}
		}		

		res.statusCode = 200
		res.setHeader('Content-Type', 'text/plain')
		res.end()
	})
}

const handleGetReq = (req, res) => {
	res.setHeader('Access-Control-Allow-Origin', '*')
	const reqURL = decodeURI(req.url)
	console.log(reqURL)
	if (isRandomNoteRequest(req.url)) {
		res.statusCode = 200
		res.setHeader('Content-Type', 'text/plain')

		const noteOptions = []
		fs.readdirSync(shuffleDir).forEach(filename => {
			const filepath = path.join(shuffleDir, filename)
			if (!checkIfDir(filepath) && checkIfMD(filepath)) {
				noteOptions.push(filepath)
			}
		})

		let noteContent = 'no notes!';
		if (noteOptions.length) {
			const chosenFile = noteOptions[
				Math.floor(Math.random() * noteOptions.length)]
			noteContent = readNote(chosenFile)
		}

		res.end(noteContent)
	} else if (isSpecificNoteRequest(reqURL)) {
		res.setHeader('Content-Type', 'text/plain')

		// This will cause problems if a note has '=' in its name.
		const noteTitle = reqURL.split('=')[1]
		const noteFilename = noteTitle + '.md'

		targetFilepath = path.join(shuffleDir, noteFilename)

		if (fs.existsSync(targetFilepath)) {
			const noteContent = readNote(targetFilepath)
			res.statusCode = 200
			res.end(noteContent)
		} else {
			res.statusCode = 404
			console.error(`client requested nonexistent ${targetFilepath}`)
			res.end()
		}
	} else {
		console.error(`malformed request: ${reqURL}`)
	}
}

const readNote = (noteFilepath) => {
	console.log(`served ${noteFilepath}`)
	return fs.readFileSync(noteFilepath, 'utf-8')		
}

const isRandomNoteRequest = (reqURL) => reqURL === '/random_note'
const isSpecificNoteRequest = (reqURL) => {
	const re = /^\/note=/i

	// Not yet supporting multiple parameters.
	return re.test(reqURL) && !reqURL.slice(1).includes('/')
}

server.listen(port, hostname, () => {
	console.log(`Server running at http://${hostname}:${port}/`)
})