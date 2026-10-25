#pragma once
#import <Foundation/Foundation.h>

// Production retains its existing domain. Every explicit UI/smoke test process
// uses a fresh suite shared by all adapters, including Settings writes.
NSUserDefaults* NeonPreferences();
