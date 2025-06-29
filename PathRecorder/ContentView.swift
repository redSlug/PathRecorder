//
//  ContentView.swift
//  PathRecorder
//
//  Created by Brad Dettmer on 6/1/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @StateObject private var locationManager = LocationManager()
    @StateObject private var pathStorage = PathStorage()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button(action: {
                    if locationManager.isRecording {
                        locationManager.stopRecording(pathStorage: pathStorage)
                    } else {
                        locationManager.startRecording()
                    }
                }) {
                    Text(locationManager.isRecording ? "Stop Recording" : "Start Recording")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(locationManager.isRecording ? Color.red : Color.green)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                if locationManager.isRecording {
                    Button(action: {
                        if locationManager.isPaused {
                            locationManager.resumeRecording()
                        } else {
                            locationManager.pauseRecording()
                        }
                    }) {
                        Text(locationManager.isPaused ? "Resume Recording" : "Pause Recording")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(locationManager.isPaused ? Color.green : Color.orange)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                if locationManager.isRecording {
                    Text("Recording in progress...")
                        .foregroundColor(.red)
                    
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
                }
                
                if !pathStorage.recordedPaths.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recorded Paths")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        List {
                            ForEach(pathStorage.recordedPaths.reversed()) { path in
                                NavigationLink(destination: PathMapView(recordedPath: path)) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(path.name)
                                            .font(.headline)
                                        Text("Distance: \(String(format: "%.2f", path.totalDistance / 1000)) km")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("Duration: \(formatTime(path.totalDuration))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 5)
                                }
                                .contextMenu {
                                    if !locationManager.isRecording {
                                        Button(action: {
                                            locationManager.loadPathForEditing(path)
                                        }) {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                    }
                                }
                            }
                            .onDelete(perform: deletePaths)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Path Recorder")
            .onAppear {
                locationManager.requestPermission()
            }
        }
    }
    
    private func deletePaths(offsets: IndexSet) {
        let reversedPaths = Array(pathStorage.recordedPaths.reversed())
        for index in offsets {
            let pathToDelete = reversedPaths[index]
            pathStorage.deletePath(pathToDelete)
        }
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
