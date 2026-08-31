import SwiftUI
import RiveRuntime
import FittiDesign

/// The mascot, played from a Rive file when one exists.
///
/// Rive and the shader do different jobs and both are worth having. The shader
/// owns physics — squash, touch response, the liquid fill — because those want a
/// value per frame, not a state transition. Rive owns *performance*: blinking,
/// looking around, reacting when an outfit is saved. Animating those by hand is
/// tedious; running touch response through a state machine is the wrong shape.
///
/// If `fitti.riv` isn't in the bundle this falls back to the shader blob, so the
/// app is never broken by a missing animation file and a `.riv` can be dropped in
/// later with no code change.
struct RiveMascot: View {
    var size: CGFloat = 130
    /// 0...1. How well the current outfit works — drives the mascot's mood.
    var mood: Double = 0.5
    /// 0...1. Closet fullness, for the liquid fill in the fallback.
    var level: Double = 0

    @State private var viewModel: RiveViewModel? = Self.load()

    var body: some View {
        Group {
            if let viewModel {
                viewModel.view()
                    .frame(width: size, height: size)
                    .onChange(of: mood) { _, value in
                        viewModel.setInput("mood", value: value * 100)
                    }
                    .onChange(of: level) { _, value in
                        viewModel.setInput("level", value: value * 100)
                    }
                    .onTapGesture {
                        viewModel.triggerInput("poke")
                    }
            } else {
                FittiBlob(size: size, level: level)
            }
        }
        .accessibilityLabel("Fitti")
    }

    /// Rive throws if the file is absent, so this is a genuine "is it bundled"
    /// check rather than an error being swallowed.
    private static func load() -> RiveViewModel? {
        guard Bundle.main.url(forResource: "fitti", withExtension: "riv") != nil else {
            return nil
        }
        return RiveViewModel(fileName: "fitti", stateMachineName: "Fitti")
    }
}
