const frontmatterPattern = /^---\n(?:.*\n)*---\n\n/
const hexColorPattern = /^#[0-9A-F]{6}$/i

const appState = {
	noteData: {},
	shelf: {
		order: [],     // Ordered list of titles.
		params: {},    // Mapping of titles => params objects.
		elements: {},  // Mapping of titles => DOM elements
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

		tagsTextDiv.innerHTML = formatTagsHTML(noteData.params)
	}
}

// Later, `tag` will refer to something more specific. For now, I'm just going
// to show all front matter params.
const formatTagsHTML = (params) => {
	// This implementation would be inefficient in some languages depending on
	// string concatenation behavior.
	// TODO: Look into whether this is relevant here.
	var tagsHTML = 'Tags:<ul>'
	for (const key in params) {
		tagsHTML += `<li>${key}: ${params[key]}</li>`
	}
	tagsHTML += '</ul>'
	return tagsHTML
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
	saveLocalStorageState()
}

const makeDeletePinFunction = (title) => {
	const deletePin = () => {
		// Making assumption that title is exactly once in shelf. This is 
		// currently correct, but could break if state structure changes.
		// const shelfEntries = shelfDiv.children
		// for (var i = 0; i < shelfEntries; i++) {
		// 	const element = shelfEntries[i]
		// 	const candidateTitle = element.children[0]
		// 	if (element) {
				
		// 		break
		// 	}
		// }
		// shelfDiv.
		shelfDiv.removeChild(appState.shelf.elements[title])
		appState.shelf.order = appState.shelf.order.filter((t) => t !== title)
		delete appState.shelf.params[title]
		delete appState.shelf.elements[title]
		saveLocalStorageState()
	}
	return deletePin
}

const constructShelfEntry = (title, color) => {
	if (appState.shelf.order.includes(title)) {

	} else {
		const entryContainer = document.createElement('div')
		entryContainer.style.backgroundColor = getNoteColorValues(color)
		entryContainer.classList.add('flex_container')
		
		const deleteButton = document.createElement('button')
		deleteButton.innerHTML = '❌'
		deleteButton.onclick = makeDeletePinFunction(title)
		entryContainer.appendChild(deleteButton)

		const entry = document.createElement('div')
		entry.onclick = makeLoadNoteFunction(title)
		const titleText = document.createTextNode(title)
		entry.appendChild(titleText)	
		entryContainer.appendChild(entry)

		appState.shelf.order.push(title)
		appState.shelf.params[title] = {
			color: color,
		}
		appState.shelf.elements[title] = entryContainer

		shelfDiv.appendChild(entryContainer)
	}
}

const makeLoadNoteFunction = (title) => {
	const loadNoteFromShelf = () => {
		requestSpecificNote(title)
	}
	return loadNoteFromShelf
}

const saveLocalStorageState = () => {
	localStorage.shelf = JSON.stringify(appState.shelf)
}

const loadLocalStorageState = () => {
	console.log(localStorage)
	console.log(localStorage.shelf)
	if (localStorage.shelf !== undefined) {
		const shelf = JSON.parse(localStorage.shelf)
		// Currently unnecessary but might matter later.
		resetShelf()
		shelf.order.forEach((title) => {
			constructShelfEntry(title, shelf.params[title].color)
		})
	}
}

const resetShelf = () => {
	appState.shelf = {
		order: [],
		params: {},
		elements: {},
	}
}


const shuffleButton = document.getElementById('shuffle_button')
const pinButton = document.getElementById('pin_button')
const noteTextDiv = document.getElementById('note_text')
const noteTitleDiv = document.getElementById('note_title')
const noteContainerDiv = document.getElementById('note_container')
const shelfDiv = document.getElementById('side_panel')
const tagsTextDiv = document.getElementById('tags_text')

shuffleButton.onclick = requestRandomNote
pinButton.onclick = pinNote

loadLocalStorageState()
requestRandomNote()