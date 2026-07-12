import SwiftUI
import NextDNSToolbarCore

struct StatusPill: View {
    let title: String
    let detail: String?
    let isPositive: Bool

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(isPositive ? Color.green : Color.red).frame(width: 8, height: 8)
            Text(title).fontWeight(.semibold)
            if let detail { Text(detail).foregroundStyle(.secondary) }
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassCapsule(tint: isPositive ? .green.opacity(0.18) : .red.opacity(0.14))
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .panelStyle()
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    var iconDomain: String?

    var body: some View {
        HStack(spacing: 9) {
            if let iconDomain { FaviconView(domain: iconDomain, size: 20) }
            Text(label).lineLimit(1)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .frame(height: 36)
    }
}

struct LogRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 10) {
            FaviconView(domain: entry.iconDomain, size: 24)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(entry.status == "blocked" ? Color.red : Color.green)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                        .offset(x: 2, y: 2)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.domain).lineLimit(1).font(.subheadline)
                HStack(spacing: 5) {
                    Text(entry.timestamp, style: .time)
                    if let device = entry.device?.name { Text("• \(device)") }
                    if let reason = entry.reason { Text("• \(reason)").lineLimit(1) }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

struct MetricBreakdown: View {
    let metrics: [LabeledMetric]

    var body: some View {
        if metrics.isEmpty {
            EmptyState(text: "No analytics for this period")
        } else {
            VStack(spacing: 12) {
                ForEach(metrics) { metric in
                    VStack(spacing: 5) {
                        HStack {
                            Text(metric.label).lineLimit(1)
                            Spacer()
                            Text(metric.queries.formatted()).monospacedDigit().foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(metric.queries), total: Double(max(metrics.first?.queries ?? 1, 1)))
                    }
                }
            }
            .font(.subheadline)
            .padding(12)
            .panelStyle()
        }
    }
}

struct EmptyState: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(24)
            .panelStyle()
    }
}

extension View {
    func panelStyle() -> some View {
        modifier(GlassPanelModifier(cornerRadius: 12, tint: nil))
    }

    func glassPanel(cornerRadius: CGFloat = 16, tint: Color? = nil) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius, tint: tint))
    }

    func glassCapsule(tint: Color? = nil) -> some View {
        modifier(GlassCapsuleModifier(tint: tint))
    }

    func glassControl() -> some View {
        modifier(GlassControlModifier())
    }
}

private struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.tint(tint), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 0.75)
                }
        }
    }
}

private struct GlassCapsuleModifier: ViewModifier {
    let tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.tint(tint), in: Capsule())
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

private struct GlassControlModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content
                .buttonStyle(.plain)
                .padding(7)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}

struct GlassBackdrop: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [Color.blue.opacity(0.17), Color.clear, Color.cyan.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.accentColor.opacity(0.13), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 300
            )
        }
    }
}
