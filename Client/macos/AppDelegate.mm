//
//  AppDelegate.m
//  SonyHeadphonesClient
//
//  Created by Sem Visscher on 01/12/2020.
//

#import "AppDelegate.h"

@interface AppDelegate ()


@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _window = [[[NSApplication sharedApplication] windows] firstObject];
    _window.delegate = self;
    _window.titlebarAppearsTransparent = YES;
    _window.titleVisibility = NSWindowTitleHidden;
    _window.movableByWindowBackground = YES;
    _window.backgroundColor = NSColor.windowBackgroundColor;
    if (@available(macOS 11.0, *)) {
        _window.toolbarStyle = NSWindowToolbarStyleUnified;
    }
    if (@available(macOS 10.12, *)) {
        _window.tabbingMode = NSWindowTabbingModeDisallowed;
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    if (flag) {
        return NO;
    }
    else {
        [_window makeKeyAndOrderFront:self];
        return YES;
    }
}

- (BOOL)windowShouldClose:(id)sender {
    [_window orderOut:self];
    return NO;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
