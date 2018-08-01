//
// AUParamsApp
// AUParamsPresetsAudioUnit.m
//
// last build: macOS 10.13, Swift 4.0
//
// Created by Gene De Lisa on 5/25/18.
 
//  Copyright ©(c) 2018 Gene De Lisa. All rights reserved.
//
//  This source code is licensed under the MIT license found in the
//  LICENSE file in the root directory of this source tree.
//
//  In addition:
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright
//  notice, this list of conditions and the following disclaimer in the
//  documentation and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//
    
    

#import "AUParamsPresetsAudioUnit.h"

#import <AVFoundation/AVFoundation.h>
#import "IntervalPlugin.hpp"
#import "GDAudio.h"

// Define parameter addresses.
const AudioUnitParameterID intervalParameter = 1;

// Presets
static const UInt8 kNumberOfPresets = 12;
static const NSInteger kDefaultFactoryPreset = 0;

typedef struct FactoryPresetParameters {
    AUValue intervalValue;
} FactoryPresetParameters;

static const FactoryPresetParameters presetParameters[kNumberOfPresets] = {
    { 1 },
    { 2 },
    { 3 },
    { 4 },
    { 5 },
    { 6 },
    { 7 },
    { 8 },
    { 9 },
    { 10 },
    { 11 },
    { 12 },
};



@interface AUParamsPresetsAudioUnit ()

@property (nonatomic, readwrite) AUParameterTree *parameterTree;

@property AUAudioUnitBus *inputBus;
@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;

@end


@implementation AUParamsPresetsAudioUnit {
    // C++ members need to be ivars; they would be copied on access if they were properties.
    IntervalPlugin                *_intervalPlugin;
    
    AUParameter                  *intervalParam;
    
    AUAudioUnitPreset            *_currentPreset;
    NSInteger                    _currentFactoryPresetIndex;
    NSArray<AUAudioUnitPreset *> *_presets;
    
    AudioStreamBasicDescription  asbd;
    
    AUHostMusicalContextBlock    _musicalContext;
    AUMIDIOutputEventBlock       _outputEventBlock;
    AUHostTransportStateBlock    _transportStateBlock;
    AUScheduleMIDIEventBlock     _scheduleMIDIEventBlock;
}

@synthesize parameterTree = _parameterTree;

@synthesize inputBus = _inputBus;
@synthesize outputBus = _outputBus;
@synthesize inputBusArray = _inputBusArray;
@synthesize outputBusArray = _outputBusArray;

@synthesize factoryPresets = _presets;
//@synthesize currentPreset = _currentPreset;
//NSArray<AUAudioUnitPreset *> *_presets;
//@synthesize factoryPresets = _presets;


- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) {
        return nil;
    }
    
    [GDAudio displayACD: componentDescription];
    
    [self createBusses];
    
    [self setupParameters];

    //@property (nonatomic, readonly) BOOL hasMIDIOutput;
    //[self hasMIDIOutput] = YES; nope
    
    self.maximumFramesToRender = 512;
    
    return self;
}

- (void) createBusses {
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
    
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
    asbd = *defaultFormat.streamDescription;
    [GDAudio displayASBD: asbd];
    
    _intervalPlugin = new IntervalPlugin();
    
    _inputBus = [[AUAudioUnitBus alloc]
                 initWithFormat:defaultFormat error:nil];
    _outputBus = [[AUAudioUnitBus alloc]
                  initWithFormat:defaultFormat error:nil];
    
    // Create the input and output bus arrays.
    _inputBusArray  = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses: @[_inputBus]];
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses: @[_outputBus]];
    
    [self setupParameters];

}

- (void) setupParameters {
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
    
    AudioUnitParameterOptions flags = kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable;
    
    NSArray<NSString *> *intervalNames =
    [NSArray arrayWithObjects: @"Unison", @"Minor Second", @"Major Second", @"Minor Third", @"Major Third", @"Fourth", @"Tritone", @"Fifth", @"Minor Sixth", @"Sixth", @"Minor Seventh", @"Seventh", @"Octave", nil];
    
    // you should really define these values someplace else as constants or in a struct/class
    intervalParam = [AUParameterTree createParameterWithIdentifier: @"intervalParameter" // keyPath
                                                              name: @"Interval" // displayName
                                                           address:intervalParameter
                                                               min: 0
                                                               max: 12
                                                              unit: kAudioUnitParameterUnit_Indexed
                                                          unitName: nil
                                                             flags: flags
                                                      valueStrings: intervalNames
                                               dependentParameters: nil];
    
    // Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[ intervalParam ]];
    
    
    // A function to provide string representations of parameter values.
    _parameterTree.implementorStringFromValueCallback = ^(AUParameter *param, const AUValue *__nullable valuePtr) {
        AUValue value = valuePtr == nil ? param.value : *valuePtr;
        
        switch (param.address) {
                
            case intervalParameter:
                
                if (value > [intervalNames count]) {
                    return @"default value string";
                }
                return intervalNames[(int)value];
                
            default:
                return @"?";
        }
    };

    __weak typeof(self) weakSelf = self;
    _parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        __strong typeof(self) strongSelf = weakSelf;

        NSLog(@"Param Value Changed Value: %f", value);
        
        switch (param.address) {
            case intervalParameter:
                NSLog(@"it is the interval param. sending to plugin");
                strongSelf->_intervalPlugin->setInterval(value);
            default: break;
        }
    };
    
    
    // can do this
    intervalParam.value = 4;
    // or this
    //    [_parameterTree parameterWithAddress:intervalParameter].value = 4;
    
    
    // Init Presets
    _currentFactoryPresetIndex = kDefaultFactoryPreset;
    
    _currentPreset = self.factoryPresets[_currentFactoryPresetIndex];
    
    _presets = @[
                 [self createPreset:0 name:@"Minor Second"],
                 [self createPreset:1 name:@"Major Second"],
                 [self createPreset:2 name:@"Minor Third"],
                 [self createPreset:3 name:@"Major Third"],
                 [self createPreset:4 name:@"Fourth"],
                 [self createPreset:5 name:@"Tritone"],
                 [self createPreset:6 name:@"Fifth"],
                 [self createPreset:7 name:@"Minor Sixth"],
                 [self createPreset:8 name:@"Major Sixth"],
                 [self createPreset:9 name:@"Minor Seventh"],
                 [self createPreset:10 name:@"Major Seventh"],
                 [self createPreset:11 name:@"Octave"]
                 ];

}




//- (void) setupFactoryPresets {
//    NSMutableArray* presetItems = [NSMutableArray new];
//
//    AUAudioUnitPreset* newPreset = [AUAudioUnitPreset new];
//    newPreset.number = 0;
//    newPreset.name = @"Frobnozz";
//    [presetItems addObject:newPreset];
//
//    newPreset = [AUAudioUnitPreset new];
//    newPreset.number = 1;
//    newPreset.name = @"SnizzWhiz";
//    [presetItems addObject:newPreset];
//
//    _presets = [NSArray arrayWithArray:presetItems];
//
//    _currentFactoryPresetIndex = 0;
//    _currentPreset = _presets[_currentFactoryPresetIndex];
//
//}

//- (NSArray*)factoryPresets {
//
//NSArray *presetArray = = @[
//             [self createPreset:0 name:@"Minor Second"],
//             [self createPreset:1 name:@"Major Second"],
//             [self createPreset:2 name:@"Minor Third"],
//             [self createPreset:3 name:@"Major Third"],
//             [self createPreset:4 name:@"Fourth"],
//             [self createPreset:5 name:@"Tritone"],
//             [self createPreset:6 name:@"Fifth"],
//             [self createPreset:7 name:@"Minor Sixth"],
//             [self createPreset:8 name:@"Major Sixth"],
//             [self createPreset:9 name:@"Minor Seventh"],
//             [self createPreset:10 name:@"Major Seventh"],
//             [self createPreset:11 name:@"Octave"]
//             ];
//    return presetArray;
//}

// might be convenient just to define getters and setters for the params
- (void) setInterval:(int) value {
    [_parameterTree parameterWithAddress:intervalParameter].value = value;
}

- (int) getInterval {
    return (int)[_parameterTree parameterWithAddress:intervalParameter].value;
}


#pragma mark - AUAudioUnit Presets

- (AUAudioUnitPreset*)createPreset:(NSInteger)number name:(NSString*)name {
    AUAudioUnitPreset* newPreset = [AUAudioUnitPreset new];
    newPreset.name = name;
    newPreset.number = number;
    return newPreset;
}

// this property is inherited
// @property (NS_NONATOMIC_IOSONLY, copy, nullable) NSDictionary<NSString *, id> *fullState;


// called when you save a new preset. e.g. in AUM press the + in the Presets title bar
- (NSDictionary<NSString *,id> *)fullState {
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
    
    NSMutableDictionary *state = [[NSMutableDictionary alloc] initWithDictionary:super.fullState];
    // this will contain manufacturer, data, type, subtype, and version
    
    // you can do just a setObject:forKey on state, but in real life you will probably have many parameters.
    // so, add a param dictionary to fullState.
    
    NSDictionary<NSString*, id> *params = @{
                                            @"intervalParameter": [NSNumber numberWithInt: intervalParam.value],
                                            };

    state[@"fullStateParams"] = [NSKeyedArchiver archivedDataWithRootObject: params];
    return state;
}

// called when the user preset is selected
- (void)setFullState:(NSDictionary<NSString *,id> *)fullState {
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );

    NSData *data = (NSData *)fullState[@"fullStateParams"];
    NSDictionary *params = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    intervalParam.value = [(NSNumber *)params[@"intervalParameter"] intValue];
}

- (AUAudioUnitPreset *)currentPreset {
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );

    if (_currentPreset.number >= 0) {
        NSLog(@"Returning Current Factory Preset: %ld\n", (long)_currentFactoryPresetIndex);
        return [_presets objectAtIndex:_currentFactoryPresetIndex];
    } else {
        NSLog(@"Returning Current Custom Preset: %ld, %@\n", (long)_currentPreset.number, _currentPreset.name);
        return _currentPreset;
    }
}

- (void)setCurrentPreset:(AUAudioUnitPreset *)currentPreset {
    if (nil == currentPreset) { NSLog(@"nil passed to setCurrentPreset!"); return; }
    
    NSLog(@"current preset num %ld name %@", (long)currentPreset.number, currentPreset.name );
    
    if (currentPreset.number >= 0) {
        // factory preset
        for (AUAudioUnitPreset *factoryPreset in _presets) {
            if (currentPreset.number == factoryPreset.number) {
                
                AUParameter *intervalParameter = [self.parameterTree valueForKey: @"intervalParameter"];
                intervalParameter.value = presetParameters[factoryPreset.number].intervalValue;
                
                // set factory preset as current
                _currentPreset = currentPreset;
                _currentFactoryPresetIndex = factoryPreset.number;
                NSLog(@"currentPreset Factory: %ld, %@\n", (long)_currentFactoryPresetIndex, factoryPreset.name);
                
                break;
            }
        }
    } else if (nil != currentPreset.name) {
        // set custom preset as current
        _currentPreset = currentPreset;
        NSLog(@"currentPreset Custom: %ld, %@\n", (long)_currentPreset.number, _currentPreset.name);
    } else {
        NSLog(@"setCurrentPreset not set! - invalid AUAudioUnitPreset\n");
    }
}


#pragma mark - AUAudioUnit Overrides

// If an audio unit has input, an audio unit's audio input connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray *)inputBusses {
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
    
    return _inputBusArray;
}

// An audio unit's audio output connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray *)outputBusses {
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
    return _outputBusArray;
}

// Allocate resources required to render.
// Subclassers should call the superclass implementation.
- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
    
    if (![super allocateRenderResourcesAndReturnError:outError]) {
        return NO;
    }
    
    [self cacheBlox];
    
    _intervalPlugin->setMusicalContextBlock(self.musicalContextBlock);
    _intervalPlugin->setOutputEventBlock(self.MIDIOutputEventBlock);
    _intervalPlugin->setTransportStateBlock(self.transportStateBlock);
    _intervalPlugin->setScheduleMIDIEventBlock(self.scheduleMIDIEventBlock);
    
    
    // Validate that the bus formats are compatible.
    // Allocate your resources.
    
    [GDAudio showAllParams:self.parameterTree];
    
    return YES;
}

// Deallocate resources allocated in allocateRenderResourcesAndReturnError:
// Subclassers should call the superclass implementation.
- (void)deallocateRenderResources {
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
    
    // Deallocate your resources.
    [super deallocateRenderResources];
    
    _transportStateBlock = nil;
    _outputEventBlock = nil;
    _musicalContext = nil;
    _scheduleMIDIEventBlock = nil;
}

- (void) cacheBlox {
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
    
    if (self.musicalContextBlock) {
        _musicalContext = self.musicalContextBlock;
        NSLog(@"have a non nil musicalContextBlock");
    } else {
        _musicalContext = nil;
    }
    
    if (self.MIDIOutputEventBlock) {
        _outputEventBlock = self.MIDIOutputEventBlock;
        NSLog(@"have a non nil MIDIOutputEventBlock");
        
    } else {
        _outputEventBlock = nil;
    }
    
    if (self.transportStateBlock) {
        _transportStateBlock = self.transportStateBlock;
        NSLog(@"have a non nil transportStateBlock");
        
    } else {
        _transportStateBlock = nil;
    }
    
    if (self.scheduleMIDIEventBlock) {
        _scheduleMIDIEventBlock = self.scheduleMIDIEventBlock;
        NSLog(@"have a non nil scheduleMIDIEventBlock");
    } else {
        _scheduleMIDIEventBlock = nil;
    }
}

- (NSArray<NSString *>*) MIDIOutputNames {
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
    
    return @[@"AUParamsPresetsMidiOut"];
}


#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

// Block which subclassers must provide to implement rendering.
- (AUInternalRenderBlock)internalRenderBlock {
    // Capture in locals to avoid ObjC member lookups. If "self" is captured in render, we're doing it wrong. See sample code.
    
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
    
    // allocateRenderResourcesAndReturnError is sometimes called after internalRenderBlock!
    [self cacheBlox];
    
    IntervalPlugin *pluginCapture = _intervalPlugin;
    
    __block AUHostMusicalContextBlock _musicalContextCapture = _musicalContext;
    if (_musicalContextCapture == nil) {
        _musicalContextCapture = self.musicalContextBlock;
    }
    __block AUMIDIOutputEventBlock _outputEventBlockCapture = _outputEventBlock;
    if (_outputEventBlockCapture == nil) {
        _outputEventBlockCapture = self.MIDIOutputEventBlock;
    }
    __block AUHostTransportStateBlock _transportStateBlockCapture = _transportStateBlock;
    if (_transportStateBlockCapture == nil) {
        _transportStateBlockCapture = self.transportStateBlock;
    }
    __block AUScheduleMIDIEventBlock _scheduleMIDIEventBlockCapture = _scheduleMIDIEventBlock;
    if (_scheduleMIDIEventBlockCapture == nil) {
        _scheduleMIDIEventBlockCapture = self.scheduleMIDIEventBlock;
    }
    
    __block BOOL transportStateIsMoving = NO;

    Float64 sampleRate = asbd.mSampleRate;
    
    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList *outputData, const AURenderEvent *realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
        
        // Do event handling and signal processing here.
        
        // Do not use NSLog in this block. The calls you see here are for debugging only.
        // You might hear weird things if you leave them in.
        
        // NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
        
        double currentTempo = 120.0;
        
        double samplesPerSecond = 0.0;
        
        pluginCapture->processRenderEvents(actionFlags, timestamp, frameCount, realtimeEventListHead);
//        pluginCapture->handleRealtimeMIDI(actionFlags, timestamp, frameCount, realtimeEventListHead);

        if ( _musicalContextCapture ) {
            double timeSignatureNumerator;
            NSInteger timeSignatureDenominator;
            double currentBeatPosition;
            NSInteger sampleOffsetToNextBeat;
            double currentMeasureDownbeatPosition;
            
            if (_musicalContextCapture( &currentTempo, &timeSignatureNumerator, &timeSignatureDenominator, &currentBeatPosition, &sampleOffsetToNextBeat, &currentMeasureDownbeatPosition ) ) {
                
                samplesPerSecond = 60.0 / currentTempo * sampleRate;
                
                pluginCapture->setTempo(currentTempo);
                
                //NSLog(@"current tempo %f", currentTempo);
                //NSLog(@"samplesPerSecond %f", samplesPerSecond);
                // NSLog(@"timeSignatureNumerator %f", timeSignatureNumerator);
                // NSLog(@"timeSignatureDenominator %ld", (long)timeSignatureDenominator);
                
                if (transportStateIsMoving) {
                    NSLog(@"currentBeatPosition %f", currentBeatPosition);
                    // these two seem to always be 0. Probably a host issue.
                    NSLog(@"sampleOffsetToNextBeat %ld", (long)sampleOffsetToNextBeat);
                    NSLog(@"currentMeasureDownbeatPosition %f", currentMeasureDownbeatPosition);
                }
            }
        }
        
        
        if (_transportStateBlockCapture) {
            AUHostTransportStateFlags flags;
            double currentSamplePosition;
            double cycleStartBeatPosition;
            double cycleEndBeatPosition;
            
            _transportStateBlockCapture(&flags, &currentSamplePosition, &cycleStartBeatPosition, &cycleEndBeatPosition);
            
            if (flags & AUHostTransportStateChanged) {
                NSLog(@"AUHostTransportStateChanged bit set");
                NSLog(@"currentSamplePosition %f", currentSamplePosition);
            }
            
            if (flags & AUHostTransportStateMoving) {
                NSLog(@"AUHostTransportStateMoving bit set");
                NSLog(@"currentSamplePosition %f", currentSamplePosition);
                transportStateIsMoving = YES;
                
            } else {
                transportStateIsMoving = NO;
            }
            
            if (flags & AUHostTransportStateRecording) {
                NSLog(@"AUHostTransportStateRecording bit set");
                NSLog(@"currentSamplePosition %f", currentSamplePosition);
            }
            
            if (flags & AUHostTransportStateCycling) {
                NSLog(@"AUHostTransportStateCycling bit set");
                NSLog(@"currentSamplePosition %f", currentSamplePosition);
                NSLog(@"cycleStartBeatPosition %f", cycleStartBeatPosition);
                NSLog(@"cycleEndBeatPosition %f", cycleEndBeatPosition);
            }
            
        }
        
        if( _scheduleMIDIEventBlockCapture) {
        }
        
        
        return noErr;
    };
}

@end


