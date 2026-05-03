# Contributing to Keystroke Viewer

Thank you for your interest in contributing to Keystroke Viewer! This guide will help you get started.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+
- No Apple Developer account needed for local builds

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/keystroke-viewer.git
   ```
3. Open `KeystrokeViewer.xcodeproj` in Xcode
4. Build and run (Cmd+R)
5. Grant Accessibility permission when prompted:
   **System Settings > Privacy & Security > Accessibility > Enable Keystroke Viewer**
6. Restart the app after granting permission

## Code Style

- **Types**: PascalCase (`AppSettings`, `KeyMonitor`)
- **Properties/Methods**: camelCase (`overlayEnabled`, `startMonitor()`)
- **Indentation**: 4 spaces
- **State**: Use `@State private var` for SwiftUI state, `let` for constants
- **Imports**: Keep imports minimal and at the top of the file
- **Comments**: Only add comments for non-obvious logic
- **Architecture**: Follow SwiftUI patterns, prefer async/await over Combine

## Making Changes

1. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Make your changes
3. Build and test locally — ensure no compiler warnings
4. Test with Accessibility permission enabled
5. Commit with a clear, descriptive message
6. Push to your fork and open a Pull Request

## Pull Request Guidelines

- Keep PRs focused on a single feature or fix
- Describe what changed and why in the PR description
- Include screenshots for UI changes
- Ensure the project builds without errors or warnings

## Reporting Issues

- Use GitHub Issues to report bugs or request features
- Include macOS version and steps to reproduce for bugs
- Check existing issues before creating a new one

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
