//
// AUParamsApp
// AUParamsAudioUnit.m
//
// last build: macOS 10.13, Swift 4.0
//
// Created by Gene De Lisa on 5/21/18.
 
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
    
    

#import "AUParamsAudioUnit.h"

#import <AVFoundation/AVFoundation.h>
//#import "IntervalPlugin.hpp"


// Define parameter addresses.
const AudioUnitParameterID intervalParameter = 0;

@interface AUParamsAudioUnit ()

@property (nonatomic, readwrite) AUParameterTree *parameterTree;
@property AUAudioUnitBus *inputBus;
@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;

@end


@implementation AUParamsAudioUnit
@synthesize parameterTree = _parameterTree;
@synthesize inputBus = _inputBus;
@synthesize outputBus = _outputBus;
@synthesize inputBusArray = _inputBusArray;
@synthesize outputBusArray = _outputBusArray;

AUParameter *intervalParam;
NSArray<NSString *> *intervalNames;

AudioStreamBasicDescription asbd;

AUHostMusicalContextBlock _musicalContext;
AUMIDIOutputEventBlock _outputEventBlock;
AUHostTransportStateBlock _transportStateBlock;
AUScheduleMIDIEventBlock _scheduleMIDIEventBlock;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) {
        return nil;
    }
    
//    super.supportsMPE = NO;
//
//    self.hasMIDIOutput = YES;
//
//    self.musicDeviceOrEffect = YES;
    
    [self createBusses];
    
    [self setupParameters];
    
    self.maximumFramesToRender = 512;
    
    return self;
}

- (void) createBusses {
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );

    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
    asbd = *defaultFormat.streamDescription;
    
    NSLog (@"defaultFormat.streamDescription:\n"\
           "mBitsPerChannel: %u,\n"\
           "mBytesPerFrame: %u,\n"\
           "mBytesPerPacket: %u,\n"\
           "mChannelsPerFrame: %u,\n"\
           "mFormatID: %u, \n"\
           "mFormatFlags: 0x%x,\n"\
           "mFramesPerPacket: %u,\n"\
           "mSampleRate: %f\n",
           (unsigned int) asbd.mBitsPerChannel,
           (unsigned int) asbd.mBytesPerFrame,
           (unsigned int) asbd.mBytesPerPacket,
           (unsigned int) asbd.mChannelsPerFrame,
           (unsigned int) asbd.mFormatID,
           (unsigned int) asbd.mFormatFlags,
           (unsigned int) asbd.mFramesPerPacket,
           asbd.mSampleRate
           );
    NSLog(@"This %@ kAudioFormatFlagsNativeFloatPacked (%u)",
          asbd.mFormatFlags == kAudioFormatFlagsNativeFloatPacked ? @"is" : @"is not",
          kAudioFormatFlagsNativeFloatPacked);
    
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
    
    intervalNames =
    [NSArray arrayWithObjects: @"Unison", @"Minor Second", @"Major Second", @"Minor Third", @"Major Third", @"Fourth", @"Tritone", @"Fifth", @"Minor Sixth", @"Sixth", @"Minor Seventh", @"Seventh", @"Octave", nil];
    
    intervalParam = [AUParameterTree createParameterWithIdentifier: @"intervalParameter"
                                                              name: @"Interval"
                                                           address:intervalParameter
                                                               min: 0
                                                               max: 12
                                                              unit: kAudioUnitParameterUnit_Indexed
                                                          unitName: nil
                                                             flags: flags | kAudioUnitParameterFlag_ValuesHaveStrings
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
    
    // can do this
    intervalParam.value = 4;
//    // or this
//    [_parameterTree parameterWithAddress:intervalParameter].value = 4;
    
}
- (void) setInterval:(int) value {
    [_parameterTree parameterWithAddress:intervalParameter].value = value;
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
    
    // Validate that the bus formats are compatible.
    // Allocate your resources.
    
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

    return @[@"AUParamsMidiOut"];
}


#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

// Block which subclassers must provide to implement rendering.
- (AUInternalRenderBlock)internalRenderBlock {
    // Capture in locals to avoid ObjC member lookups. If "self" is captured in render, we're doing it wrong. See sample code.
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
    
    // allocated resource is called after internal render block!
    [self cacheBlox];

//    IntervalPlugin *pluginCapture = _intervalPlugin;
    
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
    

    AUParameter *intervalParamCapture = intervalParam;

    
    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList *outputData, const AURenderEvent *realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
        // Do event handling and signal processing here.

       // NSLog(@"calling: %s", __PRETTY_FUNCTION__ );

        double currentTempo = 120.0;
//        double samplesPerSecond = 60.0 / tempo * asbd.mSampleRate;
        double samplesPerSecond = 0.0;
        //NSLog(@"samplesPerSecond %f", samplesPerSecond);
        // should be 22050

        
        BOOL transportStateIsMoving = NO;
        if ( _musicalContext ) {
            double timeSignatureNumerator;
            NSInteger timeSignatureDenominator;
            double currentBeatPosition;
            NSInteger sampleOffsetToNextBeat;
            double currentMeasureDownbeatPosition;
            
            if (_musicalContext( &currentTempo, &timeSignatureNumerator, &timeSignatureDenominator, &currentBeatPosition, &sampleOffsetToNextBeat, &currentMeasureDownbeatPosition ) ) {

                samplesPerSecond = 60.0 / currentTempo * asbd.mSampleRate;
                
                //NSLog(@"current tempo %f", currentTempo);
                //NSLog(@"samplesPerSecond %f", samplesPerSecond);
                //                NSLog(@"timeSignatureNumerator %f", timeSignatureNumerator);
                //                NSLog(@"timeSignatureDenominator %ld", (long)timeSignatureDenominator);
                
                if (transportStateIsMoving) {
                    NSLog(@"currentBeatPosition %f", currentBeatPosition);
                    // these two seem to always be 0
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
        
        int interval = intervalParamCapture.value;
        
        const AURenderEvent* event = realtimeEventListHead;
        AUMIDIEvent midiEvent;
        AUParameterEvent parameterEvent;
        OSStatus osstatus = noErr;
        
        while (event != NULL) {
            switch (realtimeEventListHead->head.eventType) {
                case AURenderEventParameter:
                case AURenderEventParameterRamp:
                    parameterEvent = event->parameter;
                    NSLog(@"%llu %f", parameterEvent.parameterAddress, parameterEvent.value);
                    interval = parameterEvent.value;
                    
                    break;
                    
                case AURenderEventMIDI:

                    midiEvent = event->MIDI;
                    uint8_t midiStatus = (midiEvent.data[0] & 0xF0);
                    uint8_t channel = midiEvent.data[0] & 0x0F;
                    uint8_t data1 = midiEvent.data[1];
                    uint8_t data2 = midiEvent.data[2];
                    AUEventSampleTime when = midiEvent.eventSampleTime;
                    uint16_t length = midiEvent.length;
//                    NSLog(@" when %lld message %d", when, midiStatus);
                    
                    if (_outputEventBlockCapture) {
                        // send back the original unchanged
                        osstatus = _outputEventBlockCapture(midiEvent.eventSampleTime, midiEvent.cable, midiEvent.length, midiEvent.data);
                        if (osstatus != noErr) {
                            NSLog(@"Error sending midi mess %d", osstatus);
                        }
                        
                        // note on
                        uint8_t bytes[3];
                        bytes[0] = 0x90;
                        bytes[1] = data1;
                        bytes[2] = data2;
                        if (midiStatus == 0x90 && data2 != 0) {
                            bytes[1] = data1 + interval;
                            osstatus = _outputEventBlockCapture(AUEventSampleTimeImmediate, midiEvent.cable, 3, bytes);
                            if (osstatus != noErr) {
                                NSLog(@"Error sending midi mess %d", osstatus);
                            }
                        }
                        
                        // note off
                        bytes[0] = 0x90;
                        bytes[1] = data1;
                        bytes[2] = 0;
                        if (midiStatus == 0x90 && data2 == 0) {
                            bytes[1] = data1 + interval;
                            osstatus = _outputEventBlockCapture(AUEventSampleTimeImmediate, midiEvent.cable, 3, bytes);
                            if (osstatus != noErr) {
                                NSLog(@"Error sending midi mess %d", osstatus);
                            }
                        }
                        
                    }
                    
                    break;
                    
                case AURenderEventMIDISysEx:
                    
                    break;
            }
            
            event = event->head.next;
        }
        

        return noErr;
    };
}

@end


