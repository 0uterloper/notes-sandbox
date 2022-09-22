path = require 'path'
bus = require('statebus').serve
  port: 3006

bus.http.use '/static', require('express').static('static')
bus.http.get '/', (req, res) -> res.redirect '/shufflenotes'
bus.http.get '/shufflenotes',
  (req, res) -> res.sendFile path.join __dirname, '/client/shufflenotes.html'

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
