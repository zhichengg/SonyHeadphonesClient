//
//  ViewController.m
//  SonyHeadphonesClient
//
//  Created by Sem Visscher on 01/12/2020.
//

#import "ViewController.h"

static NSString * const kLastConnectedDeviceAddressKey = @"lastConnectedDeviceAddress";
static NSString * const kLastConnectedDeviceNameKey = @"lastConnectedDeviceName";
static constexpr int kXm3NoiseCancellingLevel = CommandSerializer::XM3_LEVEL_NOISE_CANCELLING;
static constexpr int kXm3WindNoiseReductionLevel = CommandSerializer::XM3_LEVEL_WIND_NOISE_REDUCTION;
static constexpr int kXm3AmbientLevelMinRaw = CommandSerializer::XM3_LEVEL_AMBIENT_MIN;
static constexpr int kXm3AmbientLevelMaxRaw = CommandSerializer::XM3_LEVEL_AMBIENT_MAX;

@interface ViewController () <NSMenuDelegate>
@property (strong) NSMenu *statusMenu;
@property (strong) NSMenuItem *connectionStatusItem;
@property (strong) NSMenuItem *showHideWindowItem;
@property (strong) NSMenuItem *connectDisconnectItem;
@property (strong) NSMenuItem *reconnectLastDeviceItem;
@property (strong) NSMenuItem *focusOnVoiceItem;
@property (strong) NSMenuItem *syncVolumeItem;
@property (strong) NSMenuItem *ancEnabledItem;
@property (strong) NSMenuItem *ancModeMenuItem;
@property (strong) NSMenu *ancModeMenu;
@property (strong) NSMenuItem *ancModeNoiseCancellingItem;
@property (strong) NSMenuItem *ancModeWindNoiseReductionItem;
@property (strong) NSMenuItem *ancModeAmbientItem;
@property (strong) NSMenuItem *ancLevelSliderItem;
@property (strong) NSSlider *ancLevelStatusSlider;
@property (strong) NSTextField *ancLevelValueLabel;
@end

@implementation ViewController
@synthesize connectedLabel, connectButton, ANCSlider, ANCValueLabel, focusOnVoice, ANCEnabled, ANCValuePrefixLabel, virtualSoundLabel, soundPositionLabel, surroundLabel, soundPosition, surround;

typedef NS_ENUM(NSInteger, XM3ANCMode) {
    XM3ANCModeNoiseCancelling = 0,
    XM3ANCModeWindNoiseReduction = 1,
    XM3ANCModeAmbientSound = 2
};

- (XM3ANCMode)currentANCMode {
    int rawLevel = ANCSlider.intValue;
    if (rawLevel == kXm3NoiseCancellingLevel) {
        return XM3ANCModeNoiseCancelling;
    }
    if (rawLevel == kXm3WindNoiseReductionLevel) {
        return XM3ANCModeWindNoiseReduction;
    }
    return XM3ANCModeAmbientSound;
}

- (int)currentAmbientLevel {
    int rawLevel = ANCSlider.intValue;
    if (rawLevel < kXm3AmbientLevelMinRaw) {
        return 20;
    }
    return rawLevel - 1; // 2..21 => 1..20
}

- (void)applyANCMode:(XM3ANCMode)mode ambientLevel:(int)ambientLevel sender:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }

    [ANCEnabled setState:NSControlStateValueOn];
    headphones->setAmbientSoundControl(TRUE);

    int rawLevel = kXm3NoiseCancellingLevel;
    switch (mode) {
        case XM3ANCModeNoiseCancelling:
            rawLevel = kXm3NoiseCancellingLevel;
            break;
        case XM3ANCModeWindNoiseReduction:
            rawLevel = kXm3WindNoiseReductionLevel;
            break;
        case XM3ANCModeAmbientSound:
            if (ambientLevel < 1) ambientLevel = 1;
            if (ambientLevel > 20) ambientLevel = 20;
            rawLevel = ambientLevel + 1; // 1..20 => 2..21
            break;
    }

    BOOL keepFocusOnVoice = (mode == XM3ANCModeAmbientSound) && ([focusOnVoice state] == NSControlStateValueOn);
    [ANCSlider setIntValue:rawLevel];
    [focusOnVoice setState:keepFocusOnVoice ? NSControlStateValueOn : NSControlStateValueOff];
    headphones->setFocusOnVoice(keepFocusOnVoice);
    headphones->setAsmLevel(rawLevel);
    [self updateHeadphones];
}

- (NSImage *)statusImageForConnected:(BOOL)connected focusModeEnabled:(BOOL)focusModeEnabled {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(18.0, 18.0) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        [[NSColor blackColor] setStroke];
        [[NSColor blackColor] setFill];

        // Headband
        NSBezierPath *headband = [NSBezierPath bezierPath];
        headband.lineWidth = 1.8;
        [headband moveToPoint:NSMakePoint(4.2, 11.2)];
        [headband curveToPoint:NSMakePoint(13.8, 11.2)
                 controlPoint1:NSMakePoint(6.0, 15.3)
                 controlPoint2:NSMakePoint(12.0, 15.3)];
        [headband stroke];

        // Left ear cup
        NSBezierPath *leftCup = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(3.5, 6.0, 3.0, 5.0) xRadius:1.0 yRadius:1.0];
        [leftCup fill];

        // Right ear cup
        NSBezierPath *rightCup = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(11.5, 6.0, 3.0, 5.0) xRadius:1.0 yRadius:1.0];
        [rightCup fill];

        if (focusModeEnabled) {
            NSBezierPath *wave = [NSBezierPath bezierPath];
            wave.lineWidth = 1.3;
            [wave moveToPoint:NSMakePoint(8.3, 4.2)];
            [wave lineToPoint:NSMakePoint(8.3, 6.1)];
            [wave moveToPoint:NSMakePoint(9.5, 3.4)];
            [wave lineToPoint:NSMakePoint(9.5, 6.8)];
            [wave moveToPoint:NSMakePoint(10.7, 4.5)];
            [wave lineToPoint:NSMakePoint(10.7, 6.0)];
            [wave stroke];
        }

        if (!connected) {
            NSBezierPath *slash = [NSBezierPath bezierPath];
            slash.lineWidth = 1.7;
            [slash moveToPoint:NSMakePoint(3.0, 14.6)];
            [slash lineToPoint:NSMakePoint(15.2, 2.5)];
            [slash stroke];
        }
        return YES;
    }];
    [image setTemplate:YES];
    return image;
}

- (void)rememberLastConnectedDeviceAddress:(NSString *)address name:(NSString *)name {
    if (address.length == 0) {
        return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:address forKey:kLastConnectedDeviceAddressKey];
    [defaults setObject:(name.length > 0 ? name : address) forKey:kLastConnectedDeviceNameKey];
}

- (NSString *)lastConnectedDeviceAddress {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kLastConnectedDeviceAddressKey];
}

- (NSString *)lastConnectedDeviceName {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kLastConnectedDeviceNameKey];
}

- (void)applyConnectedGUIForDeviceName:(NSString *)deviceName {
    NSString *safeName = (deviceName.length > 0) ? deviceName : @"Unknown Device";
    [connectedLabel setStringValue:[@"Connected: " stringByAppendingString:safeName]];
    [connectButton setTitle:@"Disconnect"];
    [ANCSlider setEnabled:TRUE];
    [ANCSlider setIntValue:kXm3AmbientLevelMaxRaw];
    [ANCEnabled setEnabled:TRUE];
    [ANCEnabled setState:TRUE];
    [focusOnVoice setEnabled:FALSE];
    [surround setEnabled:TRUE];
    [soundPosition setEnabled:TRUE];
    [virtualSoundLabel setTextColor:NSColor.labelColor];
    [surroundLabel setTextColor:NSColor.labelColor];
    [soundPositionLabel setTextColor:NSColor.labelColor];
    [ANCValuePrefixLabel setTextColor:NSColor.labelColor];
    [ANCValueLabel setTextColor:NSColor.labelColor];
}

- (BOOL)connectToDeviceAddress:(NSString *)address deviceName:(NSString *)deviceName {
    if (address.length == 0) {
        return NO;
    }

    statusItem.button.image = [self statusImageForConnected:NO focusModeEnabled:NO];
    [statusItem.button.image setTemplate:YES];

    try {
        bt.connect([address UTF8String]);
    } catch (RecoverableException& exc) {
        [self displayError:exc];
        return NO;
    }

    // wait up to ~5 seconds
    int timeout = 50;
    while (!bt.isConnected() && timeout-- >= 0) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }

    if (!bt.isConnected()) {
        [self displayDisconnectedWithText:@"Not connected, connection timed out."];
        bt.disconnect();
        return NO;
    }

    [self applyConnectedGUIForDeviceName:deviceName];
    if (headphones != nullptr) {
        delete headphones;
    }
    headphones = new Headphones(bt);
    [self applyANCMode:XM3ANCModeNoiseCancelling ambientLevel:[self currentAmbientLevel] sender:nil];
    [self rememberLastConnectedDeviceAddress:address name:deviceName];
    [self refreshStatusMenu];
    return YES;
}

- (void)refreshStatusMenu {
    BOOL connected = bt.isConnected();
    BOOL focusModeEnabled = connected && [focusOnVoice state] == NSControlStateValueOn;
    NSString *labelText = connected ? connectedLabel.stringValue : @"Not connected";
    self.connectionStatusItem.title = labelText.length > 0 ? labelText : @"Not connected";
    self.showHideWindowItem.title = self.view.window.isVisible ? @"Hide Window" : @"Show Window";
    self.connectDisconnectItem.title = connected ? @"Disconnect Headphones" : @"Connect Headphones...";
    BOOL canToggleFocusOnVoice = connected && headphones != nullptr && [ANCEnabled state] == NSControlStateValueOn && [self currentANCMode] == XM3ANCModeAmbientSound;
    self.focusOnVoiceItem.enabled = canToggleFocusOnVoice;
    self.focusOnVoiceItem.state = focusModeEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    NSString *lastAddress = [self lastConnectedDeviceAddress];
    NSString *lastName = [self lastConnectedDeviceName];
    self.reconnectLastDeviceItem.enabled = !connected && lastAddress.length > 0;
    self.reconnectLastDeviceItem.title = lastName.length > 0 ? [@"Reconnect " stringByAppendingString:lastName] : @"Reconnect Last Device";

    BOOL canControlANC = connected && headphones != nullptr;
    BOOL ancEnabled = [ANCEnabled state] == NSControlStateValueOn;
    BOOL canSetAncLevel = canControlANC && headphones->isSetAsmLevelAvailable();
    XM3ANCMode mode = [self currentANCMode];
    BOOL ambientMode = mode == XM3ANCModeAmbientSound;
    self.syncVolumeItem.enabled = connected;
    self.ancEnabledItem.enabled = canControlANC;
    self.ancEnabledItem.state = ancEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.ancModeMenuItem.enabled = canControlANC;
    self.ancModeNoiseCancellingItem.state = (mode == XM3ANCModeNoiseCancelling) ? NSControlStateValueOn : NSControlStateValueOff;
    self.ancModeWindNoiseReductionItem.state = (mode == XM3ANCModeWindNoiseReduction) ? NSControlStateValueOn : NSControlStateValueOff;
    self.ancModeAmbientItem.state = (mode == XM3ANCModeAmbientSound) ? NSControlStateValueOn : NSControlStateValueOff;

    self.ancLevelSliderItem.enabled = canSetAncLevel && ambientMode;
    self.ancLevelStatusSlider.enabled = canSetAncLevel && ambientMode;
    if (canSetAncLevel && ambientMode) {
        int ambientLevel = [self currentAmbientLevel];
        [self.ancLevelStatusSlider setIntValue:ambientLevel];
        self.ancLevelValueLabel.stringValue = [NSString stringWithFormat:@"%d", ambientLevel];
    } else {
        self.ancLevelValueLabel.stringValue = @"-";
    }

    NSImage *icon = [self statusImageForConnected:connected focusModeEnabled:focusModeEnabled];
    statusItem.button.image = icon;
    [statusItem.button.image setTemplate:YES];
}

- (IBAction)toggleWindowFromStatusItem:(id)sender {
    if (self.view.window.isVisible) {
        [self.view.window orderOut:self];
        return;
    }

    [NSApp activateIgnoringOtherApps:YES];
    [self.view.window makeKeyAndOrderFront:self];
}

- (IBAction)toggleConnectFromStatusItem:(id)sender {
    [self connectToDevice:sender];
}

- (IBAction)reconnectLastDeviceFromStatusItem:(id)sender {
    if (bt.isConnected()) {
        return;
    }
    NSString *lastAddress = [self lastConnectedDeviceAddress];
    NSString *lastName = [self lastConnectedDeviceName];
    if (lastAddress.length == 0) {
        return;
    }
    [self connectToDeviceAddress:lastAddress deviceName:(lastName.length > 0 ? lastName : lastAddress)];
}

- (IBAction)toggleANCFromStatusItem:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }
    NSControlStateValue newState = [ANCEnabled state] == NSControlStateValueOn ? NSControlStateValueOff : NSControlStateValueOn;
    [ANCEnabled setState:newState];
    [self ANCEnabledButtonChanged:sender];
}

- (IBAction)selectNoiseCancellingModeFromStatusItem:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }
    [self applyANCMode:XM3ANCModeNoiseCancelling ambientLevel:[self currentAmbientLevel] sender:sender];
}

- (IBAction)selectWindNoiseReductionModeFromStatusItem:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }
    [self applyANCMode:XM3ANCModeWindNoiseReduction ambientLevel:[self currentAmbientLevel] sender:sender];
}

- (IBAction)selectAmbientSoundModeFromStatusItem:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }
    [self applyANCMode:XM3ANCModeAmbientSound ambientLevel:[self currentAmbientLevel] sender:sender];
}

- (IBAction)ancSliderChangedFromStatusItem:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }

    int level = self.ancLevelStatusSlider.intValue;
    if (level < 1) level = 1;
    if (level > 20) level = 20;
    [self.ancLevelStatusSlider setIntValue:level];
    self.ancLevelValueLabel.stringValue = [NSString stringWithFormat:@"%d", level];
    [self applyANCMode:XM3ANCModeAmbientSound ambientLevel:level sender:sender];
}

- (void)applyFocusOnVoiceDesiredState:(BOOL)enabled sender:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }

    if (enabled) {
        if ([self currentANCMode] != XM3ANCModeAmbientSound) {
            [self applyANCMode:XM3ANCModeAmbientSound ambientLevel:20 sender:sender];
            if (!bt.isConnected() || headphones == nullptr) {
                return;
            }
        }
        [focusOnVoice setState:NSControlStateValueOn];
        headphones->setFocusOnVoice(TRUE);
        headphones->setAsmLevel(ANCSlider.intValue);
    } else {
        [focusOnVoice setState:NSControlStateValueOff];
        headphones->setFocusOnVoice(FALSE);
    }

    [self updateHeadphones];
}

- (IBAction)toggleFocusOnVoiceFromStatusItem:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }
    BOOL shouldEnable = [focusOnVoice state] != NSControlStateValueOn;
    [self applyFocusOnVoiceDesiredState:shouldEnable sender:sender];
}

- (IBAction)syncVolumeFromStatusItem:(id)sender {
    if (!bt.isConnected()) return;

    // Read the current system output volume (0–100).
    NSAppleScript *getScript = [[NSAppleScript alloc] initWithSource:@"output volume of (get volume settings)"];
    NSAppleEventDescriptor *result = [getScript executeAndReturnError:nil];
    if (!result) return;

    NSInteger vol = [result int32Value];
    // Nudge by ±1 to force macOS to re-send the AVRCP Absolute Volume
    // command, resyncing the headphone's internal volume with the Mac level.
    NSInteger nudged = (vol > 0) ? vol - 1 : 1;

    NSString *nudgeSource = [NSString stringWithFormat:@"set volume output volume %ld", (long)nudged];
    [[[NSAppleScript alloc] initWithSource:nudgeSource] executeAndReturnError:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        NSString *restoreSource = [NSString stringWithFormat:@"set volume output volume %ld", (long)vol];
        [[[NSAppleScript alloc] initWithSource:restoreSource] executeAndReturnError:nil];
    });
}

- (IBAction)quitFromStatusItem:(id)sender {
    [NSApp terminate:self];
}

- (void)setupANCControls {
    self.ancEnabledItem = [[NSMenuItem alloc] initWithTitle:@"Ambient Sound Control" action:@selector(toggleANCFromStatusItem:) keyEquivalent:@""];
    self.ancEnabledItem.target = self;
    [self.statusMenu addItem:self.ancEnabledItem];

    self.ancModeMenu = [[NSMenu alloc] initWithTitle:@"ANC Mode"];
    self.ancModeNoiseCancellingItem = [[NSMenuItem alloc] initWithTitle:@"Noise Canceling" action:@selector(selectNoiseCancellingModeFromStatusItem:) keyEquivalent:@""];
    self.ancModeNoiseCancellingItem.target = self;
    [self.ancModeMenu addItem:self.ancModeNoiseCancellingItem];

    self.ancModeWindNoiseReductionItem = [[NSMenuItem alloc] initWithTitle:@"Wind Noise Reduction" action:@selector(selectWindNoiseReductionModeFromStatusItem:) keyEquivalent:@""];
    self.ancModeWindNoiseReductionItem.target = self;
    [self.ancModeMenu addItem:self.ancModeWindNoiseReductionItem];

    self.ancModeAmbientItem = [[NSMenuItem alloc] initWithTitle:@"Ambient Sound" action:@selector(selectAmbientSoundModeFromStatusItem:) keyEquivalent:@""];
    self.ancModeAmbientItem.target = self;
    [self.ancModeMenu addItem:self.ancModeAmbientItem];

    self.ancModeMenuItem = [[NSMenuItem alloc] initWithTitle:@"ANC Mode" action:nil keyEquivalent:@""];
    self.ancModeMenuItem.submenu = self.ancModeMenu;
    [self.statusMenu addItem:self.ancModeMenuItem];

    NSView *sliderContainer = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 250, 46)];

    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(12, 25, 150, 16)];
    titleLabel.stringValue = @"Ambient Sound Level";
    titleLabel.bezeled = NO;
    titleLabel.drawsBackground = NO;
    titleLabel.editable = NO;
    titleLabel.selectable = NO;
    titleLabel.font = [NSFont systemFontOfSize:12];
    [sliderContainer addSubview:titleLabel];

    self.ancLevelValueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(210, 25, 28, 16)];
    self.ancLevelValueLabel.bezeled = NO;
    self.ancLevelValueLabel.drawsBackground = NO;
    self.ancLevelValueLabel.editable = NO;
    self.ancLevelValueLabel.selectable = NO;
    self.ancLevelValueLabel.alignment = NSTextAlignmentRight;
    self.ancLevelValueLabel.font = [NSFont systemFontOfSize:12];
    self.ancLevelValueLabel.stringValue = @"20";
    [sliderContainer addSubview:self.ancLevelValueLabel];

    self.ancLevelStatusSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(12, 6, 226, 16)];
    self.ancLevelStatusSlider.minValue = 1;
    self.ancLevelStatusSlider.maxValue = 20;
    self.ancLevelStatusSlider.numberOfTickMarks = 20;
    self.ancLevelStatusSlider.allowsTickMarkValuesOnly = YES;
    self.ancLevelStatusSlider.continuous = NO;
    self.ancLevelStatusSlider.target = self;
    self.ancLevelStatusSlider.action = @selector(ancSliderChangedFromStatusItem:);
    [sliderContainer addSubview:self.ancLevelStatusSlider];

    self.ancLevelSliderItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    self.ancLevelSliderItem.view = sliderContainer;
    [self.statusMenu addItem:self.ancLevelSliderItem];
}

- (void)setupStatusMenu {
    self.statusMenu = [[NSMenu alloc] initWithTitle:@"Sony Headphones"];
    self.statusMenu.delegate = self;
    self.connectionStatusItem = [[NSMenuItem alloc] initWithTitle:@"Not connected" action:nil keyEquivalent:@""];
    self.connectionStatusItem.enabled = NO;
    [self.statusMenu addItem:self.connectionStatusItem];
    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    self.showHideWindowItem = [[NSMenuItem alloc] initWithTitle:@"Show Window" action:@selector(toggleWindowFromStatusItem:) keyEquivalent:@""];
    self.showHideWindowItem.target = self;
    [self.statusMenu addItem:self.showHideWindowItem];

    self.connectDisconnectItem = [[NSMenuItem alloc] initWithTitle:@"Connect Headphones..." action:@selector(toggleConnectFromStatusItem:) keyEquivalent:@""];
    self.connectDisconnectItem.target = self;
    [self.statusMenu addItem:self.connectDisconnectItem];

    self.reconnectLastDeviceItem = [[NSMenuItem alloc] initWithTitle:@"Reconnect Last Device" action:@selector(reconnectLastDeviceFromStatusItem:) keyEquivalent:@""];
    self.reconnectLastDeviceItem.target = self;
    [self.statusMenu addItem:self.reconnectLastDeviceItem];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    [self setupANCControls];

    self.focusOnVoiceItem = [[NSMenuItem alloc] initWithTitle:@"Focus on Voice" action:@selector(toggleFocusOnVoiceFromStatusItem:) keyEquivalent:@""];
    self.focusOnVoiceItem.target = self;
    [self.statusMenu addItem:self.focusOnVoiceItem];

    self.syncVolumeItem = [[NSMenuItem alloc] initWithTitle:@"Sync Volume" action:@selector(syncVolumeFromStatusItem:) keyEquivalent:@""];
    self.syncVolumeItem.target = self;
    [self.statusMenu addItem:self.syncVolumeItem];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit SonyHeadphonesClient" action:@selector(quitFromStatusItem:) keyEquivalent:@"q"];
    quitItem.target = self;
    [self.statusMenu addItem:quitItem];

    statusItem.menu = self.statusMenu;
}

- (void)menuWillOpen:(NSMenu *)menu {
    [self refreshStatusMenu];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    std::unique_ptr<IBluetoothConnector> connector = std::make_unique<MacOSBluetoothConnector>();
    bt = BluetoothWrapper(std::move(connector));
    headphones = nullptr;

    statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:-1];
    statusItem.button.image = [self statusImageForConnected:NO focusModeEnabled:NO];
    [statusItem.button.image setTemplate:YES];
    [ANCSlider setMinValue:kXm3NoiseCancellingLevel];
    [ANCSlider setMaxValue:kXm3AmbientLevelMaxRaw];
    [ANCSlider setNumberOfTickMarks:(kXm3AmbientLevelMaxRaw - kXm3NoiseCancellingLevel + 1)];
    [ANCSlider setAllowsTickMarkValuesOnly:YES];
    [self setupStatusMenu];
    [self refreshStatusMenu];
}

- (void)dealloc {
    if (headphones != nullptr) {
        delete headphones;
        headphones = nullptr;
    }
    if (statusItem != nil) {
        [NSStatusBar.systemStatusBar removeStatusItem:statusItem];
        statusItem = nil;
    }
}

- (void)displayError:(RecoverableException)exc {
    NSString *errorText;
    if (exc.shouldDisconnect){
        errorText = @"Unexpected error occurred and disconnected.";
        bt.disconnect();
        [self displayDisconnectedWithText:errorText];
    } else {
        errorText = @"Unexpected error occurred.";
        [connectedLabel setStringValue:errorText];
    }
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:errorText];
    [alert setInformativeText:@(exc.what())];
    [alert addButtonWithTitle:@"Ok"];
    [alert runModal];

    [self refreshStatusMenu];
}

- (void)displayDisconnectedWithText:(NSString *)text{
    if (headphones != nullptr) {
        delete headphones;
        headphones = nullptr;
    }
    [ANCSlider setEnabled:FALSE];
    [ANCSlider setIntValue:0];
    [focusOnVoice setEnabled:FALSE];
    [ANCEnabled setEnabled:FALSE];
    [ANCEnabled setState:FALSE];
    [focusOnVoice setEnabled:FALSE];
    [surround setEnabled:FALSE];
    [soundPosition setEnabled:FALSE];
    [virtualSoundLabel setTextColor:NSColor.tertiaryLabelColor];
    [surroundLabel setTextColor:NSColor.tertiaryLabelColor];
    [soundPositionLabel setTextColor:NSColor.tertiaryLabelColor];
    [ANCValuePrefixLabel setTextColor:NSColor.tertiaryLabelColor];
    [ANCValueLabel setTextColor:NSColor.tertiaryLabelColor];
    [connectedLabel setStringValue:text];
    [surround selectItemAtIndex:0];
    [soundPosition selectItemAtIndex:0];
    [connectButton setTitle:@"Connect to Bluetooth device"];
    [self refreshStatusMenu];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

- (IBAction)connectToDevice:(id)sender {
    statusItem.button.image = [self statusImageForConnected:NO focusModeEnabled:NO];
    [statusItem.button.image setTemplate:YES];

    if (bt.isConnected()) {
        bt.disconnect();
        [self displayDisconnectedWithText:@"Not connected"];
        return;
    }

    [NSApp activateIgnoringOtherApps:YES];
    IOBluetoothDeviceSelectorController *dSelector = [IOBluetoothDeviceSelectorController deviceSelector];
    int result = [dSelector runModal];

    if (result == kIOBluetoothUISuccess) {
        IOBluetoothDevice *device = [[dSelector getResults] lastObject];
        NSString *address = [device addressString];
        NSString *name = [device nameOrAddress];
        [self connectToDeviceAddress:address deviceName:(name.length > 0 ? name : address)];
    } else {
        [self displayDisconnectedWithText:@"Not connected, device selector canceled."];
    }
}

- (IBAction)ANCSliderChanged:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }
    if (ANCSlider.intValue < kXm3AmbientLevelMinRaw) {
        [focusOnVoice setState:NSControlStateValueOff];
        headphones->setFocusOnVoice(FALSE);
    }
    headphones->setAmbientSoundControl(TRUE);
    headphones->setAsmLevel(ANCSlider.intValue);
    [self updateHeadphones];
}

- (IBAction)ANCEnabledButtonChanged:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }
    if (ANCEnabled.state != NSControlStateValueOn) {
        [focusOnVoice setState:NSControlStateValueOff];
        headphones->setFocusOnVoice(FALSE);
    }
    headphones->setAmbientSoundControl(ANCEnabled.state);
    [self updateHeadphones];
}

- (IBAction)focusOnVoiceChanged:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }
    [self applyFocusOnVoiceDesiredState:(focusOnVoice.state == NSControlStateValueOn) sender:sender];
}

- (IBAction)surroundChanged:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }
    headphones->setVptType((int)surround.indexOfSelectedItem);
    headphones->setSurroundPosition(SOUND_POSITION_PRESET_ARRAY[0]);
    [self updateHeadphones];
}

- (IBAction)soundPositionChanged:(id)sender {
    if (!bt.isConnected() || headphones == nullptr) {
        return;
    }
    headphones->setVptType(0);
    headphones->setSurroundPosition(SOUND_POSITION_PRESET_ARRAY[soundPosition.indexOfSelectedItem]);
    [self updateHeadphones];
}

- (void)updateHeadphones {
    if (!bt.isConnected()) {
        [self displayDisconnectedWithText:@"Not connected, please reconnect."];
        return;
    }
    if (headphones == nullptr) {
        return;
    }
    if (headphones->isChanged()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            try {
                headphones->setChanges();
                [self updateGUI];
            } catch (RecoverableException& exc) {
                [self displayError:exc];
            }
        });
    }
}

- (void)updateGUI {
    if (headphones == nullptr) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->ANCEnabled setState:headphones->getAmbientSoundControl()];
        [self->focusOnVoice setState:headphones->getFocusOnVoice()];
        [self->surround selectItemAtIndex:headphones->getVptType()];
        SOUND_POSITION_PRESET preset = headphones->getSurroundPosition();
        int index = 0;
        for (SOUND_POSITION_PRESET p : SOUND_POSITION_PRESET_ARRAY) {
            if (p == preset) {
                break;
            }
            index++;
        }
        [self->soundPosition selectItemAtIndex:index];
        if (headphones->isSetAsmLevelAvailable()) {
            [self->ANCSlider setEnabled:TRUE];
            [self->ANCValuePrefixLabel setTextColor:NSColor.labelColor];
            [self->ANCValueLabel setTextColor:NSColor.labelColor];
        } else {
            [self->ANCValuePrefixLabel setTextColor:NSColor.tertiaryLabelColor];
            [self->ANCValueLabel setTextColor:NSColor.tertiaryLabelColor];
            [self->focusOnVoice setEnabled:FALSE];
            [self->ANCSlider setEnabled:FALSE];
        }

        int rawLevel = headphones->getAsmLevel();
        [self->ANCSlider setIntValue:rawLevel];
        if (rawLevel == kXm3NoiseCancellingLevel) {
            [self->ANCValueLabel setStringValue:@"NC"];
        } else if (rawLevel == kXm3WindNoiseReductionLevel) {
            [self->ANCValueLabel setStringValue:@"Wind"];
        } else {
            [self->ANCValueLabel setStringValue:[NSString stringWithFormat:@"%d", rawLevel - 1]];
        }

        BOOL ambientMode = rawLevel >= kXm3AmbientLevelMinRaw;
        [self->focusOnVoice setTitle:@"Focus on Voice"];
        [self->focusOnVoice setEnabled:ambientMode];
        if (!ambientMode) {
            [self->focusOnVoice setState:NSControlStateValueOff];
        }
        [self refreshStatusMenu];
    });
}

@end
