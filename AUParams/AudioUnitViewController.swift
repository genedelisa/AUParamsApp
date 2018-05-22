//
// AUParamsApp
// AudioUnitViewController.swift
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
    
    

import CoreAudioKit

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    var audioUnit: AUAudioUnit?
    
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
        
        // Get the parameter tree and add observers for any parameters that the UI needs to keep in sync with the AudioUnit
        
        NSLog("connecting UI in view did load")
        connectUIToAudioUnit()
        
    }
    
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        NSLog("\(#function)")

        audioUnit = try AUParamsAudioUnit(componentDescription: componentDescription, options: [])
        
        // Check if the UI has been loaded
        if self.isViewLoaded {
            NSLog("connecting UI in create audio unit")
            connectUIToAudioUnit()
        }
        return audioUnit!
    }
    
    func connectUIToAudioUnit() {
        NSLog("\(#function)")
        
        guard let paramTree = audioUnit?.parameterTree else {
            NSLog("The audio unit has no parameters!")
            return
        }
        
        // get the parameter
        intervalAUParameter = paramTree.value(forKey: "intervalParameter") as? AUParameter

        // or
        if let theUnit = audioUnit as? AUParamsAudioUnit {
            if let param =  theUnit.parameterTree?.parameter(withAddress: AUParameterAddress(intervalParameter)) {
                NSLog("intervalParam: \(String(describing: param))")
                self.intervalAUParameter = param
                
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    NSLog("connectUIToAudioUnit new value: \(param.value) will sub 1")
                    strongSelf.intervalSegmentedControl.selectedSegmentIndex = Int(param.value - 1)
                    strongSelf.intervalLabel.text = strongSelf.intervalAUParameter!.string(fromValue: nil)
                }
            }
        }
        
        parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let strongSelf = self else { return }
            
            DispatchQueue.main.async {
                if address == strongSelf.intervalAUParameter!.address {
                    NSLog("observed new value: \(value)")
                    strongSelf.intervalSegmentedControl.selectedSegmentIndex = Int(value - 1)
                    strongSelf.intervalLabel.text = strongSelf.intervalAUParameter!.string(fromValue: nil)
                }
            }
        })
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
        self.intervalAUParameter?.value = interval
        
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
