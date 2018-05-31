//
// AUParamsApp
// IntervalPlugin.h
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

#ifndef IntervalPlugin_hpp
#define IntervalPlugin_hpp

#include <stdio.h>
#include <iostream>
#include <list>
#include <vector>
#include <iterator>
using namespace std;


class IntervalPlugin {
private:
    AUHostMusicalContextBlock musicalContext;
    AUMIDIOutputEventBlock outputEventBlock;
    AUHostTransportStateBlock transportStateBlock;
    AUScheduleMIDIEventBlock scheduleMIDIEventBlock;
    double tempo;
    uint8_t interval = 4;
    
public:
    IntervalPlugin() {
    }
    ~IntervalPlugin() {
    }
    void setMusicalContextBlock(AUHostMusicalContextBlock block) {
        this->musicalContext = block;
    }
    void setOutputEventBlock(AUMIDIOutputEventBlock block) {
        this->outputEventBlock = block;
    }
    void setTransportStateBlock(AUHostTransportStateBlock block) {
        this->transportStateBlock = block;
    }
    void setScheduleMIDIEventBlock(AUScheduleMIDIEventBlock block) {
        this->scheduleMIDIEventBlock = block;
    }
    void setTempo(double t) {
        this->tempo = t;
    }
    void setInterval(uint8_t ivl) {
        this->interval = ivl;
        NSLog(@"plugin has a new interval %d", this->interval);
    }
    
    void handleParameterEvent(AUParameterEvent const& parameterEvent) {
        NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
        
        NSLog(@"parameter address %llu value %f", parameterEvent.parameterAddress,
              parameterEvent.value);
    }
    
    void handleMIDIEvent(AUMIDIEvent const& midiEvent) {
        //NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
        
        OSStatus osstatus = noErr;
        
        uint8_t midiStatus = (midiEvent.data[0] & 0xF0);
        uint8_t channel = midiEvent.data[0] & 0x0F;
        uint8_t data1 = 0;
        uint8_t data2 = 0;
        uint8_t bytes[3];
        
        switch (midiEvent.length) {
                
            case 2:
                // data1 = midiEvent.data[1];
                // we're just doing notes
                return;
                
            case 3:
                data1 = midiEvent.data[1];
                data2 = midiEvent.data[2];
                break;
        }
        
        if (this->outputEventBlock) {
            // send back the original unchanged
            osstatus = this->outputEventBlock(midiEvent.eventSampleTime, midiEvent.cable, midiEvent.length, midiEvent.data);
            if (osstatus != noErr) {
                NSLog(@"Error sending midi mess %d", osstatus);
            }
            
            NSLog(@"sending back with interval %d", interval);
            
            // note on
            bytes[0] = 0x90 | channel;
            bytes[1] = data1;
            bytes[2] = data2;
            if (midiStatus == 0x90 && data2 != 0) {
                bytes[1] = data1 + interval;
                this->outputEventBlock(AUEventSampleTimeImmediate, midiEvent.cable, 3, bytes);
            }
            
            // note off
            bytes[0] = 0x90 | channel;
            bytes[1] = data1;
            bytes[2] = 0;
            if (midiStatus == 0x90 && data2 == 0) {
                bytes[1] = data1 + interval;
                this->outputEventBlock(AUEventSampleTimeImmediate, midiEvent.cable, 3, bytes);
            }
            
        }
        
    }
    
    
    void processRenderEvents(AudioUnitRenderActionFlags *actionFlags,
                             const AudioTimeStamp *timestamp,
                             AUAudioFrameCount frameCount,
                             const AURenderEvent *realtimeEventListHead
                             ) {
        
        //NSLog(@"calling: %s", __PRETTY_FUNCTION__ );
        
        AUEventSampleTime now = (AUEventSampleTime)timestamp->mSampleTime;
        AUAudioFrameCount midiSampleOffset = 0;
        const AURenderEvent *event = realtimeEventListHead;
                             
        
        while (event != NULL) {
            AUAudioFrameCount const framesThisSegment = (AUAudioFrameCount)(event->head.eventSampleTime - now);
            now += framesThisSegment;
            midiSampleOffset += framesThisSegment;
            
            if (midiSampleOffset >= frameCount)
                break;
            
            do {
                
                switch (realtimeEventListHead->head.eventType) {
                    case AURenderEventParameter:
                    case AURenderEventParameterRamp:
                        this->handleParameterEvent(event->parameter);
                        break;
                        
                    case AURenderEventMIDI:
                        this->handleMIDIEvent(event->MIDI);
                        break;
                        
                    case AURenderEventMIDISysEx:
                        break;
                }
                
                event = event->head.next;
            } while (event && event->head.eventSampleTime == now);
            
        }
    }
    
};

#endif /* IntervalPlugin_hpp */

