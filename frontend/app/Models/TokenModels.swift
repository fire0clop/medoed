// Models/TokenModels.swift

import Foundation

struct TokenPair: Decodable {
    let access_token: String
    let refresh_token: String
    let token_type: String
}
