import SwiftUI

struct RenamePathSheet: View {
    @State private var newName: String
    let path: RecordedPath
    let pathStorage: PathStorage
    let onDismiss: () -> Void

    init(path: RecordedPath, pathStorage: PathStorage, onDismiss: @escaping () -> Void) {
        self.path = path
        self.pathStorage = pathStorage
        self.onDismiss = onDismiss
        _newName = State(initialValue: path.name)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Rename Path")) {
                    TextField("Path Name", text: $newName)
                }
            }
            .navigationBarItems(leading: Button("Cancel") {
                onDismiss()
            }, trailing: Button("Save") {
                var updatedPath = path
                updatedPath.editName(newName)
                pathStorage.updatePath(updatedPath)
                onDismiss()
            })
        }
    }
}
