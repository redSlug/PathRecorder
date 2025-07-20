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
    var onStop: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if locationManager.isPaused {
                    Text(locationManager.editingPathName != nil ? "PAUSED EDIT" : "PAUSED")
                        .foregroundColor(.orange)
                        .fontWeight(.bold)
                } else {
                    if(locationManager.editingPathName != nil) {
                        Text("EDITING")
                            .foregroundColor(.purple)
                            .fontWeight(.bold)
                    } else {
                        Text("RECORDING")
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    if let location = locationManager.currentLocation {
                        Text("GPS: \(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))")
                    }
                    HStack(spacing: 20) {
                        HStack(spacing: 10) {
                            Image(systemName: "figure.walk")
                                .foregroundColor(.green)
                                .font(.subheadline)
                            Text("\(String(format: "%.2f", locationManager.totalDistance / 1000)) km")
                        }
                        if locationManager.elapsedTime > 0 {
                            HStack(spacing: 10) {
                                Image(systemName: "timer")
                                    .foregroundColor(.orange)
                                    .font(.subheadline)
                                Text(formatTime(locationManager.elapsedTime))
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.blue.opacity(0.25))
                .cornerRadius(10)
                .padding(.horizontal)

                LivePathMapView(locationManager: locationManager)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            }
            .padding(.vertical)
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