#include <string>
#include <cstring>
// Apple APIs
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>
#import <Contacts/Contacts.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreLocation/CoreLocation.h>
#import <EventKit/EventKit.h>
#import <Foundation/Foundation.h>
#import <IOKit/hidsystem/IOHIDLib.h>
#import <Photos/Photos.h>
#import <Speech/Speech.h>
#import <StoreKit/StoreKit.h>
#import <pwd.h>

/***** HELPER FUNCTIONS *****/

const std::string kAuthorized{"authorized"};
const std::string kDenied{"denied"};
const std::string kRestricted{"restricted"};
const std::string kNotDetermined{"not determined"};
const std::string kLimited{"limited"};

std::string CheckFileAccessLevel(NSString *path) {
  int fd = open([path cStringUsingEncoding:kCFStringEncodingUTF8], O_RDONLY);
  if (fd != -1) {
    close(fd);
    return kAuthorized;
  }

  if (errno == ENOENT)
    return kNotDetermined;

  if (errno == EPERM || errno == EACCES)
    return kDenied;

  return kNotDetermined;
}

PHAccessLevel GetPHAccessLevel(const std::string &type)
    API_AVAILABLE(macosx(10.16)) {
  return type == "read-write" ? PHAccessLevelReadWrite : PHAccessLevelAddOnly;
}

IOHIDRequestType GetInputMonitoringAccessType(const std::string &type)
    API_AVAILABLE(macosx(10.15)) {
  return type == "post" ? kIOHIDRequestTypePostEvent
                        : kIOHIDRequestTypeListenEvent;
}

NSURL *URLForDirectory(NSSearchPathDirectory directory) {
  NSFileManager *fm = [NSFileManager defaultManager];
  return [fm URLForDirectory:directory
                    inDomain:NSUserDomainMask
           appropriateForURL:nil
                      create:false
                       error:nil];
}

const std::string &StringFromPhotosStatus(PHAuthorizationStatus status) {
  switch (status) {
  case PHAuthorizationStatusAuthorized:
    return kAuthorized;
  case PHAuthorizationStatusDenied:
    return kDenied;
  case PHAuthorizationStatusRestricted:
    return kRestricted;
  case PHAuthorizationStatusLimited:
    return kLimited;
  default:
    return kNotDetermined;
  }
}

const std::string &
StringFromMusicLibraryStatus(SKCloudServiceAuthorizationStatus status)
    API_AVAILABLE(macosx(10.16)) {
  switch (status) {
  case SKCloudServiceAuthorizationStatusAuthorized:
    return kAuthorized;
  case SKCloudServiceAuthorizationStatusDenied:
    return kDenied;
  case SKCloudServiceAuthorizationStatusRestricted:
    return kRestricted;
  default:
    return kNotDetermined;
  }
}

std::string
StringFromSpeechRecognitionStatus(SFSpeechRecognizerAuthorizationStatus status)
    API_AVAILABLE(macosx(10.15)) {
  switch (status) {
  case SFSpeechRecognizerAuthorizationStatusAuthorized:
    return kAuthorized;
  case SFSpeechRecognizerAuthorizationStatusDenied:
    return kDenied;
  case SFSpeechRecognizerAuthorizationStatusRestricted:
    return kRestricted;
  default:
    return kNotDetermined;
  }
}

// Open a specific pane in System Preferences Security and Privacy.
void OpenPrefPane(const std::string &pane_string) {
  NSWorkspace *workspace = [[NSWorkspace alloc] init];
  NSString *pref_string = [NSString
      stringWithFormat:
          @"x-apple.systempreferences:com.apple.preference.security?%s",
          pane_string.c_str()];
  [workspace openURL:[NSURL URLWithString:pref_string]];
}

// Returns the user's home folder path.
NSString *GetUserHomeFolderPath() {
  NSString *path;
  BOOL isSandboxed =
      (nil !=
       NSProcessInfo.processInfo.environment[@"APP_SANDBOX_CONTAINER_ID"]);

  if (isSandboxed) {
    struct passwd *pw = getpwuid(getuid());
    assert(pw);
    path = [NSString stringWithUTF8String:pw->pw_dir];
  } else {
    path = NSHomeDirectory();
  }

  return path;
}

// This method determines whether or not a system preferences security
// authentication request is currently open on the user's screen and foregrounds
// it if found
bool HasOpenSystemPreferencesDialog() {
  int MAX_NUM_LIKELY_OPEN_WINDOWS = 4;
  bool isDialogOpen = false;
  CFArrayRef windowList;

  // loops for max 1 second, breaks if/when dialog is found
  for (int index = 0; index <= MAX_NUM_LIKELY_OPEN_WINDOWS; index++) {
    windowList = CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenAboveWindow, kCGNullWindowID);
    int numberOfWindows = CFArrayGetCount(windowList);

    for (int windowIndex = 0; windowIndex < numberOfWindows; windowIndex++) {
      NSDictionary *windowInfo =
          (NSDictionary *)CFArrayGetValueAtIndex(windowList, windowIndex);
      NSString *windowOwnerName = windowInfo[(id)kCGWindowOwnerName];
      NSNumber *windowLayer = windowInfo[(id)kCGWindowLayer];
      NSNumber *windowOwnerPID = windowInfo[(id)kCGWindowOwnerPID];

      if ([windowLayer integerValue] == 0 &&
          [windowOwnerName isEqual:@"universalAccessAuthWarn"]) {
        // make sure the auth window is in the foreground
        NSRunningApplication *authApplication = [NSRunningApplication
            runningApplicationWithProcessIdentifier:[windowOwnerPID
                                                        integerValue]];

        [NSRunningApplication.currentApplication
            activateWithOptions:NSApplicationActivateAllWindows];
        [authApplication activateWithOptions:NSApplicationActivateAllWindows];

        isDialogOpen = true;
        break;
      }
    }

    CFRelease(windowList);

    if (isDialogOpen) {
      break;
    }

    usleep(250000);
  }

  return isDialogOpen;
}

// Returns a status indicating whether the user has authorized Contacts
// access.
std::string ContactAuthStatus() {
  switch (
      [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts]) {
  case CNAuthorizationStatusAuthorized:
    return kAuthorized;
  case CNAuthorizationStatusDenied:
    return kDenied;
  case CNAuthorizationStatusRestricted:
    return kRestricted;
  default:
    return kNotDetermined;
  }
}

// Returns a status indicating whether the user has authorized Bluetooth access.
std::string BluetoothAuthStatus() {
  if (@available(macOS 10.15, *)) {
    switch ([CBCentralManager authorization]) {
    case CBManagerAuthorizationAllowedAlways:
      return kAuthorized;
    case CBManagerAuthorizationDenied:
      return kDenied;
    case CBManagerAuthorizationRestricted:
      return kRestricted;
    default:
      return kNotDetermined;
    }
  }

  return kAuthorized;
}

// Returns a status indicating whether the user has authorized
// input monitoring access.
std::string InputMonitoringAuthStatus() {
  if (@available(macOS 10.15, *)) {
    switch (IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)) {
    case kIOHIDAccessTypeGranted:
      return kAuthorized;
    case kIOHIDAccessTypeDenied:
      return kDenied;
    default:
      return kNotDetermined;
    }
  }

  return kAuthorized;
}

// Returns a status indicating whether the user has authorized Apple Music
// Library access.
std::string MusicLibraryAuthStatus() {
  if (@available(macOS 10.16, *)) {
    SKCloudServiceAuthorizationStatus status =
        [SKCloudServiceController authorizationStatus];
    return StringFromMusicLibraryStatus(status);
  }

  return kAuthorized;
}

// Returns a status indicating whether the user has authorized
// Calendar/Reminders access.
std::string EventAuthStatus(const std::string &type) {
  EKEntityType entity_type =
      (type == "calendar") ? EKEntityTypeEvent : EKEntityTypeReminder;

  switch ([EKEventStore authorizationStatusForEntityType:entity_type]) {
  case EKAuthorizationStatusAuthorized:
    return kAuthorized;
  case EKAuthorizationStatusDenied:
    return kDenied;
  case EKAuthorizationStatusRestricted:
    return kRestricted;
  default:
    return kNotDetermined;
  }
}

// Returns a status indicating whether the user has Full Disk Access.
std::string FDAAuthStatus() {
  NSString *home_folder = GetUserHomeFolderPath();
  NSMutableArray<NSString *> *files = [[NSMutableArray alloc]
      initWithObjects:[home_folder stringByAppendingPathComponent:
                                       @"Library/Safari/Bookmarks.plist"],
                      @"/Library/Application Support/com.apple.TCC/TCC.db",
                      @"/Library/Preferences/com.apple.TimeMachine.plist", nil];

  if (@available(macOS 10.15, *)) {
    [files addObject:[home_folder stringByAppendingPathComponent:
                                      @"Library/Safari/CloudTabs.db"]];
  }

  std::string auth_status = kNotDetermined;
  for (NSString *file in files) {
    const std::string can_read = CheckFileAccessLevel(file);
    if (can_read == kAuthorized) {
      auth_status = kAuthorized;
      break;
    } else if (can_read == kDenied) {
      auth_status = kDenied;
    }
  }

  return auth_status;
}

// Returns a status indicating whether the user has authorized
// Screen Capture access.
std::string ScreenAuthStatus() {
  std::string auth_status = kNotDetermined;
  if (@available(macOS 11.0, *)) {
    auth_status = CGPreflightScreenCaptureAccess() ? kAuthorized : kDenied;
  } else if (@available(macOS 10.15, *)) {
    auth_status = kDenied;
    NSRunningApplication *runningApplication =
        NSRunningApplication.currentApplication;
    NSNumber *ourProcessIdentifier =
        [NSNumber numberWithInteger:runningApplication.processIdentifier];

    CFArrayRef windowList =
        CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
    int numberOfWindows = CFArrayGetCount(windowList);
    for (int index = 0; index < numberOfWindows; index++) {
      // Get information for each window.
      NSDictionary *windowInfo =
          (NSDictionary *)CFArrayGetValueAtIndex(windowList, index);
      NSString *windowName = windowInfo[(id)kCGWindowName];
      NSNumber *processIdentifier = windowInfo[(id)kCGWindowOwnerPID];

      // Don't check windows owned by the current process.
      if (![processIdentifier isEqual:ourProcessIdentifier]) {
        // Get process information for each window.
        pid_t pid = processIdentifier.intValue;
        NSRunningApplication *windowRunningApplication =
            [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
        if (windowRunningApplication) {
          NSString *windowExecutableName =
              windowRunningApplication.executableURL.lastPathComponent;
          if (windowName) {
            if (![windowExecutableName isEqual:@"Dock"]) {
              auth_status = kAuthorized;
              break;
            }
          }
        }
      }
    }
    CFRelease(windowList);
  } else {
    auth_status = kAuthorized;
  }

  return auth_status;
}

// Returns a status indicating whether the user has authorized
// Camera/Microphone access.
std::string MediaAuthStatus(const std::string &type) {
  if (@available(macOS 10.14, *)) {
    AVMediaType media_type =
        (type == "microphone") ? AVMediaTypeAudio : AVMediaTypeVideo;

    switch ([AVCaptureDevice authorizationStatusForMediaType:media_type]) {
    case AVAuthorizationStatusAuthorized:
      return kAuthorized;
    case AVAuthorizationStatusDenied:
      return kDenied;
    case AVAuthorizationStatusRestricted:
      return kRestricted;
    default:
      return kNotDetermined;
    }
  }

  return kAuthorized;
}

// Returns a status indicating whether the user has authorized speech
// recognition access.
std::string SpeechRecognitionAuthStatus() {
  if (@available(macOS 10.15, *)) {
    SFSpeechRecognizerAuthorizationStatus status =
        [SFSpeechRecognizer authorizationStatus];
    return StringFromSpeechRecognitionStatus(status);
  }

  return kAuthorized;
}

// Returns a status indicating whether the user has authorized location
// access.
std::string LocationAuthStatus() {
  switch ([CLLocationManager authorizationStatus]) {
  case kCLAuthorizationStatusAuthorized:
    return kAuthorized;
  case kCLAuthorizationStatusDenied:
    return kDenied;
  case kCLAuthorizationStatusRestricted:
    return kDenied;
  default:
    return kDenied;
  }
}

// Returns a status indicating whether or not the user has authorized Photos
// access.
std::string PhotosAuthStatus(const std::string &access_level) {
  PHAuthorizationStatus status = PHAuthorizationStatusNotDetermined;

  if (@available(macOS 10.16, *)) {
    PHAccessLevel level = GetPHAccessLevel(access_level);
    status = [PHPhotoLibrary authorizationStatusForAccessLevel:level];
  } else {
    status = [PHPhotoLibrary authorizationStatus];
  }

  return StringFromPhotosStatus(status);
}

/***** EXPORTED FUNCTIONS *****/

// Returns the user's access consent status as a string.
std::string GetAuthStatus(const std::string &type) {
  std::string auth_status;

  if (type == "contacts") {
    auth_status = ContactAuthStatus();
  } else if (type == "calendar") {
    auth_status = EventAuthStatus("calendar");
  } else if (type == "reminders") {
    auth_status = EventAuthStatus("reminders");
  } else if (type == "full-disk-access") {
    auth_status = FDAAuthStatus();
  } else if (type == "microphone") {
    auth_status = MediaAuthStatus("microphone");
  } else if (type == "photos-add-only") {
    auth_status = PhotosAuthStatus("add-only");
  } else if (type == "photos-read-write") {
    auth_status = PhotosAuthStatus("read-write");
  } else if (type == "speech-recognition") {
    auth_status = SpeechRecognitionAuthStatus();
  } else if (type == "camera") {
    auth_status = MediaAuthStatus("camera");
  } else if (type == "accessibility") {
    auth_status = AXIsProcessTrusted() ? kAuthorized : kDenied;
  } else if (type == "location") {
    auth_status = LocationAuthStatus();
  } else if (type == "screen") {
    auth_status = ScreenAuthStatus();
  } else if (type == "bluetooth") {
    auth_status = BluetoothAuthStatus();
  } else if (type == "music-library") {
    auth_status = MusicLibraryAuthStatus();
  } else if (type == "input-monitoring") {
    auth_status = InputMonitoringAuthStatus();
  }

  return auth_status;
}


extern "C" {
    const char* GetAuthStatus(const char* type) {
        std::string result = ::GetAuthStatus(std::string(type));
        char* cstr = new char[result.length() + 1];
        std::strcpy(cstr, result.c_str());
        return cstr;
    }
}