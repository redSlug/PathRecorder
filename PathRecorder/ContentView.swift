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
    @StateObject private var locationManager = LocationManager()
    @StateObject private var pathStorage = PathStorage()
    @State private var showRecordingSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button(action: {
                    locationManager.startRecording()
                    showRecordingSheet = true
                }) {
                    Text("Start Recording")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
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
                                RecordedPathRow(
                                    path: path,
                                    onEdit: {
                                        showRecordingSheet = true
                                        locationManager.loadPathForEditing(path, pathStorage: pathStorage)
                                    },
                                    onDelete: {
                                        pathStorage.deletePath(id: path.id)
                                    },
                                    formatTime: formatTime
                                )
                            }
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
                get: { showRecordingSheet },
                set: { newValue in
                    if !newValue {
                        showRecordingSheet = false
                    }
                })
            ) {
                RecordingView(
                    locationManager: locationManager,
                    pathStorage: pathStorage,
                    onStop: {
                        showRecordingSheet = false
                    }
                )
            }
        }
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct RecordedPathRow: View {
    let path: RecordedPath
    let onEdit: () -> Void
    let onDelete: () -> Void
    let formatTime: (TimeInterval) -> String

    var body: some View {
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
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(.purple)
            Button(action: onEdit) {
                Label("Resume", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
