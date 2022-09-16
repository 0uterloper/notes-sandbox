jsyaml = require 'js-yaml'
path = require 'path'
bus = require('statebus').serve
  port: 3006

bus.http.use '/static', require('express').static('static')
bus.http.get '/', (req, res) -> res.redirect '/shufflenotes'
bus.http.get '/shufflenotes',
  (req, res) -> res.sendFile path.join __dirname, '/client/shufflenotes.html'

FRONTMATTER_PATTERN = /^---\n(?:.*\n)*---\n/

slash = (key) -> if key[0] == '/' then key else '/' + key
deslash = (key) -> if key[0] == '/' then key.slice(1) else key

initialize_key_list = (key) ->
  bus.fetch key, (obj) ->
    obj.list ?= []

push_key_if_new = (list_key, obj) ->
  bus.fetch_once list_key, (list_obj) ->
    key = slash obj.key
    if not list_obj.list.includes key
      list_obj.list.push key
    bus.save list_obj

remove_key_by_value = (list_key, delete_key) ->
  bus.fetch_once list_key, (list_obj) ->
    list_obj.list = list_obj.list.filter (key) -> key != slash delete_key
    bus.save list_obj

# Logic ~copied from shufflenotes.coffee.
# TODO: Move this to a utils/common file to remove the duplication.
unpack_yaml_headers = (raw_md) ->
  has_frontmatter = FRONTMATTER_PATTERN.test(raw_md)
  if has_frontmatter
    content_index = raw_md.indexOf('\n---')
    {params: jsyaml.load(raw_md.slice('---\n'.length, content_index)),
     content: raw_md.slice(content_index + '\n---'.length).trimStart()}
  else
    {params: {}, content: raw_md}

repack_yaml_headers = (params, content) ->
  if Object.keys(params).length == 0 then content
  else
    frontmatter = jsyaml.dump params
    '---\n' + frontmatter + '---\n\n' + content

manage_list_of_keys = (key_pattern, list_key,
                       save_handlers=null, delete_handlers=null) ->
  initialize_key_list list_key
  bus(key_pattern).to_save = (obj) ->
    push_key_if_new list_key, obj
    if save_handlers? then save_handlers.forEach (fn) -> fn obj
    bus.save.fire obj
  bus(key_pattern).to_delete = (delete_key, t) ->
    remove_key_by_value list_key, delete_key
    if delete_handlers? then delete_handlers.forEach (fn) -> fn delete_key
    t.done()

manage_list_of_keys 'note/*', 'all_notes'

# Edited from https://coffeescript-cookbook.github.io/ to not modify `source`.
shuffle = (source) ->
  copy = [...source]
  if source.length < 2 then return copy
  for index in [copy.length-1..1]
    randomIndex = Math.floor Math.random() * (index + 1)
    [copy[index], copy[randomIndex]] = [copy[randomIndex], copy[index]]
  copy

# Spaced repetition

ONE_DAY = 1000 * 60 * 60 * 24

initialize_sm2_params = (note_obj, force=false) ->
  {params, content} = unpack_yaml_headers note_obj.content
  if not force and (params.sm2? or not note_obj.content?) then return note_obj
  params.sm2 =
    vf: 2.5
    num_reps: 0
    interval: 0
    next_rep: new Date().toString()
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

bus('next_note').to_fetch = (key, t) ->
  soonest = 
    note_key: null
    time: Infinity
  bus.fetch('all_notes').list.forEach (note_key) ->
    note_obj = initialize_sm2_params bus.fetch deslash note_key
    {params, content} = unpack_yaml_headers note_obj.content
    note_time = new Date(params.sm2?.next_rep).getTime()
    if note_time < soonest.time
      # If lookup failed, note_time is NaN and this is false.
      soonest.note_key = note_key
      soonest.time = note_time
  return
    key: 'next_note'
    note_key: deslash soonest.note_key  # Deslash due to statebus oddity.

bus.http.post '/v_rating/:note_key/:v_score', (req, res) ->
  try
    save_v_rating req.params.note_key, req.params.v_score
    res.end()
  catch e
    res.status(400)
    res.send(e.message)

# Ontology: the number itself is the score; the pair (note, score) is a rating.
save_v_rating = (note_key, v_score_string) ->
  note_obj = bus.fetch deslash note_key
  if not note_obj.content?
    throw new Error("Rating submitted for nonexistent note #{note_key}")
  v_score = if v_score_string == 'null' then null else parseInt v_score_string
  if not (0 <= v_score <= 5)  # v_score is out of bounds or NaN.
    # Incidentally, 0 <= null evaluates to true, so this handles the null case.
    throw new Error("Invalid v_score submitted: #{v_score_string}")

  note_obj = initialize_sm2_params note_obj

  {params, content} = unpack_yaml_headers note_obj.content
  params.sm2 = iterate_sm2_algo params.sm2, v_score
  note_obj.content = repack_yaml_headers params, content

  # Save the rating for future reference.
  note_obj.v_rating_history ?= []
  note_obj.v_rating_history.push
    date: new Date().toString()
    v_score: v_score

  bus.save note_obj
