use std::ffi::{CStr, CString};

#[derive(Debug, PartialEq)]
pub enum PermissionStatus {
    NotDetermined,
    Denied,
    Authorized,
    Restricted,
    Limited,
}

impl From<&str> for PermissionStatus {
    fn from(status: &str) -> Self {
        match status {
            "not determined" => PermissionStatus::NotDetermined,
            "denied" => PermissionStatus::Denied,
            "authorized" => PermissionStatus::Authorized,
            "restricted" => PermissionStatus::Restricted,
            "limited" => PermissionStatus::Limited,
            _ => PermissionStatus::NotDetermined,
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub enum Permission {
    // Location,
    Calendar,
    Contacts,
    // FilesAndFolders,
    FullDiskAccess,
    // Homekit,
    // MediaAndAppleMusic,
    // Passkeys,
    Photos,
    Reminders,
    Accessibility,
    // AppManagement,
    // Automation
    Bluetooth,
    Camera,
    // DeveloperTools,
    InputMonitoring,
    // LocalNetwork,
    Microphone,
    // MotionAndFitness,
    // RemoteDesktop,
    ScreenCapture,
    SpeechRecognition,
}

impl Permission {
    fn to_str(&self) -> &'static str {
        match self {
            Permission::Calendar => "calendar",
            Permission::Contacts => "contacts",
            Permission::FullDiskAccess => "full-disk-access",
            Permission::Photos => "photos",
            Permission::Reminders => "reminders",
            Permission::Accessibility => "accessibility",
            Permission::Bluetooth => "bluetooth",
            Permission::Camera => "camera",
            Permission::InputMonitoring => "input-monitoring",
            Permission::Microphone => "microphone",
            Permission::ScreenCapture => "screen",
            Permission::SpeechRecognition => "speech-recognition",
        }
    }
}

extern "C" {
    fn GetAuthStatus(type_: *const std::os::raw::c_char) -> *const std::os::raw::c_char;
}

pub fn check_permission(permission: Permission) -> anyhow::Result<String> {
    let c_type = CString::new(permission.to_str())?;
    unsafe {
        let result = GetAuthStatus(c_type.as_ptr());
        Ok(CStr::from_ptr(result).to_string_lossy().into_owned())
    }
}

pub fn has_permission(permission: Permission) -> bool {
    check_permission(permission).unwrap_or("not determined".to_owned()) == "authorized"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_application_has_calendar_permission() {
        let x = check_permission(Permission::Calendar);
        println!("--------->{:?}", x);
        assert!(x.is_ok() && x.unwrap() != "authorized");

        assert!(!has_permission(Permission::Calendar));
    }
}
