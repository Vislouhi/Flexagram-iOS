//
//  AudioWriter.swift
//  Flexatar
//
//  Created by Matey Vislouh on 19.06.2024.
//

import Foundation

public class AudioWriter{
    private let fileDescriptor: Int32
    public init(){
        let fileName = "flx_auido.bin"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.getPath()) {
           do {
               try FileManager.default.removeItem(at: fileURL)
               print("Existing file deleted.")
           } catch {
               print("Error deleting file: \(error.localizedDescription)")
           }
       }
//       FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
//        self.fileHandle = try! FileHandle(forWritingTo: fileURL)
        self.fileDescriptor = open(fileURL.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        if fileDescriptor == -1 {
            print("Error opening file: \(String(cString: strerror(errno)))")
        }
        print("FLX_INJECT tmp flx audio start writing")
    }
    public func closeFile() {
        close(self.fileDescriptor)
        print("FLX_INJECT tmp flx audio closed")
     }
    
  
    public func addData(pointer: UnsafeMutableRawPointer, length:Int) {
        print("FLX_INJECT tmp flx audio writing")
        var bytesWritten = 0
        while bytesWritten < length {
           let result = write(fileDescriptor, pointer + bytesWritten, length - bytesWritten)
           if result == -1 {
               print("Error writing to file: \(String(cString: strerror(errno)))")
               return
           }
           bytesWritten += result
        }
    }
}
