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
                                    formatTime: formatTime,
                                    locationManager: locationManager,
                                    pathStorage: pathStorage
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
                // Automatically show recording view if in-progress recording exists
                if locationManager.isRecording && locationManager.isPaused {
                    showRecordingSheet = true
                }
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
    let locationManager: LocationManager
    let pathStorage: PathStorage

    var body: some View {
        NavigationLink(destination: PathMapView(recordedPath: path, locationManager: locationManager, pathStorage: pathStorage)) {
            VStack(alignment: .leading, spacing: 5) {
                Text(path.name)
                    .font(.headline)
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(.red)
                        .font(.subheadline)
                    Text(DateFormatter.localizedString(from: path.startTime, dateStyle: .medium, timeStyle: .short))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .foregroundColor(.green)
                            .font(.subheadline)
                        Text("\(String(format: "%.2f", path.totalDistance / 1000)) km")
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                        Text(formatTime(path.totalDuration))
                    }
                }
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
