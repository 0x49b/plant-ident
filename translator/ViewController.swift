//
//  ViewController.swift
//  Object Around Translator
//
//  Created by Tayeb on 10/10/19.
//  Copyright © 2019 Tayeb. All rights reserved.
//

import UIKit
import AVFoundation
import GoogleMobileAds

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, GADInterstitialDelegate {
    var captureSession: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var modelReady = false
    var selectedFromIndex = 1
    var selectedToIndex = 2
    var interstitial: GADInterstitial!
    //imagepicker setup
    let imagePicker = UIImagePickerController()
    //setup capture session on viewDidAppear()
    @IBOutlet weak var languageButton: UIButton!
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resultView.text = "Result will appear here."
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //setup
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
            else {
                print("Unable to access back camera!")
                //self.resultView.text = "Cannot Access camera!"
                return
        }
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            stillImageOutput = AVCapturePhotoOutput()
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(stillImageOutput)
                setupLivePreview()
            }
        }
        catch let error  {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
            self.resultView.text = "cannot access camera!"
        }
    }
    
    //stop running when the view will disappear
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        resultView.text = "Result will appear here."
        resultView.layer.masksToBounds = true
        resultView.layer.cornerRadius = 20
        imagePicker.delegate = self
        interstitial = createAndLoadInterstitial()
        
    }

    @IBOutlet weak var previewView: UIImageView!
    @IBOutlet weak var cameraView: UIView!
    
    
    @IBOutlet weak var resultView: UILabel!
    @IBOutlet weak var captureAgainButton: UIButton!
    
    @IBOutlet weak var captureButton: UIButton!
    @IBAction func didTakePic(_ sender: Any) {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func setupLivePreview() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        cameraView.layer.addSublayer(videoPreviewLayer)
        DispatchQueue.global(qos: .userInitiated).async { //[weak self] in
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.videoPreviewLayer.frame = self.cameraView.bounds
                print(self.videoPreviewLayer.frame)
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        
        let image = UIImage(data: imageData)
        if let imageExtracted = image {
            resultView.text = "Loading result..."
            identifyPlant(imageToUpload: imageExtracted)
            //self.resultView.text = "English: " + objectTag + "\n" + "French: " + TranslatedText
            
        } else {
            print("error, image is nil.")
        }
        previewView.image = image
        previewView.isHidden = false
        captureButton.isEnabled = false
        captureButton.isHidden = true
        captureAgainButton.isEnabled = true
        captureAgainButton.isHidden = false
    }
    
    @IBAction func captureAgainClicked(_ sender: Any) {
        captureAgainButton.isEnabled = false
        captureAgainButton.isHidden = true
        previewView.isHidden = true
        captureButton.isEnabled = true
        captureButton.isHidden = false
        resultView.text = "Result will appear here."
        showInterstitialIfLoaded()
    }
    
    
    func identifyPlant(imageToUpload: UIImage){

        //declare parameter as a dictionary which contains string as key and value combination. considering inputs are valid

        
        let image = ViewController.convertImageToBase64String(image: imageToUpload)
        
        let parameters = [
            "images": [image],
            "modifiers": ["similar_images"],
            //"plant_details": ["common_names", "url", "wiki_description", "taxonomy"]
            //"plant_details": ["common_names"]
        ]

        //create the url with URL
        let url = URL(string: ENDPOINT)! //change the url

        //create the session object
        let session = URLSession.shared

        //now create the URLRequest object using the url object
        var request = URLRequest(url: url)
        request.httpMethod = "POST" //set http method as POST

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted) // pass dictionary to nsdata object and set it as request body
        } catch let error {
            print(error.localizedDescription)
        }

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(API_KEY, forHTTPHeaderField: "api-key")

        //create dataTask using the session object to send data to the server
        let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in

            guard error == nil else {
                return
            }
            
            

            // parse json data
            let jsonDecoder = JSONDecoder()
            
            struct sn: Decodable {
                let genus: String

            }
            
            struct plant_detail: Decodable {
                let scientific_name: String
                let structured_name: sn
            }
            struct suggestion: Decodable {
                let id: Int
                let plant_name: String
                let plant_details: plant_detail
                let probability: Double
            }
            struct returnedJSON: Decodable{
                let suggestions: [suggestion]
            }
            do{
                let decodedData = try jsonDecoder.decode(returnedJSON.self, from: data!)
                print(decodedData.suggestions[0].plant_name)
                print(decodedData.suggestions[0].probability)
                DispatchQueue.main.async {
                    self.resultView.text = decodedData.suggestions[0].plant_name + "\nProbability: " + String(decodedData.suggestions[0].probability)
                }
                
            } catch{
                print(error)
            }
        })
        task.resume()
    }
    
    
    
    @IBAction func galleryButtonClicked(_ sender: Any) {
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = false
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let pickedImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage? {
            resultView.text = "Loading result..."
            identifyPlant(imageToUpload: pickedImage)
            previewView.image = pickedImage
            previewView.isHidden = false
            captureButton.isEnabled = false
            captureButton.isHidden = true
            captureAgainButton.isEnabled = true
            captureAgainButton.isHidden = false
        }
        dismiss(animated: true, completion: nil)
    }
    
    func createAndLoadInterstitial() -> GADInterstitial {
        let interstitialWithID = GADInterstitial(adUnitID: ADMOB_INTERSTITIAL_ID)
        interstitialWithID.delegate = self
        interstitialWithID.load(GADRequest())
        return interstitialWithID
    }
    
    func interstitialDidDismissScreen(_ ad: GADInterstitial) {
        interstitial = createAndLoadInterstitial()
    }
    
    func showInterstitialIfLoaded(){
        if interstitial.isReady {
            interstitial.present(fromRootViewController: self)
        } else {
            print("Ad wasn't ready")
        }
    }
    
    public static func  convertImageToBase64String(image : UIImage ) -> String
    {
        let strBase64 =  image.pngData()?.base64EncodedString()
        return strBase64!
    }
    
}

