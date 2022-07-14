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
    for entry in state['ls/shelf'] ? []
      SHELF_ENTRY
        entry: entry

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
    backgroundColor: if state['ls/note_data']? 
      get_color_values state['ls/note_data'].params.color
    DIV {},
      id: 'note_title'
      if state['ls/note_data']? then state['ls/note_data'].params.title ? ''
    BR()
    DIV {},
      id: 'note_text'
      if state['ls/note_data']? then state['ls/note_data'].content

dom.TAGS_CONTAINER = ->
  DIV {},
    id: 'tags_container'
    DIV {},
      id: 'tags_text'
      'Tags:'
      UL {},
        if state['ls/note_data']?
          LI "#{k}: #{v}" for k, v of JSON.parse state['ls/note_data'].params

dom.SHELF_ENTRY = (entry) ->
  DIV {},
    display: 'flex'
    backgroundColor: get_color_values entry.color
    BUTTON {},
      color: 'red'
      onClick: => unpin_note entry.title
      'x'
    DIV {},
      onClick: => request_specific_note entry.title
      entry.title

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
    state['ls/note_data'] = note_data

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
  title = state['ls/note_data'].params.title
  color = state['ls/note_data'].params.color
  if not state['ls/shelf'].some((entry) -> entry.title == title)
    state['ls/shelf'].push
      title: title
      color: color

unpin_note = (title) ->
  state['ls/shelf'] =
    (entry for entry in state['ls/shelf'] when entry.title != title)

init_state = ->
  if not state['ls/note_data']? then request_random_note()
  state['ls/shelf'] ?= []

get_color_values = (color_string) ->
  default_color = '#ffffff'
  color_map =
    red: '#E59086'
    orange: '#F2BE42'
    yellow: '#FEF388'
    green: '#D6FD9D'
    teal: '#B9FDEC'
    blue: '#D1EFF7'
    darkblue: '#B3CBF6'
    purple: '#D0B1F6'
    pink: '#F7D1E7'
    brown: '#E1CAAC'
    gray: '#E8EAED'
    default: default_color

  if not color_string? then default_color
  else if HEX_COLOR_PATTERN.test(color_string) then color_string
  else color_map[color_string.replaceAll(' ', '').toLowerCase()]

init_state()
