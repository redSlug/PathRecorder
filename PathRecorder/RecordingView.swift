//  RecordingView.swift
//  PathRecorder
//
//  Created by GitHub Copilot on 6/29/25.
//

import SwiftUI
import MapKit

struct RecordingView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var pathStorage: PathStorage
    var editingPath: RecordedPath? = nil
    var onStop: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(editingPath != nil ? "Editing Path..." : "Recording in progress...")
                    .font(.title2)
                    .foregroundColor(editingPath != nil ? .blue : .red)
                
                VStack(alignment: .leading, spacing: 10) {
                    if let location = locationManager.currentLocation {
                        Text("GPS: \(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))")
                    }
                    Text("Distance: \(String(format: "%.2f", locationManager.totalDistance / 1000)) km")
                    if locationManager.elapsedTime > 0 {
                        Text("Time: \(formatTime(locationManager.elapsedTime))")
                    }
                    if locationManager.isPaused {
                        Text("PAUSED")
                            .foregroundColor(.orange)
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // PathMapView(recordedPath: locationManager.currentPath)
                //     .frame(height: 300)
                //     .cornerRadius(12)
                //     .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button(action: {
                        onStop()
                        locationManager.stopRecording(pathStorage: pathStorage)
                    }) {
                        Text("Stop Recording")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    if locationManager.isPaused {
                        Button(action: {
                            locationManager.resumeRecording()
                        }) {
                            Text("Resume")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    } else {
                        Button(action: {
                            locationManager.pauseRecording()
                        }) {
                            Text("Pause")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// Preview for Xcode Canvas
#Preview {
    RecordingView(locationManager: LocationManager(), pathStorage: PathStorage(), onStop: {})
}
