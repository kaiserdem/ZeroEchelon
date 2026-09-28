import Foundation

struct CivicMockCatalog: Codable, Hashable, Sendable {
    var version: String
    var consultations: [CivicConsultation]
    var clinics: [CivicClinic]
    var pharmacies: [CivicPharmacy]
    var donationCenters: [CivicDonationCenter]
}

struct CivicConsultation: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
    var specialty: LocalizedText
    var formats: LocalizedText
    var priceNote: LocalizedText
    var exampleURL: String

    func specialtyText(for locale: ContentLocale) -> String {
        specialty.text(for: locale)
    }

    func formatsText(for locale: ContentLocale) -> String {
        formats.text(for: locale)
    }

    func priceNoteText(for locale: ContentLocale) -> String {
        priceNote.text(for: locale)
    }
}

struct CivicClinic: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
    var address: String
    var hours: LocalizedText
    var phone: String

    func hoursText(for locale: ContentLocale) -> String {
        hours.text(for: locale)
    }
}

struct CivicPharmacy: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
    var address: String
    var hours: LocalizedText
    var phone: String
    var isDutyNight: Bool

    func hoursText(for locale: ContentLocale) -> String {
        hours.text(for: locale)
    }
}

struct CivicDonationCenter: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
    var address: String
    var hours: LocalizedText
    var phone: String
    var signupURL: String

    func hoursText(for locale: ContentLocale) -> String {
        hours.text(for: locale)
    }
}
