//
//  PathRecorderWidgetLiveActivity.swift
//  PathRecorderWidget
//
//  Created by Aparna Natarajan on 6/21/25.
//

import ActivityKit
import WidgetKit
import SwiftUI
import Shared  // Import the Shared module

@available(iOS 16.1, *)
struct PathRecorderWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PathRecorderAttributes.self) { context in
            // Lock screen/banner UI
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(radius: 5)
                
                VStack(spacing: 10) {
                    Text("Path Recorder")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    /*HStack {
                        Label {
                            Text(String(format: "%.6f, %.6f", 
                                      context.state.latitude, 
                                      context.state.longitude))
                            .font(.caption2)
                        } icon: {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                        }
                    }*/
                    
                    HStack(spacing: 15) {
                        Label {
                            Text(formatDistance(context.state.distance, unit: context.state.distanceUnit))
                                .bold()
                        } icon: {
                            Image(systemName: "figure.walk")
                                .foregroundColor(.green)
                        }

                        Label {
                            Text(formatTime(context.state.elapsedTime))
                                .bold()
                        } icon: {
                            Image(systemName: "alarm")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if context.state.isPaused {
                        Text("RECORDING PAUSED")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.bold)
                            .padding(.top, 2)
                    }/* else {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.blue)
                                .font(.subheadline)
                            Text(context.state.pace)
                        }
                    }*/
                }
                .padding()
                .multilineTextAlignment(.center)
            }
            .activityBackgroundTint(Color.clear)
            .activitySystemActionForegroundColor(.blue)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Label(formatDistance(context.state.distance, unit: context.state.distanceUnit),
                          systemImage: "figure.walk")
                        .foregroundColor(.green)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Label(formatTime(context.state.elapsedTime), 
                          systemImage: "alarm")
                        .foregroundColor(.orange)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
                        Text(String(format: "GPS: %.6f, %.6f", 
                                    context.state.latitude, 
                                    context.state.longitude))
                            .font(.caption)
                        
                        if context.state.isPaused {
                            Text("RECORDING PAUSED")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .fontWeight(.bold)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.walk")
                    .foregroundColor(.green)
            } compactTrailing: {
                Text(formatDistanceCompact(context.state.distance, unit: context.state.distanceUnit))
                    .font(.caption)
                    .foregroundColor(.green)
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundColor(.green)
            }
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func formatDistance(_ meters: Double, unit: String) -> String {
        if unit == "mi" {
            let miles = meters / 1000 * 0.621371
            return String(format: "%.2f mi", miles)
        } else {
            let km = meters / 1000
            return String(format: "%.2f km", km)
        }
    }

    private func formatDistanceCompact(_ meters: Double, unit: String) -> String {
        if unit == "mi" {
            let miles = meters / 1000 * 0.621371
            return String(format: "%.1f mi", miles)
        } else {
            let km = meters / 1000
            return String(format: "%.1f km", km)
        }
    }
}

#if DEBUG
@available(iOS 16.2, *)
struct PathRecorderLiveActivity_Previews: PreviewProvider {
    static let attributes = PathRecorderAttributes()
    static let contentState = PathRecorderAttributes.ContentState(
        latitude: 37.332077, 
        longitude: -122.03031, 
        distance: 1234, 
        elapsedTime: 3600,
        isPaused: false,
        distanceUnit: "km"
    )

    static var previews: some View {
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Island Compact")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Island Expanded")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.minimal))
            .previewDisplayName("Minimal")
        attributes
            .previewContext(contentState, viewKind: .content)
            .previewDisplayName("Notification")
    }
}
#endif
