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
    @State private var showRecordingSheet = false
    @State private var editingPath: RecordedPath? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button(action: {
                    if locationManager.isRecording {
                        locationManager.stopRecording(pathStorage: pathStorage)
                        showRecordingSheet = false
                    } else {
                        locationManager.startRecording()
                        showRecordingSheet = true
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
                                            editingPath = path
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
            .fullScreenCover(isPresented: Binding(
                get: { showRecordingSheet || editingPath != nil },
                set: { newValue in
                    if !newValue {
                        showRecordingSheet = false
                        editingPath = nil
                    }
                })
            ) {
                RecordingView(
                    locationManager: locationManager,
                    pathStorage: pathStorage,
                    editingPath: editingPath,
                    onStop: {
                        showRecordingSheet = false
                        editingPath = nil
                    }
                )
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
