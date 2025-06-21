//
//  PathRecorderWidgetBundle.swift
//  PathRecorderWidget
//
//  Created by Aparna Natarajan on 6/21/25.
//

import WidgetKit
import SwiftUI

@main
struct PathRecorderWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            PathRecorderWidgetLiveActivity()
        }
    }
}
