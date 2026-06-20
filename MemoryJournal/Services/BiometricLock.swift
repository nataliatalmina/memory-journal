//
//  BiometricLock.swift
//  MemoryJournal
//
//  Thin wrapper around Apple's `LocalAuthentication` framework for the optional
//  "App Lock" feature (Phase 6). It ONLY asks the system to verify the device
//  owner — it never sees or stores any biometric data (Face/Touch ID data lives
//  in the Secure Enclave; iOS just tells us pass/fail). Honesty rule (CLAUDE.md):
//  nothing here transmits or persists anything off-device.
//
//  Key idea: we always evaluate `.deviceOwnerAuthentication`, which means "Face ID
//  / Touch ID if available, AND automatically fall back to the device passcode."
//  So a user with no enrolled biometrics — but a passcode — can still lock the
//  app, and a failed Face ID scan offers the passcode rather than dead-ending.
//

import LocalAuthentication

enum BiometricLock {

    /// What kind of authentication this device can actually perform right now.
    enum Availability: Equatable {
        case biometric(LABiometryType)   // Face ID / Touch ID / Optic ID enrolled
        case passcodeOnly                // no biometrics, but a device passcode is set
        case unavailable                 // nothing set up (no passcode) → can't lock
    }

    /// Probe the device. A fresh `LAContext` is required each time — a context
    /// caches its result, so reusing one can report stale availability.
    static func availability() -> Availability {
        var error: NSError?

        // Biometrics enrolled and usable? `canEvaluatePolicy` also populates the
        // context's `biometryType` as a side effect, so read it right after.
        let biometricContext = LAContext()
        if biometricContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return .biometric(biometricContext.biometryType)
        }

        // No biometrics — is there at least a device passcode to fall back to?
        let passcodeContext = LAContext()
        if passcodeContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            return .passcodeOnly
        }

        return .unavailable
    }

    /// A human-readable name for the available method, for button/row labels.
    static func methodName() -> String {
        switch availability() {
        case .biometric(.faceID):  return "Face ID"
        case .biometric(.touchID): return "Touch ID"
        case .biometric(.opticID): return "Optic ID"
        case .biometric:           return "biometrics"   // future/unknown types
        case .passcodeOnly:        return "your passcode"
        case .unavailable:         return "a passcode"
        }
    }

    /// Prompt the user to authenticate. Returns whether it succeeded.
    ///
    /// We use the completion-handler API wrapped in `withCheckedContinuation` to
    /// expose it as a clean `async` call (the same pattern as the microphone
    /// permission in `MediaPermissions`). Any thrown error (cancel, lockout, …)
    /// is treated as "not authenticated".
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
