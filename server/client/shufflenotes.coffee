FRONTMATTER_PATTERN = /^---\n(?:.*\n)*---\n/
HEX_COLOR_PATTERN = /^#[0-9A-F]{6}$/i

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
    position: 'absolute'
    top: 0
    bottom: 0
    width: '100%'
    display: 'flex'
    SIDE_PANEL()
    SHUFFLE_AREA()

dom.SIDE_PANEL = ->
  DIV {},
    flex: '1 1 200px'
    wordWrap: 'break-word'
    borderRight: '1px solid gray'
    DIV {},
      fontSize: 12
      color: if state['ls/spaced_repetition_active'] then 'black' else 'white'
      margin: '10px'
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
    flex: '5 5 200px'
    padding: '10px'
    BUTTON_CONTAINER()
    NOTE_CONTAINER()
    BR()
    TAGS_CONTAINER()

dom.BUTTON_CONTAINER = ->
  DIV {},
    margin: 'auto'
    width: '400px'
    display: 'flex'
    DIV {},
      flex: '0 0 10px'
      BUTTON {},
        onClick: request_random_note
        '🔀'
    SPACED_REPETITION_CONTROLS()
    DIV flex: '1 0 0px'  # Spacer.
    COLOR_DROPDOWN()
    DIV {},
      flex: '0 0 10px'
      BUTTON {},
        onClick: pin_current_note
        '📌'

dom.SPACED_REPETITION_CONTROLS = ->
  DIV {},
    display: 'flex'
    id: 'spaced_repetition_controls_container'
    if state['ls/spaced_repetition_active']
      num_unrated = num_unrated_notes()
      DIV {},
        BUTTON '🌝', onClick: -> state['ls/spaced_repetition_active'] = false
        BUTTON '⓪', onClick: -> score_note 0
        BUTTON '①', onClick: -> score_note 1
        BUTTON '②', onClick: -> score_note 2
        BUTTON '③', onClick: -> score_note 3
        BUTTON '④', onClick: -> score_note 4
        BUTTON '⑤', onClick: -> score_note 5
        BUTTON '➡', onClick: -> score_note null
        if num_unrated > 0 then " (#{num_unrated} new)"
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
    margin: 'auto'
    width: '400px'
    border: '1px solid gray'
    padding: '10px'
    borderRadius: '5px'
    marginTop: '5px'
    backgroundColor: get_color_values note_color()
    DIV {},
      fontSize: 'large'
      fontWeight: 'bold'
      fontFamily: 'Futura'
      A {},
        textDecoration: 'none'
        href: encode_obsidian_link()
        '🖊'
      ' ' + note_title()
    BR()
    DIV {},
      fontSize: 'small'
      fontFamily: 'Verdana'
      whiteSpace: 'pre-wrap'
      current_note_text()

dom.TAGS_CONTAINER = ->
  DIV {},
    margin: 'auto'
    width: '400px'
    DIV {},
      fontSize: 'medium'
      fontFamily: 'Verdana'
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

random_choice = (list) ->
  list[Math.floor(Math.random() * list.length)]

request_random_note = ->
  bus.fetch_once '/all_notes', (all_notes) ->
    request_specific_note random_choice all_notes.list

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

ONE_DAY = 1000 * 60 * 60 * 24

initialize_sm2_params = (note_obj, force=false) ->
  {params, content} = unpack_yaml_headers note_obj.content
  if not force and (params.sm2? or not note_obj.content?) then return note_obj
  params.sm2 =
    vf: 2.5
    num_reps: 1
    interval: ONE_DAY
    next_rep: new Date(new Date().getTime() + ONE_DAY).toString()
  note_obj.content = repack_yaml_headers params, content
  bus.save note_obj
  note_obj

iterate_sm2_algo = (sm2_params, v_score) ->
  if sm2_params.num_reps == 0
    sm2_params.interval = ONE_DAY
  else if sm2_params.num_reps == 1
    sm2_params.interval = 6 * ONE_DAY
  else
    sm2_params.interval *= sm2_params.vf
  sm2_params.num_reps += 1

  if v_score?
    sm2_params.vf = sm2_params.vf + (0.1 - v_score * (0.08 + v_score * 0.02))
    if sm2_params.vf < 1.3 then sm2_params.vf = 1.3

    if v_score >= 3
      sm2_params.num_reps = 0

  sm2_params.next_rep = 
    new Date(new Date().getTime() + sm2_params.interval).toString()
  
  sm2_params

request_next_note = (excluding=null) ->
  soonest =
    note_keys: []
    day: Infinity
  bus.fetch_once '/all_notes', (all_notes) ->
    count = remaining: all_notes.list.length
    all_notes.list.forEach (note_key) ->
      if excluding == note_key then count.remaining--
      else bus.fetch_once note_key, (note_obj) ->
        initialize_sm2_params note_obj
        {params, content} = unpack_yaml_headers note_obj.content
        # Group notes scheduled for the same day.
        note_day = new Date(params.sm2?.next_rep).getTime() // ONE_DAY
        if note_day == soonest.day
          soonest.note_keys.push note_key
        else if note_day < soonest.day
          soonest.note_keys = [note_key]
          soonest.day = note_day
        if --count.remaining <= 0
          # Pick a random note among the ones scheduled for the soonest day.
          request_specific_note random_choice soonest.note_keys

score_note = (v_score) ->
  note_key = current_note_key()
  request_next_note note_key
  bus.fetch_once note_key, (note_obj) ->
    if not (0 <= v_score <= 5)  # v_score is out of bounds or NaN.
      # Incidentally, 0 <= null evaluates to true; this handles the null case.
      throw new Error("Invalid v_score submitted: #{v_score}")

    initialize_sm2_params note_obj

    {params, content} = unpack_yaml_headers note_obj.content
    params.sm2 = iterate_sm2_algo params.sm2, v_score
    note_obj.content = repack_yaml_headers params, content

    # Save the rating for future reference.
    note_obj.v_rating_history ?= []
    note_obj.v_rating_history.push
      date: new Date().toString()
      v_score: v_score

    bus.save note_obj

num_unrated_notes = ->
  unrated = count: 0
  bus.fetch('/all_notes').list.forEach (note_key) ->
    note_obj = bus.fetch note_key
    if not note_obj.v_rating_history then unrated.count++
  unrated.count

# Execution

init_state = ->
  if not current_note_key()? then request_random_note()
  state['ls/shelf'] ?= []

init_state()
