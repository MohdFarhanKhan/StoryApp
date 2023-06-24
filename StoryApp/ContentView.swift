//
//  ContentView.swift
//  StoryApp
//
//  Created by Najran Emarah on 01/12/1444 AH.
//

import SwiftUI
import AVKit
struct StoryItem: Identifiable {
    let id = UUID()
    let mediaURL: URL
    let isVideo: Bool
    let duration: TimeInterval
}

struct Story: Identifiable {
    let id = UUID()
    let items: [StoryItem]
}
class PlayerObserver: ObservableObject {
    let player: AVPlayer
    
    @Published var currentTime: CMTime = .zero
    
    private var timeObserver: Any?
    
    init(player: AVPlayer) {
        self.player = player
        addTimeObserver()
    }
    
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time
        }
    }
    
    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
    }
}
struct PlayerView: View {
    @ObservedObject var observer: PlayerObserver
    @State var videoDuration : Double = 0
    var player: AVPlayer
    let callBackTime: (Double, Double)->()
    func cmTimeToSeconds(_ time: CMTime) -> TimeInterval? {
        let seconds = CMTimeGetSeconds(time)
        if seconds.isNaN {
            return nil
        }
        return TimeInterval(seconds)
    }


    var body: some View {
        
        VideoPlayer(player: player)
            .onAppear {
                player.play()
                if let currentItem = player.currentItem {
                                    let duration = currentItem.asset.duration
                    videoDuration = CMTimeGetSeconds(duration)
                    print(cmTimeToSeconds(duration))
                                }
                
            }
            .onDisappear {
                player.pause()
            }
            .onReceive(observer.$currentTime) { currentTime in
                // Handle time updates here
                let seconds = CMTimeGetSeconds(currentTime)
                callBackTime(seconds,videoDuration)
                print("Current time: \(seconds) seconds")
            }
            .frame(width:.infinity, height: .infinity)
    }
}
struct PlayerMediaView: View {
    
    let player: AVPlayer
    @StateObject private var observer: PlayerObserver
    let callback: (Double, Double)->()
    init(url: URL, pos:Double ,callback: @escaping (Double, Double)->()) {
        self.callback = callback
        player = AVPlayer(url: url)
        let targetTime = CMTime(seconds: pos ,
                                preferredTimescale: 600)
        player.seek(to: targetTime) { _ in
            // Now the seek is finished, resume normal operation
           
        }
        let obs = PlayerObserver(player: player)
        _observer = StateObject(wrappedValue: obs)
       
    }
    
    var body: some View {
       
        PlayerView(observer: observer, player: player){ time, totTimne in
            callback(time, totTimne)
        }
        .frame(width:.infinity, height: .infinity)
    }
}
// This is the UIView that contains the AVPlayerLayer for rendering the video
class VideoPlayerUIView: UIView {
    private let player: AVPlayer
    private let playerLayer = AVPlayerLayer()
    private let videoPos: Binding<Double>
    private let videoDuration: Binding<Double>
    private let seeking: Binding<Bool>
    private var durationObservation: NSKeyValueObservation?
    private var timeObservation: Any?
    let callback: (Double, Double)->()
    init(player: AVPlayer, videoPos: Binding<Double>, videoDuration: Binding<Double>, seeking: Binding<Bool>, call:@escaping (Double, Double)->()) {
        self.player = player
        self.videoDuration = videoDuration
        self.videoPos = videoPos
        self.seeking = seeking
        callback = call
        super.init(frame: .zero)
    
        backgroundColor = .lightGray
        playerLayer.player = player
        layer.addSublayer(playerLayer)
        
        // Observe the duration of the player's item so we can display it
        // and use it for updating the seek bar's position
        durationObservation = player.currentItem?.observe(\.duration, changeHandler: { [weak self] item, change in
            guard let self = self else { return }
            self.videoDuration.wrappedValue = item.duration.seconds
        })
        
        // Observe the player's time periodically so we can update the seek bar's
        // position as we progress through playback
        timeObservation = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: nil) { [weak self] time in
            guard let self = self else { return }
            // If we're not seeking currently (don't want to override the slider
            // position if the user is interacting)
            guard !self.seeking.wrappedValue else {
                return
            }
        
            // update videoPos with the new video time (as a percentage)
            self.videoPos.wrappedValue = time.seconds / self.videoDuration.wrappedValue
            callback(time.seconds, videoDuration.wrappedValue)
        }
    }
  
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
  
    override func layoutSubviews() {
        super.layoutSubviews()
    
        playerLayer.frame = bounds
    }
    
    func cleanUp() {
        // Remove observers we setup in init
        durationObservation?.invalidate()
        durationObservation = nil
        
        if let observation = timeObservation {
            player.removeTimeObserver(observation)
            timeObservation = nil
        }
    }
  
}

// This is the SwiftUI view which wraps the UIKit-based PlayerUIView above
struct VideoPlayerView: UIViewRepresentable {
    @Binding private(set) var videoPos: Double
    @Binding private(set) var videoDuration: Double
    @Binding private(set) var seeking: Bool
    
    @Binding private(set) var player: AVPlayer
    let callback: (Double, Double)->()
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<VideoPlayerView>) {
        // This function gets called if the bindings change, which could be useful if
        // you need to respond to external changes, but we don't in this example
    }
    
    func makeUIView(context: UIViewRepresentableContext<VideoPlayerView>) -> UIView {
        player.play()
        let uiView = VideoPlayerUIView(player: player,
                                       videoPos: $videoPos,
                                       videoDuration: $videoDuration,
                                       seeking: $seeking){ time, totTime in
            callback(time, totTime)
        }
        return uiView
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        guard let playerUIView = uiView as? VideoPlayerUIView else {
            return
        }
        
        playerUIView.cleanUp()
    }
}

// This is the SwiftUI view that contains the controls for the player
struct VideoPlayerControlsView : View {
    
    @Binding private(set) var videoPos: Double
    @Binding private(set) var videoDuration: Double
    @Binding private(set) var seeking: Bool
    
    @Binding private(set) var  player: AVPlayer
    @Binding private(set)  var playerPaused : Bool
    let callback: (Double, Double)->()
   
    
    var body: some View {
        HStack {
           
            // Play/pause button
            Button(action: togglePlayPause) {
                Image(systemName: playerPaused ? "play" : "pause")
                    .padding(.trailing, 10)
            }
            // Current video time
            Text("\(Utility.formatSecondsToHMS(videoPos * videoDuration))")
            // Slider for seeking / showing video progress
            Slider(value: $videoPos, in: 0...1, onEditingChanged: sliderEditingChanged)
           
            // Video duration
            Text("\(Utility.formatSecondsToHMS(videoDuration))")
        }
        .padding(.leading, 10)
        .padding(.trailing, 10)
    }
    
    private func togglePlayPause() {
        pausePlayer(!playerPaused)
    }
    
    private func pausePlayer(_ pause: Bool) {
        playerPaused = pause
        if playerPaused {
            player.pause()
        }
        else {
            player.play()
        }
    }
    
    private func sliderEditingChanged(editingStarted: Bool) {
        callback(videoPos * videoDuration, videoDuration)
        if editingStarted {
            // Set a flag stating that we're seeking so the slider doesn't
            // get updated by the periodic time observer on the player
            seeking = true
            pausePlayer(true)
        }
        
        // Do the seek if we're finished
        if !editingStarted {
            
            let targetTime = CMTime(seconds: videoPos * videoDuration,
                                    preferredTimescale: 600)
            player.seek(to: targetTime) { _ in
                // Now the seek is finished, resume normal operation
                self.seeking = false
                self.pausePlayer(false)
            }
        }
    }
}

// This is the SwiftUI view which contains the player and its controls
struct VideoPlayerContainerView : View {
    let callback: (Double, Double)->()
    // The progress through the video, as a percentage (from 0 to 1)
    @State private var videoPos: Double = 0
    // The duration of the video in seconds
    @State private var videoDuration: Double = 0
    // Whether we're currently interacting with the seek bar or doing a seek
    @State private var seeking = false
    
    @State private var player: AVPlayer
    @State  var playerPaused: Bool = true
    
    init(url: URL, callBack: @escaping (Double,Double)->()) {
        player = AVPlayer(url: url)
        self.playerPaused = false
        callback = callBack
    }
  
    var body: some View {
        VStack {
            VideoPlayerView(videoPos: $videoPos,
                            videoDuration: $videoDuration,
                            seeking: $seeking,
                            player: $player){ time, totTime in
                callback(time, totTime)
            }
            VideoPlayerControlsView(videoPos: $videoPos,
                                    videoDuration: $videoDuration,
                                    seeking: $seeking,
                                    player: $player,playerPaused: $playerPaused){time, totTime in
                callback(time, totTime)
            }
        }
        .onDisappear {
            // When this View isn't being shown anymore stop the player
            self.player.replaceCurrentItem(with: nil)
        }
    }
}
struct StoryView: View {
    @State private var currentTime = 0.0
    @State  private var durationTime = 0.0
    @State private var currentStoryIndex = 0
    @State private var currentSlideIndex = 0
    @State private var isPlaying = false
    
    private let stories: [Story] = [
        Story(items: [
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg")!, isVideo: false, duration: 3.0),
            StoryItem(mediaURL: URL(string:  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!, isVideo: true, duration: 596),
            StoryItem(mediaURL: URL(string:  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4")!, isVideo: true, duration: 653),
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ElephantsDream.jpg")!, isVideo: false, duration: 3.0),
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg")!, isVideo: false, duration: 3.0)
            
        ]),
        Story(items: [
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg")!, isVideo: false, duration: 3.0),
            StoryItem(mediaURL: URL(string:  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4")!, isVideo: true, duration: 15),
            StoryItem(mediaURL: URL(string:  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4")!, isVideo: true, duration: 15),
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerEscapes.jpg")!, isVideo: false, duration: 3.0),
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerFun.jpg")!, isVideo: false, duration: 3.0)
        ]),
        Story(items: [
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerFun.jpg")!, isVideo: false, duration: 3.0),
            StoryItem(mediaURL: URL(string:  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4")!, isVideo: true, duration: 60),
            StoryItem(mediaURL: URL(string:  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4")!, isVideo: true, duration: 15),
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerJoyrides.jpg")!, isVideo: false, duration: 3.0),
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerMeltdowns.jpg")!, isVideo: false, duration: 3.0)
        ])
    ]
    /*
    private let stories: [Story] = [
        Story(items: [
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg")!, isVideo: false, duration: 3.0),
            StoryItem(mediaURL: URL(string:  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!, isVideo: true, duration: 596.47),
            StoryItem(mediaURL: URL(string:  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4")!, isVideo: true, duration: 596.47),
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ElephantsDream.jpg")!, isVideo: false, duration: 3.0),
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg")!, isVideo: false, duration: 3.0)
            
        ]),
        Story(items: [
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg")!, isVideo: false, duration: 3.0),
            StoryItem(mediaURL: URL(string:  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4")!, isVideo: true, duration: 596.47),
            StoryItem(mediaURL: URL(string:  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4")!, isVideo: true, duration: 596.47),
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerEscapes.jpg")!, isVideo: false, duration: 3.0),
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerFun.jpg")!, isVideo: false, duration: 3.0)
        ]),
        Story(items: [
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerFun.jpg")!, isVideo: false, duration: 3.0),
            StoryItem(mediaURL: URL(string:  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4")!, isVideo: true, duration: 596.47),
            StoryItem(mediaURL: URL(string:  "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4")!, isVideo: true, duration: 596.47),
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerJoyrides.jpg")!, isVideo: false, duration: 3.0),
            StoryItem(mediaURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerMeltdowns.jpg")!, isVideo: false, duration: 3.0)
        ])
    ]
*/
    var body: some View {
        VStack {

            if currentStoryIndex < stories.count, currentSlideIndex < stories[currentStoryIndex].items.count, stories[currentStoryIndex].items[currentSlideIndex].isVideo {
                    
                   
                    VideoPlayerContainerView(url: stories[currentStoryIndex].items[currentSlideIndex].mediaURL){ time, totTime in
                        self.durationTime = totTime
                        self.currentTime = time
                         if Int(self.currentTime) >=  Int(self.durationTime){
                             if currentStoryIndex < stories.count, currentSlideIndex < (stories[currentStoryIndex].items.count - 1) {
                                 currentSlideIndex += 1
                             }
                             else {
                                 if currentStoryIndex < stories.count-1{
                                     currentSlideIndex = 0
                                     currentStoryIndex += 1
                                 }
                                 else{
                                     currentSlideIndex = 0
                                     currentStoryIndex = 0
                                 }
                             }
                            
                         }
                    }
                    /*
                    PlayerMediaView(url:   stories[currentStoryIndex].items[currentSlideIndex].mediaURL, pos: Double(currentTime)) { time in
                       self.currentTime = time
                        if self.currentTime >= (Int(stories[currentStoryIndex].items[currentSlideIndex].duration)-1){
                           
                            if currentSlideIndex < (stories[currentStoryIndex].items.count - 1) {
                                currentSlideIndex += 1
                            }
                            else{
                                currentSlideIndex = 0
                                if currentStoryIndex < stories.count-1{
                                    currentStoryIndex -= 1
                                }
                                else{
                                    currentStoryIndex = 0
                                }
                            }
                        }
                    }
                    .frame(width: .infinity, height: .infinity)
                    
                    */
                    
                   
                } else {
                    @State var startDate = Date.now
                     
                    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
                   
                AsyncImage(url: stories[currentStoryIndex].items[currentSlideIndex].mediaURL, scale: 2)
                        .aspectRatio(contentMode: .fill)
                        .onReceive(timer) { firedDate in
                            self.durationTime = stories[currentStoryIndex].items[currentSlideIndex].duration ?? 0.0
                           
                            self.currentTime = firedDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
                            print("\(self.currentTime) : \(self.durationTime)")
                            if Int(self.currentTime) >=  Int(self.durationTime){
                                timer.upstream.connect().cancel()
                                if currentStoryIndex < stories.count, currentSlideIndex < (stories[currentStoryIndex].items.count - 1) {
                                    currentSlideIndex += 1
                                }
                                else {
                                    if currentStoryIndex < stories.count-1{
                                        currentSlideIndex = 0
                                        currentStoryIndex += 1
                                    }
                                    else{
                                        currentSlideIndex = 0
                                        currentStoryIndex = 0
                                    }
                                }
                               
                            }
                                    }
                  

             
                }

                ProgressBar(
                    progress: $currentTime,
                    total: $durationTime,
                    isPaused: $isPlaying
                )

              
                HStack {
                    
                    ForEach(0..<stories[self.currentStoryIndex].items.count) { index in
                        ZStack{
                            Circle()
                                .foregroundColor(index == currentSlideIndex ? .white : .gray)
                                .frame(width: 20, height: 20)
                                .onTapGesture {
                                    self.currentSlideIndex = index
                                    
                                }
                            Text(String(index+1))
                        }

                    }
                }
                .padding()
           

            Spacer()
            HStack(alignment: .center) {
                ScrollView(.horizontal) {
                    HStack {
                        Button(action: previousSlide) {
                            Image(systemName: "chevron.left")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        ForEach(0..<stories.count) { index in
                            ZStack{
                                Circle()
                                    .foregroundColor(index == currentStoryIndex ? .red : .yellow)
                                    .frame(width: 70, height: 70)
                                    .onTapGesture {
                                        currentStoryIndex = index
                                        currentSlideIndex = 0
                                    }

                                Text( "Story:\(index+1)")
                            }

                        }
                        Spacer()
                        Button(action: nextSlide) {
                            Image(systemName: "chevron.right")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
           
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }

    private func previousSlide() {
        if currentStoryIndex > 0 {
            currentStoryIndex -= 1
            currentSlideIndex = 0
        }
//        if currentSlideIndex > 0 {
//            currentSlideIndex -= 1
//        } else if currentStoryIndex > 0 {
//            currentStoryIndex -= 1
//            currentSlideIndex = stories[currentStoryIndex].items.count - 1
//        }
    }

    private func nextSlide() {
        if currentStoryIndex < stories.count - 1 {
            currentStoryIndex += 1
            currentSlideIndex = 0
        }
//        if currentSlideIndex < stories[currentStoryIndex].items.count - 1 {
//            currentSlideIndex += 1
//        } else if currentStoryIndex < stories.count - 1 {
//            currentStoryIndex += 1
//            currentSlideIndex = 0
//        }
    }

    private func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            playVideo()
        } else {
            pauseVideo()
        }
    }

    private func playVideo() {
        
        // Code to play the video
    }

    private func pauseVideo() {
        // Code to pause the video
    }
}

struct ProgressBar: View {
    @Binding private(set) var progress: Double
    @Binding private(set) var total: Double
    @Binding private(set) var isPaused: Bool
   

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(Color.gray.opacity(0.3))
                    .frame(width: geometry.size.width, height: 4)

                Rectangle()
                    .foregroundColor(.white)
                    .frame(width: progressRatio(in: geometry), height: 4)
            }
        }
    }

    private func progressRatio(in geometry: GeometryProxy) -> CGFloat {
        let totalWidth = geometry.size.width
        let ratio = progress / total
        return totalWidth * ratio
    }
}

struct ContentView: View {
     
    var body: some View {
       
       
       StoryView()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
