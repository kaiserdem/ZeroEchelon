import SwiftUI

struct CivicConsultationListView: View {
    var locale: ContentLocale
    var items: [CivicConsultation]

    var body: some View {
        CivicChrome.sectionScaffold(
            locale: locale
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(items) { item in
                    consultationCard(item)
                }
            }
        }
    }

    @ViewBuilder
    private func consultationCard(_ item: CivicConsultation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.name)
                .font(CivicTheme.buttonFont)
                .foregroundStyle(CivicTheme.ink)

            Text(item.specialtyText(for: locale))
                .font(CivicTheme.helperFont)
                .foregroundStyle(CivicTheme.ink)

            Text(item.formatsText(for: locale))
                .font(CivicTheme.helperFont)
                .foregroundStyle(CivicTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.priceNoteText(for: locale))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CivicTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            CivicChrome.primaryButton(
                title: locale == .uk ? "Відкрити приклад" : "Open example"
            ) {
                CivicChrome.open(item.exampleURL)
            }
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
}

struct CivicClinicListView: View {
    var locale: ContentLocale
    var items: [CivicClinic]

    var body: some View {
        CivicChrome.sectionScaffold(
            locale: locale
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(items) { item in
                    placeCard(
                        name: item.name,
                        address: item.address,
                        hours: item.hoursText(for: locale),
                        phone: item.phone
                    )
                }
            }
        }
    }
}

struct CivicPharmacyListView: View {
    var locale: ContentLocale
    var items: [CivicPharmacy]

    var body: some View {
        CivicChrome.sectionScaffold(
            locale: locale
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 12) {
                        if item.isDutyNight {
                            Text(locale == .uk ? "Чергова аптека" : "Night duty")
                                .font(CivicTheme.badgeFont)
                                .foregroundStyle(CivicTheme.danger)
                        }

                        Text(item.name)
                            .font(CivicTheme.buttonFont)
                            .foregroundStyle(CivicTheme.ink)

                        Text(item.address)
                            .font(CivicTheme.helperFont)
                            .foregroundStyle(CivicTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(item.hoursText(for: locale))
                            .font(CivicTheme.helperFont)
                            .foregroundStyle(CivicTheme.ink)

                        CivicChrome.primaryButton(
                            title: locale == .uk ? "Зателефонувати" : "Call"
                        ) {
                            CivicChrome.dial(item.phone)
                        }
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
            }
        }
    }
}

struct CivicDonationListView: View {
    var locale: ContentLocale
    var items: [CivicDonationCenter]

    var body: some View {
        CivicChrome.sectionScaffold(
            locale: locale
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.name)
                            .font(CivicTheme.buttonFont)
                            .foregroundStyle(CivicTheme.ink)

                        Text(item.address)
                            .font(CivicTheme.helperFont)
                            .foregroundStyle(CivicTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(item.hoursText(for: locale))
                            .font(CivicTheme.helperFont)
                            .foregroundStyle(CivicTheme.ink)

                        CivicChrome.primaryButton(
                            title: locale == .uk ? "Записатися" : "Sign up"
                        ) {
                            CivicChrome.open(item.signupURL)
                        }

                        CivicChrome.secondaryButton(
                            title: locale == .uk ? "Зателефонувати" : "Call"
                        ) {
                            CivicChrome.dial(item.phone)
                        }
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
            }
        }
    }
}

// MARK: - Shared place card

private extension CivicClinicListView {
    @ViewBuilder
    func placeCard(name: String, address: String, hours: String, phone: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(name)
                .font(CivicTheme.buttonFont)
                .foregroundStyle(CivicTheme.ink)

            Text(address)
                .font(CivicTheme.helperFont)
                .foregroundStyle(CivicTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Text(hours)
                .font(CivicTheme.helperFont)
                .foregroundStyle(CivicTheme.ink)

            CivicChrome.primaryButton(
                title: locale == .uk ? "Зателефонувати" : "Call"
            ) {
                CivicChrome.dial(phone)
            }
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
}
