//
//  ViewController.swift
//  CoreMLExperiments
//
//  Created by southernchelseafan on 10/21/17.
//  Copyright © 2017 southernchelseafan. All rights reserved.
//

import UIKit
import Vision
import CoreML
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var scene: UIImageView!
    @IBOutlet weak var answerText: UILabel!
    @IBOutlet weak var answerTextIncept: UILabel!
    @IBOutlet weak var answerTextSqueeze: UILabel!
    @IBOutlet weak var answerTextMobile: UILabel!
    
    let vowels: [Character] = ["a", "e", "i", "o", "u"]
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    let label: UILabel = {
        let label = UILabel()
        label.textColor = .yellow
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "CoreML Experiment"
        label.font = label.font.withSize(20)
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.layoutIfNeeded()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func detectSceneGoogleNet(image: CIImage) {
        detectSceneWithModel(image: image, type: "GoogLeNetPlaces")
    }
    
    func detectSceneInception(image: CIImage) {
        detectSceneWithModel(image: image, type: "Inception")
    }
    
    func detectSceneSqueezeNet(image: CIImage) {
        detectSceneWithModel(image: image, type: "SqueezeNet")
    }
    
    func detectSceneMobileNet(image: CIImage) {
        detectSceneWithModel(image: image, type: "MobileNet")
    }
    
    func detectSceneWithModel(image: CIImage, type: String) {
        answerTextIncept.text = "analysing #3"
        // Default to Inceptionv3 model
        var _model: VNCoreMLModel = try! VNCoreMLModel(for : Inceptionv3().model)
        
        if type == "MobileNet" {
            _model = try! VNCoreMLModel(for : MobileNet().model)
        } else if type == "SqueezeNet" {
            _model = try! VNCoreMLModel(for : SqueezeNet().model)
        } else if type == "GoogLeNetPlaces" {
            _model = try! VNCoreMLModel(for : GoogLeNetPlaces().model)
        } else {
            // Leave as Inception
        }
        
        let request = VNCoreMLRequest(model: _model) { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation],
                let topResult = results.first else {
                    fatalError("Unable to get valid result")
            }
            
            let article = (self?.vowels.contains(topResult.identifier.first!))! ? "an" : "a"
            DispatchQueue.main.async { [weak self ] in
                let precision = topResult.confidence * 100
                let answer = String(precision) + "% " + topResult.identifier
                if type == "MobileNet" {
                    self!.answerTextMobile.text = answer
                } else if type == "GoogLeNetPlaces" {
                    self!.answerText.text = answer
                } else if type == "SqueezeNet" {
                    self!.answerTextSqueeze.text = answer
                } else {
                    self!.answerTextIncept.text = answer
                }
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                print(error)
            }
        }
    }
    
}

extension ViewController {
    
    @IBAction func pickImage(_ sender: Any) {
        let pickerController = UIImagePickerController()
        pickerController.delegate = self
        pickerController.sourceType = .savedPhotosAlbum
        present(pickerController, animated: true)
    }
    
    @IBAction func useCamera(_ sender: Any) {
        setupCaptureSession()
        view.addSubview(label)
        setupLabel()
    }

}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func setupCaptureSession() {
        
        // creates a new capture session
        let captureSession = AVCaptureSession()
        
        // search for available capture devices
        let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices
        
        // get capture device, add device input to capture session
        do {
            if let captureDevice = availableDevices.first {
                captureSession.addInput(try AVCaptureDeviceInput(device: captureDevice))
            }
        } catch {
            print(error.localizedDescription)
        }
        
        // setup output, add output to capture session
        let captureOutput = AVCaptureVideoDataOutput()
        captureSession.addOutput(captureOutput)
        
        captureOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.frame
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let model = try? VNCoreMLModel(for: Inceptionv3().model) else { return }
        let request = VNCoreMLRequest(model: model) { (finishedRequest, error) in
            guard let results = finishedRequest.results as? [VNClassificationObservation] else { return }
            guard let Observation = results.first else { return }
            
            DispatchQueue.main.async(execute: {
                self.label.text = "\(Observation.identifier)"
            })
        }
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // executes request
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
    
    func setupLabel() {
        label.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50).isActive = true
    }

    
}

extension ViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true)
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            fatalError("Unable to access camera images")
        }
        
        scene.image = image
        guard let ciImage = CIImage(image: image) else {
            fatalError("Conversion error")
        }
        
        detectSceneGoogleNet(image: ciImage)
        detectSceneInception(image: ciImage)
        detectSceneSqueezeNet(image: ciImage)
        detectSceneMobileNet(image: ciImage)
    }
}

extension ViewController: UINavigationControllerDelegate {
}

