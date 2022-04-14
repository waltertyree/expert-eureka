//
//  ViewController.swift
//  gifmaker
//
//

import UIKit
import AVFoundation
import QuickLook

class ViewController: UIViewController {
  var currentTime: Double = 0.0 //seconds
  var startTime: Double = 2.0 //seconds
  var endTime: Double =  6.0 //seconds
  var frameRate = 20 //how many frames per second

  var animatedGifFileURL = URL(string: "")

  var player: AVPlayer?

  @IBOutlet var spinner: UIActivityIndicatorView!
  @IBOutlet var playerView: UIView!

  @IBOutlet var timeScrubber: UISlider!
  @IBOutlet var createGIFButton: UIButton!
  @IBOutlet var currentTimeLabel: UILabel!
  @IBOutlet var startTimeLabel: UILabel!
  @IBOutlet var endTimeLabel: UILabel!
  @IBOutlet var markStartButton: UIButton!
  @IBOutlet var markEndButton: UIButton!


  override func viewDidLoad() {
    super.viewDidLoad()

    updateUI()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if player == nil {
      self.player = AVPlayer(url: Bundle.main.url(forResource: "swish", withExtension: "mp4")!)

      let playerLayer = AVPlayerLayer(player: player)
      playerLayer.frame = playerView.layer.bounds
      playerLayer.videoGravity = .resizeAspect

      playerView.layer.addSublayer(playerLayer)

    }
  }

  func updateUI() {
    self.startTimeLabel.text = String(format: "%.3f", startTime)
    self.endTimeLabel.text = String(format: "%.3f", endTime)
    self.currentTimeLabel.text = String(format: "%.3f", currentTime)
    let seekTime = CMTimeMakeWithSeconds(currentTime, preferredTimescale: 600)
    self.player?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
  }

  @IBAction func scrubberChanged(_ sender: UISlider) {
    guard let videoDuration = self.player?.currentItem?.duration else { return }
    self.currentTime = Double(sender.value) * videoDuration.seconds
    updateUI()
  }

  @IBAction func startTimeMarked(_ sender: UIButton) {
    startTime = currentTime
    updateUI()

  }

  @IBAction func endTimeMarked(_ sender: UIButton) {
    endTime = currentTime
    updateUI()
  }


  @IBAction func generateAnimatedGif(_ sender: Any) {
    guard let movie = self.player?.currentItem?.asset else {
      print("error, no movie in player")
      return
    }

    spinner.startAnimating()
    
    let totalFrames = Int((endTime - startTime) * Double(frameRate))


    //create empty file to hold gif
    let destinationFilename = String(NSUUID().uuidString + ".gif")
    let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(destinationFilename)

    //metadata for gif file to describe it as an animated gif
    let fileDictionary = [kCGImagePropertyGIFDictionary : [
      kCGImagePropertyGIFLoopCount : 0]]

    //metadata to apply to each frame of the file (we'll use this in the completion block)
    let frameDictionary = [kCGImagePropertyGIFDictionary : [
      kCGImagePropertyGIFDelayTime: 1.0 / 20.0]]



    guard let animatedGifFile = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.gif.identifier as CFString, totalFrames, nil) else {
      print("error creating gif file")
      return
    }
    CGImageDestinationSetProperties(animatedGifFile, fileDictionary as CFDictionary)


    //generate frames
    let frameGenerator = AVAssetImageGenerator(asset: movie)
    frameGenerator.requestedTimeToleranceBefore = CMTime(seconds: 0, preferredTimescale: 600)
    frameGenerator.requestedTimeToleranceAfter = CMTime(seconds: 0, preferredTimescale: 600)

    var timeStamps = [NSValue]()



    for currentFrame in 0..<totalFrames {
      let frameTime = Double(currentFrame) / Double(frameRate)
      let timeStamp = CMTime(seconds: startTime + Double(frameTime), preferredTimescale: 600)
      timeStamps.append(NSValue(time: timeStamp))
    }

    //The completion handler never says when it's actually done so
    //keeping track of the number of frames it's generated will let us know when to
    //end the process and clean up
    var framesGenerated = 0

    frameGenerator.generateCGImagesAsynchronously(forTimes: timeStamps) { requestedTime, frameImage, actualTime, result, error in
      guard let frameImage = frameImage else {
        print("no image")
        return

      }

      framesGenerated = framesGenerated + 1
      CGImageDestinationAddImage(animatedGifFile, frameImage, frameDictionary as CFDictionary)

      if framesGenerated == totalFrames {

        if CGImageDestinationFinalize(animatedGifFile) {
          DispatchQueue.main.async {
            self.spinner.stopAnimating()
            print("success \(destinationURL)")
            self.animatedGifFileURL = destinationURL

            //this is just a standard QuickLook controller
            //I like using this instead of an embedded WebKit view to display
            //the animated gif
            let qlPreviewController = QLPreviewController()
            qlPreviewController.dataSource = self
            qlPreviewController.currentPreviewItemIndex = 0
            self.present(qlPreviewController, animated: true)
          }

        }
      }

    }
  }

}

extension ViewController: QLPreviewControllerDataSource {
  func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
    return 1
  }

  func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
    self.animatedGifFileURL! as QLPreviewItem
  }


}

