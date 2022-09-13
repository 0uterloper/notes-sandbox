FRONTMATTER_PATTERN = /^---\n(?:.*\n)*---\n/
HEX_COLOR_PATTERN = /^#[0-9A-F]{6}$/i

MQ_KEY_PREFIX = '/metadata_question/'

# Apparently SELECT tags can only have strings as value, not null...
NULL = 'none'

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
    for note_key in state['ls/shelf'] ? []
      SHELF_ENTRY
        note_key: note_key

dom.SHUFFLE_AREA = ->
  DIV {},
    id: 'shuffle_area'
    METADATA_QUESTION_DROPDOWN()
    if current_mq_short_label() == NULL
      BR()
    else
      METADATA_GAME()
    BUTTON_CONTAINER()
    NOTE_CONTAINER()
    BR()
    TAGS_CONTAINER()

dom.METADATA_QUESTION_DROPDOWN = ->
  DIV {},
    LABEL {},
      htmlFor: 'metadata_question'
      'Metadata question:'
    select = SELECT {},
      name: 'metadata_question'
      id: 'metadata_question'
      value: current_mq_short_label()
      onChange: (event) => set_metadata_question_by_label event.target.value
      OPTION {},
        value: NULL
        NULL
      for mq_key in all_metadata_question_keys()
        mq = bus.fetch mq_key
        OPTION {},
          value: mq.short_label
          mq.short_label

dom.METADATA_GAME = ->
  DIV {},
    "#{num_to_label()} / #{bus.fetch('/all_notes').list.length} left to label\n"
    BR()
    bus.fetch current_metadata_question_key()
      .long_question
    BR()
    BUTTON {},
      onClick: -> answer_metadata_question true
      '✅'
    BUTTON {},
      onClick: -> answer_metadata_question false
      '❌'

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
        LI "#{k}: #{v}" for k, v of current_note_headers()

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

answer_metadata_question = (answer) ->
  mq = bus.fetch current_metadata_question_key()
  if mq.type != 'bool'
    console.log("Labeling metadata of type #{mq.type} not yet implemented.")
    return
  else  # it's a bool!
    if answer
      add_to_yaml_list 'tags', mq.short_label
    else
      remove_from_yaml_list 'tags', mq.short_label

  # Advance labeling_queue
  mq = bus.fetch(current_metadata_question_key())
  mq.labeling_queue = remove_by_val mq.labeling_queue, current_note_key()

  all_notes_list = bus.fetch('/all_notes').list
  until mq.labeling_queue.length == 0 or mq.labeling_queue[0] in all_notes_list
    # Note at front of queue has been deleted; remove it from queue.
    # TODO: replace by logic on note deletion to handle this.
    mq.labeling_queue = mq.labeling_queue.slice(1)
  if mq.labeling_queue.length > 0
    request_specific_note mq.labeling_queue[0]
  bus.save(mq)

delete_metadata_question = (mq_key, wipe_from_md=true) ->
  short_label = bus.fetch(mq_key).short_label
  if short_label == current_mq_short_label()
    set_metadata_question NULL

  bus.delete mq_key
  if wipe_from_md
    bus.fetch_once '/all_notes', (all_notes) ->
      all_notes.list.forEach (note_key) ->
        bus.fetch_once note_key, (note_obj) ->
          remove_from_yaml_list 'tags', short_label, note_obj

all_metadata_question_keys = ->
  bus.fetch('/metadata_questions').list
current_metadata_question_key = ->
  bus.fetch('ls/current_metadata_question_key').mq_key
current_mq_short_label = ->
  mq_key = current_metadata_question_key()
  if mq_key == NULL then NULL else bus.fetch(mq_key).short_label
num_to_label = ->
  mq_key = current_metadata_question_key()
  if mq_key == NULL then 0 else bus.fetch(mq_key).labeling_queue.length
set_metadata_question = (mq_key) ->
  bus.save
    key: 'ls/current_metadata_question_key'
    mq_key: mq_key
set_metadata_question_by_label = (mq_label) ->
  if mq_label == NULL
    set_metadata_question(NULL)
  else
    set_metadata_question(MQ_KEY_PREFIX + mq_label)

create_metadata_question = (short_label, long_question=null, type='bool') ->
  bus.fetch_once '/all_notes', (all_notes) ->
    bus.save
      key: MQ_KEY_PREFIX + short_label
      short_label: short_label
      long_question: long_question
      type: type
      labeling_queue: shuffle all_notes.list

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
  if not current_metadata_question_key()? then set_metadata_question NULL
  state['ls/shelf'] ?= []

init_state()
