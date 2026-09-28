import SwiftUI
import UIKit

struct CivicHubView: View {
    var locale: ContentLocale
    var catalog: CivicMockCatalog
    var onClose: () -> Void

    /// Loads bundled `civic-mock.json`. Throws if the resource is missing or invalid.
    static func make(
        locale: ContentLocale,
        onClose: @escaping () -> Void,
        bundle: Bundle = .main
    ) throws -> CivicHubView {
        CivicHubView(
            locale: locale,
            catalog: try CivicMockStore.loadBundled(bundle: bundle),
            onClose: onClose
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            CivicChrome.backBar(
                backTitle: locale == .uk ? "Назад" : "Back",
                action: onClose
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NavigationLink {
                        CivicConsultationListView(locale: locale, items: catalog.consultations)
                    } label: {
                        CivicChrome.navCard(
                            title: locale == .uk ? "Онлайн-консультація" : "Online consultation",
                            subtitle: locale == .uk
                                ? "Розмова з лікарем, коли це не 112"
                                : "Talk to a doctor when it is not 112"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        CivicClinicListView(locale: locale, items: catalog.clinics)
                    } label: {
                        CivicChrome.navCard(
                            title: locale == .uk ? "Запис у клініку" : "Clinic appointment",
                            subtitle: locale == .uk
                                ? "Заклад поруч · телефон на картці"
                                : "Nearby facility · phone on the card"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        CivicPharmacyListView(locale: locale, items: catalog.pharmacies)
                    } label: {
                        CivicChrome.navCard(
                            title: locale == .uk ? "Аптека" : "Pharmacy",
                            subtitle: locale == .uk
                                ? "Чергові аптеки міста"
                                : "City duty pharmacies"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        CivicDonationListView(locale: locale, items: catalog.donationCenters)
                    } label: {
                        CivicChrome.navCard(
                            title: locale == .uk ? "Донорство крові" : "Blood donation",
                            subtitle: locale == .uk
                                ? "Центр крові · запис у їхньому каналі"
                                : "Blood center · sign up in their channel"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            EmergencyBar(
                locale: locale,
                show101: false,
                prioritize101: false,
                emphasizeCall: false
            ) { number in
                CivicChrome.dial(number)
            }
        }
        .background(CivicTheme.canvas.ignoresSafeArea())
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
    }
}

/// Shared chrome for civic screens (cards, dial / open URL).
enum CivicChrome {
    static func dial(_ number: String) {
        let trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "tel:\(trimmed)") else { return }
        UIApplication.shared.open(url)
    }

    static func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }

    @ViewBuilder
    static func backBar(
        backTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.backward")
                        .font(.body.weight(.bold))
                    Text(backTitle)
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(CivicTheme.accent)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(CivicTheme.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CivicTheme.border)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    static func navCard(title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(CivicTheme.buttonFont)
                    .foregroundStyle(CivicTheme.ink)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(CivicTheme.helperFont)
                    .foregroundStyle(CivicTheme.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CivicTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            CivicTheme.surface,
            in: RoundedRectangle(cornerRadius: CivicTheme.corner)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CivicTheme.corner)
                .stroke(CivicTheme.border, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    static func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(CivicTheme.buttonFont)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    CivicTheme.accent,
                    in: RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    static func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(CivicTheme.buttonFont)
                .foregroundStyle(CivicTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    CivicTheme.secondaryFill,
                    in: RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                        .stroke(CivicTheme.border, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    static func sectionScaffold<Content: View>(
        locale: ContentLocale,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        CivicSectionScaffold(locale: locale, content: content)
    }
}

/// Separate type so `@Environment(\.presentationMode)` can pop the pushed section.
private struct CivicSectionScaffold<Content: View>: View {
    var locale: ContentLocale
    var content: () -> Content

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            CivicChrome.backBar(
                backTitle: locale == .uk ? "Назад" : "Back",
                action: { presentationMode.wrappedValue.dismiss() }
            )

            ScrollView {
                content()
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            EmergencyBar(
                locale: locale,
                show101: false,
                prioritize101: false,
                emphasizeCall: false
            ) { number in
                CivicChrome.dial(number)
            }
        }
        .background(CivicTheme.canvas.ignoresSafeArea())
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
    }
}
