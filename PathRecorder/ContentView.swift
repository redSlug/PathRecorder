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

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if locationManager.isRecording {
                    Text("Recording in progress...")
                        .foregroundColor(.red)
                }
                
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
                
                Button(action: {
                    if locationManager.isRecording {
                        locationManager.stopRecording()
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
                
                // Only show pause/resume button when recording is active
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
                
                Spacer()
            }
            .padding()
            .navigationTitle("Path Recorder")
            .onAppear {
                locationManager.requestPermission()
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
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

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
