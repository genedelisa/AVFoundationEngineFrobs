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
        let fileURL = NSBundle.mainBundle().URLForResource("modem-dialing-02", withExtension: "mp3")
        var error: NSError?
        audioFile = AVAudioFile(forReading: fileURL, error: &error)
        if let e = error {
            println(e.localizedDescription)
        }
    }
    
    
    func initAudioEngine () {
        
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        playerTapNode = AVAudioPlayerNode()
        engine.attachNode(playerNode)
        engine.attachNode(playerTapNode)
        mixer = engine.mainMixerNode
        // engine.connect(playerNode, to: mixer, format: mixer.outputFormatForBus(0))
        //        engine.connect(playerNode, to: engine.mainMixerNode, format: mixer.outputFormatForBus(0))
        
        
        var iformat = engine.inputNode.inputFormatForBus(0)
        println("input format \(iformat)")
        
        var error: NSError?
        if !engine.startAndReturnError(&error) {
            println("error couldn't start engine")
            if let e = error {
                println("error \(e.localizedDescription)")
            }
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector:"configChange:",
            name:AVAudioEngineConfigurationChangeNotification,
            object:engine)
        
        reverb()
        distortion()
        delay()
        //        addEQ(audioFile)
        //        timePitch()
        //        varispeed()
        
        var format = mixer.outputFormatForBus(0)
        //engine.connect(playerNode, to: mixer, format: format)
        
        engine.connect(playerNode, to: reverbNode, format: format)
        engine.connect(reverbNode, to: distortionNode, format: format)
        engine.connect(distortionNode, to: delayNode, format: format)
        engine.connect(delayNode, to: mixer, format: format)
        
        // tapMixer()

        
    }
    
    func configChange(notification:NSNotification) {
        println("config change")
    }
    
    func bounceEngine() {
        if engine.running {
            engine.stop()
        } else {
            var error: NSError?
            if !engine.startAndReturnError(&error) {
                println("error couldn't start engine")
                if let e = error {
                    println("error \(e.localizedDescription)")
                }
            }
        }
    }
    func engineStart() {
        var error: NSError?
        if !engine.startAndReturnError(&error) {
            println("error couldn't start engine")
            if let e = error {
                println("error \(e.localizedDescription)")
                
                
                
                
            }
        }
    }
    
    /**
    Use headphones!
    */
    @IBAction func useInputNode(sender: AnyObject) {
        //engine.disconnectNodeOutput(playerNode)
        // engine.stop()
        //engine.reset()
        println("\(__FUNCTION__) connecting input \(engine.inputNode)")
        
        /*
        Audio input is performed via an input node. The engine creates a singleton on demand when
        this property is first accessed. To receive input, connect another node from the output of
        the input node, or create a recording tap on it.
        
        The AVAudioSesssion category and/or availability of hardware determine whether an app can
        perform input. Check the input format of input node (i.e. hardware format) for non-zero
        sample rate and channel count to see if input is enabled.
        */
        
        setSessionRecord()
        var format = engine.inputNode.inputFormatForBus(0)
        engine.mainMixerNode.volume = 1.0
        engine.mainMixerNode.pan = 0.0
        println("input format sr \(format.sampleRate) channels \(format.channelCount)")
        engine.connect(engine.inputNode, to: reverbNode, format: format)
//        engine.connect(engine.inputNode, to: engine.mainMixerNode, format: format)
        // engineStart()
        // engine.disconnectNodeOutput(engine.inputNode)
    }
    
    func recordInputNodeToFile() {
        let filename = "testrecord.wav"
        let docsDir = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0] as NSString
        let path = docsDir.stringByAppendingPathComponent(filename)
        let url = NSURL(fileURLWithPath: path)
        
        let settings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1 ]
        
        var possibleError : NSError?
        audioFile = AVAudioFile(forWriting: url, settings: settings, error: &possibleError)
        if let error = possibleError {
            println("Error opening audio file for writing: \(error.localizedDescription)")
            return
        }
        
        let input = engine.inputNode
        input.installTapOnBus(0, bufferSize: 4096, format: audioFile.processingFormat) {
            (buffer : AVAudioPCMBuffer!, when : AVAudioTime!) in
            //println("Got buffer of length: \(buffer.frameLength) at time: \(when)")
            
            var possibleWriteError : NSError?
            self.audioFile.writeFromBuffer(buffer, error: &possibleWriteError)
            if let error = possibleWriteError {
                println("Error writing audio data to file")
            }
        }
        
        println("starting audio engine for recording")
        println("writing to \(path)")
        engine.startAndReturnError(&possibleError)
        
        if let error = possibleError {
            println("Error starting audio engine: \(error.localizedDescription)")
        }
        
    }
    func stopRecording() {
        self.engine.inputNode.removeTapOnBus(0)
        self.engine.stop()
    }
    
    
    func setSessionPlayAndRecord() {
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        var error: NSError?
        if !session.setCategory(AVAudioSessionCategoryPlayAndRecord, error:&error) {
            println("could not set session category")
            if let e = error {
                println(e.localizedDescription)
            }
        }
        if !session.setActive(true, error: &error) {
            println("could not make session active")
            if let e = error {
                println(e.localizedDescription)
            }
        }
    }
    
    func setSessionRecord() {
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        var error: NSError?
        if !session.setCategory(AVAudioSessionCategoryRecord, error:&error) {
            println("could not set session category")
            if let e = error {
                println(e.localizedDescription)
            }
        }
        if !session.setActive(true, error: &error) {
            println("could not make session active")
            if let e = error {
                println(e.localizedDescription)
            }
        }
    }
    
    
    @IBAction func reverbWetDryMix(sender: UISlider) {
        reverbNode.wetDryMix = sender.value
    }
    
    var reverbNode:AVAudioUnitReverb!
    func reverb() {
        reverbNode = AVAudioUnitReverb()
        reverbNode.loadFactoryPreset(.Cathedral)
        engine.attachNode(reverbNode)
        //The blend is specified as a percentage. The range is 0% (all dry) through 100% (all wet).
        reverbNode.wetDryMix = 0.0
        // engine.connect(playerNode, to: reverbNode, format: mixer.outputFormatForBus(0))
        // engine.connect(reverbNode, to: mixer, format: mixer.outputFormatForBus(0))
    }
    
    @IBAction func distortionWetDryMix(sender: UISlider) {
        distortionNode.wetDryMix = sender.value
    }
    
    var distortionNode:AVAudioUnitDistortion!
    func distortion() {
        distortionNode = AVAudioUnitDistortion()
        distortionNode.loadFactoryPreset(.SpeechAlienChatter)
        // The blend is specified as a percentage. The default value is 50%. The range is 0% (all dry) through 100% (all wet).
        distortionNode.wetDryMix = 0
        //The default value is -6 db. The valid range of values is -80 db to 20 db
        distortionNode.preGain = 0
        engine.attachNode(distortionNode)
        //engine.connect(playerNode, to: auDistortion, format: mixer.outputFormatForBus(0))
        //engine.connect(auDistortion, to: mixer, format: mixer.outputFormatForBus(0))
    }
    
    @IBAction func delayWetDryMix(sender: UISlider) {
        delayNode.wetDryMix = sender.value
    }
    
    @IBAction func delayTime(sender: UISlider) {
        var t = NSTimeInterval(sender.value)
        delayNode.delayTime = t
    }
    
    @IBAction func delayFeedback(sender: UISlider) {
        delayNode.feedback = sender.value
    }
    
    @IBAction func delayLowpass(sender: UISlider) {
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
        
        engine.attachNode(delayNode)
        // engine.connect(playerNode, to: auDelay, format: mixer.outputFormatForBus(0))
        // engine.connect(auDelay, to: mixer, format: mixer.outputFormatForBus(0))
    }
    
    var EQNode:AVAudioUnitEQ!
    func addEQ() {
        EQNode = AVAudioUnitEQ(numberOfBands: 2)
        engine.attachNode(EQNode)
        
        var filterParams = EQNode.bands[0] as AVAudioUnitEQFilterParameters
        filterParams.filterType = .HighPass
        filterParams.frequency = 80.0
        
        filterParams = EQNode.bands[1] as AVAudioUnitEQFilterParameters
        filterParams.filterType = .Parametric
        filterParams.frequency = 500.0
        filterParams.bandwidth = 2.0
        filterParams.gain = 4.0
        
        var format = mixer.outputFormatForBus(0)
        engine.connect(playerNode, to: EQNode, format: format )
        engine.connect(EQNode, to: engine.mainMixerNode, format: format)
    }
    
    var auVarispeed:AVAudioUnitVarispeed!
    func varispeed() {
        auVarispeed = AVAudioUnitVarispeed()
        auVarispeed.rate = 3 //The default value is 1.0. The range of values is 0.25 to 4.0.
        engine.attachNode(auVarispeed)
        engine.connect(playerNode, to: auVarispeed, format: mixer.outputFormatForBus(0))
        engine.connect(auVarispeed, to: mixer, format: mixer.outputFormatForBus(0))
    }
    
    var auTimePitch:AVAudioUnitTimePitch!
    func timePitch() {
        auTimePitch = AVAudioUnitTimePitch()
        auTimePitch.pitch = 1200 // In cents. The default value is 1.0. The range of values is -2400 to 2400
        auTimePitch.rate = 2 //The default value is 1.0. The range of supported values is 1/32 to 32.0.
        engine.attachNode(auTimePitch)
        engine.connect(playerNode, to: auTimePitch, format: mixer.outputFormatForBus(0))
        engine.connect(auTimePitch, to: mixer, format: mixer.outputFormatForBus(0))
    }
    
    @IBAction func playerNodeAction(sender: AnyObject) {
        playerNode.scheduleFile(audioFile, atTime:nil, completionHandler:nil)
        playerNodePlay()
    }
    
    /**
    Uses an AVAudioPlayerNode to play an audio file.
    */
    func playerNodePlay() {
        if engine.running {
            println("engine is running")
            //engine.disconnectNodeOutput(engine.inputNode)
            // engine.connect(playerNode, to: reverbNode, format: mixer.outputFormatForBus(0))
            playerNode.play()
        } else {
            var error: NSError?
            if !engine.startAndReturnError(&error) {
                println("error couldn't start engine")
                if let e = error {
                    println("error \(e.localizedDescription)")
                }
            } else {
                playerNode.play()
            }
        }
    }
    
    /**
    Swift translation of code from that less than optimal WWDC 2014 presentation.
    */
    func printLoudestSample() {
        var error: NSError?
        let fileURL:NSURL = NSBundle.mainBundle().URLForResource("modem-dialing-02", withExtension: "mp3")!
        
        let audioFile = AVAudioFile(forReading: fileURL, error: &error)
        if let e = error {
            println(e.localizedDescription)
        }
        let fileLength = audioFile.length
        
        println("file format: \(audioFile.fileFormat.description)")
        println("processing format: \(audioFile.processingFormat.description)")
        println("file length: \(fileLength) frames")
        println("seconds: \( Double(fileLength)/audioFile.fileFormat.sampleRate)")
        
        let fc:AVAudioFrameCount = 128 * 1024
        var buffer = AVAudioPCMBuffer(PCMFormat: audioFile.processingFormat,
            frameCapacity: fc)
        
        println("mdata 0 : \(buffer.mutableAudioBufferList.memory.mBuffers.mData[0])")
        println("buffer nchannels \(buffer.mutableAudioBufferList.memory.mBuffers.mNumberChannels)")
        println("buffer databyte size: \(buffer.mutableAudioBufferList.memory.mBuffers.mDataByteSize)")
        
        var position:AVAudioFramePosition = 0
        var loudestSample:Float = 0
        var loudestSamplePosition:AVAudioFramePosition = 0
        while audioFile.framePosition < fileLength {
            var readPosition = audioFile.framePosition
            if !audioFile.readIntoBuffer(buffer, error:&error) {
                if let e = error {
                    println(e.localizedDescription)
                }
            }
            if buffer.frameLength == 0 {
                break
            }
            
            //FIXME: ++ prefix? that's in the wwdc slides
            for var channelIndex = 0; channelIndex < Int(buffer.format.channelCount); ++channelIndex {
                var data = buffer.floatChannelData[channelIndex]
                for var frameIndex = 0; frameIndex < Int(buffer.frameLength); ++frameIndex {
                    var sampleAbsLevel = fabs(data[frameIndex])
                    if sampleAbsLevel > loudestSample {
                        loudestSample = sampleAbsLevel
                        loudestSamplePosition = readPosition + frameIndex
                    }
                }
            }
        }
        println("loudest sample is \(loudestSample) at position \(loudestSamplePosition)")
    }
    
    func tapInput() {
        var audioInputNode = engine.inputNode
        var frameLength:AVAudioFrameCount = 128
        audioInputNode.installTapOnBus(0, bufferSize:frameLength, format: audioInputNode.outputFormatForBus(0), block: {(buffer, time) in
            for var channelIndex = 0; channelIndex < Int(buffer.format.channelCount); ++channelIndex {
                var data = buffer.floatChannelData[channelIndex]
                for var frameIndex = 0; frameIndex < Int(buffer.frameLength); ++frameIndex {
                    // data[frameIndex] = blah blah
                    self.playerTapNode.scheduleBuffer(buffer, atTime: nil, options: nil, completionHandler: nil)
                }
            }
        })
    }
    
    var mixerIsTapped:Bool = false
    @IBAction func tap(sender: AnyObject) {
        if !mixerIsTapped {
            println("tapping mixer")
            tapMixer()
            mixerIsTapped = true
        } else {
            println("untapping mixer")
            mixerIsTapped = false
            mixer.removeTapOnBus(0)
        }
    }
    
    @IBAction func playTapped(sender: AnyObject) {
        var format = mixer.outputFormatForBus(0)
        engine.connect(playerTapNode, to: engine.mainMixerNode, format: format)
        playerTapNode.play()
        println("playing tap node \(engine.running)")
    }
    
    /**
    Taps the mixer output and shoves it into the playerTapNode for later playback.
    */
    func tapMixer() {
        var frameLength:AVAudioFrameCount = 4096
        
        var format = mixer.outputFormatForBus(0)
        mixer.installTapOnBus(0, bufferSize:frameLength, format: format, block:
            {(buffer:AVAudioPCMBuffer!, time:AVAudioTime!) in
                //                println("got a mixer buffer \(time)")
                //                println("got a mixer buffer bc \(buffer.format.channelCount)")
                //                println("got a mixer buffer fc \(format.channelCount)")
                self.playerTapNode.scheduleBuffer(buffer, atTime: nil, options: nil, completionHandler: nil)
        })
    }
    
    
    
    
    
    func radiansToDegrees(radians:Double) -> Double {
        return radians * (180.0 / M_PI)
    }
    
    func degreesToRadians(degrees:Double) -> Double {
        return degrees / (180.0 * M_PI)
    }
    
}

