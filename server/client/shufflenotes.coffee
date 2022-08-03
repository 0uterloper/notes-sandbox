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
    for note_key in state['ls/shelf'] ? []
      SHELF_ENTRY
        note_key: note_key

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
        onClick: pin_current_note

dom.COLOR_DROPDOWN = ->
  DIV {},
    LABEL {},
      htmlFor: 'note_color'
      'Color:'
    select = SELECT {},
      name: 'note_color'
      id: 'note_color'
      value: current_note_color()
      onChange: (event) => change_current_note_color event.target.value
      for color of COLOR_MAP
        OPTION {},
          value: color
          color

dom.NOTE_CONTAINER = ->
  DIV {},
    id: 'note_container'
    backgroundColor: get_color_values current_note_color()
    DIV {},
      id: 'note_title'
      current_note_title()
    BR()
    DIV {},
      id: 'note_text'
      current_note_text()

dom.TAGS_CONTAINER = ->
  DIV {},
    id: 'tags_container'
    DIV {},
      id: 'tags_text'
      'Tags:'
      UL {},
        LI "#{k}: #{v}" for k, v of current_note_headers()

dom.SHELF_ENTRY = (note_key) ->
  entry = bus.fetch(note_key)
  DIV {},
    display: 'flex'
    backgroundColor: get_color_values read_header(entry.content, 'color')
    BUTTON {},
      color: 'red'
      onClick: => unpin_note note_key
      'x'
    DIV {},
      onClick: => request_specific_note entry.key
      read_header(entry.content, 'title') ? entry.location

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

current_note_key = -> bus.fetch('ls/current_note_key').note_key
current_note = -> bus.fetch current_note_key()
current_note_text = -> unpack_yaml_headers(current_note().content).content
current_note_headers = -> unpack_yaml_headers(current_note().content).params
current_note_color = -> read_header(current_note().content, 'color') ? 'default'
current_note_title = ->
  note = current_note()
  read_header(note.content, 'title') ? note.location

unpack_yaml_headers = (raw_md) ->
  has_frontmatter = FRONTMATTER_PATTERN.test(raw_md)
  if has_frontmatter
    content_index = raw_md.indexOf('\n---')
    {params: jsyaml.load(raw_md.slice('---\n'.length, content_index)),
     content: raw_md.slice(content_index + '\n---'.length).trimStart()}
  else
    {params: {}, content: raw_md}

repack_yaml_headers = (params, content) ->
  frontmatter = jsyaml.dump params
  '---\n' + frontmatter + '\n---\n\n' + content

edit_yaml_header_of_current_note = (key, val) ->
  note_obj = current_note()
  {params, content} = unpack_yaml_headers note_obj.content
  params[key] = val
  note_obj.content = repack_yaml_headers params, content
  bus.save note_obj

read_header = (raw_md, key) ->
  unpack_yaml_headers(raw_md).params[key]

pin_current_note = -> pin_note current_note_key()

pin_note = (note_key) ->
  if not state['ls/shelf'].some((nk) -> nk == note_key)
    state['ls/shelf'].push note_key

unpin_note = (note_key) ->
  state['ls/shelf'] = (nk for nk in state['ls/shelf'] when nk != note_key)

get_color_values = (color_string) ->
  if not color_string? then DEFAULT_COLOR
  else if HEX_COLOR_PATTERN.test(color_string) then color_string
  else COLOR_MAP[color_string.replaceAll(' ', '').toLowerCase()]

change_current_note_color = (new_color) ->
  edit_yaml_header_of_current_note('color', new_color)

init_state = ->
  if not current_note_key()? then request_random_note()
  state['ls/shelf'] ?= []

init_state()