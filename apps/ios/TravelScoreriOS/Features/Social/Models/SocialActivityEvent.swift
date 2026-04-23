import Foundation

enum SocialActivityEventType: String, Codable {
    case bucketListAdded = "bucket_list_added"
    case countryVisited = "country_visited"
    case nextDestinationChanged = "next_destination_changed"
    case profilePhotoUpdated = "profile_photo_updated"
    case currentCountryChanged = "current_country_changed"
    case homeCountryChanged = "home_country_changed"
}

struct SocialActivityEvent: Identifiable, Decodable {
    let id: UUID
    let actorUserId: UUID
    let eventType: SocialActivityEventType
    let metadata: [String: SocialActivityMetadataValue]
    let createdAt: Date
    let actorProfile: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case actorUserId = "actor_user_id"
        case eventType = "event_type"
        case metadata
        case createdAt = "created_at"
        case actorProfile = "profiles"
    }
}
enum SocialActivityMetadataValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: SocialActivityMetadataValue])
    case array([SocialActivityMetadataValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: SocialActivityMetadataValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([SocialActivityMetadataValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }

        return nil
    }
}
