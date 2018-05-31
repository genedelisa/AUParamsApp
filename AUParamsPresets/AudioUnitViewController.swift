//
// AUParamsApp
// AudioUnitViewController.swift
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
    
    

import CoreAudioKit

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
//    var audioUnit: AUAudioUnit?
    
    /*
     When this view controller is instantiated within the FilterDemoApp, its
     audio unit is created independently, and passed to the view controller here.
     */
    public var audioUnit: AUAudioUnit? {
        didSet {
            /*
             We may be on a dispatch worker queue processing an XPC request at
             this time, and quite possibly the main queue is busy creating the
             view. To be thread-safe, dispatch onto the main queue.
             
             It's also possible that we are already on the main queue, so to
             protect against deadlock in that case, dispatch asynchronously.
             */
            NSLog("got the audio unit \(String(describing: audioUnit))")//
            DispatchQueue.main.async {
                if self.isViewLoaded {
                    self.connectUIToAudioUnit()
                }
            }
        }
    }
    
    var intervalAUParameter: AUParameter?
    
    var parameterObserverToken: AUParameterObserverToken?
    
    @IBOutlet weak var intervalSegmentedControl: UISegmentedControl!
    
    @IBOutlet weak var intervalLabel: UILabel!
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("\(#function)")
        
        if audioUnit == nil {
            return
        }
        
        connectUIToAudioUnit()
    }
    
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        NSLog("\(#function)")
        
        audioUnit = try AUParamsPresetsAudioUnit(componentDescription: componentDescription, options: [])
        
        // Check if the UI has been loaded
//        if self.isViewLoaded {
//            NSLog("\(#function) connecting UI in create audio unit")
//            connectUIToAudioUnit()
//        }
        
        return audioUnit!
    }
    
    
    func connectUIToAudioUnit() {
        NSLog("\(#function)")
        
        guard let paramTree = audioUnit?.parameterTree else {
            NSLog("The audio unit has no parameters!")
            return
        }
        
        // get the parameter
        self.intervalAUParameter = paramTree.value(forKey: "intervalParameter") as? AUParameter
        NSLog("interauparameter \(String(describing: intervalAUParameter))");
        
        // or
//        if let theUnit = audioUnit as? AUParamsPresetsAudioUnit {
//            if let param =  theUnit.parameterTree?.parameter(withAddress: AUParameterAddress(intervalParameter)) {
//                NSLog("connectUIToAudioUnit intervalParam: \(String(describing: param))")
//                self.intervalAUParameter = param
//
//                DispatchQueue.main.async { [weak self] in
//                    guard let strongSelf = self else { return }
//                    NSLog("connectUIToAudioUnit new value: \(param.value) will sub 1")
//                    strongSelf.intervalSegmentedControl.selectedSegmentIndex = Int(param.value - 1)
//                    strongSelf.intervalLabel.text = strongSelf.intervalAUParameter!.string(fromValue: nil)
//                }
//            }
//        }
        

        parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let strongSelf = self else {
                NSLog("self is nil; returning")
                return
            }
            
            DispatchQueue.main.async {
                if address == strongSelf.intervalAUParameter!.address {
                    NSLog("connectUIToAudioUnit2 observed new value: \(value)")
                    strongSelf.intervalSegmentedControl.selectedSegmentIndex = Int(value - 1)
                    strongSelf.intervalLabel.text = strongSelf.intervalAUParameter!.string(fromValue: nil)
                }
            }
        })

        self.intervalLabel.text = self.intervalAUParameter!.string(fromValue: nil)
        self.intervalSegmentedControl.selectedSegmentIndex = Int(self.intervalAUParameter!.value - 1)
        
    }
    
    // if I had a slider
    @IBAction func intervalSliderValueChangedAction(_ sender: UISlider) {
        guard let theAudioUnit = audioUnit as? AUParamsPresetsAudioUnit,
            let intervalParameter =
            theAudioUnit.parameterTree?.parameter(withAddress: AUParameterAddress(intervalParameter))
            else {
                NSLog("could not get the audio unit or the parameter in \(#function)")
                return
        }
        
        intervalParameter.setValue(sender.value, originator: parameterObserverToken)
    }
    
    @IBAction func intervalValueChanged(_ sender: UISegmentedControl) {
        
        var interval: AUValue = 0
        
        switch sender.selectedSegmentIndex {
        case 0: interval = 1
        case 1: interval = 2
        case 2: interval = 3
        case 3: interval = 4
        case 4: interval = 5
        case 5: interval = 6
        case 6: interval = 7
        case 7: interval = 8
        case 8: interval = 9
        case 9: interval = 10
        case 10: interval = 11
        case 11: interval = 12
        default: break
        }
        
        //or  self.intervalAUParameter?.value = interval
        self.intervalAUParameter?.setValue(interval, originator: parameterObserverToken)
        
        // just debugging
        if let p = self.intervalAUParameter {
            NSLog("intervalParam: \(String(describing: p))")
            let s = p.string(fromValue: &p.value)
            NSLog("value string: \(s)")
            NSLog("final value: \(p.value)")
        } else {
            NSLog("oops self.intervalAUParameter is nil")
        }
        
    }
    
    
}
