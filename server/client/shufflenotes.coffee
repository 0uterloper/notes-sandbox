FRONTMATTER_PATTERN = /^---\n(?:.*\n)*---\n/
HEX_COLOR_PATTERN = /^#[0-9A-F]{6}$/i

SERVER_ADDRESS = 'http://127.0.0.1:3000'

OBSIDIAN_VAULT_NAME = 'obsidian'

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

DEFAULT_NOTE =
  location: 'fake note'
  content: 'no note has loaded yet'

# DOM

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
    DIV {},
      fontSize: 12
      color: if state['ls/spaced_repetition_active'] then 'black' else 'white'
      paddingLeft: '10px'
      paddingTop: '10px'
      marginBottom: '10px'
      marginRight: '10px'
      borderBottom: '1px dashed black'
      "5 - imminently valuable for current context", BR()
      "4 - definitely valuable, not for current context", BR()
      "3 - probable future value", BR()
      "2 - possible future value", BR()
      "1 - not likely of value; don't want to discard", BR()
      "0 - no apparent reason to revisit this", BR()
      BR()
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
    SPACED_REPETITION_CONTROLS()
    DIV flex: '1 0 0px'  # Spacer.
    COLOR_DROPDOWN()
    DIV {},
      flex: '0 0 10px'
      BUTTON {},
        id: 'pin_button'
        onClick: pin_current_note

dom.SPACED_REPETITION_CONTROLS = ->
  DIV {},
    display: 'flex'
    id: 'spaced_repetition_controls_container'
    if state['ls/spaced_repetition_active']
      DIV {},
        BUTTON '🌝', onClick: -> state['ls/spaced_repetition_active'] = false
        BUTTON '⓪', onClick: -> score_note 0
        BUTTON '①', onClick: -> score_note 1
        BUTTON '②', onClick: -> score_note 2
        BUTTON '③', onClick: -> score_note 3
        BUTTON '④', onClick: -> score_note 4
        BUTTON '⑤', onClick: -> score_note 5
        BUTTON '➡', onClick: -> score_note null
    else
      BUTTON '🌚', onClick: -> state['ls/spaced_repetition_active'] = true 

dom.COLOR_DROPDOWN = ->
  DIV {},
    LABEL {},
      htmlFor: 'note_color'
      'Color:'
    select = SELECT {},
      name: 'note_color'
      id: 'note_color'
      value: note_color()
      onChange: (event) => change_current_note_color event.target.value
      for color of COLOR_MAP
        OPTION {},
          value: color
          color

dom.NOTE_CONTAINER = ->
  DIV {},
    id: 'note_container'
    backgroundColor: get_color_values note_color()
    DIV {},
      id: 'note_title'
      A {},
        textDecoration: 'none'
        href: encode_obsidian_link()
        '🖊'
      ' ' + note_title()
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
        (RECURSIVE_BULLETS k: k, v: v) for k, v of current_note_headers()

dom.RECURSIVE_BULLETS = (k, v) ->
  if v? and typeof v == 'object'
    LI "#{k}:",
    UL {},
      (RECURSIVE_BULLETS k:_k, v:_v) for _k, _v of v
  else
    LI "#{k}: #{v}"

dom.SHELF_ENTRY = (note_key) ->
  DIV {},
    display: 'flex'
    backgroundColor: get_color_values note_color note_key
    BUTTON {},
      color: 'red'
      onClick: => unpin_note note_key
      'x'
    DIV {},
      onClick: => request_specific_note note_key
      note_title note_key

# Logic

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

map_over_notes = (fn) ->
  bus.fetch_once '/all_notes', (all_notes) ->
    all_notes.list.forEach (note_key) ->
      bus.fetch_once note_key, (note) ->
        result = fn(note.content)
        if result?
          note.content = result
          bus.save note

current_note_key = -> bus.fetch('ls/current_note_key').note_key
current_note = ->
  note_key = current_note_key()
  if note_key? then bus.fetch note_key else DEFAULT_NOTE
current_note_text = -> unpack_yaml_headers(current_note().content).content
current_note_headers = -> unpack_yaml_headers(current_note().content).params
note_color = (note_key=null) ->
  note = if note_key? then bus.fetch(note_key) else current_note()
  read_header(note.content, 'color') ? 'default'
note_title = (note_key=null) ->
  note = if note_key? then bus.fetch(note_key) else current_note()
  note.location.slice(0, -'.md'.length)  # Remove extension.

unpack_yaml_headers = (raw_md) ->
  has_frontmatter = FRONTMATTER_PATTERN.test(raw_md)
  if has_frontmatter
    content_index = raw_md.indexOf('\n---')
    {params: jsyaml.load(raw_md.slice('---\n'.length, content_index)),
     content: raw_md.slice(content_index + '\n---'.length).trimStart()}
  else
    {params: {}, content: raw_md}

repack_yaml_headers = (params, content) ->
  if Object.keys(params).length == 0
    content
  else
    frontmatter = jsyaml.dump params
    '---\n' + frontmatter + '---\n\n' + content

# TODO: clean up redundant code in these three fns
edit_yaml_header_of_current_note = (key, val) ->
  note_obj = current_note()
  {params, content} = unpack_yaml_headers note_obj.content
  params[key] = val
  note_obj.content = repack_yaml_headers params, content
  bus.save note_obj

add_to_yaml_list = (key, new_val) ->
  note_obj = current_note()
  {params, content} = unpack_yaml_headers note_obj.content
  params[key] ?= []
  if new_val not in params[key]
    params[key].push(new_val)
    note_obj.content = repack_yaml_headers params, content
    bus.save note_obj

remove_from_yaml_list = (key, del_val, note_obj=null) ->
  note_obj ?= current_note()
  {params, content} = unpack_yaml_headers note_obj.content
  if params[key]?
    params[key] = params[key].filter((val) -> val != del_val)
    if params[key].length == 0 then delete params[key]
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
  else COLOR_MAP[color_string]

change_current_note_color = (new_color) ->
  edit_yaml_header_of_current_note('color', new_color)

encode_obsidian_link = ->
  vault = encodeURIComponent(OBSIDIAN_VAULT_NAME)
  file = encodeURIComponent(current_note().location)
  "obsidian://open?vault=#{vault}&file=#{file}"

# Spaced Repetition
request_next_note = ->
  bus.fetch '/next_note', (obj) -> request_specific_note obj.note_key

score_note = (v_score) ->
  post_v_rating current_note_key(), v_score
  request_next_note()

post_v_rating = (note_key, v_score) ->
  xhr = new XMLHttpRequest()
  xhr.open 'POST', "/v_rating/#{encodeURIComponent note_key}/#{v_score}"
  xhr.send()
  xhr.onloadend = -> console.log xhr.response

# Utils

# Edited from https://coffeescript-cookbook.github.io/ to not modify `source`.
shuffle = (source) ->
  copy = [...source]
  if source.length < 2 then return copy
  for index in [copy.length-1..1]
    randomIndex = Math.floor Math.random() * (index + 1)
    [copy[index], copy[randomIndex]] = [copy[randomIndex], copy[index]]
  copy

remove_by_val = (arr, val) -> arr.filter((v) -> v != val)

slash = (key) -> if key[0] == '/' then key else '/' + key
deslash = (key) -> if key[0] == '/' then key.slice(1) else key

# Execution

init_state = ->
  if not current_note_key()? then request_random_note()
  state['ls/shelf'] ?= []

init_state()
