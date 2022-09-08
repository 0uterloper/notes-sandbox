jsyaml = require 'js-yaml'
bus = require('statebus').serve
  port: 3006

bus.http.use('/static', require('express').static('static'))

FRONTMATTER_PATTERN = /^---\n(?:.*\n)*---\n/

slash = (key) -> '/' + key
deslash = (key) -> key.slice(1)

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

move_to_graveyard_and_add_labeled_notes = (delete_key) ->
  bus.fetch_once delete_key, (mq_obj) ->
    if not mq_obj.short_label?
      return  # No MQ in DB for this key.
    # Copy to metadata graveyard
    mq_obj.key = 'dead_metadata_question/' + mq_obj.short_label
    delete mq_obj.labeling_queue
    mq_obj.labeled_notes = []
    bus.save mq_obj
    bus.fetch_once 'all_notes', (all_notes) ->
      all_notes.list.forEach (note_key) ->
        bus.fetch_once deslash note_key, (note_obj) ->
          if mq_obj.type == 'bool'
            tags = unpack_yaml_headers(note_obj.content).params.tags
            if tags? and tags.includes mq_obj.short_label
              mq_obj.labeled_notes.push note_key
              bus.save mq_obj

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
manage_list_of_keys 'metadata_question/*', 'metadata_questions', null,
  [move_to_graveyard_and_add_labeled_notes]
manage_list_of_keys 'dead_metadata_question/*', 'metadata_graveyard'


# Spaced repetition

ONE_DAY = 1000 * 60 * 60 * 24

initialize_sm2_params = (note_obj) ->
  {params, content} = unpack_yaml_headers note_obj.content
  if params.sm2? then return note_obj
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
    note_key: deslash soonest.note_key

# Syntax: 'v_rating/<note_key (including 'note/')>/<numerical v score>'
bus('v_rating/*').to_save = (obj) ->
  tokens = obj.key.replace('//', '/').split('/')
  note_key = tokens.slice(1, -1).join('/')
  v_score = parseInt tokens[tokens.length - 1]
  if 0 <= v_score <= 5  # Will be false if v_score is NaN.
    note_obj = initialize_sm2_params bus.fetch note_key
    {params, content} = unpack_yaml_headers note_obj.content
    params.sm2 = iterate_sm2_algo params.sm2, v_score
    note_obj.content = repack_yaml_headers params, content

    # Save the rating for future reference.
    note_obj.v_rating_history ?= []
    note_obj.v_rating_history.push
      date: new Date().toString()
      v_score: v_score

    console.log 'HERE IT IS', note_obj
    # bus.save note_obj

  bus.save.abort obj
