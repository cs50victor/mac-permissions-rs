#[cfg(target_os = "macos")]
fn main() {
    println!("cargo:rustc-link-lib=framework=AppKit");
    println!("cargo:rustc-link-lib=framework=AVFoundation");
    println!("cargo:rustc-link-lib=framework=CoreBluetooth");
    println!("cargo:rustc-link-lib=framework=CoreFoundation");
    println!("cargo:rustc-link-lib=framework=CoreLocation");
    println!("cargo:rustc-link-lib=framework=CoreGraphics");
    println!("cargo:rustc-link-lib=framework=Contacts");
    println!("cargo:rustc-link-lib=framework=EventKit");
    println!("cargo:rustc-link-lib=framework=IOKit");
    println!("cargo:rustc-link-lib=framework=Photos");
    println!("cargo:rustc-link-lib=framework=Speech");
    println!("cargo:rustc-link-lib=framework=StoreKit");

    std::env::set_var("MACOSX_DEPLOYMENT_TARGET", "10.13");

    cc::Build::new()
        .file("src/permissions.mm")
        .cpp(true)
        .std("c++14")
        .cpp_link_stdlib("libc++")
        .extra_warnings(false)
        .compile("permissions");
}

#[cfg(not(target_os = "macos"))]
fn main() {
    panic!("\n\n[[ mac-permissions-rs is ony supported on macOS ]]\n\n");
}
