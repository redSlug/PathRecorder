import SwiftUI

struct PathEditingSheet: View {
    @Binding var editedName: String
    var recordedPath: RecordedPath
    var pathStorage: PathStorage
    var sheetDetent: PresentationDetent
    var onSetName: () -> Void
    @Binding var pickedPathPhotos: [PathPhoto]
    var pathSegments: [PathSegment]
    var onPhotoPickerComplete: () -> Void
    var onModifyPath: () -> Void
    var onDeletePath: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            TextField("Path Name", text: $editedName)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal)
            Button(action: onSetName) {
                Text("Set Name")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(color: Color.accentColor.opacity(0.2), radius: 2, x: 0, y: 2)
            }
            .padding(.horizontal)
            .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if sheetDetent == .medium {
                PhotoLibraryPicker(
                    pathPhotos: $pickedPathPhotos,
                    recordedPath: recordedPath,
                    pathSegments: pathSegments,
                    onComplete: onPhotoPickerComplete
                )
                Button(action: onModifyPath) {
                    Text("Modify Path")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: Color.blue.opacity(0.2), radius: 2, x: 0, y: 2)
                }
                .padding(.horizontal)
                Button(action: onDeletePath) {
                    Text("Delete Path")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: Color.red.opacity(0.2), radius: 2, x: 0, y: 2)
                }
                .padding(.horizontal)
            }
            Spacer()
        }
        .padding(.bottom, 12)
    }
}
