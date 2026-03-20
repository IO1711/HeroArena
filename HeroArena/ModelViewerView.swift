import RealityKit
import SwiftUI

struct CharacterPreviewViewerView: UIViewRepresentable {
    @ObservedObject var controller: CharacterPreviewSceneController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        context.coordinator.installGestures(on: view)
        controller.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.controller = controller
        controller.attach(to: uiView)
    }
}

extension CharacterPreviewViewerView {
    final class Coordinator: NSObject {
        var controller: CharacterPreviewSceneController

        init(controller: CharacterPreviewSceneController) {
            self.controller = controller
        }

        func installGestures(on view: ARView) {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            panGesture.maximumNumberOfTouches = 1
            view.addGestureRecognizer(panGesture)

            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            view.addGestureRecognizer(pinchGesture)
        }

        @objc
        private func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            let rotationDelta = Float(translation.x) * 0.01
            Task { @MainActor [controller] in
                controller.rotateView(by: rotationDelta)
            }
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc
        private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            let scale = Float(gesture.scale)
            Task { @MainActor [controller] in
                controller.zoomView(by: scale)
            }
            gesture.scale = 1
        }
    }
}

struct ModelViewerView: UIViewRepresentable {
    @ObservedObject var controller: ModelSceneController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        context.coordinator.installGestures(on: view)
        controller.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.controller = controller
        controller.attach(to: uiView)
    }
}

extension ModelViewerView {
    final class Coordinator: NSObject {
        var controller: ModelSceneController

        init(controller: ModelSceneController) {
            self.controller = controller
        }

        func installGestures(on view: ARView) {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            panGesture.maximumNumberOfTouches = 1
            view.addGestureRecognizer(panGesture)

            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            view.addGestureRecognizer(pinchGesture)
        }

        @objc
        private func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            let rotationDelta = Float(translation.x) * 0.01
            Task { @MainActor [controller] in
                controller.rotateView(by: rotationDelta)
            }
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc
        private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            let scale = Float(gesture.scale)
            Task { @MainActor [controller] in
                controller.zoomView(by: scale)
            }
            gesture.scale = 1
        }
    }
}

struct ArenaBattleViewerView: UIViewRepresentable {
    @ObservedObject var controller: ArenaBattleSceneController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        context.coordinator.installGestures(on: view)
        controller.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.controller = controller
        controller.attach(to: uiView)
    }
}

extension ArenaBattleViewerView {
    final class Coordinator: NSObject {
        var controller: ArenaBattleSceneController

        init(controller: ArenaBattleSceneController) {
            self.controller = controller
        }

        func installGestures(on view: ARView) {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            panGesture.maximumNumberOfTouches = 1
            view.addGestureRecognizer(panGesture)

            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            view.addGestureRecognizer(pinchGesture)
        }

        @objc
        private func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            let rotationDelta = Float(translation.x) * 0.01
            Task { @MainActor [controller] in
                controller.rotateView(by: rotationDelta)
            }
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc
        private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            let scale = Float(gesture.scale)
            Task { @MainActor [controller] in
                controller.zoomView(by: scale)
            }
            gesture.scale = 1
        }
    }
}

struct FightShowdownViewerView: UIViewRepresentable {
    @ObservedObject var controller: FightShowdownSceneController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        context.coordinator.installGestures(on: view)
        controller.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.controller = controller
        controller.attach(to: uiView)
    }
}

extension FightShowdownViewerView {
    final class Coordinator: NSObject {
        var controller: FightShowdownSceneController

        init(controller: FightShowdownSceneController) {
            self.controller = controller
        }

        func installGestures(on view: ARView) {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            panGesture.maximumNumberOfTouches = 1
            view.addGestureRecognizer(panGesture)

            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            view.addGestureRecognizer(pinchGesture)
        }

        @objc
        private func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            let rotationDelta = Float(translation.x) * 0.01
            Task { @MainActor [controller] in
                controller.rotateView(by: rotationDelta)
            }
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc
        private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            let scale = Float(gesture.scale)
            Task { @MainActor [controller] in
                controller.zoomView(by: scale)
            }
            gesture.scale = 1
        }
    }
}

struct FightFighterViewerView: UIViewRepresentable {
    @ObservedObject var controller: FightFighterSceneController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        context.coordinator.installGestures(on: view)
        controller.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.controller = controller
        controller.attach(to: uiView)
    }
}

extension FightFighterViewerView {
    final class Coordinator: NSObject {
        var controller: FightFighterSceneController

        init(controller: FightFighterSceneController) {
            self.controller = controller
        }

        func installGestures(on view: ARView) {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            panGesture.maximumNumberOfTouches = 1
            view.addGestureRecognizer(panGesture)

            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            view.addGestureRecognizer(pinchGesture)
        }

        @objc
        private func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            let rotationDelta = Float(translation.x) * 0.01
            Task { @MainActor [controller] in
                controller.rotateView(by: rotationDelta)
            }
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc
        private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            let scale = Float(gesture.scale)
            Task { @MainActor [controller] in
                controller.zoomView(by: scale)
            }
            gesture.scale = 1
        }
    }
}
