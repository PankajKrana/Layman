// Project Architecture (MVVM)

// This project is organized using Model–View–ViewModel (MVVM).

// Folder Structure

// - Sources/
//   - Models/
//     - Domain/data models (e.g., `NewsArticle.swift`)
//   - Views/
//     - SwiftUI views or UIKit view controllers (e.g., `HomeScreen.swift`, `ArticleDetailScreen.swift`, `ChatScreen.swift`, `AuthScreen.swift`, `ProfileScreen.swift`)
//   - ViewModels/
//     - View models that bind views to business logic (e.g., `HomeViewModel.swift`, `ArticleDetailViewModel.swift`, `ChatViewModel.swift`, `AuthViewModel.swift`, `ProfileViewModel.swift`)
//   - Services/
//     - Networking, persistence, API clients (e.g., `APIClient.swift`, `PersistenceStore.swift`)
//   - Utilities/
//     - Helpers and extensions (e.g., `HeadlineFormatter.swift`, `Date+Format.swift`)
//   - Resources/
//     - Assets, strings, JSON stubs, fonts, configuration files

// Moving Existing Files

// - Move all `*Screen.swift` files into `Sources/Views/`.
// - Move `*ViewModel.swift` files into `Sources/ViewModels/`.
// - Move model structs/classes (e.g., `NewsArticle`) into `Sources/Models/`.
// - Move service-like types (API client, persistence) into `Sources/Services/`.
// - Move helpers and extensions into `Sources/Utilities/`.
// - Keep asset catalogs and resources under `Sources/Resources/`.

// These moves won’t change code imports. Xcode resolves by module, not path. If any file paths are referenced directly (e.g., reading a JSON by bundle URL), update those paths accordingly.

// Next Steps

// 1. In Xcode, create groups that mirror these folders if they are not visible yet (Right-click the project > Add Files to … > select the `Sources` folders, enable “Create folder references” or “Create groups” as you prefer).
// 2. Drag your existing files into the appropriate groups/folders on disk to keep the file system in sync.
// 3. Verify target membership for each moved file (File inspector > Target Membership).
// 4. Build and run to ensure everything links as expected.

// Contributing Guidelines

// - New features should add their Views and ViewModels together.
// - Keep networking/persistence in Services; avoid putting business logic in Views.
// - Favor Swift Concurrency (async/await) in Services and ViewModels.
// - Write small, focused types; prefer composition over inheritance.
