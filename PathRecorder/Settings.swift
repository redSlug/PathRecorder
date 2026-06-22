import Foundation
import SwiftUI
import UIKit
import Supabase

struct CountryDialCode: Identifiable, Equatable {
    let id: String
    let flag: String
    let name: String
    let dialCode: String

    static let us = CountryDialCode(id: "US", flag: "🇺🇸", name: "United States", dialCode: "+1")

    static let all: [CountryDialCode] = [
        .us,
        CountryDialCode(id: "CA", flag: "🇨🇦", name: "Canada", dialCode: "+1"),
        CountryDialCode(id: "GB", flag: "🇬🇧", name: "United Kingdom", dialCode: "+44"),
        CountryDialCode(id: "AU", flag: "🇦🇺", name: "Australia", dialCode: "+61"),
        CountryDialCode(id: "DE", flag: "🇩🇪", name: "Germany", dialCode: "+49"),
        CountryDialCode(id: "FR", flag: "🇫🇷", name: "France", dialCode: "+33"),
        CountryDialCode(id: "IT", flag: "🇮🇹", name: "Italy", dialCode: "+39"),
        CountryDialCode(id: "ES", flag: "🇪🇸", name: "Spain", dialCode: "+34"),
        CountryDialCode(id: "NL", flag: "🇳🇱", name: "Netherlands", dialCode: "+31"),
        CountryDialCode(id: "BE", flag: "🇧🇪", name: "Belgium", dialCode: "+32"),
        CountryDialCode(id: "CH", flag: "🇨🇭", name: "Switzerland", dialCode: "+41"),
        CountryDialCode(id: "AT", flag: "🇦🇹", name: "Austria", dialCode: "+43"),
        CountryDialCode(id: "SE", flag: "🇸🇪", name: "Sweden", dialCode: "+46"),
        CountryDialCode(id: "NO", flag: "🇳🇴", name: "Norway", dialCode: "+47"),
        CountryDialCode(id: "DK", flag: "🇩🇰", name: "Denmark", dialCode: "+45"),
        CountryDialCode(id: "FI", flag: "🇫🇮", name: "Finland", dialCode: "+358"),
        CountryDialCode(id: "PL", flag: "🇵🇱", name: "Poland", dialCode: "+48"),
        CountryDialCode(id: "CZ", flag: "🇨🇿", name: "Czech Republic", dialCode: "+420"),
        CountryDialCode(id: "PT", flag: "🇵🇹", name: "Portugal", dialCode: "+351"),
        CountryDialCode(id: "GR", flag: "🇬🇷", name: "Greece", dialCode: "+30"),
        CountryDialCode(id: "RU", flag: "🇷🇺", name: "Russia", dialCode: "+7"),
        CountryDialCode(id: "TR", flag: "🇹🇷", name: "Turkey", dialCode: "+90"),
        CountryDialCode(id: "IN", flag: "🇮🇳", name: "India", dialCode: "+91"),
        CountryDialCode(id: "CN", flag: "🇨🇳", name: "China", dialCode: "+86"),
        CountryDialCode(id: "JP", flag: "🇯🇵", name: "Japan", dialCode: "+81"),
        CountryDialCode(id: "KR", flag: "🇰🇷", name: "South Korea", dialCode: "+82"),
        CountryDialCode(id: "SG", flag: "🇸🇬", name: "Singapore", dialCode: "+65"),
        CountryDialCode(id: "HK", flag: "🇭🇰", name: "Hong Kong", dialCode: "+852"),
        CountryDialCode(id: "TW", flag: "🇹🇼", name: "Taiwan", dialCode: "+886"),
        CountryDialCode(id: "PH", flag: "🇵🇭", name: "Philippines", dialCode: "+63"),
        CountryDialCode(id: "ID", flag: "🇮🇩", name: "Indonesia", dialCode: "+62"),
        CountryDialCode(id: "MY", flag: "🇲🇾", name: "Malaysia", dialCode: "+60"),
        CountryDialCode(id: "TH", flag: "🇹🇭", name: "Thailand", dialCode: "+66"),
        CountryDialCode(id: "VN", flag: "🇻🇳", name: "Vietnam", dialCode: "+84"),
        CountryDialCode(id: "PK", flag: "🇵🇰", name: "Pakistan", dialCode: "+92"),
        CountryDialCode(id: "BD", flag: "🇧🇩", name: "Bangladesh", dialCode: "+880"),
        CountryDialCode(id: "AE", flag: "🇦🇪", name: "UAE", dialCode: "+971"),
        CountryDialCode(id: "SA", flag: "🇸🇦", name: "Saudi Arabia", dialCode: "+966"),
        CountryDialCode(id: "IL", flag: "🇮🇱", name: "Israel", dialCode: "+972"),
        CountryDialCode(id: "EG", flag: "🇪🇬", name: "Egypt", dialCode: "+20"),
        CountryDialCode(id: "MA", flag: "🇲🇦", name: "Morocco", dialCode: "+212"),
        CountryDialCode(id: "NG", flag: "🇳🇬", name: "Nigeria", dialCode: "+234"),
        CountryDialCode(id: "KE", flag: "🇰🇪", name: "Kenya", dialCode: "+254"),
        CountryDialCode(id: "ZA", flag: "🇿🇦", name: "South Africa", dialCode: "+27"),
        CountryDialCode(id: "BR", flag: "🇧🇷", name: "Brazil", dialCode: "+55"),
        CountryDialCode(id: "MX", flag: "🇲🇽", name: "Mexico", dialCode: "+52"),
        CountryDialCode(id: "AR", flag: "🇦🇷", name: "Argentina", dialCode: "+54"),
        CountryDialCode(id: "CO", flag: "🇨🇴", name: "Colombia", dialCode: "+57"),
        CountryDialCode(id: "CL", flag: "🇨🇱", name: "Chile", dialCode: "+56"),
        CountryDialCode(id: "PE", flag: "🇵🇪", name: "Peru", dialCode: "+51"),
    ]
}

struct CountryPickerView: View {
    @Binding var selectedCountry: CountryDialCode
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var filtered: [CountryDialCode] {
        if searchText.isEmpty { return CountryDialCode.all }
        return CountryDialCode.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.dialCode.contains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { country in
                Button {
                    selectedCountry = country
                    dismiss()
                } label: {
                    HStack {
                        Text(country.flag)
                        Text(country.name)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(country.dialCode)
                            .foregroundColor(.secondary)
                        if country == selectedCountry {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search country")
            .navigationTitle("Country Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

enum DistanceUnit: String, CaseIterable, Codable {
    case kilometers = "km"
    case miles = "mi"

    var displayName: String {
        switch self {
        case .kilometers:
            return "Kilometers"
        case .miles:
            return "Miles"
        }
    }

    var conversionFactor: Double {
        switch self {
        case .kilometers:
            return 1.0
        case .miles:
            return 0.621371 // Convert from meters to miles
        }
    }

    var unitLabel: String {
        switch self {
        case .kilometers:
            return "km"
        case .miles:
            return "mi"
        }
    }
}

class Settings: ObservableObject {
    @Published var distanceUnit: DistanceUnit {
        didSet {
            UserDefaults.standard.set(distanceUnit.rawValue, forKey: "distanceUnit")
        }
    }

    init() {
        if let savedUnit = UserDefaults.standard.string(forKey: "distanceUnit"),
           let unit = DistanceUnit(rawValue: savedUnit) {
            self.distanceUnit = unit
        } else {
            self.distanceUnit = .kilometers
        }
    }

    func convertDistance(_ meters: Double) -> Double {
        return meters / 1000 * distanceUnit.conversionFactor
    }

    func formatDistance(_ meters: Double) -> String {
        let convertedDistance = convertDistance(meters)
        return String(format: "%.2f %@", convertedDistance, distanceUnit.unitLabel)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var pathStorage: PathStorage
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    // Sign-out
    @State private var isSigningOut = false
    @State private var backupSuccessMessage: String? = nil
    // Inline sign-in OTP flow
    @State private var selectedCountry: CountryDialCode = .us
    @State private var showCountryPicker = false
    @State private var authPhone = ""
    @State private var authOTP = ""
    @State private var didRequestOTP = false
    @State private var isSendingOTP = false
    @State private var isVerifyingOTP = false
    @State private var authErrorMessage: String? = nil

    private var fullPhone: String {
        selectedCountry.dialCode + authPhone.filter(\.isNumber)
    }

    private var isPhoneValid: Bool {
        let digits = authPhone.filter(\.isNumber)
        return digits.count >= 6 && digits.count <= 14
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account")) {
                    if authManager.isAuthenticated {
                        HStack {
                            Text("Phone")
                            Spacer()
                            Text(authManager.displayPhone(for: authManager.currentUser))
                                .foregroundColor(.secondary)
                        }
                        if authManager.isRestoringFromCloud {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Restoring from cloud... \(Int(authManager.restoreProgress * 100))%")
                                        .font(.subheadline)
                                    Spacer()
                                }
                                ProgressView(value: authManager.restoreProgress)
                            }
                        }
                        if authManager.isUploadingBackup || authManager.hasUnsyncedPaths {
                            Button {
                                Task { await uploadBackup() }
                            } label: {
                                if authManager.isUploadingBackup {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Backing up... \(Int(authManager.backupProgress * 100))%")
                                                .font(.subheadline)
                                            Spacer()
                                            if let remaining = estimatedTimeRemaining {
                                                Text(remaining)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        ProgressView(value: authManager.backupProgress)
                                    }
                                } else {
                                    HStack {
                                        Image(systemName: "icloud.and.arrow.up")
                                        Text("Backup to Cloud")
                                    }
                                }
                            }
                            .disabled(authManager.isUploadingBackup)
                        }

                        Button(role: .destructive) {
                            Task { await signOut() }
                        } label: {
                            if isSigningOut {
                                HStack { ProgressView(); Text("Signing out...") }
                            } else {
                                Text("Sign Out")
                            }
                        }
                        .disabled(isSigningOut || authManager.isUploadingBackup)
                    } else {
                        HStack(spacing: 0) {
                            Button {
                                showCountryPicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text(selectedCountry.flag)
                                    Text(selectedCountry.dialCode)
                                        .foregroundColor(.primary)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.trailing, 8)
                            }
                            .buttonStyle(.plain)

                            TextField("Phone number", text: $authPhone)
                                .keyboardType(.phonePad)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .onChange(of: authPhone) { _ in
                                    if didRequestOTP { didRequestOTP = false; authOTP = "" }
                                }
                        }
                        .sheet(isPresented: $showCountryPicker) {
                            CountryPickerView(selectedCountry: $selectedCountry)
                        }
                        .onChange(of: selectedCountry) { _ in
                            if didRequestOTP { didRequestOTP = false; authOTP = "" }
                        }

                        if didRequestOTP {
                            TextField("6-digit code", text: $authOTP)
                                .keyboardType(.numberPad)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                        }
                        if didRequestOTP && authOTP.filter(\.isNumber).count == 6 {
                            Button(isVerifyingOTP ? "Verifying..." : "Verify Code") {
                                Task { await verifyOTP() }
                            }
                            .disabled(isVerifyingOTP)
                        } else {
                            Button(isSendingOTP ? "Sending..." : didRequestOTP ? "Resend Code" : "Send Code") {
                                Task { await sendOTP() }
                            }
                            .disabled(isSendingOTP || !isPhoneValid)
                        }


                        Text("Enter your phone number to sign in or create an account.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                Section(header: Text("Distance Units")) {
                    Picker("Distance Unit", selection: $settings.distanceUnit) {
                        ForEach(DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Backup Saved", isPresented: .constant(backupSuccessMessage != nil)) {
            Button("OK") { backupSuccessMessage = nil }
        } message: {
            Text(backupSuccessMessage ?? "")
        }
        .alert("Auth Error", isPresented: .constant(authErrorMessage != nil)) {
            Button("OK") {
                authErrorMessage = nil
            }
        } message: {
            Text(authErrorMessage ?? "Unknown error")
        }
    }

    private var estimatedTimeRemaining: String? {
        guard let start = authManager.backupStartTime,
              authManager.backupProgress > 0.05 else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let total = elapsed / authManager.backupProgress
        let remaining = total - elapsed
        guard remaining > 1 else { return nil }
        let secs = Int(remaining.rounded())
        let y = secs / (365 * 24 * 3600)
        let d = (secs % (365 * 24 * 3600)) / (24 * 3600)
        let h = (secs % (24 * 3600)) / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        var parts: [String] = []
        if y > 0 { parts.append("\(y)y") }
        if d > 0 { parts.append("\(d)d") }
        if h > 0 { parts.append("\(h)h") }
        if m > 0 { parts.append("\(m)m") }
        if s > 0 || parts.isEmpty { parts.append("\(s)s") }
        return "~\(parts.joined(separator: " ")) left"
    }

    private func uploadBackup() async {
        guard let userId = authManager.currentUser?.id else {
            authErrorMessage = "Not signed in."
            return
        }
        authManager.isUploadingBackup = true
        authManager.backupProgress = 0.0
        authManager.backupStartTime = Date()
        defer {
            authManager.isUploadingBackup = false
            authManager.backupProgress = 0.0
            authManager.backupStartTime = nil
        }
        do {
            struct PathRow: Encodable {
                let id: UUID
                let user_id: UUID
                let name: String
                let created_at: Date
            }
            struct SegmentRow: Encodable {
                let id: UUID
                let path_id: UUID
            }
            struct LocationRow: Encodable {
                let id: UUID
                let segment_id: UUID
                let latitude: Double
                let longitude: Double
                let timestamp: Date
            }
            struct PhotoRow: Encodable {
                let id: UUID
                let user_id: UUID
                let location_id: UUID
                let timestamp: Date
                let storage_path: String
            }

            var pathRows: [PathRow] = []
            var segmentRows: [SegmentRow] = []
            var locationRows: [LocationRow] = []
            var photoRows: [PhotoRow] = []

            let pathsToUpload = authManager.unsyncedPathIds.union(authManager.dirtyPathIds)
            let pathsToBackup = pathStorage.recordedPaths.filter { pathsToUpload.contains($0.id) }
            let totalPhotos = pathsToBackup.reduce(0) { $0 + $1.photos.count }
            var uploadedPhotos = 0
            print("[Backup] \(pathsToBackup.count) unsynced paths, \(totalPhotos) photos total")
            for path in pathsToBackup {
                print("[Backup] path '\(path.name)' — segments: \(path.segments.count), photos: \(path.photos.count)")
                pathRows.append(PathRow(
                    id: path.id,
                    user_id: userId,
                    name: path.name,
                    created_at: path.startTime
                ))

                for segment in path.segments {
                    segmentRows.append(SegmentRow(id: segment.id, path_id: path.id))
                    for location in segment.locations {
                        locationRows.append(LocationRow(
                            id: location.id,
                            segment_id: segment.id,
                            latitude: location.latitude,
                            longitude: location.longitude,
                            timestamp: location.timestamp
                        ))
                    }
                }

                for photo in path.photos {
                    let storagePath = "\(userId.uuidString.lowercased())/\(photo.id.uuidString.lowercased()).jpg"
                    guard let image = photo.image,
                          let jpegData = image.jpegData(compressionQuality: 0.9) else {
                        print("[Backup]   ⚠️ skipping photo \(photo.id) — image missing from disk")
                        continue
                    }
                    print("[Backup]   uploading \(storagePath) (\(jpegData.count) bytes)")
                    try await supabase.storage
                        .from("path-photos")
                        .upload(storagePath, data: jpegData, options: FileOptions(contentType: "image/jpeg", upsert: true))
                    uploadedPhotos += 1
                    if totalPhotos > 0 {
                        authManager.backupProgress = Double(uploadedPhotos) / Double(totalPhotos)
                    }
                    print("[Backup]   ✓ uploaded (\(uploadedPhotos)/\(totalPhotos))")
                    photoRows.append(PhotoRow(
                        id: photo.id,
                        user_id: userId,
                        location_id: photo.locationId,
                        timestamp: photo.timestamp,
                        storage_path: storagePath
                    ))
                }
            }

            print("[Backup] upserting \(pathRows.count) paths, \(segmentRows.count) segments, \(locationRows.count) locations, \(photoRows.count) photos")
            if !pathRows.isEmpty {
                try await supabase.from("paths").upsert(pathRows, onConflict: "id").execute()
                print("[Backup] ✓ paths")
            }
            if !segmentRows.isEmpty {
                try await supabase.from("path_segments").upsert(segmentRows, onConflict: "id").execute()
                print("[Backup] ✓ segments")
            }
            if !locationRows.isEmpty {
                try await supabase.from("gps_locations").upsert(locationRows, onConflict: "id").execute()
                print("[Backup] ✓ locations")
            }
            if !photoRows.isEmpty {
                try await supabase.from("path_photos").upsert(photoRows, onConflict: "id").execute()
                print("[Backup] ✓ photos")
            }

            authManager.dirtyPathIds.subtract(pathsToUpload)
            backupSuccessMessage = "Your data has been backed up to the cloud."
            await authManager.refreshSyncStatus(localPaths: pathStorage.recordedPaths)
        } catch {
            print("[Backup] ❌ \(error)")
            authErrorMessage = error.localizedDescription
        }
    }

    private func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }
        do {
            try await authManager.signOut()
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    private func sendOTP() async {
        isSendingOTP = true
        authErrorMessage = nil
        defer { isSendingOTP = false }
        do {
            try await authManager.requestOTP(phone: fullPhone)
            didRequestOTP = true
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    private func verifyOTP() async {
        isVerifyingOTP = true
        authErrorMessage = nil
        defer { isVerifyingOTP = false }
        do {
            try await authManager.verifyOTP(phone: fullPhone, token: authOTP)
            authOTP = ""
            authPhone = ""
            didRequestOTP = false
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }


}

// MARK: - Color <-> Hex helpers

extension Color {
    func toHexString() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let rgb: Int = (Int)(red*255)<<16 | (Int)(green*255)<<8 | (Int)(blue*255)<<0
        return String(format: "%06x", rgb)
    }

    static func fromHexString(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
