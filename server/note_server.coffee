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
get_yaml_headers = (raw_md) ->
  has_frontmatter = FRONTMATTER_PATTERN.test raw_md
  if has_frontmatter
    jsyaml.load raw_md.slice('---\n'.length, raw_md.indexOf '\n---')
  else {}

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
            tags = get_yaml_headers(note_obj.content).tags
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
