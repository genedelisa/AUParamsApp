//
// AUParamsApp
// GDAudio.m
//
// last build: macOS 10.13, Swift 4.0
//
// Created by Gene De Lisa on 5/31/18.
 
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
    
    

#import <Foundation/Foundation.h>
#import "GDAudio.h"

// just some utilities

@implementation GDAudio

+ (id)sharedInstance {
    static GDAudio *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (id)init {
    if (self = [super init]) {

    }
    return self;
}

- (void)dealloc {

}

#pragma mark - Displaying

+(void)displayACD:(AudioComponentDescription)acd {
    char formatIDString[5];
    formatIDString[4] = '\0';
    
    NSAssert(acd.componentType != 0, @"Component Type not set.");
    UInt32 formatID = CFSwapInt32HostToBig (acd.componentType);
    bcopy (&formatID, formatIDString, 4);
    NSLog (@"Component Type:           %10s",    formatIDString);
    
    NSAssert(acd.componentSubType != 0, @"Component SubType not set.");
    formatID = CFSwapInt32HostToBig(acd.componentSubType);
    bcopy(&formatID, formatIDString, 4);
    NSLog (@"Component SubType:        %10s",    formatIDString);
    
    NSAssert(acd.componentManufacturer != 0, @"Component Manufacturer not set.");
    formatID = CFSwapInt32HostToBig(acd.componentManufacturer);
    bcopy(&formatID, formatIDString, 4);
    NSLog (@"Component Manufacturer:   %10s",    formatIDString);
    
    NSLog (@"Component Flags:          %10u",    (unsigned int)acd.componentFlags);
    NSLog (@"Component Flags Mask:     %10u",    acd.componentFlagsMask);
}

+(void)displayASBD:(AudioStreamBasicDescription)asbd {
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig (asbd.mFormatID);
    bcopy (&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
    
    NSLog (@"Sample Rate:         %10.0f",  asbd.mSampleRate);
    NSLog (@"Format ID:           %10s",    formatIDString);
    NSLog (@"Format Flags:        %10u",    (unsigned int)asbd.mFormatFlags);
    NSLog (@"Bytes per Packet:    %10u",    (unsigned int)asbd.mBytesPerPacket);
    NSLog (@"Frames per Packet:   %10u",    (unsigned int)asbd.mFramesPerPacket);
    NSLog (@"Bytes per Frame:     %10u",    (unsigned int)asbd.mBytesPerFrame);
    NSLog (@"Channels per Frame:  %10u",    (unsigned int)asbd.mChannelsPerFrame);
    NSLog (@"Bits per Channel:    %10u",    (unsigned int)asbd.mBitsPerChannel);
    NSLog(@"%@ NativeFloatPacked: (%u)",
          asbd.mFormatFlags == kAudioFormatFlagsNativeFloatPacked ? @"is" : @"is not",
          kAudioFormatFlagsNativeFloatPacked);
}

+ (void) showAllParams:(AUParameterTree *) parameterTree {
    NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
    
    //NSMutableArray *parameters = [NSMutableArray new];
    
    [[parameterTree allParameters] enumerateObjectsUsingBlock:
     ^(AUParameter * _Nonnull parameter, NSUInteger idx, BOOL * _Nonnull stop) {
         
         NSLog(@"param index %lu", (unsigned long)idx );
         NSLog(@"param displayName %@", parameter.displayName);
         NSLog(@"param keypath %@", parameter.keyPath);
         NSLog(@"param keypath %f", parameter.value);
         
//         [parameters addObject:[NSDictionary dictionaryWithObjectsAndKeys:
//                                parameter.keyPath, @"KeyPath",
//                                [NSNumber numberWithFloat:parameter.value], @"Value", nil]];
     }];
}


@end










