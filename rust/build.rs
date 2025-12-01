use std::env;
use std::path::PathBuf;
use std::fs;

fn main() {
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap();
    let profile = env::var("PROFILE").unwrap();
    
    println!("cargo:rerun-if-changed=src/");
    
    // Determine output library name and extension
    let (lib_name, _lib_ext) = match target_os.as_str() {
        "windows" => ("godot_livekit.dll", "dll"),
        "macos" => ("libgodot_livekit.dylib", "dylib"),
        "linux" | "android" => ("libgodot_livekit.so", "so"),
        _ => panic!("Unsupported target OS: {}", target_os),
    };
    
    // Determine platform directory
    let platform_dir = match target_os.as_str() {
        "windows" => "windows",
        "macos" => "macos",
        "linux" => "linux",
        "android" => "android",
        _ => panic!("Unsupported target OS: {}", target_os),
    };
    
    println!("Building for {} ({})", platform_dir, profile);
    
    // Copy the built library to the addon directory
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let target_dir = PathBuf::from(&manifest_dir)
        .join("target")
        .join(env::var("TARGET").unwrap())
        .join(&profile);
    
    let addon_bin_dir = PathBuf::from(&manifest_dir)
        .parent().unwrap()
        .join("addons")
        .join("godot-livekit")
        .join("bin")
        .join(platform_dir);
    
    // Create addon bin directory if it doesn't exist
    fs::create_dir_all(&addon_bin_dir).ok();
    
    let source = target_dir.join(lib_name);
    let dest = addon_bin_dir.join(lib_name);
    
    println!("Will copy {} to {}", source.display(), dest.display());
}
