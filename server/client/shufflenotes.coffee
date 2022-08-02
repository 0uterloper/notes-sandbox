FRONTMATTER_PATTERN = /^---\n(?:.*\n)*---\n/
HEX_COLOR_PATTERN = /^#[0-9A-F]{6}$/i

SERVER_ADDRESS = 'http://127.0.0.1:3000'

DEFAULT_COLOR = '#ffffff'
COLOR_MAP =
  default: DEFAULT_COLOR
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
    COLOR_DROPDOWN()
    DIV {},
      flex: '0 0 10px'
      BUTTON {},
        id: 'pin_button'
        onClick: pin_note

dom.COLOR_DROPDOWN = ->
  DIV {},
    LABEL {},
      htmlFor: 'note_color'
      'Color:'
    select = SELECT {},
      name: 'note_color'
      id: 'note_color'
      value:
        if state['ls/note_data'].params.color?
          state['ls/note_data'].params.color.toLowerCase()
        else
          'default'
      onChange: (event) => change_note_color event.target.value
      for color of COLOR_MAP
        OPTION {},
          value: color
          color

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
      onClick: => request_specific_note entry.note_key
      entry.title

request_random_note = ->
  bus.fetch_once('/all_notes', (obj) ->
    options = obj.list
    note_key = options[Math.floor(Math.random() * options.length)]
    request_specific_note note_key
  )

request_specific_note = (note_key) ->
  bus.save
    key: 'ls/current_note_key'
    note_key: note_key

# Whenever current_note_key changes, update note_data
note_data = ->
  current_note_key = bus.fetch('ls/current_note_key').note_key
  note = bus.fetch current_note_key
  note_data = parse_raw_note_md(note.content.trim())
  note_data.params.title ?= note.location
  note_data.key = 'ls/note_data'
  bus.save note_data

parse_raw_note_md = (raw_md) =>
  [params, content] = unpack_yaml_headers raw_md
  {
    params: params
    content: content
  }

unpack_yaml_headers = (raw_md) ->
  has_frontmatter = FRONTMATTER_PATTERN.test(raw_md)
  if has_frontmatter
    content_index = raw_md.indexOf('\n---')
    [jsyaml.load(raw_md.slice('---\n'.length, content_index)),
     raw_md.slice(content_index + '\n---'.length).trimStart()]
  else
    [{}, raw_md]

repack_yaml_headers = (params, content) ->
  frontmatter = jsyaml.dump params
  '---\n' + frontmatter + '\n---\n\n' + content

edit_yaml_headers_of_current_note = (key, val) ->
  current_note_key = bus.fetch('ls/current_note_key').note_key
  bus.fetch_once(current_note_key, (note_obj) ->
    [params, content] = unpack_yaml_headers note_obj.content
    params[key] = val
    note_obj.content = repack_yaml_headers params, content
    bus.save note_obj
  )

pin_note = ->
  new_entry = {
    title: state['ls/note_data'].params.title
    color: state['ls/note_data'].params.color
  }
  bus.fetch_once 'ls/current_note_key', (obj) =>
    new_entry.note_key = obj.note_key
  if not state['ls/shelf'].some((entry) -> entry.title == new_entry.title)
    state['ls/shelf'].push new_entry

unpin_note = (title) ->
  state['ls/shelf'] =
    (entry for entry in state['ls/shelf'] when entry.title != title)

get_color_values = (color_string) ->
  if not color_string? then DEFAULT_COLOR
  else if HEX_COLOR_PATTERN.test(color_string) then color_string
  else COLOR_MAP[color_string.replaceAll(' ', '').toLowerCase()]

change_note_color = (new_color) ->
  edit_yaml_headers_of_current_note('color', new_color)
  state['ls/shelf'].forEach((entry) ->
    if entry.title == state['ls/note_data'].params.title
      entry.color = new_color
  )

init_state = ->
  bus.fetch_once 'ls/current_note_key', (obj) =>
    if not obj.note_key? then request_random_note()
  state['ls/shelf'] ?= []

init_state()
bus(note_data)
