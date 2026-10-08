import AVFoundation
import Testing

extension Helper {
    static func audioDuration(for url: URL) throws -> Duration {
        let audioFile = try AVAudioFile(forReading: url)
        let seconds = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        return .milliseconds(Int((seconds * 1_000).rounded(.up)))
    }
    
    static func loadAudioChunks(from url: URL,
                                framesPerChunk: AVAudioFrameCount = 1_024) throws -> [AVAudioPCMBuffer] {
        let audioFile = try AVAudioFile(forReading: url,
                                        commonFormat: .pcmFormatFloat32,
                                        interleaved: false)
        var chunks: [AVAudioPCMBuffer] = []
        
        while audioFile.framePosition < audioFile.length {
            let frameCount = AVAudioFrameCount(min(AVAudioFramePosition(framesPerChunk),
                                                   audioFile.length - audioFile.framePosition))
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                                       frameCapacity: frameCount),
                                      "Could not create an AVAudioPCMBuffer while reading '\(url.path)'.")
            
            try audioFile.read(into: buffer, frameCount: frameCount)
            guard buffer.frameLength > 0 else { break }
            chunks.append(buffer)
        }
        
        try #require(!chunks.isEmpty, "Audio fixture '\(url.path)' did not produce any buffers.")
        
        return chunks
    }
}
