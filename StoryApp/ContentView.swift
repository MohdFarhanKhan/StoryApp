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
    var player: AVPlayer
    let callBackTime: (Int)->()
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
                    print(cmTimeToSeconds(duration))
                                }
                
            }
            .onDisappear {
                player.pause()
            }
            .onReceive(observer.$currentTime) { currentTime in
                // Handle time updates here
                let seconds = CMTimeGetSeconds(currentTime)
                callBackTime(Int(seconds))
                print("Current time: \(seconds) seconds")
            }
    }
}
struct PlayerMediaView: View {
    let player: AVPlayer
    @StateObject private var observer: PlayerObserver
    let callback: (Int)->()
    init(url: URL, callback: @escaping (Int)->()) {
        self.callback = callback
        player = AVPlayer(url: url)
        let obs = PlayerObserver(player: player)
        _observer = StateObject(wrappedValue: obs)
       
    }
    
    var body: some View {
       
        PlayerView(observer: observer, player: player){ time in
            callback(time)
        }
    }
}

struct StoryView: View {
    @State private var currentTime = 0
    @State private var currentStoryIndex = 0
    @State private var currentSlideIndex = 0
    @State private var isPlaying = false
    
    
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

    var body: some View {
        VStack {

           

                if stories[currentStoryIndex].items[currentSlideIndex].isVideo {
                    PlayerMediaView(url:   stories[currentStoryIndex].items[currentSlideIndex].mediaURL) { time in
                        self.currentTime = time
                    }
                   
                } else {
                    @State var startDate = Date.now
                     
                    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
                AsyncImage(url: stories[currentStoryIndex].items[currentSlideIndex].mediaURL, scale: 2)
                        .aspectRatio(contentMode: .fit)
                        .onReceive(timer) { firedDate in

                            self.currentTime = Int(firedDate.timeIntervalSince(startDate))
                            if self.currentTime >= (Int(stories[currentStoryIndex].items[currentSlideIndex].duration)-1){
                                timer.upstream.connect().cancel()
                                if currentSlideIndex < (stories.count - 1) {
                                    currentSlideIndex += 1
                                }
                                else{
                                    currentSlideIndex = 0
                                }
                            }
                                    }
                  

             
                }

                ProgressBar(
                    progress: CGFloat(currentTime),
                    total: CGFloat(stories[currentStoryIndex].items[currentSlideIndex].duration),
                    isPaused: !isPlaying
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
    let progress: CGFloat
    let total: CGFloat
    let isPaused: Bool

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
