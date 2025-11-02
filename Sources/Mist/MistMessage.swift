import Vapor

// Message types for WebSocket communication
enum Message: Codable
{
    case subscribe(component: String)
    case update(component: String, id: UUID?, html: String)

    private enum CodingKeys: String, CodingKey
    {
        case type
        case component
        case id
        case html
    }
    
    // Custom encoding to properly format the message
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self
        {
            case .subscribe(let component):
                try container.encode("subscribe", forKey: .type)
                try container.encode(component, forKey: .component)
                
            case .update(let component, let id, let html):
                try container.encode("update", forKey: .type)
                try container.encode(component, forKey: .component)
                try container.encode(id, forKey: .id)
                try container.encode(html, forKey: .html)
        }
    }
    
    // Custom decoding to handle the message format
    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type
        {
            case "subscribe":
                let component = try container.decode(String.self, forKey: .component)
                self = .subscribe(component: component)
                
            case "update":
                let component = try container.decode(String.self, forKey: .component)
                let id = try container.decodeIfPresent(UUID.self, forKey: .id)
                let html = try container.decode(String.self, forKey: .html)
                self = .update(component: component, /*action: action,*/ id: id, html: html)
                
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Invalid message type"
                    )
                )
        }
    }
}
