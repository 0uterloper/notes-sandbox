fs = require 'fs'
path = require 'path'
chokidar = require 'chokidar'
jsyaml = require 'js-yaml'

bus = require('statebus').serve file_store:false
bus.net_mount '/*', 'http://localhost:3006'
bus.honk = false

WRITE_TO_FS = true

FRONTMATTER_PATTERN = /^---\n(?:.*\n)*---\n/

note_key_prefix = '/note/'

# Add a config.js file that exports fs_root, the directory where notes live.
if fs.existsSync './config.js' then fs_root = require('./config.js').fs_root
else throw new Error('Please configure fs_root (see synchronizer.coffee)')

save_note = (rel_path, msg_on_save=null) ->
  abs_path = path.join fs_root, rel_path
  content = fs.readFileSync abs_path, 'utf8'
  note_key = note_key_prefix + rel_path

  bus.fetch_once note_key, (note_obj) -> 
    if content != note_obj.content
      note_obj.content = content
      note_obj.location = rel_path
      bus.save note_obj

      if msg_on_save? then console.log msg_on_save

delete_note = (rel_path) -> bus.delete (note_key_prefix + rel_path)

register_deletions = () ->
  to_delete = []
  bus.fetch('/all_notes').list.forEach (note_key) ->
    rel_path = bus.fetch(note_key).location
    abs_path = path.join fs_root, rel_path
    if not fs.existsSync abs_path
      console.log "Deleting #{rel_path} on server (does not exist locally)."
      to_delete.push rel_path
  if not bus.loading() then to_delete.forEach delete_note

check_deletions = () ->
  bus.fetch('/all_notes').list.every (note_key) ->
    fs.existsSync path.join fs_root, (bus.fetch note_key).location

watch_local_files = () ->
  chokidar.watch fs_root, {ignored: watcher_should_ignore, cwd: fs_root}
    .on 'add', (rel_path) ->
      save_note rel_path, "Local added file #{rel_path}"
    .on 'change', (rel_path) ->
      save_note rel_path, "Local edit to file #{rel_path}"
    .on 'unlink', (rel_path) ->
      console.log "Local deleted file #{rel_path}"
      delete_note rel_path

write_back_changes = () ->
  bus.fetch('/all_notes').list.forEach (note_key) ->
    note_obj = bus.fetch note_key
    if not note_obj.location?
      # Can't write a change without a location to write.
      # In practice, this occurs during race conditions from batch
      # deletions executed locally.
      return
    abs_path = path.join fs_root, note_obj.location
    if fs.existsSync abs_path
      local = unpack_yaml_headers fs.readFileSync abs_path, 'utf-8'
      server = unpack_yaml_headers note_obj.content

      if local.content != server.content
        console.log "Server edited content of #{note_obj.location}.",
          "This should not happen. Discarding edit."
        console.log '- local :', local.content
        console.log '- server:', server.content
      else if JSON.stringify(local.params) != JSON.stringify(server.params)
        # Checking this way is lazy but should be fine since these are small,
        # human-readable YAML objects.
        console.log "Server edit to params of file #{note_obj.location}"
        new_text = repack_yaml_headers server.params, local.content
        if WRITE_TO_FS
          fs.writeFileSync abs_path, new_text
          note_obj.content = new_text
          bus.save note_obj
        else
          console.log 'WRITE_TO_FS is false, so dry-running:'
          console.log '- local :', local
          console.log '- server:', server
    else
      # For now, server doesn't create new files, so this only happens on
      # local batch delete/rename. If server creates files in the future,
      # have to somehow disambiguate here.
      return

# Utils

is_private = (filepath) -> /^\.|\/\./.test filepath
is_md = (filepath) -> path.extname(filepath) == '.md'
is_dir = (filepath) ->
  fs.existsSync(filepath) and fs.lstatSync(filepath).isDirectory()

watcher_should_ignore = (filepath) ->
  is_private(filepath) or not ['', '.md'].includes path.extname filepath

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

# Execution

bus.once register_deletions
bus () ->
  if check_deletions()
    watch_local_files()
    bus write_back_changes
    bus.forget()
