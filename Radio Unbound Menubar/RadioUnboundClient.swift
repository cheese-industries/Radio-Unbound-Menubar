//
//  RadioUnboundClient.swift
//  Radio Unbound Menubar
//
//  Created by Daniel Lee on 2/18/26.
//

import Foundation

final class RadioUnboundClient {
    private let stationURL = URL(string: "https://api.live365.com/station/a94197")!

    func fetchCurrentTrack() async throws -> Track? {
        var req = URLRequest(url: stationURL)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(StationResponse.self, from: data).currentTrack
    }
}
