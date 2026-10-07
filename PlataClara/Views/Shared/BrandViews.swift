import SwiftUI

/// El logo de PlataClara: una P hecha con una moneda (asta, aro y un punto al centro).
/// Se dibuja con formas para que se vea nítido en cualquier tamaño y siga el modo claro u oscuro.
struct LogoMark: View {
    var size: CGFloat = 96
    var cornerRadius: CGFloat? = nil

    var body: some View {
        let u = size / 100
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius ?? size * 0.224, style: .continuous)
                .fill(Color(red: 0x0E / 255, green: 0x7C / 255, blue: 0x66 / 255))
            RoundedRectangle(cornerRadius: 4.5 * u)
                .fill(.white)
                .frame(width: 9 * u, height: 56.5 * u)
                .offset(x: 30 * u, y: 23.5 * u)
            Circle()
                .strokeBorder(.white, lineWidth: 9 * u)
                .frame(width: 41 * u, height: 41 * u)
                .offset(x: 33.5 * u, y: 23.5 * u)
            Circle()
                .fill(Color(red: 0xBF / 255, green: 0xF0 / 255, blue: 0xE1 / 255))
                .frame(width: 11 * u, height: 11 * u)
                .offset(x: 48.5 * u, y: 38.5 * u)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("PlataClara")
    }
}

/// Portada que se muestra un instante al abrir la app, sobre el mismo fondo que la pantalla de arranque de iOS.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                LogoMark(size: 120)
                VStack(spacing: 8) {
                    Text("PlataClara").font(.system(size: 36, weight: .heavy, design: .rounded))
                    Text("Tu plata, clara.").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
        }
    }
}
