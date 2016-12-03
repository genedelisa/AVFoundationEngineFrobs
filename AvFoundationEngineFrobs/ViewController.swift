//
//  ViewController.swift
//  AvFoundationEngineFrobs
//
//  Created by Gene De Lisa on 8/14/14.
//  Copyright (c) 2014 Gene De Lisa. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    var engine:AVAudioEngine!
    var playerNode:AVAudioPlayerNode!
    var playerTapNode:AVAudioPlayerNode!
    var mixer:AVAudioMixerNode!
    var sampler:AVAudioUnitSampler!
    var buffer:AVAudioPCMBuffer!
    var audioFile:AVAudioFile!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initAudioEngine()
        loadAudioFile()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    /**
     called by playerNodeAction
     */
    func loadAudioFile() {
        let fileURL = Bundle.main.url(forResource: "modem-dialing-02", withExtension: "mp3")
        
        do {
            audioFile = try AVAudioFile(forReading: fileURL!)
        } catch {
            print("error \(error.localizedDescription)")
        }
        
    }
    
    
    func initAudioEngine () {
        
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        playerTapNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.attach(playerTapNode)
        mixer = engine.mainMixerNode
        // engine.connect(playerNode, to: mixer, format: mixer.outputFormatForBus(0))
        //        engine.connect(playerNode, to: engine.mainMixerNode, format: mixer.outputFormatForBus(0))
        
        mixer.outputVolume = 1.0
        mixer.pan = 0.0 // -1 to +1
        let iformat = engine.inputNode?.inputFormat(forBus: 0)
        print("input format \(iformat)")
        
        
        do {
            try engine.start()
        } catch {
            print("error \(error.localizedDescription)")
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(ViewController.configChange(_:)),
                                               name:NSNotification.Name.AVAudioEngineConfigurationChange,
                                               object:engine)
        
        reverb()
        distortion()
        delay()
        //        addEQ(audioFile)
        //        timePitch()
        //        varispeed()
        
        let format = mixer.outputFormat(forBus: 0)
        //engine.connect(playerNode, to: mixer, format: format)
        
        engine.connect(playerNode, to: reverbNode, format: format)
        engine.connect(reverbNode, to: distortionNode, format: format)
        engine.connect(distortionNode, to: delayNode, format: format)
        engine.connect(delayNode, to: mixer, format: format)
        
        // tapMixer()
        
        
    }
    
    func configChange(_ notification:Notification) {
        print("config change")
    }
    
    func bounceEngine() {
        if engine.isRunning {
            engine.stop()
        } else {
            do {
                try engine.start()
            } catch {
                print("error \(error.localizedDescription)")
            }
            
        }
    }
    func engineStart() {
        do {
            try engine.start()
        } catch {
            print("error \(error.localizedDescription)")
        }
    }
    
    /**
     Use headphones!
     */
    @IBAction func useInputNode(_ sender: AnyObject) {
        engine.stop()
        print("\(#function) connecting input \(engine.inputNode)")
        
        /*
         Audio input is performed via an input node. The engine creates a singleton on demand when
         this property is first accessed. To receive input, connect another node from the output of
         the input node, or create a recording tap on it.
         
         The AVAudioSesssion category and/or availability of hardware determine whether an app can
         perform input. Check the input format of input node (i.e. hardware format) for non-zero
         sample rate and channel count to see if input is enabled.
         */
        
        setSessionPlayAndRecord()
        
        let format = engine.inputNode?.inputFormat(forBus: 0)
        engine.mainMixerNode.volume = 1.0
        engine.mainMixerNode.pan = 0.0
        print("input format sr \(format?.sampleRate) channels \(format?.channelCount)")
        engine.connect(engine.inputNode!, to: reverbNode, format: format)
        engineStart()
    }
    
    func recordInputNodeToFile() {
        let filename = "testrecord.wav"
        let docsDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0] as NSString
        let path = docsDir.appendingPathComponent(filename)
        let url = URL(fileURLWithPath: path)
        
        let settings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1 ] as [String : Any]
        
        do {
            audioFile = try AVAudioFile(forWriting: url, settings: settings)
        } catch {
            print("error \(error.localizedDescription)")

        }
        
        
        let input = engine.inputNode
        input?.installTap(onBus: 0, bufferSize: 4096, format: audioFile.processingFormat) {
            (buffer : AVAudioPCMBuffer!, when : AVAudioTime!) in
            //print("Got buffer of length: \(buffer.frameLength) at time: \(when)")
            
            do {
                try self.audioFile.write(from: buffer)
            } catch {
                print("error \(error.localizedDescription)")

            }
            
        }
        
        print("starting audio engine for recording")
        print("writing to \(path)")
        do {
            try engine.start()
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
        }
        
        
    }
    func stopRecording() {
        self.engine.inputNode?.removeTap(onBus: 0)
        self.engine.stop()
    }
    
    
    func setSessionPlayAndRecord() {
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
        } catch{
            print("could not set session category")
            print("error \(error.localizedDescription)")

        }
        do {
            try session.setActive(true)
        } catch{
            print("could not make session active")
            print("error \(error.localizedDescription)")

        }
        
    }
    
    func setSessionRecord() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSessionCategoryRecord)
        } catch{
            print("could not set session category")
            print("error \(error.localizedDescription)")

        }
        do {
            try session.setActive(true)
        } catch{
            print("could not make session active")
            print("error \(error.localizedDescription)")

        }
    }
    
    
    @IBAction func reverbWetDryMix(_ sender: UISlider) {
        reverbNode.wetDryMix = sender.value
    }
    
    var reverbNode:AVAudioUnitReverb!
    func reverb() {
        reverbNode = AVAudioUnitReverb()
        reverbNode.loadFactoryPreset(.cathedral)
        engine.attach(reverbNode)
        //The blend is specified as a percentage. The range is 0% (all dry) through 100% (all wet).
        reverbNode.wetDryMix = 0.0
        // engine.connect(playerNode, to: reverbNode, format: mixer.outputFormatForBus(0))
        // engine.connect(reverbNode, to: mixer, format: mixer.outputFormatForBus(0))
    }
    
    @IBAction func distortionWetDryMix(_ sender: UISlider) {
        distortionNode.wetDryMix = sender.value
    }
    
    var distortionNode:AVAudioUnitDistortion!
    func distortion() {
        distortionNode = AVAudioUnitDistortion()
        distortionNode.loadFactoryPreset(.speechAlienChatter)
        // The blend is specified as a percentage. The default value is 50%. The range is 0% (all dry) through 100% (all wet).
        distortionNode.wetDryMix = 0
        //The default value is -6 db. The valid range of values is -80 db to 20 db
        distortionNode.preGain = 0
        engine.attach(distortionNode)
        //engine.connect(playerNode, to: auDistortion, format: mixer.outputFormatForBus(0))
        //engine.connect(auDistortion, to: mixer, format: mixer.outputFormatForBus(0))
    }
    
    @IBAction func delayWetDryMix(_ sender: UISlider) {
        delayNode.wetDryMix = sender.value
    }
    
    @IBAction func delayTime(_ sender: UISlider) {
        let t = TimeInterval(sender.value)
        delayNode.delayTime = t
    }
    
    @IBAction func delayFeedback(_ sender: UISlider) {
        delayNode.feedback = sender.value
    }
    
    @IBAction func delayLowpass(_ sender: UISlider) {
        delayNode.lowPassCutoff = sender.value
    }
    
    var delayNode:AVAudioUnitDelay!
    func delay() {
        delayNode = AVAudioUnitDelay()
        //The delay is specified in seconds. The default value is 1. The valid range of values is 0 to 2 seconds.
        delayNode.delayTime = 1
        
        //The feedback is specified as a percentage. The default value is 50%. The valid range of values is -100% to 100%.
        delayNode.feedback = 50
        
        // The default value is 15000 Hz. The valid range of values is 10 Hz through (sampleRate/2).
        delayNode.lowPassCutoff = 5000
        
        
        //The blend is specified as a percentage. The default value is 100%. The valid range of values is 0% (all dry) through 100% (all wet).
        delayNode.wetDryMix = 0
        
        engine.attach(delayNode)
        // engine.connect(playerNode, to: auDelay, format: mixer.outputFormatForBus(0))
        // engine.connect(auDelay, to: mixer, format: mixer.outputFormatForBus(0))
    }
    
    var EQNode:AVAudioUnitEQ!
    func addEQ() {
        EQNode = AVAudioUnitEQ(numberOfBands: 2)
        engine.attach(EQNode)
        
        var filterParams = EQNode.bands[0] as AVAudioUnitEQFilterParameters
        filterParams.filterType = .highPass
        filterParams.frequency = 80.0
        
        filterParams = EQNode.bands[1] as AVAudioUnitEQFilterParameters
        filterParams.filterType = .parametric
        filterParams.frequency = 500.0
        filterParams.bandwidth = 2.0
        filterParams.gain = 4.0
        
        let format = mixer.outputFormat(forBus: 0)
        engine.connect(playerNode, to: EQNode, format: format )
        engine.connect(EQNode, to: engine.mainMixerNode, format: format)
    }
    
    var auVarispeed:AVAudioUnitVarispeed!
    func varispeed() {
        auVarispeed = AVAudioUnitVarispeed()
        auVarispeed.rate = 3 //The default value is 1.0. The range of values is 0.25 to 4.0.
        engine.attach(auVarispeed)
        engine.connect(playerNode, to: auVarispeed, format: mixer.outputFormat(forBus: 0))
        engine.connect(auVarispeed, to: mixer, format: mixer.outputFormat(forBus: 0))
    }
    
    var auTimePitch:AVAudioUnitTimePitch!
    func timePitch() {
        auTimePitch = AVAudioUnitTimePitch()
        auTimePitch.pitch = 1200 // In cents. The default value is 1.0. The range of values is -2400 to 2400
        auTimePitch.rate = 2 //The default value is 1.0. The range of supported values is 1/32 to 32.0.
        engine.attach(auTimePitch)
        engine.connect(playerNode, to: auTimePitch, format: mixer.outputFormat(forBus: 0))
        engine.connect(auTimePitch, to: mixer, format: mixer.outputFormat(forBus: 0))
    }
    
    @IBAction func playerNodeAction(_ sender: AnyObject) {
        playerNode.scheduleFile(audioFile, at:nil, completionHandler:nil)
        playerNodePlay()
    }
    
    /**
     Uses an AVAudioPlayerNode to play an audio file.
     */
    func playerNodePlay() {
        if engine.isRunning {
            print("engine is running")
            engine.disconnectNodeOutput(engine.inputNode!)
            engine.connect(playerNode, to: reverbNode, format: mixer.outputFormat(forBus: 0))
            playerNode.play()
        } else {
            
            do {
                try engine.start()
            } catch {
                print("error couldn't start engine")
                print("error \(error.localizedDescription)")

            }
            playerNode.play()
            
        }
    }
    
    /**
     Swift translation of code from that less than optimal WWDC 2014 presentation.
     */
    func printLoudestSample() {
        
        let fileURL:URL = Bundle.main.url(forResource: "modem-dialing-02", withExtension: "mp3")!
        
        let audioFile:AVAudioFile!
        do {
            audioFile = try AVAudioFile(forReading: fileURL)
        } catch {
            print("error \(error.localizedDescription)")
            return
        }
        
        let fileLength = audioFile.length
        
        print("file format: \(audioFile.fileFormat.description)")
        print("processing format: \(audioFile.processingFormat.description)")
        print("file length: \(fileLength) frames")
        print("seconds: \( Double(fileLength)/audioFile.fileFormat.sampleRate)")
        
        let fc:AVAudioFrameCount = 128 * 1024
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                      frameCapacity: fc)
        
        //  print("mdata 0 : \(buffer.mutableAudioBufferList.pointee.mBuffers.mData[0])")
        //  print("buffer nchannels \(buffer.mutableAudioBufferList.memory.mBuffers.mNumberChannels)")
        //  print("buffer databyte size: \(buffer.mutableAudioBufferList.memory.mBuffers.mDataByteSize)")
        
        //var position:AVAudioFramePosition = 0
        var loudestSample:Float = 0
        var loudestSamplePosition:AVAudioFramePosition = 0
        while audioFile.framePosition < fileLength {
            let readPosition = audioFile.framePosition
            do {
                try audioFile.read(into: buffer)
            } catch {
                print("error \(error.localizedDescription)")

            }
            
            if buffer.frameLength == 0 {
                break
            }
            
            //FIXME: ++ prefix? that's in the wwdc slides
            for channelIndex in 0 ..< Int(buffer.format.channelCount) {
                //            for var channelIndex = 0; channelIndex < Int(buffer.format.channelCount); channelIndex += 1 {
                let data = buffer.floatChannelData![channelIndex]
                for frameIndex in 0 ..< Int(buffer.frameLength) {
                    let sampleAbsLevel = fabs(data[frameIndex])
                    if sampleAbsLevel > loudestSample {
                        loudestSample = sampleAbsLevel
                        loudestSamplePosition = readPosition + frameIndex
                    }
                }
            }
        }
        print("loudest sample is \(loudestSample) at position \(loudestSamplePosition)")
    }
    
    func tapInput() {
        let audioInputNode = engine.inputNode
        let frameLength:AVAudioFrameCount = 128
        audioInputNode?.installTap(onBus: 0, bufferSize:frameLength, format: audioInputNode?.outputFormat(forBus: 0), block: {(buffer, time) in
            for channelIndex in 0 ..< Int(buffer.format.channelCount) {
                var data = buffer.floatChannelData?[channelIndex]
                for frameIndex in 0 ..< Int(buffer.frameLength) {
                    // data[frameIndex] = blah blah
                    self.playerTapNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
                }
            }
        })
    }
    
    var mixerIsTapped:Bool = false
    @IBAction func tap(_ sender: AnyObject) {
        if !mixerIsTapped {
            print("tapping mixer")
            tapMixer()
            mixerIsTapped = true
        } else {
            print("untapping mixer")
            mixerIsTapped = false
            mixer.removeTap(onBus: 0)
        }
    }
    
    @IBAction func playTapped(_ sender: AnyObject) {
        let format = mixer.outputFormat(forBus: 0)
        engine.connect(playerTapNode, to: engine.mainMixerNode, format: format)
        playerTapNode.play()
        print("playing tap node \(engine.isRunning)")
    }
    
    /**
     Taps the mixer output and shoves it into the playerTapNode for later playback.
     */
    func tapMixer() {
        let frameLength:AVAudioFrameCount = 4096
        
        let format = mixer.outputFormat(forBus: 0)
        mixer.installTap(onBus: 0, bufferSize:frameLength, format: format, block:
            {(buffer:AVAudioPCMBuffer!, time:AVAudioTime!) in
                //                print("got a mixer buffer \(time)")
                //                print("got a mixer buffer bc \(buffer.format.channelCount)")
                //                print("got a mixer buffer fc \(format.channelCount)")
                self.playerTapNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        })
    }
    
    
    
    
    
    func radiansToDegrees(_ radians:Double) -> Double {
        return radians * (180.0 / M_PI)
    }
    
    func degreesToRadians(_ degrees:Double) -> Double {
        return degrees / (180.0 * M_PI)
    }
    
    
    
}

