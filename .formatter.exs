local_locals_without_parens = [
  route_event: 2,
  route_command: 1,
  callback: 2
]

published_locals_without_parens = [
  assert_disconnect: 1,

  refute_disconnect: 1,

  assert_join: 3,
  assert_join: 4,

  refute_join: 2,
  refute_join: 3,

  assert_leave: 1,
  assert_leave: 2,

  refute_leave: 1,
  refute_leave: 2,

  assert_push: 3,
  assert_push: 4,
  assert_push: 5,

  refute_push: 3,
  refute_push: 4,

  connect_and_assert_join: 4,
  connect_and_assert_join: 5
]

[
  inputs: ["mix.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [],
  locals_without_parens: local_locals_without_parens ++ published_locals_without_parens,
  export: [locals_without_parens: published_locals_without_parens],
  line_length: 80
]
