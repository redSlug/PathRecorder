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
    @State private var selectedPathForRename: RecordedPath? = nil
    @State private var navigationPath = NavigationPath()
    @State private var showRenameSheet = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 20) {
                Text("No history yet — start recording to track your journeys.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: pathStorage.recordedPaths.isEmpty ? .infinity : 0, alignment: .center)
                    .opacity(pathStorage.recordedPaths.isEmpty ? 1 : 0)
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
                            onSelect: {
                                navigationPath.append(path)
                            }
                        )
                    }
                }
                .listStyle(.plain)
                
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .onAppear {
                locationManager.requestPermission()
                // Automatically show recording view if in-progress recording exists
                if locationManager.isRecording && locationManager.isPaused {
                    showRecordingSheet = true
                }
            }
            .onReceive(locationManager.$pathNeedingRename) { path in
                if let path = path {
                    selectedPathForRename = path
                    navigationPath.append(path)
                    showRenameSheet = true
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
            .navigationTitle("Recorded Paths")
            .navigationDestination(for: RecordedPath.self) { path in
                let view = PathMapView(recordedPath: path, locationManager: locationManager, pathStorage: pathStorage, showRenameSheetOnAppear: showRenameSheet)
                showRenameSheet = false
                return view
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
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
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
