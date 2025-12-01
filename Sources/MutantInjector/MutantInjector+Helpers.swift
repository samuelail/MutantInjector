//
//  MutantInjector+Helpers.swift
//  MutantInjector
//
//  Created by samuel Ailemen on 11/13/25.
//

import Foundation

public enum BodyMatchHelpers {
    public static func jsonContainsObject(
        where predicate: @escaping @Sendable ([String: Any]) -> Bool
    ) -> (@Sendable (Data?) -> Bool) {
        return { body in
            guard let body = body,
                  let json = try? JSONSerialization.jsonObject(with: body) else { return false }

            if let dict = json as? [String: Any] {
                return predicate(dict)
            }

            if let array = json as? [[String: Any]] {
                return array.contains(where: predicate)
            }

            return false
        }
    }
}
