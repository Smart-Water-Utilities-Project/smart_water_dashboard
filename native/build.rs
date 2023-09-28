use lib_flutter_rust_bridge_codegen::{RawOpts, frb_codegen, config_parse, get_symbols_if_no_duplicates};

/// Path of output generated Dart code
const DART_OUTPUT: &str = "../lib/native/bridge_generated.dart";
/// Path of output Rust code
const RUST_OUTPUT: &str = "src/bridge_generated.rs";

const C_OUTPUT: &str = "../macos/Runner/bridge_generated.h";

fn main() {
  println!("cargo:rerun-if-changed=src/sqlite.rs");

  let raw_opts = RawOpts {
    rust_input: vec!["src/sqlite.rs".to_string()],
    dart_output: vec![DART_OUTPUT.to_string()],
    rust_output: Some(vec![RUST_OUTPUT.to_string()]),
    c_output: Some(vec![C_OUTPUT.to_string()]),
    wasm: false,
    dart_format_line_length: 120,
    ..Default::default()
  };

  let configs = config_parse(raw_opts);

  let all_symbols = get_symbols_if_no_duplicates(&configs).unwrap();
  
  frb_codegen(&configs[0], &all_symbols).unwrap()
}