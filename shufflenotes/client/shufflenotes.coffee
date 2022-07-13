FRONTMATTER_PATTERN = /^---\n(?:.*\n)*---\n\n/
HEX_COLOR_PATTERN = /^#[0-9A-F]{6}$/i

SERVER_ADDRESS = 'http://127.0.0.1:3000'

dom.BODY = -> MAIN_CONTAINER()

dom.MAIN_CONTAINER = ->
  DIV {},
    id: 'main_container'
    display: 'flex'
    SIDE_PANEL()
    SHUFFLE_AREA()

dom.SIDE_PANEL = ->
  DIV {},
    id: 'side_panel'
    for title in state.shelf
      SHELF_ENTRY title

dom.SHUFFLE_AREA = ->
  DIV {},
    id: 'shuffle_area'
    BUTTON_CONTAINER()
    NOTE_CONTAINER()
    BR()
    TAGS_CONTAINER()

dom.BUTTON_CONTAINER = ->
  DIV {},
    id: 'button_container'
    display: 'flex'
    DIV {},
      flex: '0 0 10px'
      BUTTON {},
        id: 'shuffle_button'
        onClick: request_random_note
    DIV {},
      flex: '1 1 100px'
    DIV {},
      flex: '0 0 10px'
      BUTTON {},
        id: 'pin_button'
        onClick: pin_note

dom.NOTE_CONTAINER = ->
  DIV {},
    id: 'note_container'
    DIV {},
      id: 'note_title'
      if state.note_data? then state.note_data.params.title ? ''
    BR()
    DIV {},
      id: 'note_text'
      if state.note_data? then state.note_data.content

dom.TAGS_CONTAINER = ->
  DIV {},
    id: 'tags_container'
    DIV {},
      id: 'tags_text'
      'Tags:'
      UL {},
        if state.note_data?
          LI "#{k}: #{v}" for k, v of JSON.parse state.note_data.params

SHELF_ENTRY = (title) ->
  DIV {},
    display: 'flex'
    BUTTON {},
      color: 'red'
      onClick: => unpin_note title
      'x'
    DIV {},
      onClick: => request_specific_note title
      title

request_random_note = ->
  # Not yet implementing SB6 on server; still using XHR for now.
  make_get_request('/random_note')

request_specific_note = (title) ->
  make_get_request "/note=#{title}"

make_get_request = (url) ->
  req = new XMLHttpRequest()
  req.open('GET', SERVER_ADDRESS + url)
  req.send()
  req.onloadend = =>
    note_data = parse_raw_note_md(req.responseText.trim())
    state.note_data = note_data

parse_raw_note_md = (raw_md) =>
  has_frontmatter = FRONTMATTER_PATTERN.test(raw_md)
  content = raw_md

  if has_frontmatter
    content_index = raw_md.indexOf('\n---')
    frontmatter = raw_md.slice(4, content_index)
    parsed_params = parse_params(frontmatter.split('\n'))
    content = raw_md.slice(content_index + 6)

  {
    params: parsed_params
    content: content
  }

parse_params = (params_strings) ->
  params_pairs = (line.split(': ') for line in params_strings)
  result = {}
  (result[k] = v) for [k, v] in params_pairs
  result

# This will not work for a note with no title.
# TODO: Catch no-title case or enforce invariant.
pin_note = ->
  title = state.note_data.params.title
  if not state.shelf.includes title
    state.shelf.push title

unpin_note = (title) ->
  state.shelf = (t for t in state.shelf when t != title)

reset_state = ->
  state.shelf = []

reset_state()
request_random_note()
