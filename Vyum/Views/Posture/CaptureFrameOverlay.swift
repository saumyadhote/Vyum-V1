import SwiftUI

/// Dashed body outline plus corner guides, to help fit the whole body in the frame.
struct CaptureFrameOverlay: View {
    let angle: PostureAngle

    var body: some View {
        ZStack {
            BodyOutline()
                .stroke(
                    Color.vyumTextPrimary.opacity(0.7),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [8, 7])
                )
                // A side view is narrower than front or back.
                .scaleEffect(x: angle == .side ? 0.6 : 1)
                .padding(.vertical, Spacing.lg)
            CornerGuides()
                .stroke(Color.vyumAccentFill, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .padding(Spacing.md)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A simple standing figure, drawn in unit coordinates of its frame.
nonisolated struct BodyOutline: Shape {
    func path(in rect: CGRect) -> Path {
        // Keep the figure's proportions whatever the frame's shape.
        let height = min(rect.height, rect.width * 2.2)
        let width = height / 2.2
        let origin = CGPoint(x: rect.midX - width / 2, y: rect.midY - height / 2)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * width, y: origin.y + y * height)
        }

        var path = Path()
        // Head
        path.addEllipse(in: CGRect(origin: p(0.39, 0.0), size: CGSize(width: 0.22 * width, height: 0.11 * height)))
        // Body, clockwise from the left of the neck.
        path.move(to: p(0.45, 0.11))
        path.addLine(to: p(0.45, 0.14))
        path.addQuadCurve(to: p(0.2, 0.19), control: p(0.24, 0.14))
        path.addLine(to: p(0.12, 0.48))
        path.addQuadCurve(to: p(0.2, 0.49), control: p(0.16, 0.53))
        path.addLine(to: p(0.27, 0.27))
        path.addLine(to: p(0.29, 0.52))
        path.addLine(to: p(0.31, 0.97))
        path.addLine(to: p(0.46, 0.97))
        path.addLine(to: p(0.5, 0.58))
        path.addLine(to: p(0.54, 0.97))
        path.addLine(to: p(0.69, 0.97))
        path.addLine(to: p(0.71, 0.52))
        path.addLine(to: p(0.73, 0.27))
        path.addLine(to: p(0.8, 0.49))
        path.addQuadCurve(to: p(0.88, 0.48), control: p(0.84, 0.53))
        path.addLine(to: p(0.8, 0.19))
        path.addQuadCurve(to: p(0.55, 0.14), control: p(0.76, 0.14))
        path.addLine(to: p(0.55, 0.11))
        return path
    }
}

/// Four L-shaped brackets marking the corners of the frame.
nonisolated struct CornerGuides: Shape {
    var length: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
        ]
        for (corner, dx, dy) in corners {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * length))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * length, y: corner.y))
        }
        return path
    }
}

#Preview {
    CaptureFrameOverlay(angle: .front)
        .aspectRatio(3 / 4, contentMode: .fit)
        .background(Color.vyumSurface)
        .padding()
        .background(Color.vyumBackground)
}
