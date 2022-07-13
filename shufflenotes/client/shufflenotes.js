// Generated by CoffeeScript 2.7.0
var FRONTMATTER_PATTERN, HEX_COLOR_PATTERN, SERVER_ADDRESS, SHELF_ENTRY, make_get_request, parse_params, parse_raw_note_md, pin_note, request_random_note, request_specific_note, reset_state, unpin_note;

FRONTMATTER_PATTERN = /^---\n(?:.*\n)*---\n\n/;

HEX_COLOR_PATTERN = /^#[0-9A-F]{6}$/i;

SERVER_ADDRESS = 'http://127.0.0.1:3000';

dom.BODY = function() {
  return MAIN_CONTAINER();
};

dom.MAIN_CONTAINER = function() {
  return DIV({}, {
    id: 'main_container',
    display: 'flex'
  }, SIDE_PANEL(), SHUFFLE_AREA());
};

dom.SIDE_PANEL = function() {
  var title;
  return DIV({}, {
    id: 'side_panel'
  }, (function() {
    var i, len, ref, results;
    ref = state.shelf;
    results = [];
    for (i = 0, len = ref.length; i < len; i++) {
      title = ref[i];
      results.push(SHELF_ENTRY(title));
    }
    return results;
  })());
};

dom.SHUFFLE_AREA = function() {
  return DIV({}, {
    id: 'shuffle_area'
  }, BUTTON_CONTAINER(), NOTE_CONTAINER(), BR(), TAGS_CONTAINER());
};

dom.BUTTON_CONTAINER = function() {
  return DIV({}, {
    id: 'button_container',
    display: 'flex'
  }, DIV({}, {
    flex: '0 0 10px'
  }, BUTTON({}, {
    id: 'shuffle_button',
    onClick: request_random_note
  })), DIV({}, {
    flex: '1 1 100px'
  }), DIV({}, {
    flex: '0 0 10px'
  }, BUTTON({}, {
    id: 'pin_button',
    onClick: pin_note
  })));
};

dom.NOTE_CONTAINER = function() {
  var ref;
  return DIV({}, {
    id: 'note_container'
  }, DIV({}, {
    id: 'note_title'
  }, state.note_data != null ? (ref = state.note_data.params.title) != null ? ref : '' : void 0), BR(), DIV({}, {
    id: 'note_text'
  }, state.note_data != null ? state.note_data.content : void 0));
};

dom.TAGS_CONTAINER = function() {
  var k, v;
  return DIV({}, {
    id: 'tags_container'
  }, DIV({}, {
    id: 'tags_text'
  }, 'Tags:', UL({}, (function() {
    var ref, results;
    if (state.note_data != null) {
      ref = JSON.parse(state.note_data.params);
      results = [];
      for (k in ref) {
        v = ref[k];
        results.push(LI(`${k}: ${v}`));
      }
      return results;
    }
  })())));
};

SHELF_ENTRY = function(title) {
  return DIV({}, {
    display: 'flex'
  }, BUTTON({}, {
    color: 'red',
    onClick: () => {
      return unpin_note(title);
    }
  }, 'x'), DIV({}, {
    onClick: () => {
      return request_specific_note(title);
    }
  }, title));
};

request_random_note = function() {
  // Not yet implementing SB6 on server; still using XHR for now.
  return make_get_request('/random_note');
};

request_specific_note = function(title) {
  return make_get_request(`/note=${title}`);
};

make_get_request = function(url) {
  var req;
  req = new XMLHttpRequest();
  req.open('GET', SERVER_ADDRESS + url);
  req.send();
  return req.onloadend = () => {
    var note_data;
    note_data = parse_raw_note_md(req.responseText.trim());
    return state.note_data = note_data;
  };
};

parse_raw_note_md = (raw_md) => {
  var content, content_index, frontmatter, has_frontmatter, parsed_params;
  has_frontmatter = FRONTMATTER_PATTERN.test(raw_md);
  content = raw_md;
  if (has_frontmatter) {
    content_index = raw_md.indexOf('\n---');
    frontmatter = raw_md.slice(4, content_index);
    parsed_params = parse_params(frontmatter.split('\n'));
    content = raw_md.slice(content_index + 6);
  }
  return {
    params: parsed_params,
    content: content
  };
};

parse_params = function(params_strings) {
  var i, k, len, line, params_pairs, result, v;
  params_pairs = (function() {
    var i, len, results;
    results = [];
    for (i = 0, len = params_strings.length; i < len; i++) {
      line = params_strings[i];
      results.push(line.split(': '));
    }
    return results;
  })();
  result = {};
  for (i = 0, len = params_pairs.length; i < len; i++) {
    [k, v] = params_pairs[i];
    (result[k] = v);
  }
  return result;
};

// This will not work for a note with no title.
// TODO: Catch no-title case or enforce invariant.
pin_note = function() {
  var title;
  title = state.note_data.params.title;
  if (!state.shelf.includes(title)) {
    return state.shelf.push(title);
  }
};

unpin_note = function(title) {
  var t;
  return state.shelf = (function() {
    var i, len, ref, results;
    ref = state.shelf;
    results = [];
    for (i = 0, len = ref.length; i < len; i++) {
      t = ref[i];
      if (t !== title) {
        results.push(t);
      }
    }
    return results;
  })();
};

reset_state = function() {
  return state.shelf = [];
};

reset_state();

request_random_note();
