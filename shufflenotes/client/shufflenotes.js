const frontmatterPattern = /^---\n(?:.*\n)*---\n\n/
const hexColorPattern = /^#[0-9A-F]{6}$/i

const appState = {
	shelf: {
		order: [],
		objs: {},
	},
}

const requestRandomNote = () => {
	makeHTTPGetRequest('http://127.0.0.1:3000/random_note')
}

const requestSpecificNote = (noteTitle) => {
	makeHTTPGetRequest(`http://127.0.0.1:3000/note=${noteTitle}`)
}

const makeHTTPGetRequest = (url) => {
	const Http = new XMLHttpRequest()
	Http.open("GET", url)
	Http.send()
	Http.onloadend = (e) => {
		const noteData = parseRawNoteMD(Http.responseText)
		appState.noteData = noteData
		writeNoteToPage(noteData)
	}
}

const parseRawNoteMD = (rawNoteMD) => {
	const hasFrontmatter = frontmatterPattern.test(rawNoteMD)
	const parsedParams = {}
	let content = rawNoteMD

	if (hasFrontmatter) {
		// Index of second '---'.
		const indexOfContent = rawNoteMD.indexOf('\n---')

		// Between enclosing '---' lines.
		const frontmatter = rawNoteMD.slice(4, indexOfContent)

		frontmatter.split('\n').forEach((line) => {
			parsedParams[line.split(': ')[0]] = line.split(': ')[1]
		})

		// After second '---' line and subsequent two newlines.
		content = rawNoteMD.slice(indexOfContent + 6)
	}

	return {
		params: parsedParams,
		content: content,
	}
}

const writeNoteToPage = (noteData) => {
	const contentHTML = noteData.content.replaceAll('\n', '<br>')
	noteTextDiv.innerHTML = contentHTML

	if (!isEmpty(noteData.params)) {
		noteTitleDiv.innerHTML = noteData.params.title
		const colorValues = getNoteColorValues(noteData.params.color)
		noteContainerDiv.style.backgroundColor = colorValues
	}
}

const getNoteColorValues = (colorString) => {
	const defaultColor = '#ffffff'
	if (colorString === undefined || colorString === 'DEFAULT') {
		return defaultColor
	} else if (hexColorPattern.test(colorString)) {
		return colorString
	}

	const colorMap = {
		red: '#E59086',
		orange: '#F2BE42',
		yellow: '#FEF388',
		green: '#D6FD9D',
		teal: '#B9FDEC',
		blue: '#D1EFF7',
		darkblue: '#B3CBF6',
		purple: '#D0B1F6',
		pink: '#F7D1E7',
		brown: '#E1CAAC',
		gray: '#E8EAED',
	}
	return colorMap[colorString.replaceAll(' ', '').toLowerCase()]
}

const isEmpty = (obj) => Object.keys(obj).length === 0

const pinNote = () => {
	constructShelfEntry(
		appState.noteData.params.title, appState.noteData.params.color)
}

const constructShelfEntry = (title, color) => {
	if (appState.shelf.order.includes(title)) {

	} else {
		const entry = document.createElement('div')
		entry.style.backgroundColor = getNoteColorValues(color)
		entry.onclick = makeLoadNoteFunction(title)

		appState.shelf.order.push(title)
		appState.shelf.objs[title] = entry

		const titleText = document.createTextNode(title)
		entry.appendChild(titleText)
		shelfDiv.appendChild(entry)
	}
}

const makeLoadNoteFunction = (title) => {
	const loadNoteFromShelf = (event) => {
		requestSpecificNote(title)
	}
	return loadNoteFromShelf
}


const shuffleButton = document.getElementById('shuffle_button')
const pinButton = document.getElementById('pin_button')
const noteTextDiv = document.getElementById('note_text')
const noteTitleDiv = document.getElementById('note_title')
const noteContainerDiv = document.getElementById('note_container')
const shelfDiv = document.getElementById('side_panel')
shuffleButton.onclick = requestRandomNote
pinButton.onclick = pinNote

requestRandomNote()