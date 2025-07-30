import SwiftUI

struct PhotoAssociationConfirmationSheet: View {
    let associatedCount: Int
    let pendingPhotos: [PathPhoto]
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        let baseHeight: CGFloat = 180 // header + buttons
        let photoHeight: CGFloat = !pendingPhotos.isEmpty ? 80 : 0 // photo row height
        let sheetHeight = baseHeight + photoHeight
        VStack(spacing: 18) {
            Text("\(associatedCount) of your selected photos can be added to this path. Do you want to add them?")
                .multilineTextAlignment(.center)
            if !pendingPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pendingPhotos.prefix(10), id: \.id) { photo in
                            if let image = photo.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            HStack(spacing: 20) {
                Button(action: onAdd) {
                    Text("Add")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .presentationDetents([.height(sheetHeight)])
    }
}