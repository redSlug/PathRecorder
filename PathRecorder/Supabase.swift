//
//  Supabase.swift
//  PathRecorder
//
//  Created by Aparna Natarajan on 3/14/26.
//


import Supabase
import SwiftUI

let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://hsbnabtalqugbwspdhnq.supabase.co")!,
  supabaseKey: "sb_publishable_plix2vRBUgoocyW2QacrVA_tqPYIO-M"
)

@MainActor
final class AuthManager: ObservableObject {
  @Published var currentUser: User?
  @Published var isLoadingSession = true
  @Published var unsyncedPathIds: Set<UUID> = []
  @Published var dirtyPathIds: Set<UUID> = []
  var hasUnsyncedPaths: Bool { !unsyncedPathIds.isEmpty || !dirtyPathIds.isEmpty }

  private var authListenerTask: Task<Void, Never>?

  var isAuthenticated: Bool {
    currentUser != nil
  }

  init() {
    authListenerTask = Task {
      for await (_, session) in await supabase.auth.authStateChanges {
        self.currentUser = session?.user
        self.isLoadingSession = false
      }
    }

    Task {
      await restoreSession()
    }
  }

  deinit {
    authListenerTask?.cancel()
  }

  func restoreSession() async {
    do {
      let session = try await supabase.auth.session
      currentUser = session.user
    } catch {
      currentUser = nil
    }
    isLoadingSession = false
  }

  /// Sends an SMS OTP. Creates the user if they don't exist yet, so this
  /// doubles as both sign-in and sign-up.
  func requestOTP(phone: String) async throws {
    let normalizedPhone = normalized(phone: phone)
    guard !normalizedPhone.isEmpty else {
      throw AuthFlowError.invalidPhone
    }

    try await supabase.auth.signInWithOTP(
      phone: normalizedPhone,
      shouldCreateUser: true
    )
  }

  func verifyOTP(phone: String, token: String) async throws {
    let normalizedPhone = normalized(phone: phone)
    let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !normalizedPhone.isEmpty else {
      throw AuthFlowError.invalidPhone
    }

    guard !normalizedToken.isEmpty else {
      throw AuthFlowError.invalidOTP
    }

    _ = try await supabase.auth.verifyOTP(
      phone: normalizedPhone,
      token: normalizedToken,
      type: .sms
    )
  }

  func signOut() async throws {
    try await supabase.auth.signOut()
    currentUser = nil
  }

  func displayPhone(for user: User?) -> String {
    user?.phone ?? "Unknown"
  }

  private func normalized(phone: String) -> String {
    phone
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: " ", with: "")
  }

  // MARK: - Cloud Delete

  func deleteFromCloud(pathId: UUID, photoIds: [UUID]) async {
    guard let userId = currentUser?.id else { return }
    let storagePaths = photoIds.map { "\(userId.uuidString.lowercased())/\($0.uuidString.lowercased()).jpg" }
    if !storagePaths.isEmpty {
      try? await supabase.storage.from("path-photos").remove(paths: storagePaths)
    }
    try? await supabase.from("paths").delete().eq("id", value: pathId).execute()
  }

  /// Deletes a path locally and, if signed in, removes it from cloud storage/DB too.
  func deletePath(_ path: RecordedPath, pathStorage: PathStorage) {
    let photoIds = path.photos.map { $0.id }
    pathStorage.deletePath(id: path.id)
    Task { await deleteFromCloud(pathId: path.id, photoIds: photoIds) }
  }

  // MARK: - Cloud Sync

  func syncOnLogin(pathStorage: PathStorage, backupService: BackupRestoreService) async {
    guard let userId = currentUser?.id else { return }
    struct ServerPathId: Decodable { let id: UUID }
    guard let entries: [ServerPathId] = try? await supabase
      .from("paths").select("id").eq("user_id", value: userId)
      .execute().value else { return }

    let serverIds = Set(entries.map { $0.id })
    let localIds = Set(pathStorage.recordedPaths.map { $0.id })

    let toRestore = Array(serverIds.subtracting(localIds))
    if !toRestore.isEmpty {
      print("[Restore] \(toRestore.count) paths to restore from cloud")
      backupService.isRestoringFromCloud = true
      backupService.restoreProgress = 0.0
      await backupService.restorePaths(ids: toRestore, pathStorage: pathStorage, authManager: self)
      backupService.isRestoringFromCloud = false
      backupService.restoreProgress = 0.0
    }

    let updatedLocalIds = Set(pathStorage.recordedPaths.map { $0.id })
    await MainActor.run { unsyncedPathIds = updatedLocalIds.subtracting(serverIds) }
  }

  func refreshSyncStatus(localPaths: [RecordedPath]) async {
    guard let userId = currentUser?.id else {
      await MainActor.run { unsyncedPathIds = [] }
      return
    }
    struct ServerPathId: Decodable { let id: UUID }
    guard let entries: [ServerPathId] = try? await supabase
      .from("paths").select("id").eq("user_id", value: userId)
      .execute().value else { return }
    let serverIds = Set(entries.map { $0.id })
    let localIds = Set(localPaths.map { $0.id })
    await MainActor.run { unsyncedPathIds = localIds.subtracting(serverIds) }
  }
}

enum AuthFlowError: LocalizedError {
  case invalidPhone
  case invalidOTP

  var errorDescription: String? {
    switch self {
    case .invalidPhone:
      return "Enter a valid phone number."
    case .invalidOTP:
      return "Enter the OTP code sent to your phone."
    }
  }
}


