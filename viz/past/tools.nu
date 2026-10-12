#!/usr/bin/nu
#
# Alter an SVG file so that every <path> element with a `style=` attribute,
# if that style attribute features a `fill: $colorstr;` pair, it will
# have a `data-id="$colorstr"` attribute set, and its style reset to a
# default value.
#
# This is so we can draw maps with ggplot2 and geom_sf() with a custom
# fill palette such that the color strings are equal to some arbitrarily
# assigned "color id" column. We store a CSV of, for example,
#
# govt_name, govt_type, color_id
#
# So we know which government goes with which data-id.
#
# Now, when we use JS to `document.querySelect('[data-id=$colorstr]')`
# we'll get the right feature.
#
# (
# Or set of features, using `querySelectAll`. There is at least one case
# where a county is thin enough that the circle for a city in it cuts it
# into two non-contiguous features. Fortunately, the should both have the
# same data-id, so we can just iterate over the returned NodeCollection
# or whatever and process each one similarly.
# )

# Disclaimer:
#
# I'm not super great at reading Nushell, so this documentation is kind of
# verbose, and errs on the side of the
#
# ```{c}
# /// Add one to integer n.
# ///
# /// This function returns a value that is one greater than its input.
# fn add_one(n: i32) {
#   n + 1
# }
# ```
#
# style of documentation.

# You can set this if you want.
let default_style = {
  fill-rule: "evenodd",
  fill: "#a0a0a0",
  stroke-width: 0.35,
  stroke: "#404040",
  stroke-linecap: butt,
}

# For parsing the "key: value;" pairs in the `style=` attribute.
let style_regex = '(?<key>[-A-Za-z]+):\s+(?<value>[^;]+)'

#
# Some type assertion functions.
# 

def is [] {
  match $in {
    null => false,
    _ => true
  }
}

def "is str" [] {
  $in | describe | str starts-with "string"
}

def "is record" [] {
  $in | describe | str starts-with "record"
}

# Reads the first line from an SVG, which should just contain the
# "<?xml version="1.0" ...&c" tag.
#
# This is necessary because both `jaq` and Nushell have (different) problems
# with a raw, singleton (but not XML-closed with "/>"???) tag at the top
# of the file. We read it in separately as a plain string, keep track of it,
# and add it back later.
def read_doctype [fname: string] {
  open --raw $fname | lines | first
}

# Reads in an SVG file.
#
# This is torturous and does two less-expected things:
#
# 1. Skips the first line, but we already know what the first line is,
#    and because this will cause trouble with
# 2. Using `jaq`, and not Nushell's XML parser because Nushell does a
#    better job of interpreting the JSON put out by `jaq` than it does
#    trying to parse the XML itself.
def read_svg [fname: string] {
  (
    open --raw $fname
    | lines
    | skip 1
    | str join "\n"
    | jaq . --from xml
    | from json
  )
}

# Reassembles an SVG file from our altered data and a doctype first line.
#
# This also uses `jaq` to write the XML, again because it generates
# nicer XML.
def convert_svg [doctype: string] {
  [
    $doctype,
    (
      $in
      | to json
      | jaq . --to xml
    )
  ] | str join "\n"
}

# Turn a `{key: "value", ...}` object into a "key: value; ..." style string.
#
# We actually ended up not _really_ needing this, but it could be useful
# in the future, I guess.
def "into stylerule" [] {
  let obj = $in
  if ($obj | is str) {
    $obj
  } else {
    $obj | items {|k, v| $"($k): ($v);" } | str join " "
  }
}

# See? We only ever use "into stylerule" here.
let default_style_str = $default_style | into stylerule

# The opposite of "into stylerule". It takes a list of "key: value; ..."
# pairs and spits out a `{key: "value", ...}` object.
def parse_style [] {
  (
    $in
    | parse -r $style_regex
    | reduce --fold {} {|next, acc| $acc | insert $next.key $next.value }
  )
}

# Adjust an attributes record, if warranted.
#
# Remember that if an attributes record has a `style: "..."` entry,
# and that entry has a "fill: "#0c010r0;" key-value, then a
# `data-id: "#0c010r0"` key-value pair should be added to the record, and
# the style string itself should be rewritten with some default style.
def fix_attrs [] {
  let cur = $in
  match ($cur | get -o "style") {
    null => $cur
    $stylestr => {
      match ($stylestr | parse_style | get -o "fill") {
        null => $cur
        $fill => (
          $cur
          | update "style" $default_style_str
          | insert "data-id" $fill
        )
      }
    }
  }
}

# Updates a node's attributes record, if it has one.
def fix_node_attrs [] {
  let node = $in
  match ($node | get -o "a") {
    null => $node
    $attrs => { $node | update "a" ($attrs | fix_attrs) }
  }
}

# Recursively applies `fix_node` to all the children in the "content"
# of a given XML tag.
#
# If it doesn't have any content, it doesn't do anything.
def update_subtrees [] {
  let node = $in
  match ($node | get -o "c") {
    null => $node
    $subtree => {
      let nutree = (
        $subtree
        | each {|x| $x | fix_node }
        | where {|x| $x | is }
      )
      $node | update "c" $nutree
    }
  }
}

# Alters a node according to our aforementioned rules, as well as altering
# recursively all of its child nodes.
#
# Also, and I don't parse XML much, but there seems to be a _lot_ of blank
# (that is, entirely whitespace) text nodes in here, so this also discards
# those.
def fix_node [] {
  let node = $in

  if ($node | is str) {
    if ($node | str trim | str length) == 0 {
      null
    } else {
      $node
    }
  } else if (($node | get -o "t") != "path") {
    $node | update_subtrees
  } else {
    $node | fix_node_attrs | update_subtrees
  }
}

# Do the thing.
#
# This will read the SVG file $fname and write it, altered, to stdout.
def main [fname: string] {
  let first_line = read_doctype $fname
  let nodes = read_svg $fname
  let new_nodes = $nodes | fix_node

  $new_nodes | convert_svg $first_line
}